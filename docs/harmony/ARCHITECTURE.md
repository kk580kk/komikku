# 架构设计

## 1. 分层

```
┌─────────────────────────────────────────────┐
│ pages/           路由页面（@Entry）           │  ← 只做布局与事件绑定
│ components/      可复用 UI（@Component）      │
├─────────────────────────────────────────────┤
│ domain/          用例：GetLibrary, AddToLibrary, FetchChapters …
├─────────────────────────────────────────────┤
│ data/            仓储：RDB、偏好、下载记录     │
│ source/          内置图源：接口 + 各源实现     │
├─────────────────────────────────────────────┤
│ service/         网络、下载、通知、后台任务     │
│ util/            日志、时间、格式化            │
└─────────────────────────────────────────────┘
```

**依赖规则（硬性）**

| 层 | 允许依赖 | 禁止 |
|---|---|---|
| `pages` / `components` | `domain`、`model`、`util` | 直接 RDB、直接 HTTP |
| `domain` | `data` 接口、`source` 接口、`model` | 依赖 `pages` |
| `data` / `source` | `service`、`model`、`util` | 依赖 `domain`、`pages` |
| `service` | `util`、系统 Kit | 依赖业务层 |

> 违反依赖规则 = Review 打回。页面里出现 `relationalStore` 或 `http.createHttp()` 一律不接受。

## 2. 目录（目标态）

```
entry/src/main/ets/
├── entryability/EntryAbility.ets
├── pages/
│   ├── Index.ets                # Tabs：书架/浏览/更多
│   ├── MangaDetailPage.ets
│   └── ReaderPage.ets
├── components/
│   ├── MangaCard.ets
│   ├── ChapterRow.ets
│   └── EmptyState.ets
├── domain/
│   ├── GetLibrary.ets
│   ├── AddToLibrary.ets
│   ├── FetchPopular.ets
│   └── FetchChapters.ets
├── data/
│   ├── Database.ets             # RDB 初始化与迁移
│   ├── MangaRepository.ets
│   ├── ChapterRepository.ets
│   ├── CategoryRepository.ets
│   └── PreferenceStore.ets
├── source/
│   ├── Source.ets               # 接口 + Page 模型
│   ├── SourceRegistry.ets
│   └── mangadex/
│       ├── MangaDexSource.ets
│       └── MangaDexModels.ets
├── service/
│   ├── Http.ets                 # 请求封装、重试、限流、UA
│   ├── ImageLoader.ets          # M3
│   └── Downloader.ets           # M4
├── model/
│   └── Manga.ets                # Manga / Chapter / Category
└── util/
    ├── Logger.ets
    └── Time.ets
```

## 3. 状态管理

- 页面内：`@State`（本地）、`@Prop`（父传子只读）、`@Link`（双向）、`@Observed`+`@ObjectLink`（对象数组）
- 跨页：`AppStorage` 只放"会话级"状态（当前阅读的漫画、下载进度），**不放业务数据**
- 数据变更通知：仓储层暴露 `subscribe(callback)`（MVP 用简单回调 + 页面 `aboutToAppear` 重新拉取；后续可换 `@ohos.data.rdb` 的观察者或自建事件总线）

> MVP 不做复杂响应式：**页面进入时拉一次 + 操作后手动刷新**，避免过早引入状态框架。

## 4. 异步与并发

- 所有 I/O 用 `async/await`；页面回调里不写阻塞逻辑
- 重任务（解析、图片解码、批量入库）走 `taskpool`/`worker`，不占 UI 线程
- 每个请求带 `AbortController` 语义（ArkTS 里用请求句柄 + 取消标记），页面 `aboutToDisappear` 时取消
- 并发上限：网络 4 并发；图片解码 2 并发；下载 3 并发（可配置）

## 5. 错误处理

统一 `Result` 风格，**不把异常抛到 UI**：

```ts
export class Result<T> {
  ok: boolean;
  data?: T;
  error?: AppError;
}
```

- `AppError` 分三类：`NetworkError`（可重试）、`ParseError`（源问题，上报日志）、`StorageError`（本地异常）
- UI 只处理三种表现：空态、错误态（带重试）、加载态

## 6. 网络层约定

- 统一 UA：`Komikku/<version> (HarmonyOS; <deviceModel>)`
- 默认超时 15s，重试 2 次（指数退避），仅对 5xx/超时重试
- 每源独立令牌桶限流；MangaDex 遵守其 rate limit 头
- Cookie 持久化（E-H 需要，M5）
- 日志脱敏：不打印 URL 里的 token / Cookie

## 7. 图片管线（M3）

`ImageLoader`：内存 LRU（按字节计，默认 64MB）+ 磁盘缓存（应用沙箱 `cacheDir/covers`）。

- 解码用 `@ohos.multimedia.image` 的 `ImageSource` → `createPixelMap`
- 按目标尺寸采样解码（避免整图解码）
- 长条阅读器：预取窗口 ±3 页，滑出窗口释放 `PixelMap`

## 8. i18n 与主题

- 文案进 `resources/base/element/string.json`（英文）+ `resources/zh_CN/element/string.json`（中文）
- 不做运行时切换语言（跟随系统）
- 暗色：`resources/dark/element/color.json`，颜色一律引用 `$r('app.color.*')`，禁止硬编码色值（渐变占位除外）

## 9. 日志

统一 `Logger.ets` 包装 `hilog`：

```ts
Logger.info('source', 'fetch popular page=%{public}d', page)
```

- Domain 段位：`app` / `data` / `source` / `reader`
- Release 只输出 warn 及以上

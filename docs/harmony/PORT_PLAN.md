# Komikku → HarmonyOS 移植总纲

- 版本：v0.2（2026-11-06）— 路线已定
- 分支：`harmony/main`
- 工具链（本机实测）：DevEco Studio 26.0.0 · HarmonyOS SDK API 26 · hvigor 6.26.8 · 内置 JBR（无需另装 JDK）

## 决策记录

| 日期 | 决策 | 结论 |
|---|---|---|
| 2026-11-06 | 技术路线 | **A：ArkTS 原生重写**（放弃 KMP/CMP 复用） |
| 2026-11-06 | 图源策略 | **内置常用源**（放弃扩展 APK / JS 源 / 远程源） |
| 2026-11-06 | 平台范围 | 仅手机（`deviceTypes: ["phone"]`） |

选择 A + 内置源的直接后果：**Kotlin 代码一行都不复用**，但换来判断力最清晰、最不容易被上游生态绑架的实现路径；
同时"装不了 APK 扩展"这个致命问题被"内置源"绕开了——代价是失去社区图源生态，只保留我们内置的那几个源。

## 文档索引

| 文档 | 作用 |
|---|---|
| [MVP.md](MVP.md) | MVP 范围、P0 用户故事与验收指标 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 分层、目录、状态/并发/错误/网络约定 |
| [DATA_MODEL.md](DATA_MODEL.md) | RDB 表结构、迁移策略、仓储接口 |
| [ROADMAP.md](ROADMAP.md) | M0–M5 任务拆解、DoD、进度看板 |
| [ENGINEERING.md](ENGINEERING.md) | 分支/提交/代码规范、构建、测试、CI、发布 |
| [TESTING.md](TESTING.md) | 手工测试清单（按里程碑） |

---

## 1. 目标与非目标

**目标**

1. 在 HarmonyOS NEXT 手机上提供可日常使用的 Komikku：书架、内置图源浏览、详情、阅读器、下载、备份恢复。
2. 架构按 ArkTS 分层自洽，后续加源、加功能不依赖 Android 端。

**非目标（本期）**

- 平板 / 折叠屏 / 2in1 适配（`deviceTypes` 只声明 `phone`）。
- 与 Android 端功能逐项对齐（以 §8 的 P0 为准）。
- 扩展 APK 兼容（技术不可行）、JS 源运行时（已排除）。
- 放弃 Android 端：`app/` 保持现状，继续出包。

---

## 2. 硬约束

| 约束 | 说明 |
|---|---|
| 不能跑 APK | HarmonyOS NEXT 已移除 AOSP 兼容层；`v1.14.1` 的 APK 装不上 |
| 语言 | 应用层 ArkTS（TypeScript 严格子集）+ ArkUI 声明式 UI；底层可走 C/C++（NDK） |
| 打包 | DevEco Studio 26 / hvigor；产物 `.hap`，上架走 AppGallery Connect |
| 权限 | `module.json5` 声明 `ohos.permission.*`，敏感权限需用户授权与上架说明 |
| 三方库 | ohpm 生态；Android 的 AAR 全部不可用 |
| bundleName | 至少三段（正则 `^(字母)(\.\w+){2,}$`），`app.komikku` 会被 schema 拒绝 → 用 `app.komikku.harmony` |

---

## 3. 现状盘点（Android 端，作为功能参照系）

| 模块 | 文件 | 行数 | HarmonyOS 侧去向 |
|---|---:|---:|---|
| `app` | 944 | 159,441 | 全部重写：`entry/src/main/ets/pages|components` |
| `domain` | 177 | 6,555 | 重写为 `ets/domain`（用例类，逻辑直接翻译） |
| `data` | 44 | 3,550 | 重写为 `ets/data` + `@ohos.data.relationalStore` |
| `core/common` | 65 | 5,014 | 重写为 `ets/core`（网络/存储/工具） |
| `source-api` | 53 | 4,254 | 重写为 `ets/source`（内置源接口，不再对扩展开放） |
| `presentation-core` | 49 | 5,696 | 重写为 `ets/components` |
| `source-local` + 本地导入 | 9 + 39 文件 | ~1,500 | `ets/service/localimport`（用 picker + file.fs 重做） |
| 合计 | 1,365 | 186,412 | — |

平台 API 密度（决定重写工作量，引用次数）：`androidx.compose` 6,240 · `coroutines` 1,056 · `Voyager` 350 ·
`okhttp` 252 · `Context` 181 · `coil3` 105 · `WorkManager` 92 · `Uri/Intent` 85 · `NotificationCompat` 37 ·
`SharedPreferences` 72 · `BitmapFactory/ImageDecoder` 47 · `PackageManager` 34 · `Unifile/SAF` 30 · `WebView` 11。

> 结论：UI 与平台层是主要工作量，业务逻辑（1.5 万行）翻译成本远低于重写 UI（16 万行）。

---

## 4. 为什么选 A（以及放弃了什么）

**选 A 的理由**

1. 目标平台是单平台（手机），不存在"一套代码多端跑"的诉求，跨端框架的收益被削弱。
2. ArkUI 是官方一等公民：动效、手势、无障碍、系统级能力（通知/后台/文件）不需要额外桥接层。
3. 没有 CMP 鸿蒙运行时（KMP 2.2.21 / CMP 1.9.2）与项目 Kotlin 2.4.20 的版本治理问题，也不引入 `.so` 包体与 JNI 桥。
4. 内置源策略下，图源解析逻辑本来就要重写，KMP 复用能省的部分进一步缩水。

**放弃的方案**

| 方案 | 放弃原因 |
|---|---|
| B：KMP + CMP | 首版 CMP 鸿蒙基于 KMP 2.2.21，落后项目 2 个 minor；UI 仍有大量 Android 专属 API 要替换；双构建体系维护成本高 |
| C：KMP 核心 + ArkUI | Kotlin↔ArkTS 桥接（akinterop）在数据模型/协程/Flow 上的摩擦面大，收益不抵复杂度 |

**接受的成本**

- 双端两套实现，功能新增要写两遍（或用文档约定 P0 功能集，Android 端优先）。
- 图源只有内置的几个，用户不能自行安装扩展。
- 16 万行 UI 的重写工期（见 §8）。

---

## 5. 目标架构

```
entry/src/main/ets/
├── entryability/EntryAbility.ets     # 应用入口（窗口、日志、生命周期）
├── pages/                            # 路由页面（main_pages.json 登记）
│   ├── Index.ets                     # 主框架：书架 / 浏览 / 更多
│   ├── MangaDetailPage.ets
│   └── ReaderPage.ets                # M3
├── components/                       # 可复用 UI（卡片、筛选栏、空状态…）
├── model/                            # Manga / Chapter / Category / Track …
├── data/                             # 仓储：RDB、偏好、下载记录
├── domain/                           # 用例：GetLibrary、UpdateLibrary、ImportLocal …
├── source/                           # 内置图源接口 + 各源实现（MangaDex、E-H…）
├── service/                          # 网络、下载、通知、后台任务、备份
└── util/                             # 日志、时间、格式化
```

分层约定：`pages/components` 只依赖 `domain`；`domain` 依赖 `data` 与 `source` 的接口；`source` 只依赖
`service/network` 与 `model`。禁止页面直接发 HTTP。

**状态管理**：页面内用 `@State/@Prop/@Link` 与 `@Observed/@ObjectLink`；跨页共享用 `AppStorage`；
异步任务统一 `TaskPool`/`Worker`（下载、解析、图片解码不占 UI 线程）。

---

## 6. 能力映射（Android → HarmonyOS）

| Android | HarmonyOS / ArkTS | 备注 |
|---|---|---|
| `Context` / `Uri` | `UIAbilityContext` / `uri` 字符串 | — |
| SAF + `UniFile` | `@ohos.file.picker` + `@ohos.file.fs` | 目录授权需 `DocumentViewPicker` |
| SQLDelight + SQLCipher | `@ohos.data.relationalStore`（RDB，内置 SQLite） | 无 SQLCipher 鸿蒙版；加密需求另评估 |
| OkHttp + Coil | `@ohos.net.http` / `rcp` + `@ohos.multimedia.image` | 图片缓存自建（内存 LRU + 磁盘） |
| WorkManager | `@ohos.resourceschedule.workScheduler` + `backgroundTaskManager` | 最小间隔/配额受限，任务模型要重排 |
| `NotificationCompat` | `@ohos.notificationManager` | 通知渠道 + 权限申请 |
| `WebView`（CF 挑战/登录） | `@ohos.web.webview` | Cookie 与 JS 注入 API 不同 |
| `SharedPreferences` / DataStore | `@ohos.data.preferences` | — |
| Voyager 导航 | `router`（当前）→ `Navigation`/`NavPathStack`（页面多了之后迁移） | 当前骨架用 `router` |
| QuickJS | 需要时用 NDK 交叉编译 | 仅在内置源需要 JS 执行时考虑 |
| `PackageManager` 装扩展 | 无 | 由内置源替代 |

---

## 7. 内置图源方案（M2）

**源接口**（对应 Android `source-api` 的最小面）：

```ts
export interface Source {
  readonly id: string;
  readonly name: string;
  readonly lang: string;
  popular(page: number): Promise<Manga[]>;
  search(query: string, page: number): Promise<Manga[]>;
  details(manga: Manga): Promise<Manga>;
  chapters(manga: Manga): Promise<Chapter[]>;
  pages(chapter: Chapter): Promise<Page[]>;
}
```

**首批源**：MangaDex（JSON API，最稳）→ E-Hentai（HTML + Cookie/CF，需 WebView 兜底）→ NHentai（JSON）。
**解析**：ArkTS 无 jsoup；JSON 直接映射，HTML 用轻量选择器（自研 `HtmlQuery` 或选一个 ohpm 解析库）。
**频控**：每个源独立令牌桶 + 全局并发上限（对应 Android 端 OkHttp 拦截器 + `RateLimitInterceptor`）。

---

## 8. 里程碑

| 阶段 | 内容 | 出口标准 | 状态 |
|---|---|---|---|
| **M0** 工具链 + 骨架 | 工程可构建；三 Tab；书架网格；详情页（Mock 数据） | `./build.sh` 出 HAP，页面可交互 | ✅ 已完成 |
| **M1** 数据层（1 周） | RDB 建表/迁移、仓储、偏好设置、书架接真数据 | 冷启动读库 < 300ms；增删改查有单测 | 🚧 进行中 |
| **M2** 图源引擎（2 周） | 网络层、源接口、MangaDex，浏览/搜索/详情/章节 | 能从 MangaDex 搜索并加入书架、拉到章节 | ⬜ |
| **M3** 阅读器（2 周） | 图片解码/缓存、长条与翻页、手势缩放、进度 | 连续阅读 30 分钟无 OOM | ⬜ |
| **M4** 下载与后台（1.5 周） | 下载队列、通知、后台任务、断点续传 | 后台下载 20 章全部成功 | ⬜ |
| **M5** 补全（2–3 周） | E-H/NH 源、备份恢复、本地导入、追踪 | P0 功能对齐 Android 端 | ⬜ |

P0 功能集：书架（分类/筛选/搜索）、内置源浏览与搜索、详情、阅读器、下载、本地导入、备份恢复。

---

## 9. 风险

| 风险 | 影响 | 对策 |
|---|---|---|
| HTML 解析库缺失 | E-H 类源难做 | 先做 JSON 源（MangaDex/NH），HTML 源用 WebView 注入 + 轻量解析兜底 |
| 反爬（Cloudflare） | E-H 不可用 | WebView 过挑战 + 持久化 Cookie；必要时降级为"仅已登录可用" |
| 阅读器性能 | 长条图 + 高清解码 | 分页解码、`PixelMap` 复用、显存上限、预取窗口可调 |
| 后台调度限制 | 库更新/下载被系统打断 | 长时任务申请 + 断点续传 + 前台通知 |
| 双端维护 | 功能不同步 | 冻结 Android 端新功能，鸿蒙优先；文档记录差异 |
| 合规/上架 | 审核不过 | 仅内置合规源，不提供扩展安装入口 |

---

## 10. 分支策略

| 分支 | 用途 |
|---|---|
| `master` | 纯上游镜像（`upstream/master`），只快进 |
| `feat/*` | Android 端功能 |
| `harmony/main` | 鸿蒙主干（本分支） |
| `harmony/<topic>` | 鸿蒙子任务 |

上游同步：`git switch harmony/main && git merge master`（冲突几乎只出现在 `app/`、`docs/`，鸿蒙侧独立目录）。

---

## 11. 待决

1. M1 是否引入 SQLCipher 等价加密（RDB 无内置加密）？还是接受明文库 + 应用沙箱？
2. 阅读器优先做长条还是翻页？（影响 M3 排期）
3. 内置源首发范围：仅 MangaDex，还是 MangaDex + NH？

# Komikku → HarmonyOS 移植总纲

- 状态：草案 v0.1（2026-11-06）
- 分支：`harmony/main`（鸿蒙主干，从 `master` = 上游 v1.14.1 之后切出）
- 决策：路线待定（见 §5、§11）

---

## 1. 目标与非目标

**目标**

1. 在 HarmonyOS NEXT（纯血鸿蒙，API 17+）手机上提供可日常使用的 Komikku：书架、浏览、详情、阅读器、下载、追踪、本地导入。
2. 与 Android 端共享尽可能多的非 UI 逻辑，避免两套业务代码长期漂移。

**非目标（本期）**

- 平板 / 折叠屏 / PC / 车机适配（UI 响应式预留，但不作为验收项）。
- 与 Android 端功能 100% 对齐（以 P0 功能集为准，见 §8）。
- 放弃 Android 端：Android 端继续维护，这条线只是新增平台。

---

## 2. 硬约束

| 约束 | 说明 |
|---|---|
| 不能跑 APK | HarmonyOS NEXT 已移除 AOSP 兼容层，`v1.14.1` 的 APK 无法安装；必须产出 `.hap` |
| 语言 | 应用层为 ArkTS（TypeScript 超集）+ ArkUI 声明式 UI；底层可走 C/C++（NDK）、Native API |
| 打包 | DevEco Studio 6.0+ / hvigor；`AppScope/app.json5` + `entry` 模块；上架走 AppGallery Connect |
| 权限 | 需在 `module.json5` 声明 `ohos.permission.*`，敏感权限需用户授权 + 上架审核说明 |
| 三方库 | ohpm 生态；Android 的 AAR 全部不可用 |

> 结论：**UI 层 100% 重写**；业务逻辑能复用多少，取决于选哪条路线。

---

## 3. 现状盘点

代码量（`git ls-files` 统计，Kotlin）：

| 模块 | 文件 | 行数 | 说明 |
|---|---:|---:|---|
| `app` | 944 | 159,441 | UI（Compose）+ ScreenModel + DI + Worker，几乎全是 Android 绑定 |
| `domain` | 177 | 6,555 | 用例/仓库接口，`kotlin("android")` |
| `data` | 44 | 3,550 | SQLDelight 实现，`kotlin("android")` |
| `core/common` | 65 | 5,014 | OkHttp、存储、工具，`kotlin("android")` |
| `source-api` | 53 | 4,254 | 扩展 API，**已是 KMP**（`commonMain` + `androidMain`） |
| `presentation-core` | 49 | 5,696 | 共享 Compose 组件，Android |
| `source-local` | 9 | 721 | **KMP** |
| `i18n-kmk` / `i18n` / `i18n-sy` | — | — | moko-resources，**KMP** |
| 合计 | 1,365 | 186,412 | |

平台 API 使用面（引用次数，决定平台层工作量）：

| Android API | app | 其它模块 |
|---|---:|---:|
| `androidx.compose.*` | 6,240 | — |
| `kotlinx.coroutines` | 1,056 | 多 |
| `cafe.adriel.voyager`（导航） | 350 | — |
| `okhttp3` | 252 | 多 |
| `android.content.Context` | 181 | 多 |
| `coil3` | 105 | — |
| `androidx.work`（后台任务） | 92 | 0 |
| `android.net.Uri` / `Intent` | 44 / 41 | 少量 |
| `NotificationCompat` | 37 | 0 |
| `SharedPreferences` | 39 | 33 |
| `BitmapFactory` / `ImageDecoder` | 33 / 14 | 少量 |
| `PackageManager`（扩展 APK 安装） | 26 | 8 |
| `com.hippo.unifile`（SAF 封装） | 30 | — |
| `android.webkit.WebView` | 6 | 5 |

关键依赖版本：Kotlin **2.4.20**、AndroidX Compose BOM **2026.06.01**、OkHttp 5.3.2、SQLDelight 2.3.2、Coil 3.5.0、Voyager 1.1.0-beta03。

---

## 4. 三条候选路线

| | A. ArkTS 全量重写 | B. KMP + CMP 复用 | C. 混合（KMP 核心 + ArkUI 页面） |
|---|---|---|---|
| UI | ArkUI 从零写 ~16 万行 | Compose Multiplatform（CMP）跑在鸿蒙渲染层 | ArkUI 写页面，逻辑调 Kotlin `.so` |
| 逻辑复用 | 0（需 ArkTS 重写 domain/data） | 高（domain/data/core/source-api 迁 KMP） | 中（只复用纯逻辑，UI 数据需跨语言） |
| 原生体验/包体 | 最好 / 最小 | 有运行时与图形缓冲开销 | 好 |
| 生态成熟度 | 官方一等公民 | 依赖 CPF-KMP-CMP（2026-09 首个正式版） | 中 |
| 双端维护成本 | 高（两套业务代码） | 低 | 中 |
| 预估（1–2 人全职） | 6–9 个月 | 4–6 个月 | 5–7 个月 |

**已确认的利好**：鸿蒙版 KMP&CMP 首个正式版已于 2026-09 发布——基于 KMP 2.2.21 / CMP 1.9.2，提供 `compose.ui/foundation/material/material3` 的鸿蒙实现、Kotlin↔ArkTS 互操作（akinterop）、DevEco 6.0.0+ / API 17+、统一渲染（API 19+）。这使路线 B 从"理论可行"变成"有官方社区背书的可行"。参见 [KMP&CMP 鸿蒙首版本发布](https://android.tgbus.com/news/244787) 与 [华为 KMP&CMP 资料页](https://developer.huawei.com/consumer/cn/blog/topic/03228093828012444)。

**版本落差（路线 B 的最大技术风险）**：本项目 Kotlin 2.4.20 / AndroidX Compose 2026.06，而鸿蒙 KMP&CMP 首版对齐 KMP 2.2.21 / CMP 1.9.2。两条线不能共用同一套 Gradle 配置，必须**独立构建**（见 §6），且在 M0 阶段就要验证。

---

## 5. 推荐

**推荐路线 B（KMP + CMP），并以 M0 作为硬门禁**：如果 M0 无法在真机上稳定跑通（启动、滚动、图片、返回栈），退回路线 C（ArkUI 页面 + KMP 核心），而不是 A——因为 A 等于把 16 万行 UI 和 1.5 万行业务逻辑全部重写一遍。

推荐理由：

1. 现有代码已经是 Compose 范式，CMP 的 API 形态最接近，迁移是"改依赖 + 删 Android 专属调用"，不是"重新设计界面"。
2. `source-api`、`i18n`、`source-local` 已是 KMP，说明项目结构本身对多平台友好。
3. 共享业务逻辑后，图源/解析/同步这类高频改动只需改一处。

---

## 6. 目标仓库布局

```
komikku/
├── app/                 # 保留：Android 端（现状不动）
├── shared/              # 新增：KMP 共享层（独立 Gradle 构建）
│   ├── domain/          # 由 domain/ 迁入，去 Android 化
│   ├── data/            # SQLDelight + 平台 driver（expect/actual）
│   ├── core/            # 网络/存储/工具
│   └── source-api/      # 现有 KMP 模块
├── harmonyApp/          # 新增：DevEco 工程（ArkTS 壳 + CMP 页面 + 平台服务）
│   ├── AppScope/
│   ├── entry/           # EntryAbility、页面容器、平台能力（文件/通知/后台）
│   └── oh-package.json5
└── docs/harmony/        # 本目录
```

要点：

- `shared/` 用**独立的 `settings.gradle.kts` + Gradle wrapper**，避免把 ohos target 引入现有 Android 构建（Kotlin 版本冲突）。
- `harmonyApp/` 由 DevEco 打开与签名；CMP 产物以 `.so`/har 形式被 `entry` 引用。
- Android 端一行不改；共享层用"复制 + 逐步收敛"而不是"直接改 Android 模块"，保证 Android 能持续出包。

---

## 7. 平台能力映射

| Android | HarmonyOS 替代 | 迁移难度 |
|---|---|---|
| `Context` / `Uri` | `UIAbilityContext` / `uri` 字符串 | 低 |
| SAF + `UniFile` | `@ohos.file.picker`（选择目录）+ `@ohos.file.fs` | 中（本地导入/下载目录要重设计） |
| SQLDelight `android-driver` | SQLDelight `ohos`/native driver（或 `@ohos.data.relationalStore`） | 中（SQLCipher 加密库需重编译） |
| `WorkManager`（库更新、备份、下载调度） | `@ohos.resourceschedule.workScheduler` + `backgroundTaskManager` 长时任务 | 高（调度语义不同，需重排任务模型） |
| `NotificationCompat` | `@ohos.notificationManager` + 通知渠道 | 低 |
| `WebView`（Cloudflare / 登录） | `@ohos.web.webview` | 中（Cookie 共享、JS 注入 API 不同） |
| `BitmapFactory` / `ImageDecoder` | `@ohos.multimedia.image`（ImageSource/PixelMap） | 中 |
| `SharedPreferences` / DataStore | `@ohos.data.preferences` | 低 |
| OkHttp | 保留（KMP）；或换 `@ohos.net.http` / `rcp` | 低（若 OkHttp 有 ohos target）/ 中 |
| Coil 3 | 无鸿蒙实现 → 自建图片管线（内存缓存 + 解码 + PixelMap 渲染） | 高 |
| Voyager（导航） | CMP 侧可用；或换 Navigation3（KMP&CMP 首版推荐） | 中 |
| QuickJS（JS 源） | 需用 ohos NDK 重新交叉编译 | 中 |
| `PackageManager` 安装扩展 APK | **无对应能力** | **阻断级**（见 §9.1） |

---

## 8. 里程碑

| 阶段 | 内容 | 出口标准 |
|---|---|---|
| **M0** 工具链验证（1–2 周） | DevEco 6 + SDK API 17+；CPF-KMP-CMP 跑通 Hello World；验证 OkHttp / SQLDelight / 图片解码在 ohos target 可用 | 真机上：启动、列表滚动、网络请求、写库、显示网络图片全部通过 |
| **M1** 共享层 KMP 化（3–4 周） | `domain`/`data`/`core` 去 Android 化；`shared/` 独立构建；SQLDelight schema 与迁移对齐 | `shared` 在 ohos target 编译通过；单元测试（现有 domain 测试）全绿 |
| **M2** 平台服务层（4–6 周） | 文件/下载/通知/后台任务/WebView/图片解码/偏好设置 | 能后台下载一章并落盘、能发通知、能打开登录 WebView |
| **M3** UI 骨架（6–10 周） | 主框架 + 导航 + 书架 + 浏览 + 详情 | P0 页面可交互，数据来自真实源 |
| **M4** 阅读器（4–6 周） | 翻页/长条/双页、缩放、进度保存、章节切换 | 连续阅读 1 小时无崩溃、内存平稳 |
| **M5** 功能补齐（4–6 周） | 追踪、备份恢复、本地导入、扩展机制 | 与 Android 端 P0 功能对齐 |

**P0 功能集**：书架（分类/筛选/搜索）、浏览源、详情（章节列表/收藏）、阅读器、下载、本地导入、备份恢复、扩展源加载。

---

## 9. 风险清单

### 9.1 扩展生态（最大风险，必须先决策）

Komikku 的图源绝大多数来自**外部扩展 APK**（`PackageManager` 安装、`source-api` 加载）。鸿蒙无法安装/加载 APK 扩展，这意味着"移植 UI 完成" ≠ "能用"。可选方案：

1. **内置源**：把常用源（MangaDex、E-H、NH、8Muses 等）用 Kotlin/ArkTS 内置实现 —— 工作量可控，但失去生态。
2. **JS 源**：定义新的 JS 扩展规范，用 QuickJS 解释执行 —— 可复制 Tachiyomi 社区 JS 源经验，但要重建分发渠道。
3. **远程源**：扩展跑在服务端，客户端只做协议 —— 合规与成本问题。

> 建议 M0 之后立刻做原型验证，不要把这个问题留到 M5。

### 9.2 CMP 鸿蒙成熟度 / 版本落差

首版 2026-09 发布，KMP 2.2.21 落后本项目 2 个 minor；控件覆盖、无障碍、输入法、动画可能缺能力。对策：M0 门禁 + 关键页面（书架、阅读器）先做性能基线。

### 9.3 阅读器性能

长条图 + 双页 + 高分辨率解码是内存与渲染压力最大的部分；CMP 鸿蒙侧统一渲染需 API 19+，低版本设备回退路径要预留。

### 9.4 后台下载与库更新

`workScheduler` 有最小间隔与配额限制，长时任务需申请 `backgroundTaskManager` 类型；下载队列模型可能要重写。

### 9.5 合规与上架

阅读类应用上架 AppGallery 需版权/内容合规材料；通知、后台、文件权限均需审核说明。

---

## 10. 分支策略

| 分支 | 用途 |
|---|---|
| `master` | 纯上游镜像（`upstream/master`），定期快进 |
| `feat/*` | Android 端功能开发 |
| `harmony/main` | 鸿蒙主干（本分支） |
| `harmony/<topic>` | 鸿蒙子任务，PR 合入 `harmony/main` |

上游同步：`git switch harmony/main && git merge master`（冲突集中在 `app/`，鸿蒙侧只关心 `shared/` 与 `docs/`，冲突面可控）。

---

## 11. 待决问题

1. **路线**：B（KMP+CMP，推荐）/ C（混合）/ A（ArkTS 重写）？
2. **扩展机制**：内置源 / JS 源 / 远程源？（影响 M4–M5 全部排期）
3. **人力与时间盒**：单人兼职还是团队？决定是否砍 P0 范围。
4. **是否保留 Android 端双线维护**（当前假设：保留）。

# Komikku · HarmonyOS（ArkTS 原生重写）

这是 `harmony/main` 分支下的鸿蒙端工程，**不是** Android 端的移植包装：HarmonyOS NEXT 不再兼容 APK，
因此 UI 与平台层全部用 ArkTS / ArkUI 重写，业务能力按模块逐个重建。

- 目标平台：HarmonyOS 手机（单设备类型 `phone`）
- 工具链：DevEco Studio **26.0.0**、HarmonyOS SDK **API 26**、hvigor **6.26.8**
- 应用标识：`app.komikku.harmony`（bundleName 至少三段，`app.komikku` 会被 schema 拒绝）
- 当前版本：`0.1.0`

## 当前进度（M0 已完成）

| 能力 | 状态 |
|---|---|
| 工程骨架 / 构建 / 打包 | ✅ `hvigorw assembleHap` 通过，产出未签名 HAP |
| 主框架（书架 / 浏览 / 更多 三 Tab） | ✅ |
| 书架网格（Mock 数据） | ✅ |
| 详情页 + 章节列表（Mock） | ✅ |
| 数据持久化（relationalStore，schema v2） | ✅ |
| 内置图源 MangaDex（热门/搜索/详情/章节/页面） | ✅ |
| 阅读器（长条、进度落库、章节切换） | ✅ |
| 下载与离线阅读（断点续传） | ✅ |
| 设置页（缓存/下载清理） | ✅ |
| 缩放、后台任务、通知进度 | ⬜ |

## 目录

```
harmonyApp/
├── AppScope/
│   ├── app.json5                 # bundleName / 版本 / 图标
│   └── resources/base/...
├── entry/
│   ├── build-profile.json5
│   └── src/main/
│       ├── module.json5          # Ability、权限（INTERNET）
│       ├── ets/
│       │   ├── entryability/EntryAbility.ets
│       │   ├── pages/Index.ets           # 三 Tab 主框架 + 书架
│       │   ├── pages/MangaDetailPage.ets # 详情 + 章节列表
│       │   ├── model/Manga.ets           # Manga / Chapter / 路由参数
│       │   └── data/LibraryRepository.ets# Mock 数据源（M1 换 RDB）
│       └── resources/
│           └── base/profile/main_pages.json
├── build-profile.json5
├── hvigorfile.ts
└── build.sh                      # 本机 CLI 构建脚本
```

## 构建

### 方式一：DevEco Studio（推荐，可预览 / 真机调试）

1. 打开 DevEco Studio → `File > Open` → 选择 `harmonyApp/`
2. 首次会提示同步；`File > Project Structure > Signing Configs` 勾选自动签名（需登录华为账号）
3. 运行 `entry`

### 方式二：命令行（本机已验证）

```bash
cd harmonyApp
./build.sh            # 产出 entry/build/default/outputs/default/entry-default-unsigned.hap
```

`build.sh` 做的事情：把 DevEco 自带的 Node 与 JBR 加进 `PATH`，设置 `DEVECO_SDK_HOME`，再调 `hvigorw`。
**hvigor 打包阶段需要 JDK**（缺 `JAVA_HOME` 会报 `Unable to locate a Java Runtime`），这里直接复用
DevEco 内置的 JBR，不额外安装 JDK。

未签名 HAP 只能用于本地检查；装到真机/模拟器需要 DevEco 里生成的调试签名。

## 约定

- 页面统一放 `entry/src/main/ets/pages/`，并登记到 `resources/base/profile/main_pages.json`
- 数据模型放 `model/`，仓储放 `data/`，与 Android 端 `domain` / `data` 的层次一一对应
- ArkTS 限制比 TypeScript 严：对象字面量必须有具名类型；`@State` 属性名不要和内置属性冲突
  （踩过坑：`tabIndex` 与 `CustomComponent` 冲突，改名 `activeTab`）
- 新增网络能力记得在 `module.json5` 里声明权限

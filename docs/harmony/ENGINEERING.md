# 工程规范

## 1. 分支与提交

| 分支 | 用途 | 合并方式 |
|---|---|---|
| `master` | 上游镜像，只快进 | — |
| `harmony/main` | 鸿蒙主干 | 只接受 PR/squash |
| `harmony/<topic>` | 子任务（`harmony/m1-data-layer`） | squash 合入主干 |

提交信息用 Conventional Commits：`<type>(<scope>): <subject>`，type 取 `feat|fix|refactor|docs|test|chore`，
scope 用模块名（`harmony`、`harmony-data`、`harmony-source`）。一个提交只做一件事。

## 2. 代码规范

**ArkTS 硬约束（编译器会拦）**

- 不允许 `any` / `unknown` 隐式流转；对象字面量必须有具名类型
- 不允许结构化类型推断函数参数；回调参数必须标注类型
- `@State`/`@Prop`/`@Link` 属性名不能与 `CustomComponent` 内置成员冲突（如 `tabIndex`、`id`、`width`）
- 不能在 `build()` 里写复杂表达式；拆 `@Builder` 或私有方法
- `struct` 内不要持有 `Context` 长期引用，用 `getContext(this)` 现取

**命名**

| 对象 | 规则 | 例 |
|---|---|---|
| 文件 | PascalCase，一文件一主类 | `MangaRepository.ets` |
| 类/接口 | PascalCase | `class Manga` |
| 方法/变量 | camelCase | `fetchChapters` |
| 常量 | UPPER_SNAKE | `DEFAULT_TIMEOUT_MS` |
| 数据库列 | snake_case | `source_id` |
| 页面 | `XxxPage.ets`，登记到 `main_pages.json` | `MangaDetailPage.ets` |

**文件头注释**：对外暴露的类/接口写一段说明，注明对应 Android 端的哪个类（便于对照）。

**禁止**

- 页面里直接 `import { relationalStore }` / `http`
- 硬编码颜色（走 `$r('app.color.*')`），渐变色除外
- `console.log`（用 `Logger`）
- 空 `catch`；异常必须记录或转成 `AppError`

## 3. 构建与本地校验

```bash
cd harmonyApp
./build.sh              # 等价 hvigorw assembleHap
```

每次提交前至少跑 `./build.sh`。后续（M1）加 `hvigorw codeLinter`（`code-linter.json5` 已就位）。

> 当前未配置签名，产出的是 `entry-default-unsigned.hap`，只用于本地校验。装真机请在 DevEco 里配置自动签名。

## 4. 测试

| 层次 | 工具 | 位置 | 覆盖要求 |
|---|---|---|---|
| 单元（纯逻辑） | `@ohos/hypium`（`src/test/`） | 仓储的 SQL 拼接、解析器、`Result` 工具 | 新增解析/仓储逻辑必须带 |
| 集成（设备） | `@ohos/hypium`（`src/ohosTest/`） | RDB 建表/迁移、网络层 | 里程碑 DoD 相关用例 |
| 手工 | 清单 | `docs/harmony/TESTING.md`（M1 建立） | 每个 M 结束走一遍 |

ArkTS 单测不能依赖真机的地方（如纯函数）优先放 `src/test/`。

## 5. CI

鸿蒙构建依赖 DevEco 命令行工具链（`hvigorw` + SDK + `JAVA_HOME`），**不能**用 GitHub 托管 runner 直接跑（缺 SDK 与签名）。

建议方案（待落地）：

1. 自建 runner（macOS 或 Linux + DevEco command line tools），安装 SDK API 26
2. Job：`./build.sh` + `hvigorw codeLinter` + 单元测试
3. 签名放在 runner 的 secrets 里，仅 `harmony/main` 出包

在 CI 落地前，合并门槛 = 本地 `./build.sh` 通过 + Review。

## 6. 版本与发布

- `AppScope/app.json5`：`versionCode` 单调递增，`versionName` 语义化
- 每个里程碑打 tag：`harmony-v0.1.0` …；tag 与 `ROADMAP.md` 看板同步
- 发布物：签名 HAP（内测走 AppGallery Connect 内部测试轨道）

## 7. 完成定义（DoD）

一个任务算完成，必须同时满足：

1. 代码合入 `harmony/main`
2. `./build.sh` 通过
3. 新增逻辑有对应单测，或说明为何不适合单测
4. 相关文档（架构/数据模型/路线图）同步更新
5. 手工清单中受影响项已验证

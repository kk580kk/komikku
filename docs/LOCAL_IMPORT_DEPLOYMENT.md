# 本地导入功能 - 部署说明

**功能模块**: 本地漫画导入（手动 + 自动）  
**更新日期**: 2026-03-11  
**适用分支**: master（或当前开发分支）

---

## 1. 前置条件

- **环境**: Android 开发环境，JDK 11+，Android SDK
- **项目**: Komikku 源码已克隆，可正常编译
- **设备**: 真机或模拟器，建议 Android 8.0+
- **存储**: 应用需有存储/本地目录访问权限（若使用本地文件夹导入）

---

## 2. 代码与版本库

### 2.1 确认待提交内容（提交前检查）

除 `.cursor` 目录外，以下文件应纳入版本控制并提交：

**已修改（Modified）**  
- `app/src/main/java/eu/kanade/domain/DomainModule.kt`  
- `app/src/main/java/eu/kanade/presentation/more/MoreScreen.kt`  
- `app/src/main/java/eu/kanade/presentation/more/settings/screen/SettingsAdvancedScreen.kt`  
- `app/src/main/java/eu/kanade/tachiyomi/di/AppModule.kt`  
- `app/src/main/java/eu/kanade/tachiyomi/ui/more/MoreTab.kt`  
- `data/src/main/java/tachiyomi/data/local/LocalSourceRepositoryImpl.kt`  
- `domain/src/main/java/tachiyomi/domain/local/interactor/LocalImportManager.kt`  
- `domain/src/main/java/tachiyomi/domain/local/repository/LocalSourceRepository.kt`  
- `i18n-kmk/src/commonMain/moko-resources/base/strings.xml`  
- `i18n-kmk/src/commonMain/moko-resources/zh-rCN/strings.xml`  
- `source-local/src/androidMain/kotlin/tachiyomi/source/local/LocalSource.kt`  
- `source-local/src/androidMain/kotlin/tachiyomi/source/local/io/LocalSourceFileSystem.kt`  

**新增（Untracked）**  
- `app/src/main/java/eu/kanade/tachiyomi/util/system/ImportNotificationHelper.kt`  
- `app/src/main/java/exh/ui/autoimport/`（含 `AutoImportScreen.kt`, `AutoImportScreenModel.kt` 等）  
- `app/src/test/java/exh/`（自动导入相关测试）  
- `domain/src/test/java/tachiyomi/domain/local/`（Domain 层测试）  

**文档（可选提交）**  
- `LOCAL_IMPORT_COMPLETE_REPORT.md`  
- `LOCAL_IMPORT_OPTIMIZATION_SUMMARY.md`  
- `NOTIFICATION_IMPLEMENTATION.md`  
- `docs/LOCAL_IMPORT_FEATURE.md`  
- `docs/LOCAL_IMPORT_TEST_CHECKLIST.md`  
- `docs/LOCAL_IMPORT_DEPLOYMENT.md`（本文档）  

### 2.2 提交命令示例

```bash
# 进入项目根目录
cd /path/to/komikku

# 查看状态（确认无 .cursor 被添加）
git status

# 添加功能代码与资源（不包含 .cursor）
git add app/src/main/java/eu/kanade/domain/DomainModule.kt
git add app/src/main/java/eu/kanade/presentation/more/MoreScreen.kt
git add app/src/main/java/eu/kanade/presentation/more/settings/screen/SettingsAdvancedScreen.kt
git add app/src/main/java/eu/kanade/tachiyomi/di/AppModule.kt
git add app/src/main/java/eu/kanade/tachiyomi/ui/more/MoreTab.kt
git add app/src/main/java/eu/kanade/tachiyomi/util/system/ImportNotificationHelper.kt
git add app/src/main/java/exh/
git add app/src/test/java/exh/
git add data/src/main/java/tachiyomi/data/local/LocalSourceRepositoryImpl.kt
git add domain/src/main/java/tachiyomi/domain/local/
git add domain/src/test/java/tachiyomi/domain/local/
git add i18n-kmk/src/commonMain/moko-resources/base/strings.xml
git add i18n-kmk/src/commonMain/moko-resources/zh-rCN/strings.xml
git add source-local/src/androidMain/kotlin/tachiyomi/source/local/LocalSource.kt
git add source-local/src/androidMain/kotlin/tachiyomi/source/local/io/LocalSourceFileSystem.kt

# 可选：添加文档
git add docs/LOCAL_IMPORT_*.md
git add LOCAL_IMPORT_*.md NOTIFICATION_IMPLEMENTATION.md

# 提交
git commit -m "feat(local): 本地导入功能 - 手动导入、自动导入、CBZ封面、后台通知"
```

---

## 3. 编译验证

### 3.1 Debug 构建

```bash
./gradlew clean
./gradlew assembleDebug
```

- **成功**: 输出 `BUILD SUCCESSFUL`，APK 位于  
  `app/build/outputs/apk/debug/app-*-debug.apk`
- **失败**: 根据报错修复后重新编译，直至通过。

### 3.2 单元测试（推荐）

```bash
./gradlew testDebugUnitTest
```

- 确保与本地导入、自动导入相关的单元测试全部通过。

### 3.3 Release 构建（发布时）

```bash
./gradlew assembleRelease
# 或
./gradlew bundleRelease
```

- 需配置签名与 `build.gradle` 中的 release 设置。

---

## 4. 安装与运行

### 4.1 通过 ADB 安装 Debug APK

```bash
adb install -r app/build/outputs/apk/debug/app-universal-debug.apk
```

- `-r`: 覆盖安装，保留数据（若需清数据可先卸载再安装）。

### 4.2 启动应用

```bash
adb shell am start -n eu.kanade.komikku.debug/eu.kanade.tachiyomi.ui.main.MainActivity
```

- 包名以实际 `build.gradle` 中 `applicationId` 为准（debug 多为 `eu.kanade.komikku.debug`）。

### 4.3 权限与存储

- 首次使用「导入本地下载」或访问本地目录时，按系统提示授予存储/媒体权限。
- 若使用自定义本地源目录，确保应用有该路径的访问权限（如 Android 11+ 分区存储限制）。

---

## 5. 功能入口与使用说明

### 5.1 手动导入（本地下载目录 → 书架）

1. 打开应用 → **设置** → **高级**
2. 找到并点击 **导入本地下载**
3. 在弹窗中可选：
   - **添加到默认分类**：将新导入漫画加入默认分类
   - **后台导入**：不阻塞界面，完成后通过通知栏查看结果
4. 点击 **导入**，等待完成；若选择后台导入，可关闭弹窗后稍后在通知栏查看「本地导入」通知（格式：`导入：X | 跳过：Y | 错误：Z`）。

### 5.2 自动导入（标题匹配 → 导入）

1. 打开应用 → **更多**（More）→ **自动导入**
2. 在输入框中输入漫画标题，**一行一个**
3. 可选：点击 **扫描本地文件夹** 再 **开始导入**（视实现而定）
4. 点击 **开始导入**，系统会按标题/关键词在扩展源中搜索并尝试导入
5. 结果在界面列表与通知栏中查看。

### 5.3 通知说明

- **本地导入完成**: 标题「本地导入」，内容为「导入：X | 跳过：Y | 错误：Z」，点击可回到应用
- **自动导入完成**: 以实际实现为准（如导入数、失败数等）

---

## 6. 配置与依赖

- **本地源路径**: 由应用/本地源模块配置决定，通常为应用可访问的下载或自定义目录
- **默认分类**: 在应用「设置 → 图书馆」中配置默认分类，导入时「添加到默认分类」会使用该分类
- **通知**: 依赖 Android 通知渠道与权限，首次建议在系统设置中确认应用通知未关闭

---

## 7. 故障排查

| 现象 | 可能原因 | 建议 |
|------|----------|------|
| 编译失败 | 依赖未同步、JDK 版本不符 | `./gradlew --stop` 后重新 `assembleDebug`，检查 JDK 与 Android SDK |
| 找不到「导入本地下载」 | 未正确合并/提交 UI 与菜单修改 | 确认 `SettingsAdvancedScreen.kt`、More 入口与字符串资源已提交 |
| 导入后无通知 | 通知权限关闭或渠道被禁用 | 检查系统设置中应用通知权限与渠道 |
| 自动导入无结果 | 标题与扩展源不一致、网络或源不可用 | 检查网络、扩展源可用性，尝试更短/更准确标题或关键词 |
| 封面不显示 | CBZ 内无有效图片或格式异常 | 确认 CBZ 内包含可解码图片，查看日志是否有解码错误 |

---

## 8. 版本与回滚

- 部署前建议在版本库打标签，便于回滚，例如：  
  `git tag -a local-import-v1 -m "Local import feature release"`
- 回滚：根据标签或 commit 执行 `git checkout <tag_or_commit>` 后重新编译安装（注意备份数据）。

---

**文档维护**: 随功能变更更新本文档中的路径、包名与操作步骤。  
**测试依据**: 详见 `docs/LOCAL_IMPORT_TEST_CHECKLIST.md`。

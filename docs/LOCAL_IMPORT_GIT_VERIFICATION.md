# 本地导入功能 - Git 提交验证清单

**用途**: 提交前确认所有相关代码已纳入版本库，且不包含 `.cursor` 等不应提交的目录。  
**更新日期**: 2026-03-11

---

## 1. 提交前检查

在项目根目录执行：

```bash
git status
```

### 1.1 应被提交的文件（本地导入相关）

**修改的文件 (12 个)**  
- [ ] `app/src/main/java/eu/kanade/domain/DomainModule.kt`  
- [ ] `app/src/main/java/eu/kanade/presentation/more/MoreScreen.kt`  
- [ ] `app/src/main/java/eu/kanade/presentation/more/settings/screen/SettingsAdvancedScreen.kt`  
- [ ] `app/src/main/java/eu/kanade/tachiyomi/di/AppModule.kt`  
- [ ] `app/src/main/java/eu/kanade/tachiyomi/ui/more/MoreTab.kt`  
- [ ] `data/src/main/java/tachiyomi/data/local/LocalSourceRepositoryImpl.kt`  
- [ ] `domain/src/main/java/tachiyomi/domain/local/interactor/LocalImportManager.kt`  
- [ ] `domain/src/main/java/tachiyomi/domain/local/repository/LocalSourceRepository.kt`  
- [ ] `i18n-kmk/src/commonMain/moko-resources/base/strings.xml`  
- [ ] `i18n-kmk/src/commonMain/moko-resources/zh-rCN/strings.xml`  
- [ ] `source-local/src/androidMain/kotlin/tachiyomi/source/local/LocalSource.kt`  
- [ ] `source-local/src/androidMain/kotlin/tachiyomi/source/local/io/LocalSourceFileSystem.kt`  

**新增的文件/目录**  
- [ ] `app/src/main/java/eu/kanade/tachiyomi/util/system/ImportNotificationHelper.kt`  
- [ ] `app/src/main/java/exh/ui/autoimport/`（AutoImportScreen.kt, AutoImportScreenModel.kt 等）  
- [ ] `app/src/test/java/exh/`（自动导入相关测试）  
- [ ] `domain/src/test/java/tachiyomi/domain/local/`（LocalImportManager 等测试）  

**文档（按需）**  
- [ ] `docs/LOCAL_IMPORT_FEATURE.md`  
- [ ] `docs/LOCAL_IMPORT_TEST_CHECKLIST.md`  
- [ ] `docs/LOCAL_IMPORT_DEPLOYMENT.md`  
- [ ] `docs/LOCAL_IMPORT_GIT_VERIFICATION.md`  
- [ ] `LOCAL_IMPORT_COMPLETE_REPORT.md`  
- [ ] `LOCAL_IMPORT_OPTIMIZATION_SUMMARY.md`  
- [ ] `NOTIFICATION_IMPLEMENTATION.md`  

### 1.2 不应提交的内容

- [ ] **`.cursor`** 目录及其内容（已加入 `.gitignore`，确认 `git status` 中未出现）
- [ ] `local.properties`、`*.jks`、敏感配置（见项目 `.gitignore`）

---

## 2. 一键添加命令（仅限上述功能与文档）

复制前请根据实际 `git status` 核对，避免误加无关文件：

```bash
# 功能代码与资源
git add app/src/main/java/eu/kanade/domain/DomainModule.kt \
  app/src/main/java/eu/kanade/presentation/more/MoreScreen.kt \
  app/src/main/java/eu/kanade/presentation/more/settings/screen/SettingsAdvancedScreen.kt \
  app/src/main/java/eu/kanade/tachiyomi/di/AppModule.kt \
  app/src/main/java/eu/kanade/tachiyomi/ui/more/MoreTab.kt \
  app/src/main/java/eu/kanade/tachiyomi/util/system/ImportNotificationHelper.kt \
  app/src/main/java/exh/ \
  app/src/test/java/exh/ \
  data/src/main/java/tachiyomi/data/local/LocalSourceRepositoryImpl.kt \
  domain/src/main/java/tachiyomi/domain/ \
  domain/src/test/java/tachiyomi/domain/local/ \
  i18n-kmk/src/commonMain/moko-resources/base/strings.xml \
  i18n-kmk/src/commonMain/moko-resources/zh-rCN/strings.xml \
  source-local/src/androidMain/kotlin/tachiyomi/source/local/LocalSource.kt \
  source-local/src/androidMain/kotlin/tachiyomi/source/local/io/LocalSourceFileSystem.kt

# 文档（可选）
git add docs/LOCAL_IMPORT_*.md LOCAL_IMPORT_*.md NOTIFICATION_IMPLEMENTATION.md .gitignore
```

---

## 3. 提交与验证

```bash
# 再次确认暂存区无 .cursor
git status

# 提交
git commit -m "feat(local): 本地导入功能 - 手动/自动导入、CBZ封面、后台通知与文档"

# 确认提交内容
git show --stat
```

---

## 4. 编译验证（提交前建议执行）

```bash
./gradlew assembleDebug
./gradlew testDebugUnitTest
```

- 两项均成功后再 push，便于 CI 或他人拉取后直接编译。

---

**说明**: 若仓库中已有 `.cursor` 的提交记录，可使用 `git rm -r --cached .cursor` 从版本库移除并提交，此后由 `.gitignore` 忽略。

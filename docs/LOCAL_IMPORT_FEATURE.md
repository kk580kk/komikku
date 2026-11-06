# Komikku 本地下载自动导入功能开发指南

## 功能概述
自动扫描本地源（Local Source）目录中的漫画文件夹，并将其导入到书架中，支持自动添加到默认分类。

## 用户路径
**设置 → 高级 → 数据 → 导入本地下载**

## 架构设计

### 分层架构
```
┌─────────────────────────────────────┐
│         Presentation Layer          │
│  (SettingsAdvancedScreen.kt)        │
│  - 导入按钮                         │
│  - 进度对话框                       │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│          Domain Layer               │
│  (tachiyomi.domain.local)           │
│  - LocalImportManager               │
│  - ScanLocalSource                  │
│  - GetLocalMangaDetails             │
│  - LocalSourceRepository (interface)│
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│           Data Layer                │
│  (tachiyomi.data.local)             │
│  - LocalSourceRepositoryImpl        │
└─────────────────────────────────────┘
```

## 核心文件

### 1. Domain 层

#### LocalImportManager.kt
**位置**: `domain/src/main/java/tachiyomi/domain/local/interactor/LocalImportManager.kt`

**职责**:
- 协调整个导入流程
- 管理导入状态（StateFlow）
- 处理业务逻辑（检查重复、添加到分类等）

**关键方法**:
```kotlin
suspend fun importAll(addToDefaultCategory: Boolean = true)
```

**状态类型**:
```kotlin
sealed class ImportState {
    object Idle : ImportState()
    object Scanning : ImportState()
    data class Importing(val current: Int, val total: Int, val message: String = "") : ImportState()
    data class Completed(val imported: Int, val skipped: Int, val errorCount: Int, val message: String = "") : ImportState()
    data class Error(val message: String) : ImportState()
}
```

#### ScanLocalSource.kt
**位置**: `domain/src/main/java/tachiyomi/domain/local/interactor/ScanLocalSource.kt`

**职责**: 调用仓库层扫描本地源目录

#### GetLocalMangaDetails.kt
**位置**: `domain/src/main/java/tachiyomi/domain/local/interactor/GetLocalMangaDetails.kt`

**职责**: 获取单个漫画的详细信息（标题、作者、描述等）

#### LocalSourceRepository.kt
**位置**: `domain/src/main/java/tachiyomi/domain/local/repository/LocalSourceRepository.kt`

**职责**: 定义本地源操作的接口

### 2. Data 层

#### LocalSourceRepositoryImpl.kt
**位置**: `data/src/main/java/tachiyomi/data/local/LocalSourceRepositoryImpl.kt`

**职责**:
- 实现仓库接口
- 使用 `LocalSourceFileSystem` 扫描目录
- 使用 `LocalSource` 获取漫画详情

**关键实现**:
```kotlin
override suspend fun scanLocalSourceDirectory(): List<String> {
    return localSourceFileSystem.getFilesInBaseDirectory()
        .filter { it.isDirectory && !it.name.orEmpty().startsWith('.') }
        .mapNotNull { it.name }
        .distinct()
}

override suspend fun getMangaDetails(mangaDirName: String): LocalMangaDetails {
    val manga = SManga.create().apply {
        title = mangaDirName
        url = mangaDirName
    }
    localSource.getMangaDetails(manga)
    return LocalMangaDetails(...)
}
```

### 3. Presentation 层

#### SettingsAdvancedScreen.kt
**修改位置**: `app/src/main/java/eu/kanade/presentation/more/settings/screen/SettingsAdvancedScreen.kt`

**添加内容**:
1. 导入按钮（在"数据"组）
2. `LocalImportDialog` 对话框组件
3. 状态管理（使用 `LaunchedEffect` 收集 StateFlow）

**对话框状态处理**:
```kotlin
@Composable
private fun LocalImportDialog(
    importState: LocalImportManager.ImportState,
    onDismiss: () -> Unit,
    onImport: (Boolean) -> Unit,
) {
    when (val state = importState) {
        is Idle -> // 显示配置选项
        is Scanning -> // 显示扫描动画
        is Importing -> // 显示进度条
        is Completed -> // 显示完成统计
        is Error -> // 显示错误信息
    }
}
```

### 4. 依赖注入

#### DomainModule.kt
**修改位置**: `app/src/main/java/eu/kanade/domain/DomainModule.kt`

**添加的工厂**:
```kotlin
addSingletonFactory<LocalSourceRepository> { LocalSourceRepositoryImpl(get(), get(), get()) }
addFactory { ScanLocalSource(get()) }
addFactory { GetLocalMangaDetails(get()) }
addFactory {
    LocalImportManager(
        getMangaByUrlAndSourceId = get(),
        getCategories = get(),
        setMangaCategories = get(),
        mangaRepository = get(),
        libraryPreferences = get(),
        scanLocalSource = get(),
        getLocalMangaDetails = get(),
    )
}
```

### 5. 构建配置

#### data/build.gradle.kts
**添加的依赖**:
```kotlin
implementation(projects.sourceLocal)
implementation(libs.unifile)
```

### 6. 字符串资源

#### base/strings.xml
```xml
<string name="pref_import_local_downloads">Import local downloads</string>
<string name="pref_import_local_downloads_summary">Scan local source and add manga to library</string>
<string name="pref_import_local_downloads_description">This will scan the local source directory and automatically add all found manga to your library. Manga will be added to the default category if set.</string>
<string name="pref_import_local_downloads_add_to_default_category">Add to default category</string>
<string name="pref_import_local_downloads_add_to_default_category_summary">Automatically add imported manga to the default category</string>
<string name="local_import_scanning">Scanning local source…</string>
<string name="local_import_importing">Importing %1$d / %2$d</string>
<string name="local_import_completed">Import completed! Imported: %1$d, Skipped: %2$d, Errors: %3$d</string>
<string name="local_import_error">Import failed: %1$s</string>
```

#### zh-rCN/strings.xml
```xml
<string name="pref_import_local_downloads">导入本地下载</string>
<string name="pref_import_local_downloads_summary">扫描本地源并添加漫画到书架</string>
<string name="pref_import_local_downloads_description">这将扫描本地源目录并自动将所有找到的漫画添加到您的书架。如果设置了默认分类，漫画将添加到该分类。</string>
<string name="pref_import_local_downloads_add_to_default_category">添加到默认分类</string>
<string name="pref_import_local_downloads_add_to_default_category_summary">自动将导入的漫画添加到默认分类</string>
<string name="local_import_scanning">正在扫描本地源…</string>
<string name="local_import_importing">正在导入 %1$d / %2$d</string>
<string name="local_import_completed">导入完成！已导入：%1$d，已跳过：%2$d，错误：%3$d</string>
<string name="local_import_error">导入失败：%1$s</string>
```

## 导入流程

```
1. 用户点击"导入本地下载"
   ↓
2. 显示配置对话框（是否添加到默认分类）
   ↓
3. 用户点击"开始"
   ↓
4. LocalImportManager.importAll() 被调用
   ↓
5. 状态变为 Scanning
   ↓
6. ScanLocalSource 扫描目录
   ↓
7. 获取所有漫画文件夹名称列表
   ↓
8. 状态变为 Importing
   ↓
9. 遍历每个漫画文件夹:
   a. 检查是否已存在（getMangaByUrlAndSourceId）
   b. 如果存在且未收藏 → 标记为收藏 + 添加到分类
   c. 如果不存在 → 获取详情 → 创建 Manga 对象 → 插入数据库 → 添加到分类
   d. 更新进度状态
   ↓
10. 状态变为 Completed
    ↓
11. 显示统计结果
```

## 关键技术点

### 1. StateFlow 状态管理
使用 `MutableStateFlow` 和 `asStateFlow()` 提供响应式状态更新：
```kotlin
private val _importState = MutableStateFlow<ImportState>(ImportState.Idle)
val importState: StateFlow<ImportState> = _importState.asStateFlow()
```

### 2. Compose 状态收集
使用 `LaunchedEffect` 收集 StateFlow：
```kotlin
LaunchedEffect(importManager) {
    importManager.importState.collect { importState = it }
}
```

### 3. 本地源 API 使用
```kotlin
// 获取文件系统实例
val localSourceFileSystem: LocalSourceFileSystem

// 扫描目录
localSourceFileSystem.getFilesInBaseDirectory()

// 获取漫画详情
localSource.getMangaDetails(manga: SManga)
```

### 4. 数据库操作
```kotlin
// 检查是否存在
val existing = getMangaByUrlAndSourceId.await(url, sourceId)

// 插入新漫画
val inserted = mangaRepository.insertNetworkManga(listOf(manga))

// 更新收藏状态
mangaRepository.update(MangaUpdate(id = id, favorite = true))

// 添加到分类
setMangaCategories.await(mangaId, listOf(categoryId))
```

## 测试要点

### 功能测试
- [ ] 空目录处理
- [ ] 重复漫画处理（已存在但未收藏）
- [ ] 重复漫画处理（已在书架中）
- [ ] 默认分类添加
- [ ] 无默认分类情况
- [ ] 元数据加载失败处理
- [ ] 大量漫画导入性能

### UI 测试
- [ ] 对话框显示/隐藏
- [ ] 进度条更新
- [ ] 取消操作
- [ ] 完成统计显示
- [ ] 错误信息显示

## 常见问题

### Q: 为什么使用 insertNetworkManga 而不是其他插入方法？
A: `insertNetworkManga` 是 MangaRepository 中专门为从网络源获取的漫画设计的插入方法，它会正确处理元数据更新。对于本地源导入，我们也希望保留后续从在线源刷新元数据的能力。

### Q: 如何处理导入过程中的错误？
A: 使用 try-catch 捕获每个漫画的导入错误，记录错误计数但继续处理其他漫画。最终在 Completed 状态中显示错误数量。

### Q: 为什么要检查以 '.' 开头的文件夹？
A: 以 '.' 开头的文件夹通常是隐藏文件夹或系统文件夹（如 `.nomedia`），应该被过滤掉。

### Q: 导入后如何刷新元数据？
A: 导入的漫画标记为 `initialized = true`，但元数据可能不完整。用户可以：
1. 点击漫画进入详情页
2. 点击"刷新"按钮从在线源获取元数据
3. 或者等待自动更新（如果启用）

## 扩展建议

### 未来改进
1. **后台服务**: 使用 WorkManager 在后台执行导入
2. **批量操作**: 支持选择性地导入特定漫画
3. **进度持久化**: 支持中断后恢复导入
4. **通知支持**: 导入完成后发送通知
5. **导入历史**: 记录每次导入的统计信息

### 性能优化
1. **并发处理**: 使用 `coroutineScope` 并发处理多个漫画
2. **分批插入**: 批量插入数据库减少事务开销
3. **缓存优化**: 缓存已检查的漫画列表

## 相关文档
- [Komikku 架构文档](../README.md)
- [本地源实现](../../source-local/README.md)
- [依赖注入指南](../../app/src/main/java/eu/kanade/domain/README.md)

## 提交历史
- `088d8dc4e` - feat: 添加本地下载自动导入功能
- `aa750af3a` - feat: 添加书架分类默认选择功能

## 维护者
开发日期：2026-03-08
开发者：Cursor AI + Human

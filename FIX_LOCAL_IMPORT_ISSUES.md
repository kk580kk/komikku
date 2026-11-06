# 本地导入功能修复方案

## 问题总结

1. **封面提取问题**: 后台导入后大部分漫画没有封面
2. **自动导入 UI 复杂**: 需要简化为一个按钮
3. **通知栏进度缺失**: 导入过程没有在下拉通知栏显示进度

---

## 修复 1: 封面提取问题

### 原因分析
LocalImportManager 在导入时调用了 `localSourceRepository.extractCoverFromArchive()`，但该方法依赖于 LocalSource 的封面提取逻辑。问题可能是：
1. 封面提取在后台线程执行，但漫画插入数据库时封面 URI 还未设置
2. 封面文件路径在应用重启后失效

### 解决方案
在 LocalImportManager 的 `processMangaImport` 方法中，确保封面提取完成后才插入数据库：

**文件**: `domain/src/main/java/tachiyomi/domain/local/interactor/LocalImportManager.kt`

**修改位置**: 第 199-200 行附近

```kotlin
// 原代码:
val thumbnailUrl = mangaDetails.thumbnail_url ?: localSourceRepository.extractCoverFromArchive(mangaDirName)

// 修改为:
// 先尝试从元数据获取封面
var thumbnailUrl = mangaDetails.thumbnail_url

// 如果没有，从 CBZ 提取
if (thumbnailUrl.isNullOrBlank()) {
    thumbnailUrl = localSourceRepository.extractCoverFromArchive(mangaDirName)
    // 等待一小段时间确保封面文件写入完成
    kotlinx.coroutines.delay(100)
}

// 创建漫画时使用提取的封面
val manga = Manga.create().copy(
    url = mangaDirName,
    ogTitle = mangaDetails.title,
    // ... 其他字段
    ogThumbnailUrl = thumbnailUrl,  // ✅ 确保这里使用了提取的封面
    source = sourceId,
    favorite = true,
    initialized = true,  // ✅ 设置为已初始化，避免重复加载
)
```

---

## 修复 2: 自动导入 UI 简化

### 当前问题
- 有独立的 AutoImportScreen 界面
- 需要手动输入标题或扫描
- 操作步骤过多

### 解决方案
移除自动导入独立界面，在设置 - 高级中添加一个按钮，点击直接后台导入所有本地文件夹。

**文件 1**: `app/src/main/java/eu/kanade/presentation/more/settings/screen/SettingsAdvancedScreen.kt`

**修改**: 在 `getDataGroup()` 方法中添加新按钮

```kotlin
Preference.PreferenceItem.TextPreference(
    title = stringResource(KMR.strings.pref_auto_import_local_downloads),
    subtitle = stringResource(KMR.strings.pref_auto_import_local_downloads_summary),
    onClick = {
        scope.launch {
            // 直接开始后台导入
            importManager.importAll(addToDefaultCategory = true, background = true)
            // 显示提示
            context.toast("Auto import started in background")
        }
    },
)
```

**文件 2**: 删除或隐藏 AutoImportScreen 相关代码
- `app/src/main/java/exh/ui/autoimport/AutoImportScreen.kt` - 标记为废弃
- `app/src/main/java/exh/ui/autoimport/AutoImportScreenModel.kt` - 标记为废弃
- `app/src/main/java/eu/kanade/presentation/more/MoreScreen.kt` - 移除自动导入入口
- `app/src/main/java/eu/kanade/tachiyomi/ui/more/MoreTab.kt` - 移除自动导入入口

---

## 修复 3: 通知栏进度显示

### 当前状态
ImportNotificationHelper 已有基础框架，需要添加进度更新功能。

### 解决方案

**文件 1**: `app/src/main/java/eu/kanade/tachiyomi/util/system/ImportNotificationHelper.kt`

**已添加方法**:
```kotlin
fun showLocalImportProgress(
    current: Int,
    total: Int,
    mangaName: String = "",
) {
    val title = context.stringResource(KMR.strings.local_import_background_notification_title)
    val text = if (mangaName.isNotBlank()) {
        "Importing $current/$total: $mangaName"
    } else {
        "Importing $current/$total..."
    }

    showProgressNotification(
        notificationId = LOCAL_IMPORT_NOTIFICATION_ID,
        title = title,
        text = text,
        progress = current,
        max = total,
    )
}
```

**文件 2**: `domain/src/main/java/tachiyomi/domain/local/interactor/LocalImportManager.kt`

**修改**: 在导入循环中发送进度通知

```kotlin
// 在 importAll 方法的导入循环中
mangaDirs.forEachIndexed { index, mangaDirName ->
    try {
        val result = processMangaImport(mangaDirName, LOCAL_SOURCE_ID, defaultCategoryId)
        
        // ✅ 发送进度通知
        if (background) {
            val notificationHelper = ImportNotificationHelper(context)
            notificationHelper.showLocalImportProgress(
                current = index + 1,
                total = mangaDirs.size,
                mangaName = mangaDirName,
            )
        }
        
        // ... 其他代码
    }
}
```

---

## 字符串资源

**文件**: `i18n-kmk/src/commonMain/moko-resources/base/strings.xml`

**添加**:
```xml
<string name="pref_auto_import_local_downloads">Auto Import Downloads</string>
<string name="pref_auto_import_local_downloads_summary">Scan and import all manga from downloads folder in background</string>
<string name="local_import_in_progress">Importing %1$d/%2$d: %3$s</string>
```

---

## 实施步骤

### 步骤 1: 修复封面提取
```bash
# 修改 LocalImportManager.kt
# 确保封面提取后等待一小段时间
# 设置 initialized = true
```

### 步骤 2: 添加进度通知
```bash
# 1. ImportNotificationHelper 已添加 showLocalImportProgress
# 2. LocalImportManager 中调用该方法
# 3. 需要传入 Context 参数
```

### 步骤 3: 简化自动导入 UI
```bash
# 1. SettingsAdvancedScreen 添加新按钮
# 2. 移除 MoreScreen 和 MoreTab 中的自动导入入口
# 3. 添加字符串资源
```

### 步骤 4: 编译测试
```bash
export HTTP_PROXY=http://localhost:7890
export HTTPS_PROXY=http://localhost:7890
cd /Volumes/Serene\ 2T/Workspaces/github.com/kk580kk/komikku
./gradlew :app:assembleDebug --no-daemon
```

### 步骤 5: 安装验证
```bash
/Volumes/Brave\ 2T/Android/sdk/platform-tools/adb install -r \
  app/build/outputs/apk/debug/app-universal-debug.apk
```

---

## 预期效果

### 修复后表现

1. **封面**: 导入后所有漫画都有封面（从 CBZ 第一张图片提取）
2. **自动导入**: 设置 - 高级中一个按钮，点击即后台导入
3. **通知**: 
   - 导入中：显示进度条 `Importing 5/20: MangaName`
   - 完成后：显示结果 `导入：18 | 跳过：2 | 错误：0`

---

## 技术细节

### 封面提取流程
```
LocalImportManager.processMangaImport
  ↓
localSourceRepository.extractCoverFromArchive
  ↓
LocalSource.extractCoverFromFirstArchive
  ↓
LocalSource.updateCover (使用 coverManager)
  ↓
封面保存到应用内部存储
  ↓
返回 URI 给 Manga 对象
```

### 通知更新流程
```
LocalImportManager.importAll (background=true)
  ↓
循环 mangaDirs
  ↓
每个循环调用 notificationHelper.showLocalImportProgress
  ↓
NotificationManager 更新通知
  ↓
用户在下拉通知栏看到进度
```

---

**文档生成时间**: 2026-03-11 20:40 GMT+8  
**待实施**: 需要修改 4 个文件

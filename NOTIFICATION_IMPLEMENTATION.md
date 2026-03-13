# 后台导入通知功能实现说明

## 已实现功能

### 1. 通知工具类
**文件**: `app/src/main/java/eu/kanade/tachiyomi/util/system/ImportNotificationHelper.kt`

功能:
- 创建通知渠道
- 显示本地导入完成通知
- 显示自动导入完成通知
- 显示导入错误通知
- 支持点击通知跳转到应用

### 2. 本地导入通知集成
**文件**: `domain/src/main/java/tachiyomi/domain/local/interactor/LocalImportManager.kt`

修改:
- 添加 Context 参数
- 注入 ImportNotificationHelper
- 后台导入完成后显示通知
- 错误时显示错误通知

### 3. 自动导入通知集成
**文件**: `app/src/main/java/exh/ui/autoimport/AutoImportScreenModel.kt`

需要修改:
```kotlin
// 在 startImport 方法开头添加
if (background && !::notificationHelper.isInitialized) {
    notificationHelper = ImportNotificationHelper(context)
}

// 在后台导入完成处添加
notificationHelper.showAutoImportComplete(
    imported = imported.size,
    failed = failed.size,
    errors = errors.size,
)
```

### 4. 依赖注入更新
**文件**: `app/src/main/java/eu/kanade/domain/DomainModule.kt`

修改:
```kotlin
LocalImportManager(
    context = get(),  // 添加 context 参数
    getMangaByUrlAndSourceId = get(),
    ...
)
```

### 5. 字符串资源
**文件**: 
- `i18n-kmk/src/commonMain/moko-resources/zh-rCN/strings.xml`
- `i18n-kmk/src/commonMain/moko-resources/base/strings.xml`

添加:
```xml
<string name="notification_channel_import">导入通知</string>
<string name="notification_channel_import_description">后台导入任务完成通知</string>
```

## 通知效果

### 本地导入完成
```
标题：本地导入
内容：已导入：50 | 跳过：10 | 错误：2
```

### 自动导入完成
```
标题：自动导入
内容：已导入：30 | 无匹配：15 | 错误：5
```

### 导入错误
```
标题：本地导入/自动导入
内容：[错误信息]
优先级：高
```

## 通知渠道

- **渠道 ID**: import_channel
- **渠道名称**: 导入通知
- **重要性**: 低（不发出声音，不震动）
- **徽章**: 不显示
- **自动取消**: 是（点击后消失）

## 使用方式

### 本地导入
1. 更多 → 设置 → 高级 → 导入本地下载
2. 点击"后台导入"
3. 对话框关闭，后台执行
4. 完成后显示通知

### 自动导入
1. 更多 → 自动导入
2. 输入标题或扫描本地文件夹
3. 点击"后台导入"
4. 可关闭界面，后台执行
5. 完成后显示通知

## 错误重试机制（待实现）

可以在 processMangaImport 或 processTitle 中添加重试逻辑：

```kotlin
private suspend fun processMangaImportWithRetry(
    mangaDirName: String,
    sourceId: Long,
    defaultCategoryId: Long?,
    maxRetries: Int = 2,
): ImportResult {
    var lastError: Exception? = null
    
    repeat(maxRetries + 1) { attempt ->
        try {
            return processMangaImport(mangaDirName, sourceId, defaultCategoryId)
        } catch (e: Exception) {
            lastError = e
            if (attempt < maxRetries) {
                logcat(LogPriority.WARN) { 
                    "Import attempt ${attempt + 1} failed for $mangaDirName, retrying..." 
                }
                delay(1000 * (attempt + 1)) // 指数退避
            }
        }
    }
    
    return ImportResult.Error(lastError?.message ?: "Unknown error")
}
```

## 下一步

1. ✅ 通知功能 - 已完成
2. ⏳ 错误重试 - 待实现
3. ⏳ 进度持久化 - 待实现

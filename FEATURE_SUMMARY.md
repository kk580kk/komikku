# 收藏夹默认值配置功能实现总结

## 需求
在保存收藏夹的时候，支持默认值配置，不用每次都需要勾选一次分类。

## 实现方案
添加了"使用上次使用的分类"选项，启用后添加漫画到书架时会自动使用上次选择的分类，无需每次都手动选择。

## 修改的文件

### 1. LibraryPreferences.kt
**路径**: `/Volumes/Serene 2T/Workspaces/github.com/kk580kk/komikku/domain/src/main/java/tachiyomi/domain/library/service/LibraryPreferences.kt`

**修改内容**: 添加了新的偏好设置 `useLastUsedCategoryOnAdd()`
```kotlin
fun useLastUsedCategoryOnAdd() = preferenceStore.getBoolean("use_last_used_category_on_add", false)
```

### 2. MangaScreenModel.kt
**路径**: `/Volumes/Serene 2T/Workspaces/github.com/kk580kk/komikku/app/src/main/java/eu/kanade/tachiyomi/ui/manga/MangaScreenModel.kt`

**修改内容**: 
1. 在 `toggleFavorite` 函数中添加了使用上次分类的逻辑
2. 在 `moveMangaToCategory` 函数中添加了保存上次使用分类的逻辑

```kotlin
// 在 toggleFavorite 中添加
libraryPreferences.useLastUsedCategoryOnAdd().get() -> {
    val lastUsedCategoryId = libraryPreferences.lastUsedCategory().get().toLong()
    val lastUsedCategory = categories.find { it.id == lastUsedCategoryId }
    if (lastUsedCategory != null) {
        val result = updateManga.awaitUpdateFavorite(manga.id, true)
        if (!result) return@launchIO
        moveMangaToCategory(lastUsedCategory)
    } else {
        val result = updateManga.awaitUpdateFavorite(manga.id, true)
        if (!result) return@launchIO
        moveMangaToCategory(null)
    }
}

// 在 moveMangaToCategory 中添加
if (categoryIds.isNotEmpty()) {
    libraryPreferences.lastUsedCategory().set(categoryIds.first().toInt())
}
```

### 3. SettingsLibraryScreen.kt
**路径**: `/Volumes/Serene 2T/Workspaces/github.com/kk580kk/komikku/app/src/main/java/eu/kanade/presentation/more/settings/screen/SettingsLibraryScreen.kt`

**修改内容**: 在设置界面添加了新的开关选项
```kotlin
Preference.PreferenceItem.SwitchPreference(
    preference = libraryPreferences.useLastUsedCategoryOnAdd(),
    title = stringResource(KMR.strings.pref_use_last_used_category_on_add),
    subtitle = stringResource(KMR.strings.pref_use_last_used_category_on_add_description),
),
```

### 4. 字符串资源文件

#### 英文 (base)
**路径**: `/Volumes/Serene 2T/Workspaces/github.com/kk580kk/komikku/i18n-kmk/src/commonMain/moko-resources/base/strings.xml`
```xml
<string name="pref_use_last_used_category_on_add">Use last used category</string>
<string name="pref_use_last_used_category_on_add_description">Automatically use the last selected category when adding manga to library</string>
```

#### 简体中文 (zh-rCN)
**路径**: `/Volumes/Serene 2T/Workspaces/github.com/kk580kk/komikku/i18n-kmk/src/commonMain/moko-resources/zh-rCN/strings.xml`
```xml
<string name="pref_use_last_used_category_on_add">使用上次使用的分类</string>
<string name="pref_use_last_used_category_on_add_description">添加漫画到书架时自动使用上次选择的分类</string>
```

## 功能说明

### 启用前（默认行为）
- 如果没有设置默认分类，且存在多个分类时，每次添加漫画到书架都会弹出分类选择对话框
- 用户需要每次都手动选择分类

### 启用后
- 添加漫画到书架时，会自动使用上次选择的分类
- 无需每次都手动选择，提高效率
- 如果从未选择过分类，则添加到默认分类

## 使用方法

1. 打开应用设置
2. 进入"书架"设置
3. 在"行为"部分找到"使用上次使用的分类"选项
4. 启用该选项

## 构建和部署说明

### 构建 APK
```bash
cd /Volumes/Serene\ 2T/Workspaces/github.com/kk580kk/komikku
./gradlew assembleDebug --no-daemon
```

构建完成后，APK 文件位于：
`/Volumes/Serene 2T/Workspaces/github.com/kk580kk/komikku/app/build/outputs/apk/debug/app-debug.apk`

### 使用 ADB 部署到平板
```bash
# 确保平板已通过 USB 连接并启用了 USB 调试
/Volumes/Brave\ 2T/Android/sdk/platform-tools/adb devices

# 安装 APK
/Volumes/Brave\ 2T/Android/sdk/platform-tools/adb install -r /Volumes/Serene\ 2T/Workspaces/github.com/kk580kk/komikku/app/build/outputs/apk/debug/app-debug.apk

# 如果平板有多个用户或需要覆盖安装
/Volumes/Brave\ 2T/Android/sdk/platform-tools/adb install -r -t /Volumes/Serene\ 2T/Workspaces/github.com/kk580kk/komikku/app/build/outputs/apk/debug/app-debug.apk
```

### 验证安装
```bash
# 查看已安装的应用
/Volumes/Brave\ 2T/Android/sdk/platform-tools/adb shell pm list packages | grep mihon

# 启动应用
/Volumes/Brave\ 2T/Android/sdk/platform-tools/adb shell am start -n eu.kanade.tachiyomi/eu.kanade.tachiyomi.ui.main.MainActivity
```

## 注意事项

1. 首次构建可能需要较长时间（10-30 分钟），因为需要下载依赖和编译代码
2. 确保平板已启用"开发者选项"和"USB 调试"
3. 如果安装失败，尝试先卸载旧版本：
   ```bash
   /Volumes/Brave\ 2T/Android/sdk/platform-tools/adb uninstall eu.kanade.tachiyomi
   ```
4. 该功能只影响添加新漫画到书架时的行为，不影响已有漫画

## 测试建议

1. 启用"使用上次使用的分类"选项
2. 添加一部新漫画到书架，选择某个分类
3. 再添加另一部新漫画，验证是否自动使用了上次选择的分类
4. 禁用该选项，验证是否恢复为每次弹出分类选择对话框

package tachiyomi.source.local.io

import com.hippo.unifile.UniFile
import tachiyomi.domain.storage.service.StorageManager

actual class LocalSourceFileSystem(
    private val storageManager: StorageManager,
) {

    actual fun getBaseDirectory(): UniFile? {
        return storageManager.getLocalSourceDirectory()
    }

    actual fun getFilesInBaseDirectory(): List<UniFile> {
        return getBaseDirectory()?.listFiles().orEmpty().toList()
    }

    /**
     * Get the downloads directory for importing local downloads.
     */
    fun getDownloadsDirectory(): UniFile? {
        return storageManager.getDownloadsDirectory()
    }

    /**
     * Get files in the downloads directory (including subdirectories).
     */
    fun getFilesInDownloadsDirectory(): List<UniFile> {
        return getDownloadsDirectory()?.listFiles().orEmpty().toList()
    }

    actual fun getMangaDirectory(name: String): UniFile? {
        val baseDir = getBaseDirectory() ?: return null
        
        // Support nested paths like "downloads/E-Hentai/MangaName"
        val pathParts = name.split('/')
        var currentDir: UniFile? = if (pathParts.firstOrNull() == "downloads") {
            // If path starts with "downloads", use downloads directory as base
            getDownloadsDirectory()
        } else {
            baseDir
        }
        
        // Skip "downloads" prefix if present
        val partsToProcess = if (pathParts.firstOrNull() == "downloads") {
            pathParts.drop(1)
        } else {
            pathParts
        }
        
        for (part in partsToProcess) {
            currentDir = currentDir?.findFile(part)?.takeIf { it.isDirectory }
            if (currentDir == null) return null
        }
        
        return currentDir
    }

    actual fun getFilesInMangaDirectory(name: String): List<UniFile> {
        return getMangaDirectory(name)?.listFiles().orEmpty().toList()
    }
}

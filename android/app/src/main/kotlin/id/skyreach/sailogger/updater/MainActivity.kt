package id.skyreach.sailogger.updater

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.OutputStream
import java.net.URLConnection

class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "id.skyreach.sailogger.updater/failed_sms_storage"
    }

    private val downloadSessions = mutableMapOf<Int, DownloadSession>()
    private var nextSessionId = 1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAndroidSdkInt" -> result.success(Build.VERSION.SDK_INT)
                "startDownload" -> startDownload(
                    fileName = call.argument<String>("fileName"),
                    appFolderName = call.argument<String>("appFolderName"),
                    result = result,
                )
                "writeChunk" -> writeChunk(
                    sessionId = call.argument<Number>("sessionId")?.toInt(),
                    bytes = call.argument<ByteArray>("bytes"),
                    result = result,
                )
                "finishDownload" -> finishDownload(
                    sessionId = call.argument<Number>("sessionId")?.toInt(),
                    result = result,
                )
                "abortDownload" -> abortDownload(
                    sessionId = call.argument<Number>("sessionId")?.toInt(),
                    result = result,
                )
                "openFile" -> openFile(
                    uriString = call.argument<String>("uri"),
                    mimeType = call.argument<String>("mimeType"),
                    result = result,
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun startDownload(
        fileName: String?,
        appFolderName: String?,
        result: MethodChannel.Result,
    ) {
        val sanitizedFileName = sanitizeFileName(fileName)
        val sanitizedFolderName = sanitizeFolderName(appFolderName)
        if (sanitizedFileName.isBlank() || sanitizedFolderName.isBlank()) {
            result.error("invalid_file_name", "Invalid file name from terminal.", null)
            return
        }

        val mimeType = resolveMimeType(sanitizedFileName)
        try {
            val session = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                createMediaStoreSession(
                    fileName = sanitizedFileName,
                    mimeType = mimeType,
                    appFolderName = sanitizedFolderName,
                )
            } else {
                createLegacySession(
                    fileName = sanitizedFileName,
                    mimeType = mimeType,
                    appFolderName = sanitizedFolderName,
                )
            }
            val sessionId = nextSessionId++
            downloadSessions[sessionId] = session
            result.success(
                mapOf(
                    "sessionId" to sessionId,
                    "displayName" to session.displayName,
                    "mimeType" to session.mimeType,
                    "relativePath" to session.relativePathDisplay,
                ),
            )
        } catch (error: StorageException) {
            result.error(error.code, error.message, null)
        }
    }

    private fun writeChunk(
        sessionId: Int?,
        bytes: ByteArray?,
        result: MethodChannel.Result,
    ) {
        val session = sessionId?.let(downloadSessions::get)
        if (session == null) {
            result.error("download_cancelled", "Download session is no longer available.", null)
            return
        }
        val chunk = bytes ?: byteArrayOf()
        try {
            session.outputStream.write(chunk)
            session.bytesWritten += chunk.size.toLong()
            result.success(null)
        } catch (error: IOException) {
            cleanupPartialSession(session)
            downloadSessions.remove(sessionId)
            result.error(errorCodeFor(error, "write_failed"), error.message ?: "Write failed.", null)
        }
    }

    private fun finishDownload(
        sessionId: Int?,
        result: MethodChannel.Result,
    ) {
        val session = sessionId?.let(downloadSessions::remove)
        if (session == null) {
            result.error("download_cancelled", "Download session is no longer available.", null)
            return
        }
        if (session.bytesWritten <= 0L) {
            cleanupPartialSession(session)
            result.error("write_failed", "Downloaded file is empty.", null)
            return
        }

        try {
            session.outputStream.flush()
            session.outputStream.close()
        } catch (error: IOException) {
            cleanupUriOrFile(session)
            result.error("close_failed", error.message ?: "Failed to close the storage stream.", null)
            return
        }

        try {
            if (session.isMediaStore) {
                finalizePendingMediaStore(session)
            }
            result.success(
                mapOf(
                    "displayName" to session.displayName,
                    "mimeType" to session.mimeType,
                    "relativePath" to session.relativePathDisplay,
                    "uri" to session.contentUri.toString(),
                ),
            )
        } catch (error: StorageException) {
            cleanupUriOrFile(session)
            result.error(error.code, error.message, null)
        }
    }

    private fun abortDownload(
        sessionId: Int?,
        result: MethodChannel.Result,
    ) {
        val session = sessionId?.let(downloadSessions::remove)
        if (session != null) {
            cleanupPartialSession(session)
        }
        result.success(null)
    }

    private fun openFile(
        uriString: String?,
        mimeType: String?,
        result: MethodChannel.Result,
    ) {
        if (uriString.isNullOrBlank()) {
            result.error("open_failed", "Missing file URI.", null)
            return
        }
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(Uri.parse(uriString), mimeType ?: "application/octet-stream")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        val handler = intent.resolveActivity(packageManager)
        if (handler == null) {
            result.error("open_failed", "No app can open this file type.", null)
            return
        }
        startActivity(intent)
        result.success(null)
    }

    private fun createMediaStoreSession(
        fileName: String,
        mimeType: String,
        appFolderName: String,
    ): DownloadSession {
        val relativePath = "${Environment.DIRECTORY_DOWNLOADS}/$appFolderName/"
        val displayName = resolveUniqueMediaStoreDisplayName(relativePath, fileName)
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val resolver = applicationContext.contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw StorageException("insert_failed", "Failed to create MediaStore entry.")

        val outputStream = try {
            resolver.openOutputStream(uri, "w")
                ?: throw StorageException("insert_failed", "Failed to open MediaStore output stream.")
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw if (error is StorageException) error else StorageException(
                "insert_failed",
                error.message ?: "Failed to open MediaStore output stream.",
            )
        }

        return DownloadSession(
            contentUri = uri,
            outputStream = outputStream,
            file = null,
            displayName = displayName,
            mimeType = mimeType,
            relativePathDisplay = "Download/$appFolderName",
            isMediaStore = true,
        )
    }

    @Suppress("DEPRECATION")
    private fun createLegacySession(
        fileName: String,
        mimeType: String,
        appFolderName: String,
    ): DownloadSession {
        val baseDirectory =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                ?: throw StorageException("insert_failed", "Downloads directory is unavailable.")
        val targetDirectory = File(baseDirectory, appFolderName)
        if (!targetDirectory.exists() && !targetDirectory.mkdirs()) {
            throw StorageException("insert_failed", "Failed to create target download directory.")
        }
        val displayName = resolveUniqueLegacyFileName(targetDirectory, fileName)
        val targetFile = File(targetDirectory, displayName)
        val outputStream = try {
            FileOutputStream(targetFile)
        } catch (error: IOException) {
            throw StorageException(
                errorCodeFor(error, "insert_failed"),
                error.message ?: "Failed to create legacy download file.",
            )
        }
        val fileUri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            targetFile,
        )
        return DownloadSession(
            contentUri = fileUri,
            outputStream = outputStream,
            file = targetFile,
            displayName = displayName,
            mimeType = mimeType,
            relativePathDisplay = "Download/$appFolderName",
            isMediaStore = false,
        )
    }

    private fun finalizePendingMediaStore(session: DownloadSession) {
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.IS_PENDING, 0)
        }
        val rowsUpdated = applicationContext.contentResolver.update(
            session.contentUri,
            values,
            null,
            null,
        )
        if (rowsUpdated <= 0) {
            throw StorageException("finish_failed", "Failed to finalize MediaStore entry.")
        }
    }

    private fun resolveUniqueMediaStoreDisplayName(
        relativePath: String,
        preferredName: String,
    ): String {
        if (!mediaStoreEntryExists(relativePath, preferredName)) {
            return preferredName
        }
        val dotIndex = preferredName.lastIndexOf('.')
        val baseName = if (dotIndex > 0) preferredName.substring(0, dotIndex) else preferredName
        val extension = if (dotIndex > 0) preferredName.substring(dotIndex) else ""
        var counter = 1
        var candidate: String
        do {
            candidate = "$baseName ($counter)$extension"
            counter++
        } while (mediaStoreEntryExists(relativePath, candidate))
        return candidate
    }

    private fun mediaStoreEntryExists(
        relativePath: String,
        displayName: String,
    ): Boolean {
        val projection = arrayOf(MediaStore.MediaColumns._ID)
        val selection =
            "${MediaStore.MediaColumns.RELATIVE_PATH} = ? AND ${MediaStore.MediaColumns.DISPLAY_NAME} = ?"
        val args = arrayOf(relativePath, displayName)
        applicationContext.contentResolver.query(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            args,
            null,
        )?.use { cursor ->
            return cursor.moveToFirst()
        }
        return false
    }

    private fun resolveUniqueLegacyFileName(
        directory: File,
        preferredName: String,
    ): String {
        if (!File(directory, preferredName).exists()) {
            return preferredName
        }
        val dotIndex = preferredName.lastIndexOf('.')
        val baseName = if (dotIndex > 0) preferredName.substring(0, dotIndex) else preferredName
        val extension = if (dotIndex > 0) preferredName.substring(dotIndex) else ""
        var counter = 1
        var candidate: String
        do {
            candidate = "$baseName ($counter)$extension"
            counter++
        } while (File(directory, candidate).exists())
        return candidate
    }

    private fun sanitizeFileName(value: String?): String {
        if (value.isNullOrBlank()) {
            return ""
        }
        val basename = value.trim().substringAfterLast('/').trim()
        return basename
            .replace(Regex("[<>:\"/\\\\|?*\\u0000-\\u001F]"), "_")
            .trim()
            .trim('.')
    }

    private fun sanitizeFolderName(value: String?): String {
        if (value.isNullOrBlank()) {
            return ""
        }
        return value
            .trim()
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .trim('_', '.')
    }

    private fun resolveMimeType(fileName: String): String {
        return URLConnection.guessContentTypeFromName(fileName)
            ?: "application/octet-stream"
    }

    private fun cleanupPartialSession(session: DownloadSession) {
        try {
            session.outputStream.close()
        } catch (_: IOException) {
        }
        cleanupUriOrFile(session)
    }

    private fun cleanupUriOrFile(session: DownloadSession) {
        if (session.isMediaStore) {
            applicationContext.contentResolver.delete(session.contentUri, null, null)
        } else {
            session.file?.delete()
        }
    }

    private fun errorCodeFor(error: IOException, fallback: String): String {
        val normalized = error.message?.lowercase().orEmpty()
        return if (
            normalized.contains("no space") ||
            normalized.contains("not enough space") ||
            normalized.contains("enospc")
        ) {
            "insufficient_storage"
        } else {
            fallback
        }
    }

    private data class DownloadSession(
        val contentUri: Uri,
        val outputStream: OutputStream,
        val file: File?,
        val displayName: String,
        val mimeType: String,
        val relativePathDisplay: String,
        val isMediaStore: Boolean,
        var bytesWritten: Long = 0,
    )

    private data class StorageException(
        val code: String,
        override val message: String,
    ) : Exception(message)
}

package com.rotecbr.rallet

import android.net.Uri
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    companion object {
        // Identificadores internos legados mantidos após o rebranding para
        // preservar o fluxo de restore já validado entre processos/aparelhos.
        private const val CHANNEL = "rallet/backup_picker"
        private const val PREFS = "xp_finance_backup_picker"
        private const val KEY_PENDING_PATH = "pending_backup_path"
    }

    private var pendingPickResult: MethodChannel.Result? = null

    private val backupPickerLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        handlePickedBackup(uri)
    }

    override fun getRenderMode(): RenderMode = RenderMode.texture

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickBackupFile" -> pickBackupFile(result)
                    "findPendingBackupFile" -> result.success(findPendingPath())
                    "acknowledgePendingBackupFile" -> {
                        acknowledgePending(call.arguments as? String)
                        result.success(null)
                    }
                    "discardPendingBackupFile" -> {
                        acknowledgePending(null)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun pickBackupFile(result: MethodChannel.Result) {
        val pendingPath = findPendingPath()
        if (pendingPath != null) {
            result.success(pendingPath)
            return
        }

        if (pendingPickResult != null) {
            result.error(
                "PICKER_BUSY",
                "Já existe uma seleção de backup em andamento.",
                null
            )
            return
        }

        pendingPickResult = result
        backupPickerLauncher.launch(
            arrayOf(
                "application/vnd.sqlite3",
                "application/x-sqlite3",
                "application/octet-stream",
                "*/*"
            )
        )
    }

    private fun handlePickedBackup(uri: Uri?) {
        if (uri == null) {
            pendingPickResult?.success(null)
            pendingPickResult = null
            return
        }

        try {
            val path = copyUriToPrivateCache(uri)
            val pendingSaved = getSharedPreferences(PREFS, MODE_PRIVATE)
                .edit()
                .putString(KEY_PENDING_PATH, path)
                .commit()

            if (!pendingSaved) {
                File(path).delete()
                throw IllegalStateException(
                    "Não foi possível persistir o backup selecionado para retomada."
                )
            }

            // Se o processo original ainda existe, o Future do Dart recebe o
            // caminho normalmente. Se ele morreu enquanto o DocumentsUI estava
            // aberto, pendingPickResult será null; o caminho persistido acima é
            // recuperado pelo startup do Flutter no novo processo.
            pendingPickResult?.success(path)
        } catch (error: Exception) {
            pendingPickResult?.error(
                "BACKUP_COPY_ERROR",
                error.message ?: "Não foi possível copiar o backup selecionado.",
                null
            )
        } finally {
            pendingPickResult = null
        }
    }

    private fun copyUriToPrivateCache(uri: Uri): String {
        val restoreDirectory = File(cacheDir, "xp_finance_restore")
        if (!restoreDirectory.exists() && !restoreDirectory.mkdirs()) {
            throw IllegalStateException("Não foi possível criar o cache de restore.")
        }

        val destination = File(restoreDirectory, "selected_backup.db")
        if (destination.exists()) destination.delete()

        val input = contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("Não foi possível abrir o arquivo selecionado.")

        input.use { source ->
            destination.outputStream().use { target ->
                source.copyTo(target)
                target.flush()
            }
        }

        if (!destination.exists() || destination.length() <= 0L) {
            throw IllegalStateException("O arquivo selecionado ficou vazio após a cópia.")
        }

        return destination.absolutePath
    }

    private fun findPendingPath(): String? {
        val preferences = getSharedPreferences(PREFS, MODE_PRIVATE)
        val path = preferences.getString(KEY_PENDING_PATH, null) ?: return null
        val file = File(path)

        if (!file.exists() || file.length() <= 0L) {
            preferences.edit().remove(KEY_PENDING_PATH).commit()
            return null
        }

        return path
    }

    private fun acknowledgePending(requestedPath: String?) {
        val preferences = getSharedPreferences(PREFS, MODE_PRIVATE)
        val storedPath = preferences.getString(KEY_PENDING_PATH, null)

        if (storedPath != null && (requestedPath == null || requestedPath == storedPath)) {
            try {
                File(storedPath).delete()
            } catch (_: Exception) {
                // O cache também será limpo pelo Android futuramente.
            }
            preferences.edit().remove(KEY_PENDING_PATH).commit()
        }
    }
}

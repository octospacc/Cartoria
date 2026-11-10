package org.eu.octt.cartoria

import android.database.Cursor
import android.database.MatrixCursor
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.DocumentsProvider
import android.webkit.MimeTypeMap
import java.io.File

/**
 * Exposes the app's private vault directory through Android's Storage
 * Access Framework, so it appears as a browsable location in the system
 * Files app (sidebar entry) and is accessible to other apps that
 * legitimately request access via SAF.
 *
 * The vault path is supplied by the Flutter side via a MethodChannel
 * after startup; if that never fires (or fires after the first
 * provider query), the default location
 * `<app-private>/app_flutter/Cartoria` is used.
 */
class CartoriaDocumentsProvider : DocumentsProvider() {

    companion object {
        /** Override set by MainActivity once Flutter has determined the
         *  actual vault path. `null` means "use the default". Read on
         *  every query so setting it late still takes effect. */
        var vaultPathOverride: String? = null

        private const val ROOT_ID = "cartoria_root"

        private val DEFAULT_ROOT_PROJECTION = arrayOf(
            DocumentsContract.Root.COLUMN_ROOT_ID,
            DocumentsContract.Root.COLUMN_TITLE,
            DocumentsContract.Root.COLUMN_FLAGS,
            DocumentsContract.Root.COLUMN_DOCUMENT_ID,
            DocumentsContract.Root.COLUMN_ICON,
            DocumentsContract.Root.COLUMN_AVAILABLE_BYTES
        )

        private val DEFAULT_DOCUMENT_PROJECTION = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_FLAGS,
            DocumentsContract.Document.COLUMN_SIZE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED
        )
    }

    /** Resolved on each access so a late override takes effect. */
    private fun vaultDir(): File {
        val override = vaultPathOverride
        if (override != null) return File(override)
        val ctx = context ?: throw IllegalStateException(
            "DocumentsProvider not attached to a context"
        )
        // <app-private>/files -> <app-private> -> app_flutter/Cartoria
        return File(ctx.filesDir.parentFile, "app_flutter/Cartoria")
    }

    override fun onCreate(): Boolean = true

    /**
     * Determines whether [documentId] is a descendant of [parentDocumentId].
     *
     * The framework calls this on every tree-based URI operation (via
     * `DocumentsProvider.enforceTree`) to guard against providers
     * returning documents that aren't actually under the tree the
     * caller was granted access to. The base implementation throws
     * `UnsupportedOperationException`, which the framework treats as
     * "not a descendant" — causing `SecurityException: Document ... is
     * not a descendant of ...` and, on restart, a `query() returned
     * null` from the file manager.
     *
     * Our document IDs encode absolute file paths, so the check is a
     * straightforward path prefix comparison. We use `canonicalPath` so
     * that symlinks and `..` segments don't allow a document to escape
     * the tree it claims to be under.
     */
    override fun isChildDocument(
        parentDocumentId: String,
        documentId: String
    ): Boolean {
        if (parentDocumentId == documentId) return false
        return try {
            val parent = fileForDocId(parentDocumentId).canonicalFile
            val child = fileForDocId(documentId).canonicalFile
            val parentPath = parent.path
            val childPath = child.path
            childPath == parentPath ||
                childPath.startsWith("$parentPath${File.separator}")
        } catch (_: Exception) {
            false
        }
    }
    
    override fun queryRoots(projection: Array<out String>?): Cursor {
        val cols = projection ?: DEFAULT_ROOT_PROJECTION
        val cursor = MatrixCursor(cols)
        val ctx = context ?: return cursor
        val root = vaultDir()

        val appLabel: String = try {
            ctx.applicationInfo
                .loadLabel(ctx.packageManager)
                .toString()
                .ifEmpty { "Cartoria" }
        } catch (_: Exception) {
            "Cartoria"
        }
        val appIconRes: Int = try {
            ctx.applicationInfo.icon
        } catch (_: Exception) {
            0
        }

        val row = cursor.newRow()
        row.add(DocumentsContract.Root.COLUMN_ROOT_ID, ROOT_ID)
        row.add(DocumentsContract.Root.COLUMN_TITLE, appLabel)
        row.add(
            DocumentsContract.Root.COLUMN_FLAGS,
            // Allow selecting this root as a tree (for "Add external storage")
            DocumentsContract.Root.FLAG_SUPPORTS_IS_CHILD or
                    // Signal that content is strictly local (for compatibility with
                    // apps like Syncthing, Round Sync, etc.)
                    DocumentsContract.Root.FLAG_LOCAL_ONLY or
                    // Optional: Enable "Recent" view for this provider
                    DocumentsContract.Root.FLAG_SUPPORTS_RECENTS
        )
        row.add(DocumentsContract.Root.COLUMN_DOCUMENT_ID, docIdForFile(root))
        row.add(DocumentsContract.Root.COLUMN_ICON, appIconRes)
        row.add(
            DocumentsContract.Root.COLUMN_AVAILABLE_BYTES,
            if (root.exists()) root.freeSpace else 0L
        )
        return cursor
    }

    override fun queryChildDocuments(
        parentDocumentId: String,
        projection: Array<out String>?,
        sortOrder: String?
    ): Cursor {
        val cols = projection ?: DEFAULT_DOCUMENT_PROJECTION
        val parent = fileForDocId(parentDocumentId)
        val cursor = MatrixCursor(cols)
        parent.listFiles()?.forEach { addFileToCursor(cursor, it) }
        return cursor
    }

    override fun queryDocument(
        documentId: String,
        projection: Array<out String>?
    ): Cursor {
        val cols = projection ?: DEFAULT_DOCUMENT_PROJECTION
        val cursor = MatrixCursor(cols)
        addFileToCursor(cursor, fileForDocId(documentId))
        return cursor
    }

    override fun openDocument(
        documentId: String,
        mode: String,
        signal: CancellationSignal?
    ): ParcelFileDescriptor {
        val file = fileForDocId(documentId)
        val accessMode = ParcelFileDescriptor.parseMode(mode)
        return ParcelFileDescriptor.open(file, accessMode)
    }

    // ── helpers ──────────────────────────────────────────────────────────

    private fun docIdForFile(file: File): String =
        android.util.Base64.encodeToString(
            file.absolutePath.toByteArray(),
            android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP
        )

    private fun fileForDocId(docId: String): File {
        val path = String(
            android.util.Base64.decode(
                docId,
                android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP
            )
        )
        return File(path)
    }

    private fun addFileToCursor(cursor: MatrixCursor, file: File) {
        val mime = if (file.isDirectory) {
            DocumentsContract.Document.MIME_TYPE_DIR
        } else {
            MimeTypeMap.getSingleton()
                .getMimeTypeFromExtension(file.extension.lowercase())
                ?: "application/octet-stream"
        }

        var flags = 0
        if (file.isDirectory) {
            flags = flags or
                    DocumentsContract.Document.FLAG_DIR_SUPPORTS_CREATE
        } else if (file.canWrite()) {
            flags = flags or DocumentsContract.Document.FLAG_SUPPORTS_WRITE
        }

        cursor.newRow().apply {
            add(DocumentsContract.Document.COLUMN_DOCUMENT_ID, docIdForFile(file))
            add(DocumentsContract.Document.COLUMN_DISPLAY_NAME, file.name)
            add(DocumentsContract.Document.COLUMN_MIME_TYPE, mime)
            add(DocumentsContract.Document.COLUMN_FLAGS, flags)
            add(DocumentsContract.Document.COLUMN_SIZE, file.length())
            add(DocumentsContract.Document.COLUMN_LAST_MODIFIED, file.lastModified())
        }
    }
}
package com.ironvault.app.autofill

import android.app.PendingIntent
import android.app.assist.AssistStructure
import android.content.Intent
import android.os.Build
import android.os.CancellationSignal
import android.service.autofill.AutofillService
import android.service.autofill.FillCallback
import android.service.autofill.FillRequest
import android.service.autofill.FillResponse
import android.service.autofill.SaveCallback
import android.service.autofill.SaveRequest
import android.util.Log
import android.view.View
import android.view.autofill.AutofillId
import android.widget.RemoteViews
import androidx.annotation.RequiresApi
import com.ironvault.app.R

@RequiresApi(Build.VERSION_CODES.O)
class IronVaultAutofillService : AutofillService() {
    override fun onFillRequest(
        request: FillRequest,
        cancellationSignal: CancellationSignal,
        callback: FillCallback
    ) {
        try {
            val contexts = request.fillContexts
            if (contexts.isEmpty()) {
                callback.onSuccess(null)
                return
            }

            val structure = contexts.last().structure
            val ids = findAutofillIds(structure)
            val autofillIds = mutableListOf<AutofillId>()
            ids.first?.let { autofillIds.add(it) }
            ids.second?.let { autofillIds.add(it) }

            if (autofillIds.isEmpty()) {
                callback.onSuccess(null)
                return
            }

            val intent = Intent(this, AutofillAuthActivity::class.java).apply {
                putParcelableArrayListExtra(
                    AutofillAuthActivity.EXTRA_AUTOFILL_IDS,
                    ArrayList(autofillIds)
                )
                putExtra(AutofillAuthActivity.EXTRA_USERNAME_ID, ids.first)
                putExtra(AutofillAuthActivity.EXTRA_PASSWORD_ID, ids.second)
                putExtra(
                    AutofillAuthActivity.EXTRA_PACKAGE_NAME,
                    structure.activityComponent.packageName
                )
            }

            val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            val pendingIntent = PendingIntent.getActivity(this, 0, intent, flags)

            val presentation = RemoteViews(packageName, R.layout.autofill_unlock_prompt)

            val response = FillResponse.Builder()
                .setAuthentication(
                    autofillIds.toTypedArray(),
                    pendingIntent.intentSender,
                    presentation
                )
                .build()

            callback.onSuccess(response)
        } catch (e: Exception) {
            Log.e("IronVaultAutofill", "Fill request failed", e)
            callback.onSuccess(null)
        }
    }

    override fun onSaveRequest(request: SaveRequest, callback: SaveCallback) {
        callback.onSuccess()
    }

    private fun findAutofillIds(structure: AssistStructure): Pair<AutofillId?, AutofillId?> {
        var usernameId: AutofillId? = null
        var passwordId: AutofillId? = null

        val windowCount = structure.windowNodeCount
        for (i in 0 until windowCount) {
            val node = structure.getWindowNodeAt(i).rootViewNode
            traverseNode(node) { viewNode, type ->
                if (type == FieldType.USERNAME && usernameId == null) {
                    usernameId = viewNode.autofillId
                }
                if (type == FieldType.PASSWORD && passwordId == null) {
                    passwordId = viewNode.autofillId
                }
            }
        }

        return Pair(usernameId, passwordId)
    }

    private enum class FieldType { USERNAME, PASSWORD }

    private fun traverseNode(
        node: AssistStructure.ViewNode,
        onMatch: (AssistStructure.ViewNode, FieldType) -> Unit
    ) {
        if (node.autofillType == View.AUTOFILL_TYPE_TEXT) {
            val hints = node.autofillHints?.map { it.lowercase() } ?: emptyList()
            val hintText = node.hint?.toString()?.lowercase() ?: ""
            val idEntry = node.idEntry?.lowercase() ?: ""

            val allHints = mutableListOf<String>()
            allHints.addAll(hints)
            if (hintText.isNotBlank()) allHints.add(hintText)
            if (idEntry.isNotBlank()) allHints.add(idEntry)

            if (allHints.any { it.contains("password") || it.contains("pass") }) {
                onMatch(node, FieldType.PASSWORD)
            } else if (allHints.any {
                    it.contains("user") || it.contains("email") || it.contains("login")
                }) {
                onMatch(node, FieldType.USERNAME)
            }
        }

        for (i in 0 until node.childCount) {
            traverseNode(node.getChildAt(i), onMatch)
        }
    }
}

package com.ironvault.app.autofill

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.Build
import android.os.Bundle
import android.util.Base64
import android.view.autofill.AutofillId
import android.view.autofill.AutofillManager
import android.view.autofill.AutofillValue
import android.widget.ListView
import android.widget.SimpleAdapter
import android.widget.Toast
import android.widget.RemoteViews
import androidx.annotation.RequiresApi
import android.app.Activity
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import com.ironvault.app.R
import java.io.File
import java.nio.charset.StandardCharsets
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

@RequiresApi(Build.VERSION_CODES.O)
class AutofillAuthActivity : Activity() {
    companion object {
        const val EXTRA_AUTOFILL_IDS = "extra_autofill_ids"
        const val EXTRA_USERNAME_ID = "extra_username_id"
        const val EXTRA_PASSWORD_ID = "extra_password_id"
        const val EXTRA_PACKAGE_NAME = "extra_package_name"
        private const val REQUEST_CONFIRM_DEVICE_CREDENTIALS = 42
    }

    private var usernameId: AutofillId? = null
    private var passwordId: AutofillId? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        usernameId = intent.getParcelableExtra(EXTRA_USERNAME_ID)
        passwordId = intent.getParcelableExtra(EXTRA_PASSWORD_ID)

        if (!confirmDeviceCredentials()) {
            loadAndShowCredentials()
        }
    }

    private fun confirmDeviceCredentials(): Boolean {
        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (!km.isKeyguardSecure) return false

        val intent = km.createConfirmDeviceCredentialIntent(
            "Unlock IronVault",
            "Confirm your device screen lock"
        ) ?: return false

        startActivityForResult(intent, REQUEST_CONFIRM_DEVICE_CREDENTIALS)
        return true
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CONFIRM_DEVICE_CREDENTIALS) {
            if (resultCode == RESULT_OK) {
                loadAndShowCredentials()
            } else {
                setResult(RESULT_CANCELED)
                finish()
            }
        }
    }

    private fun loadAndShowCredentials() {
        val masterKey = readMasterKey()
        if (masterKey == null) {
            Toast.makeText(this, "Unlock IronVault first", Toast.LENGTH_SHORT).show()
            setResult(RESULT_CANCELED)
            finish()
            return
        }

        val credentials = readCredentials(masterKey)
        if (credentials.isEmpty()) {
            Toast.makeText(this, "No credentials found", Toast.LENGTH_SHORT).show()
            setResult(RESULT_CANCELED)
            finish()
            return
        }

        val listView = ListView(this)
        val data = credentials.map {
            mapOf("title" to it.title, "subtitle" to it.username)
        }

        val adapter = SimpleAdapter(
            this,
            data,
            android.R.layout.simple_list_item_2,
            arrayOf("title", "subtitle"),
            intArrayOf(android.R.id.text1, android.R.id.text2)
        )

        listView.adapter = adapter
        listView.setOnItemClickListener { _, _, position, _ ->
            val cred = credentials[position]
            val dataset = buildDataset(cred)
            val response = android.service.autofill.FillResponse.Builder()
                .addDataset(dataset)
                .build()

            val reply = Intent().apply {
                putExtra(AutofillManager.EXTRA_AUTHENTICATION_RESULT, response)
            }
            setResult(RESULT_OK, reply)
            finish()
        }

        setContentView(listView)
    }

    private fun buildDataset(credential: Credential): android.service.autofill.Dataset {
        val presentation = RemoteViews(packageName, R.layout.autofill_dataset_item)
        presentation.setTextViewText(R.id.autofill_item_title, credential.title)
        presentation.setTextViewText(R.id.autofill_item_subtitle, credential.username)

        val builder = android.service.autofill.Dataset.Builder(presentation)
        usernameId?.let {
            builder.setValue(it, AutofillValue.forText(credential.username), presentation)
        }
        passwordId?.let {
            builder.setValue(it, AutofillValue.forText(credential.password), presentation)
        }
        return builder.build()
    }

    private fun readMasterKey(): String? {
        return try {
            val masterKey = MasterKey.Builder(this)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()
            val prefs = EncryptedSharedPreferences.create(
                this,
                "FlutterSecureStorage",
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )
            prefs.getString("master_key_vault", null)
        } catch (_: Exception) {
            null
        }
    }

    private fun readCredentials(masterKey: String): List<Credential> {
        val dbFile = File(dataDir, "app_flutter/vault.sqlite")
        if (!dbFile.exists()) return emptyList()

        val db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READONLY)
        val cursor = db.query(
            "credentials",
            arrayOf("title", "username", "password"),
            null,
            null,
            null,
            null,
            null
        )

        val results = mutableListOf<Credential>()
        cursor.use {
            while (it.moveToNext()) {
                val titleEnc = it.getString(0)
                val usernameEnc = it.getString(1)
                val passwordEnc = it.getString(2)

                val title = decrypt(titleEnc, masterKey)
                val username = decrypt(usernameEnc, masterKey)
                val password = decrypt(passwordEnc, masterKey)

                results.add(Credential(title, username, password))
            }
        }
        db.close()
        return results
    }

    private fun decrypt(inputBase64: String, keyBase64: String): String {
        val keyBytes = Base64.decode(keyBase64, Base64.DEFAULT)
        val combined = Base64.decode(inputBase64, Base64.DEFAULT)
        if (combined.size <= 12) return ""

        val iv = combined.copyOfRange(0, 12)
        val cipherText = combined.copyOfRange(12, combined.size)

        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val key = SecretKeySpec(keyBytes, "AES")
        val spec = GCMParameterSpec(128, iv)
        cipher.init(Cipher.DECRYPT_MODE, key, spec)

        val plaintext = cipher.doFinal(cipherText)
        return String(plaintext, StandardCharsets.UTF_8)
    }

    private data class Credential(
        val title: String,
        val username: String,
        val password: String
    )
}

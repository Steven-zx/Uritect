package ph.edu.wvsu.uritect

import android.app.Activity
import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.AEADBadTagException
import android.security.keystore.UserNotAuthenticatedException
import android.view.WindowManager
import android.hardware.biometrics.BiometricPrompt
import android.hardware.biometrics.BiometricManager
import android.os.CancellationSignal
import android.util.Log

class HistorySecurity(private val activity: Activity) {
    private val requestCode = 7301
    private val alias = "uritect_history_v1"
    private val worker = Executors.newSingleThreadExecutor()
    @Volatile private var authenticatedUntil = 0L
    private var pending: MethodChannel.Result? = null

    fun onStop() { if (pending == null) authenticatedUntil = 0L }
    fun result(code: Int, resultCode: Int): Boolean {
        if (code != requestCode) return false
        finishAuthentication(resultCode == Activity.RESULT_OK)
        return true
    }
    private fun finishAuthentication(allowed: Boolean) {
        val callback = pending ?: return
        if (!allowed) {
            pending = null
            authenticatedUntil = 0L
            callback.success(mapOf("authenticated" to false, "remainingMillis" to 0L))
            return
        }
        val deadline = SystemClock.elapsedRealtime() + 120000L
        worker.execute {
            try {
                // A successful prompt alone does not establish Keystore authorization.
                val guard = activity.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                check(!guard.isDeviceLocked) { "Device is locked." }
                val secret = key()
                val probe = Cipher.getInstance("AES/GCM/NoPadding")
                probe.init(Cipher.ENCRYPT_MODE, secret)
                probe.updateAAD("uritect:authentication-probe".toByteArray(Charsets.UTF_8))
                val encrypted = probe.doFinal(byteArrayOf(1, 2, 3, 4))
                val verify = Cipher.getInstance("AES/GCM/NoPadding")
                verify.init(Cipher.DECRYPT_MODE, secret, GCMParameterSpec(128, probe.iv))
                verify.updateAAD("uritect:authentication-probe".toByteArray(Charsets.UTF_8))
                check(verify.doFinal(encrypted).contentEquals(byteArrayOf(1, 2, 3, 4)))
                activity.runOnUiThread {
                    pending = null
                    authenticatedUntil = deadline
                    callback.success(mapOf("authenticated" to true, "remainingMillis" to (deadline - SystemClock.elapsedRealtime()).coerceAtLeast(0L)))
                }
            } catch (e: Exception) {
                Log.w("UritectHistorySecurity", "Authentication key check failed: ${e.javaClass.simpleName}")
                activity.runOnUiThread {
                    pending = null
                    authenticatedUntil = 0L
                    val code = if (e is UserNotAuthenticatedException || e is IllegalStateException) "HISTORY_LOCKED" else "HISTORY_KEY_UNAVAILABLE"
                    callback.error(code, "Android did not authorize the history key. Retry with your device PIN, pattern or password. Saved files were preserved.", null)
                }
            }
        }
    }
    private fun showCredentialPrompt(guard: KeyguardManager) {
        if (Build.VERSION.SDK_INT >= 30) {
            BiometricPrompt.Builder(activity)
                .setTitle("Unlock URITECT history")
                .setDescription("Confirm your device PIN, pattern or password to access saved health records.")
                .setAllowedAuthenticators(BiometricManager.Authenticators.DEVICE_CREDENTIAL)
                .build()
                .authenticate(CancellationSignal(), activity.mainExecutor, object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) { finishAuthentication(true) }
                    override fun onAuthenticationError(code: Int, message: CharSequence) { finishAuthentication(false) }
                })
        } else {
            @Suppress("DEPRECATION")
            val intent = guard.createConfirmDeviceCredentialIntent("Unlock URITECT history", "Confirm your device credential to access saved health records.")
                ?: throw IllegalStateException("Device authentication is unavailable.")
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, requestCode)
        }
    }
    fun handle(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "privacy" -> {
                if (call.argument<Boolean>("enabled") == true) activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                else if (activity.hasWindowFocus()) activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                result.success(null)
            }
            "lock" -> { authenticatedUntil = 0; result.success(null) }
            "authenticate" -> {
                val guard = activity.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                if (!guard.isDeviceSecure) {
                    result.error("DEVICE_LOCK_REQUIRED", "Set a device PIN, pattern or password to save or unlock history.", null)
                } else if (pending != null) {
                    result.error("AUTH_BUSY", "A history unlock is already in progress.", null)
                } else if (SystemClock.elapsedRealtime() < authenticatedUntil && !guard.isDeviceLocked) {
                    result.success(mapOf("authenticated" to true, "remainingMillis" to authenticatedUntil - SystemClock.elapsedRealtime()))
                } else {
                    pending = result
                    worker.execute {
                        try {
                            // Preserve the existing alias. New keys must exist before authentication.
                            key()
                            activity.runOnUiThread {
                                try { showCredentialPrompt(guard) }
                                catch (e: Exception) { pending = null; result.error("AUTH_UNAVAILABLE", "Could not open device authentication. Saved files were preserved.", null) }
                            }
                        } catch (e: Exception) {
                            Log.w("UritectHistorySecurity", "History key preparation failed: ${e.javaClass.simpleName}")
                            activity.runOnUiThread { pending = null; result.error("HISTORY_KEY_UNAVAILABLE", "The existing history key is unavailable. Saved files were preserved.", null) }
                        }
                    }
                }
            }
            "encrypt", "decrypt" -> {
                val bytes = call.argument<ByteArray>("bytes")
                val context = call.argument<String>("context")
                if (bytes == null || context == null || !context.startsWith("uritect:")) {
                    result.error("INVALID_REQUEST", "Invalid protected-history request.", null); return
                }
                worker.execute {
                    try {
                        val guard = activity.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
                        check(SystemClock.elapsedRealtime() < authenticatedUntil && !guard.isDeviceLocked) { "History is locked. Unlock it again." }
                        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                        val output: ByteArray
                        if (call.method == "encrypt") {
                            cipher.init(Cipher.ENCRYPT_MODE, key())
                            check(cipher.iv.size == 12) { "Unsupported protected-history nonce." }
                            cipher.updateAAD(context.toByteArray(Charsets.UTF_8))
                            output = byteArrayOf(85,82,72,49) + cipher.iv + cipher.doFinal(bytes)
                        } else {
                            require(bytes.size >= 32 && bytes.copyOfRange(0,4).contentEquals(byteArrayOf(85,82,72,49))) { "Unrecognized encrypted record." }
                            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, bytes.copyOfRange(4,16)))
                            cipher.updateAAD(context.toByteArray(Charsets.UTF_8))
                            output = cipher.doFinal(bytes.copyOfRange(16,bytes.size))
                        }
                        activity.runOnUiThread { result.success(output) }
                    } catch (e: Exception) {
                        Log.w("UritectHistorySecurity", "Protected operation failed: ${e.javaClass.simpleName}")
                        // Preserve encrypted files. Never generate a replacement key to hide a decryption failure.
                        val code = when (e) {
                            is AEADBadTagException, is IllegalArgumentException -> "HISTORY_INTEGRITY_ERROR"
                            is UserNotAuthenticatedException, is IllegalStateException -> "HISTORY_LOCKED"
                            else -> "HISTORY_KEY_UNAVAILABLE"
                        }
                        if (code == "HISTORY_LOCKED") authenticatedUntil = 0L
                        val message = when (code) {
                            "HISTORY_LOCKED" -> "History is locked. Retry with your device PIN, pattern or password. Saved files were preserved."
                            "HISTORY_INTEGRITY_ERROR" -> "History integrity could not be verified. Saved files were preserved."
                            else -> "The history key is unavailable. Saved files were preserved."
                        }
                        activity.runOnUiThread { result.error(code, message, null) }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (store.containsAlias(alias)) return store.getKey(alias, null) as SecretKey
        val builder = KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
        if (Build.VERSION.SDK_INT >= 30) builder.setUserAuthenticationParameters(120, KeyProperties.AUTH_DEVICE_CREDENTIAL)
        else { @Suppress("DEPRECATION") builder.setUserAuthenticationValidityDurationSeconds(120) }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(builder.build()); generateKey()
        }
    }
}

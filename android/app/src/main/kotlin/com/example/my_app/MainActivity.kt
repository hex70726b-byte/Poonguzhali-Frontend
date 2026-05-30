package com.example.my_app

import android.Manifest
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Vibrator
import android.os.VibrationEffect
import android.speech.tts.TextToSpeech
import java.util.Locale
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayList
import java.util.HashMap

class MainActivity : FlutterActivity() {
    private val CHANNEL = "sms_reader_channel"
    private val SMS_PERMISSION_CODE = 1234
    private var permissionResult: MethodChannel.Result? = null
    private var tts: TextToSpeech? = null

    private fun speakText(text: String) {
        if (tts == null) {
            tts = TextToSpeech(this) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    tts?.language = Locale.US
                    tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, null)
                }
            }
        } else {
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, null)
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestSmsPermission" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED) {
                        result.success("granted")
                    } else {
                        permissionResult = result
                        ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.READ_SMS), SMS_PERMISSION_CODE)
                    }
                }
                "checkSmsPermission" -> {
                    val isGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                    result.success(isGranted)
                }
                "requestStoragePermission" -> {
                    val hasRead = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                    val hasWrite = ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                    if (hasRead && hasWrite) {
                        result.success("granted")
                    } else {
                        permissionResult = result
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE),
                            5678
                        )
                    }
                }
                "checkStoragePermission" -> {
                    val hasRead = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                    val hasWrite = ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                    result.success(hasRead && hasWrite)
                }
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    speakText(text)
                    result.success(true)
                }
                "vibrate" -> {
                    val vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        vibrator.vibrate(VibrationEffect.createOneShot(500, VibrationEffect.DEFAULT_AMPLITUDE))
                    } else {
                        @Suppress("DEPRECATION")
                        vibrator.vibrate(500)
                    }
                    result.success(true)
                }
                "readBankSms" -> {
                    if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED) {
                        val smsList = fetchBankSms()
                        result.success(smsList)
                    } else {
                        result.error("PERMISSION_DENIED", "SMS Permission is not granted", null)
                    }
                }
                "markSmsProcessed" -> {
                    val dateVal = call.argument<Long>("date")
                    if (dateVal != null) {
                        val sharedPrefs = getSharedPreferences("processed_sms_prefs", Context.MODE_PRIVATE)
                        sharedPrefs.edit().putBoolean(dateVal.toString(), true).apply()
                        result.success(true)
                    } else {
                        val dateStringVal = call.argument<String>("date")
                        if (dateStringVal != null) {
                            val sharedPrefs = getSharedPreferences("processed_sms_prefs", Context.MODE_PRIVATE)
                            sharedPrefs.edit().putBoolean(dateStringVal, true).apply()
                            result.success(true)
                        } else {
                            result.error("BAD_ARGUMENT", "Date is missing", null)
                        }
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                permissionResult?.success("granted")
            } else {
                permissionResult?.success("denied")
            }
            permissionResult = null
        } else if (requestCode == 5678) {
            val allGranted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            if (allGranted) {
                permissionResult?.success("granted")
            } else {
                permissionResult?.success("denied")
            }
            permissionResult = null
        }
    }

    private fun fetchBankSms(): List<Map<String, Any>> {
        val smsList = ArrayList<Map<String, Any>>()
        val uri = Uri.parse("content://sms/inbox")
        val projection = arrayOf("address", "body", "date")
        
        val sharedPrefs = getSharedPreferences("processed_sms_prefs", Context.MODE_PRIVATE)
        
        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(uri, projection, null, null, "date DESC")
            if (cursor != null && cursor.moveToFirst()) {
                val addressIdx = cursor.getColumnIndexOrThrow("address")
                val bodyIdx = cursor.getColumnIndexOrThrow("body")
                val dateIdx = cursor.getColumnIndexOrThrow("date")
                
                var count = 0
                do {
                    val address = cursor.getString(addressIdx) ?: ""
                    val body = cursor.getString(bodyIdx) ?: ""
                    val date = cursor.getLong(dateIdx)
                    
                    if (sharedPrefs.contains(date.toString())) {
                        continue
                    }
                    
                    // Simple bank transaction filtering
                    val bodyLower = body.lowercase()
                    val isDebit = bodyLower.contains("debited") || bodyLower.contains("withdrawn") || bodyLower.contains("spent") || bodyLower.contains("sent rs") || bodyLower.contains("sent to") || bodyLower.contains("paid for") || bodyLower.contains("charged")
                    val isCredit = bodyLower.contains("credited") || bodyLower.contains("deposited") || bodyLower.contains("received rs") || bodyLower.contains("received from") || bodyLower.contains("added to your account") || bodyLower.contains("refunded")
                    
                    // Only include transaction messages
                    if (isDebit || isCredit || bodyLower.contains("transaction") || bodyLower.contains("a/c") || bodyLower.contains("acct") || bodyLower.contains("bank")) {
                        val smsMap = HashMap<String, Any>()
                        smsMap["sender"] = address
                        smsMap["body"] = body
                        smsMap["date"] = date
                        smsMap["type"] = if (isDebit) "debit" else if (isCredit) "credit" else "general"
                        
                        smsList.add(smsMap)
                        count++
                        // Fetch a reasonable limit of recent transactions, say 40
                        if (count >= 40) {
                            break
                        }
                    }
                } while (cursor.moveToNext())
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            cursor?.close()
        }
        return smsList
    }
}

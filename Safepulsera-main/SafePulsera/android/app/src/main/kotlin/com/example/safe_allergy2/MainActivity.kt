package com.example.safe_allergy2

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.media.AudioManager

class MainActivity : FlutterActivity() {
  private val CHANNEL = "com.safeallergy/audio"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "isInSilentMode" -> {
          val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
          // Detectar si está en SILENT (modo silencio) o VIBRATE (modo vibración)
          val isSilent = audioManager.ringerMode != AudioManager.RINGER_MODE_NORMAL
          result.success(isSilent)
        }
        "getVolume" -> {
          val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
          val volume = audioManager.getStreamVolume(AudioManager.STREAM_RING)
          result.success(volume)
        }
        else -> result.notImplemented()
      }
    }
  }
}

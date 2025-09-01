package com.hear4me.hear4me_protosound

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import org.pytorch.LiteModuleLoader
import org.pytorch.Module
import org.pytorch.Tensor
import org.pytorch.IValue

/** Hear4meProtosoundPlugin */
class Hear4meProtosoundPlugin :
  FlutterPlugin,
  MethodCallHandler,
  EventChannel.StreamHandler {

  private lateinit var methodChannel: MethodChannel
  private lateinit var eventChannel: EventChannel
  private lateinit var appContext: Context

  // PyTorch model (loaded on initialize)
  private var module: Module? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    appContext = binding.applicationContext
    methodChannel = MethodChannel(binding.binaryMessenger, "hear4me_protosound")
    methodChannel.setMethodCallHandler(this)

    eventChannel = EventChannel(binding.binaryMessenger, "hear4me_protosound/events")
    eventChannel.setStreamHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      // Dart: await Hear4MeProtoSound.initialize(modelAsset: 'protosound_model.ptl')
      "initialize" -> {
        val asset = call.argument<String>("modelAsset") ?: "protosound_model.ptl"
        try {
          module = LiteModuleLoader.load(assetFilePath(appContext, asset))
          result.success(null) // OK
        } catch (e: Exception) {
          result.error("INIT_FAILED", "Failed to load model asset: $asset", e.toString())
        }
      }

      // stubs you’ll fill next
      "addTrainingSample" -> {
        // TODO: capture 1s PCM, compute features, forward -> store embedding
        result.success(null)
      }
      "train" -> {
        // TODO: average stored embeddings per class -> prototype
        result.success(mapOf<String, Any>())
      }
      "startRecognition" -> {
        // TODO: start audio loop, emit detections via eventChannel.sink.success(...)
        result.success(null)
      }
      "stopRecognition" -> {
        // TODO: stop loop
        result.success(null)
      }

      else -> result.notImplemented()
    }
  }

  // ---- EventChannel ----
  private var eventSink: EventChannel.EventSink? = null
  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
  }
  override fun onCancel(arguments: Any?) {
    eventSink = null
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel.setMethodCallHandler(null)
    eventChannel.setStreamHandler(null)
  }

  // ---- Helpers ----
  // Copies an asset to internal storage and returns its absolute path.
  private fun assetFilePath(context: Context, assetName: String): String {
    val file = java.io.File(context.filesDir, assetName)
    if (file.exists() && file.length() > 0) return file.absolutePath
    context.assets.open(assetName).use { input ->
      java.io.FileOutputStream(file).use { output ->
        val buffer = ByteArray(4 * 1024)
        var read: Int
        while (input.read(buffer).also { read = it } != -1) {
          output.write(buffer, 0, read)
        }
        output.flush()
      }
    }
    return file.absolutePath
  }

  // Example of how you’ll run the model later; keeps the imports in place.
  @Suppress("unused")
  private fun forwardExample(dummy: FloatArray): FloatArray {
    val m = module ?: throw IllegalStateException("Model not loaded")
    // expecting [1,1,T,M] flattened; replace 83 and 128 if your shape differs
    val input = Tensor.fromBlob(dummy, longArrayOf(1, 1, 83, 128))
    val out = m.forward(IValue.from(input)).toTensor()
    return out.dataAsFloatArray
  }
}

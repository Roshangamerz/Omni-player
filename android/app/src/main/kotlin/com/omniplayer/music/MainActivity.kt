package com.omniplayer.music

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.RingtoneManager
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.os.Build
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.Settings
import android.support.v4.media.MediaMetadataCompat
import android.support.v4.media.session.MediaSessionCompat
import android.support.v4.media.session.PlaybackStateCompat
import android.widget.RemoteViews
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.omniplayer.music/media_notification"
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "omni_player_playback_channel"

    private var mediaSession: MediaSessionCompat? = null
    private var methodChannel: MethodChannel? = null
    private var notificationManager: NotificationManager? = null

    private var currentTitle: String = "Omni Music"
    private var currentArtist: String = "Playing Music"
    private var currentArtworkUrl: String = ""
    private var isPlayingState: Boolean = false
    private var currentArtworkBitmap: Bitmap? = null
    private var currentAccentColor: Int = 0xFF00FFC6.toInt()
    private var pendingFilePickerResult: MethodChannel.Result? = null
    private var pendingRecordPermissionResult: MethodChannel.Result? = null
    private var pendingRecordDurationMs: Int = 5500
    private val REQ_PICK_AUDIO = 5001
    private val REQ_PICK_FOLDER = 5002
    private val REQ_RECORD_AUDIO = 5003

    private var nativeEqualizer: Equalizer? = null
    private var nativeBassBoost: BassBoost? = null
    private var nativeLoudness: LoudnessEnhancer? = null
    @Volatile private var isRecordingShazam: Boolean = false

    companion object {
        const val ACTION_PLAY = "com.omniplayer.music.ACTION_PLAY"
        const val ACTION_PAUSE = "com.omniplayer.music.ACTION_PAUSE"
        const val ACTION_NEXT = "com.omniplayer.music.ACTION_NEXT"
        const val ACTION_PREV = "com.omniplayer.music.ACTION_PREV"
        const val ACTION_STOP = "com.omniplayer.music.ACTION_STOP"
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_PICK_AUDIO) {
            val paths = mutableListOf<String>()
            if (resultCode == RESULT_OK && data != null) {
                if (data.clipData != null) {
                    val count = data.clipData!!.itemCount
                    for (i in 0 until count) {
                        val uri = data.clipData!!.getItemAt(i).uri
                        val path = getPathFromUri(uri)
                        if (path != null) paths.add(path)
                    }
                } else if (data.data != null) {
                    val path = getPathFromUri(data.data!!)
                    if (path != null) paths.add(path)
                }
            }
            pendingFilePickerResult?.success(paths)
            pendingFilePickerResult = null
        } else if (requestCode == REQ_PICK_FOLDER) {
            var folderPath: String? = null
            if (resultCode == RESULT_OK && data?.data != null) {
                folderPath = getFolderPathFromTreeUri(data.data!!)
            }
            pendingFilePickerResult?.success(folderPath)
            pendingFilePickerResult = null
        }
    }

    private fun getPathFromUri(uri: android.net.Uri): String? {
        val scheme = uri.scheme
        if (scheme == "file") return uri.path
        if (scheme == "content") {
            try {
                val cursor = contentResolver.query(uri, arrayOf(android.provider.MediaStore.Audio.Media.DATA), null, null, null)
                cursor?.use {
                    if (it.moveToFirst()) {
                        val idx = it.getColumnIndex(android.provider.MediaStore.Audio.Media.DATA)
                        if (idx != -1) return it.getString(idx)
                    }
                }
            } catch (_: Exception) {}
        }
        return uri.path
    }

    private fun getFolderPathFromTreeUri(uri: android.net.Uri): String? {
        try {
            val docId = android.provider.DocumentsContract.getTreeDocumentId(uri)
            val split = docId.split(":")
            if (split.isNotEmpty()) {
                val type = split[0]
                val relativePath = if (split.size > 1) split[1] else ""
                if ("primary".equals(type, ignoreCase = true)) {
                    return android.os.Environment.getExternalStorageDirectory().toString() + "/" + relativePath
                } else {
                    return "/storage/" + type + "/" + relativePath
                }
            }
        } catch (_: Exception) {}
        return null
    }

    private val mediaReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_PLAY -> methodChannel?.invokeMethod("onNotificationAction", "play")
                ACTION_PAUSE -> methodChannel?.invokeMethod("onNotificationAction", "pause")
                ACTION_NEXT -> methodChannel?.invokeMethod("onNotificationAction", "next")
                ACTION_PREV -> methodChannel?.invokeMethod("onNotificationAction", "previous")
                ACTION_STOP -> {
                    clearMediaNotification()
                    methodChannel?.invokeMethod("onNotificationAction", "stop")
                }
            }
        }
    }

    private var initialSharedText: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        when (intent.action) {
            Intent.ACTION_SEND -> {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                    ?: intent.clipData?.getItemAt(0)?.text?.toString()
                if (!text.isNullOrBlank()) {
                    initialSharedText = text
                    methodChannel?.invokeMethod("onSharedTextReceived", text)
                }
            }
            Intent.ACTION_VIEW -> {
                val data = intent.dataString
                if (!data.isNullOrBlank()) {
                    initialSharedText = data
                    methodChannel?.invokeMethod("onSharedTextReceived", data)
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        createNotificationChannel()
        initMediaSession()

        val filter = IntentFilter().apply {
            addAction(ACTION_PLAY)
            addAction(ACTION_PAUSE)
            addAction(ACTION_NEXT)
            addAction(ACTION_PREV)
            addAction(ACTION_STOP)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(mediaReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(mediaReceiver, filter)
        }

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInitialSharedText" -> {
                    val text = initialSharedText
                    initialSharedText = null
                    result.success(text)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        pm?.isIgnoringBatteryOptimizations(packageName) ?: false
                    } else true
                    result.success(isIgnoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        try {
                            val intent = Intent(android.provider.Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = android.net.Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "updateNotification" -> {
                    val title = call.argument<String>("title") ?: "Omni Music"
                    val artist = call.argument<String>("artist") ?: "Music"
                    val artworkUrl = call.argument<String>("artworkUrl") ?: ""
                    val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                    val themeColor = call.argument<Number>("themeColor")?.toInt() ?: 0xFF00FFC6.toInt()
                    val positionMs = call.argument<Number>("positionMs")?.toLong() ?: 0L
                    val durationMs = call.argument<Number>("durationMs")?.toLong() ?: 0L

                    updateMediaNotification(title, artist, artworkUrl, isPlaying, themeColor, positionMs, durationMs)

                    try {
                        val svcIntent = Intent(this, OmniMediaService::class.java).apply {
                            action = if (isPlaying) OmniMediaService.ACTION_START else OmniMediaService.ACTION_STOP
                        }
                        if (isPlaying) {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                startForegroundService(svcIntent)
                            } else {
                                startService(svcIntent)
                            }
                        } else {
                            startService(svcIntent)
                        }
                    } catch (_: Exception) {}

                    result.success(true)
                }
                "pickAudioFiles" -> {
                    pendingFilePickerResult = result
                    val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                        type = "audio/*"
                        putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
                        addCategory(Intent.CATEGORY_OPENABLE)
                    }
                    startActivityForResult(Intent.createChooser(intent, "Select Audio Files"), REQ_PICK_AUDIO)
                }
                "pickAudioFolder" -> {
                    pendingFilePickerResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE)
                    startActivityForResult(intent, REQ_PICK_FOLDER)
                }
                "clearNotification" -> {
                    clearMediaNotification()
                    try {
                        val svcIntent = Intent(this, OmniMediaService::class.java).apply {
                            action = OmniMediaService.ACTION_STOP
                        }
                        startService(svcIntent)
                    } catch (_: Exception) {}
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // ─── SHAZAM / OMNI FIND MIC RECORDER + DEJAVU SIGNATURE CHANNEL ───
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.omniplayer.music/shazam_recorder")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "recordAndSign" -> {
                        val durationMs = call.argument<Number>("durationMs")?.toInt() ?: 5500
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO)
                            != PackageManager.PERMISSION_GRANTED
                        ) {
                            pendingRecordPermissionResult = result
                            pendingRecordDurationMs = durationMs
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.RECORD_AUDIO),
                                REQ_RECORD_AUDIO
                            )
                        } else {
                            startShazamCapture(durationMs, result)
                        }
                    }
                    "cancelRecord" -> {
                        isRecordingShazam = false
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        // ─── NATIVE ANDROID AUDIO EQUALIZER & FX CHANNEL ───
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.omniplayer.music/audio_fx")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initEq" -> {
                        try {
                            ensureAudioFx()
                            val eq = nativeEqualizer
                            if (eq == null) {
                                result.success(mapOf("supported" to false))
                                return@setMethodCallHandler
                            }
                            val bands = eq.numberOfBands.toInt()
                            val range = eq.bandLevelRange
                            val bandList = (0 until bands).map { idx ->
                                mapOf(
                                    "index" to idx,
                                    "centerFreqHz" to (eq.getCenterFreq(idx.toShort()) / 1000),
                                    "levelMb" to eq.getBandLevel(idx.toShort()).toInt()
                                )
                            }
                            result.success(mapOf(
                                "supported" to true,
                                "enabled" to eq.enabled,
                                "minMb" to range[0].toInt(),
                                "maxMb" to range[1].toInt(),
                                "bands" to bandList
                            ))
                        } catch (e: Exception) {
                            result.success(mapOf("supported" to false, "error" to e.message))
                        }
                    }
                    "setEqEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        try {
                            ensureAudioFx()
                            nativeEqualizer?.enabled = enabled
                            nativeBassBoost?.enabled = enabled
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                                nativeLoudness?.enabled = enabled
                            }
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "setBandLevel" -> {
                        val band = call.argument<Number>("band")?.toInt() ?: 0
                        val levelMb = call.argument<Number>("levelMb")?.toInt() ?: 0
                        try {
                            ensureAudioFx()
                            nativeEqualizer?.setBandLevel(band.toShort(), levelMb.toShort())
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "setBassBoost" -> {
                        val strength = (call.argument<Number>("strength")?.toInt() ?: 0).coerceIn(0, 1000)
                        try {
                            ensureAudioFx()
                            nativeBassBoost?.setStrength(strength.toShort())
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    "setLoudnessGain" -> {
                        val gainMb = (call.argument<Number>("gainMb")?.toInt() ?: 0).coerceIn(0, 2000)
                        try {
                            ensureAudioFx()
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                                nativeLoudness?.setTargetGain(gainMb)
                            }
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // ─── NATIVE SHARE SHEET & SET RINGTONE CHANNEL ───
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.omniplayer.music/system_actions")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val title = call.argument<String>("title") ?: "Share Track"
                        try {
                            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(Intent.EXTRA_SUBJECT, title)
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            startActivity(Intent.createChooser(sendIntent, title))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SHARE_ERR", e.message, null)
                        }
                    }
                    "setRingtone" -> {
                        val filePath = call.argument<String>("filePath") ?: ""
                        val title = call.argument<String>("title") ?: "Omni Ringtone"
                        handleSetRingtone(filePath, title, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_RECORD_AUDIO) {
            val res = pendingRecordPermissionResult
            pendingRecordPermissionResult = null
            if (res != null) {
                if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    startShazamCapture(pendingRecordDurationMs, res)
                } else {
                    res.error("PERMISSION_DENIED", "Microphone permission is required for Omni Find", null)
                }
            }
        }
    }

    private fun startShazamCapture(durationMs: Int, result: MethodChannel.Result) {
        if (isRecordingShazam) {
            result.error("BUSY", "Already listening", null)
            return
        }
        isRecordingShazam = true
        thread {
            var recorder: AudioRecord? = null
            try {
                val sampleRate = 16000
                val minBuf = AudioRecord.getMinBufferSize(
                    sampleRate,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT
                ).coerceAtLeast(4096)

                recorder = AudioRecord(
                    MediaRecorder.AudioSource.MIC,
                    sampleRate,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                    minBuf * 2
                )
                if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                    throw IllegalStateException("Microphone initialization failed")
                }

                val targetBytes = (sampleRate * 2 * (durationMs / 1000.0)).toInt()
                val pcmOut = java.io.ByteArrayOutputStream(targetBytes)
                val buf = ByteArray(4096)
                recorder.startRecording()
                val startTime = System.currentTimeMillis()
                while (isRecordingShazam && pcmOut.size() < targetBytes) {
                    val read = recorder.read(buf, 0, buf.size)
                    if (read > 0) {
                        pcmOut.write(buf, 0, read)
                    }
                    if (System.currentTimeMillis() - startTime > durationMs + 1500) break
                }
                recorder.stop()
                isRecordingShazam = false

                val rawBytes = pcmOut.toByteArray()
                if (rawBytes.size < 32000) {
                    throw IllegalStateException("Audio capture too short")
                }
                val evenSize = rawBytes.size - (rawBytes.size % 2)
                val trimmed = if (evenSize == rawBytes.size) rawBytes else rawBytes.copyOf(evenSize)
                val signature = ShazamSignatureGenerator.fromI16(trimmed)
                val actualMs = (trimmed.size / 2) * 1000L / sampleRate
                runOnUiThread {
                    result.success(mapOf("signature" to signature, "durationMs" to actualMs))
                }
            } catch (e: Exception) {
                isRecordingShazam = false
                runOnUiThread {
                    result.error("RECORD_ERR", e.message ?: "Failed to record audio", null)
                }
            } finally {
                try {
                    recorder?.release()
                } catch (_: Exception) {}
            }
        }
    }

    private fun ensureAudioFx() {
        if (nativeEqualizer == null) {
            nativeEqualizer = Equalizer(0, 0).apply { enabled = false }
        }
        if (nativeBassBoost == null) {
            nativeBassBoost = BassBoost(0, 0).apply { enabled = false }
        }
        if (nativeLoudness == null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            nativeLoudness = LoudnessEnhancer(0).apply { enabled = false }
        }
    }

    private fun handleSetRingtone(filePath: String, title: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.System.canWrite(this)) {
            try {
                val intent = Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
                    data = android.net.Uri.parse("package:$packageName")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                result.success(mapOf("ok" to false, "needsPermission" to true))
            } catch (e: Exception) {
                result.error("RINGTONE_ERR", e.message, null)
            }
            return
        }
        thread {
            try {
                val src = File(filePath)
                if (!src.exists()) throw IllegalStateException("Download track offline first before setting as ringtone")
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, "$title.mp3")
                    put(MediaStore.MediaColumns.TITLE, title)
                    put(MediaStore.MediaColumns.MIME_TYPE, "audio/mpeg")
                    put(MediaStore.Audio.Media.IS_RINGTONE, true)
                    put(MediaStore.Audio.Media.IS_NOTIFICATION, false)
                    put(MediaStore.Audio.Media.IS_ALARM, false)
                    put(MediaStore.Audio.Media.IS_MUSIC, false)
                }
                val uri = contentResolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
                    ?: throw IllegalStateException("Could not create MediaStore entry")
                contentResolver.openOutputStream(uri)?.use { out ->
                    FileInputStream(src).use { input -> input.copyTo(out) }
                }
                RingtoneManager.setActualDefaultRingtoneUri(this, RingtoneManager.TYPE_RINGTONE, uri)
                runOnUiThread {
                    result.success(mapOf("ok" to true, "needsPermission" to false))
                }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("RINGTONE_ERR", e.message ?: "Failed to set ringtone", null)
                }
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Omni Music Playback",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Media controls and playback notification for Omni Music"
                setShowBadge(false)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            notificationManager?.createNotificationChannel(channel)
        }
    }

    private fun initMediaSession() {
        mediaSession = MediaSessionCompat(this, "OmniPlayerMediaSession").apply {
            setFlags(
                MediaSessionCompat.FLAG_HANDLES_MEDIA_BUTTONS or
                MediaSessionCompat.FLAG_HANDLES_TRANSPORT_CONTROLS
            )
            setCallback(object : MediaSessionCompat.Callback() {
                override fun onPlay() {
                    methodChannel?.invokeMethod("onNotificationAction", "play")
                }
                override fun onPause() {
                    methodChannel?.invokeMethod("onNotificationAction", "pause")
                }
                override fun onSkipToNext() {
                    methodChannel?.invokeMethod("onNotificationAction", "next")
                }
                override fun onSkipToPrevious() {
                    methodChannel?.invokeMethod("onNotificationAction", "previous")
                }
                override fun onSeekTo(pos: Long) {
                    methodChannel?.invokeMethod("onNotificationSeek", pos)
                }
                override fun onStop() {
                    methodChannel?.invokeMethod("onNotificationAction", "stop")
                }
            })
            isActive = true
        }
    }

    private fun extractVibrantColor(bitmap: Bitmap?, fallback: Int): Int {
        if (bitmap == null) return fallback
        try {
            var rSum = 0L; var gSum = 0L; var bSum = 0L; var count = 0
            val w = bitmap.width; val h = bitmap.height
            val startX = (w * 0.2).toInt()
            val endX = (w * 0.8).toInt()
            val startY = (h * 0.2).toInt()
            val endY = (h * 0.8).toInt()
            val step = 4.coerceAtLeast(w / 40)

            for (x in startX until endX step step) {
                for (y in startY until endY step step) {
                    val pixel = bitmap.getPixel(x, y)
                    val r = (pixel shr 16) and 0xFF
                    val g = (pixel shr 8) and 0xFF
                    val b = pixel and 0xFF
                    val brightness = (r + g + b) / 3
                    if (brightness in 45..220) {
                        rSum += r; gSum += g; bSum += b; count++
                    }
                }
            }
            if (count > 0) {
                val r = (rSum / count).toInt().coerceIn(0, 255)
                val g = (gSum / count).toInt().coerceIn(0, 255)
                val b = (bSum / count).toInt().coerceIn(0, 255)
                return (0xFF shl 24) or (r shl 16) or (g shl 8) or b
            }
        } catch (_: Exception) {}
        return fallback
    }

    private var currentPositionMs: Long = 0L
    private var currentDurationMs: Long = 0L

    private fun updateMediaNotification(
        title: String,
        artist: String,
        artworkUrl: String,
        isPlaying: Boolean,
        themeColor: Int,
        positionMs: Long = 0L,
        durationMs: Long = 0L
    ) {
        currentTitle = title
        currentArtist = artist
        isPlayingState = isPlaying
        currentAccentColor = themeColor
        currentPositionMs = positionMs
        currentDurationMs = durationMs

        // Update MediaSession State with active progress scrubber position
        val stateBuilder = PlaybackStateCompat.Builder()
            .setActions(
                PlaybackStateCompat.ACTION_PLAY or
                PlaybackStateCompat.ACTION_PAUSE or
                PlaybackStateCompat.ACTION_PLAY_PAUSE or
                PlaybackStateCompat.ACTION_SKIP_TO_NEXT or
                PlaybackStateCompat.ACTION_SKIP_TO_PREVIOUS or
                PlaybackStateCompat.ACTION_SEEK_TO or
                PlaybackStateCompat.ACTION_STOP
            )
            .setState(
                if (isPlaying) PlaybackStateCompat.STATE_PLAYING else PlaybackStateCompat.STATE_PAUSED,
                positionMs,
                if (isPlaying) 1.0f else 0.0f
            )
        mediaSession?.setPlaybackState(stateBuilder.build())

        // Update MediaSession Metadata with Duration for Lock Screen seekbar
        val metadataBuilder = MediaMetadataCompat.Builder()
            .putString(MediaMetadataCompat.METADATA_KEY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_ARTIST, artist)
            .putString(MediaMetadataCompat.METADATA_KEY_ALBUM, "Omni Music HD")
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_TITLE, title)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_SUBTITLE, artist)
            .putString(MediaMetadataCompat.METADATA_KEY_DISPLAY_DESCRIPTION, "Omni Music • Lossless Hi-Fi")
        if (durationMs > 0) {
            metadataBuilder.putLong(MediaMetadataCompat.METADATA_KEY_DURATION, durationMs)
        }
        if (currentArtworkBitmap != null) {
            metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ART, currentArtworkBitmap)
            metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, currentArtworkBitmap)
            metadataBuilder.putBitmap(MediaMetadataCompat.METADATA_KEY_DISPLAY_ICON, currentArtworkBitmap)
        }
        mediaSession?.setMetadata(metadataBuilder.build())

        if (artworkUrl != currentArtworkUrl && artworkUrl.isNotEmpty()) {
            currentArtworkUrl = artworkUrl
            thread {
                try {
                    val url = URL(artworkUrl)
                    val conn = url.openConnection() as HttpURLConnection
                    conn.doInput = true
                    conn.connectTimeout = 3000
                    conn.readTimeout = 3000
                    conn.connect()
                    val input: InputStream = conn.inputStream
                    currentArtworkBitmap = BitmapFactory.decodeStream(input)
                    currentAccentColor = extractVibrantColor(currentArtworkBitmap, themeColor)
                } catch (_: Exception) {
                    currentArtworkBitmap = null
                }
                runOnUiThread {
                    if (currentArtworkBitmap != null) {
                        val metaWithArt = MediaMetadataCompat.Builder(mediaSession?.controller?.metadata)
                            .putBitmap(MediaMetadataCompat.METADATA_KEY_ART, currentArtworkBitmap)
                            .putBitmap(MediaMetadataCompat.METADATA_KEY_ALBUM_ART, currentArtworkBitmap)
                            .putBitmap(MediaMetadataCompat.METADATA_KEY_DISPLAY_ICON, currentArtworkBitmap)
                        if (currentDurationMs > 0) {
                            metaWithArt.putLong(MediaMetadataCompat.METADATA_KEY_DURATION, currentDurationMs)
                        }
                        mediaSession?.setMetadata(metaWithArt.build())
                    }
                    buildAndShowNotification()
                }
            }
        } else {
            buildAndShowNotification()
        }
    }

    private fun buildAndShowNotification() {
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        // Tap to open app
        val contentIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            },
            flags
        )

        val prevIntent = PendingIntent.getBroadcast(this, 1, Intent(ACTION_PREV), flags)
        val playPauseIntent = PendingIntent.getBroadcast(
            this, 2,
            Intent(if (isPlayingState) ACTION_PAUSE else ACTION_PLAY),
            flags
        )
        val nextIntent = PendingIntent.getBroadcast(this, 3, Intent(ACTION_NEXT), flags)
        val deleteIntent = PendingIntent.getBroadcast(this, 4, Intent(ACTION_STOP), flags)

        // Native Android MediaStyle notification (Powers lock screen player, Quick Settings carousel, Bluetooth metadata)
        val mediaStyle = androidx.media.app.NotificationCompat.MediaStyle()
            .setMediaSession(mediaSession?.sessionToken)
            .setShowActionsInCompactView(0, 1, 2)
            .setShowCancelButton(true)
            .setCancelButtonIntent(deleteIntent)

        val builder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(currentTitle)
            .setContentText(currentArtist)
            .setSubText("Omni Music • Lossless 320k")
            .setLargeIcon(currentArtworkBitmap ?: BitmapFactory.decodeResource(resources, R.mipmap.launcher_icon))
            .setColor(currentAccentColor)
            .setColorized(true)
            .setContentIntent(contentIntent)
            .setDeleteIntent(deleteIntent)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(isPlayingState)
            .setShowWhen(false)
            .setOnlyAlertOnce(true)
            .addAction(R.drawable.ic_noti_prev, "Previous", prevIntent)
            .addAction(
                if (isPlayingState) R.drawable.ic_noti_pause else R.drawable.ic_noti_play,
                if (isPlayingState) "Pause" else "Play",
                playPauseIntent
            )
            .addAction(R.drawable.ic_noti_next, "Next", nextIntent)
            .setStyle(mediaStyle)

        try {
            notificationManager?.notify(NOTIFICATION_ID, builder.build())
        } catch (_: Exception) {}
    }

    private fun clearMediaNotification() {
        try {
            notificationManager?.cancel(NOTIFICATION_ID)
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        isRecordingShazam = false
        try {
            nativeEqualizer?.release()
            nativeBassBoost?.release()
            nativeLoudness?.release()
        } catch (_: Exception) {}
        try {
            unregisterReceiver(mediaReceiver)
        } catch (_: Exception) {}
        mediaSession?.release()
        super.onDestroy()
    }
}

package echo.music.iad1tya.utils

import android.app.ActivityManager
import android.content.Context
import android.os.Build

enum class PerformanceTier {
  LOW,
  MID,
  HIGH,
}

object DevicePerformance {
  @Volatile private var cachedTier: PerformanceTier? = null

  val supportsNativeBlur: Boolean
    get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S

  fun getTier(context: Context): PerformanceTier {
    cachedTier?.let { return it }
    val tier = computeTier(context.applicationContext)
    cachedTier = tier
    return tier
  }

  private fun computeTier(context: Context): PerformanceTier {
    return try {
      val am = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
      if (am?.isLowRamDevice == true) return PerformanceTier.LOW

      val memInfo = ActivityManager.MemoryInfo()
      am?.getMemoryInfo(memInfo)
      val totalRamMb = memInfo.totalMem / (1024L * 1024L)

      when {
        totalRamMb in 1..2800 || Build.VERSION.SDK_INT < Build.VERSION_CODES.P -> PerformanceTier.LOW
        totalRamMb < 5500 || Build.VERSION.SDK_INT < Build.VERSION_CODES.S -> PerformanceTier.MID
        else -> PerformanceTier.HIGH
      }
    } catch (_: Exception) {
      if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) PerformanceTier.MID else PerformanceTier.HIGH
    }
  }
}

package echo.music.iad1tya.ui.component

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.basicMarquee
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import coil3.request.ImageRequest
import echo.music.iad1tya.R
import echo.music.iad1tya.utils.DevicePerformance
import echo.music.iad1tya.utils.PerformanceTier
import kotlinx.coroutines.delay

@Composable
fun RetroTurntableVinylPlayer(
  artworkUri: String?,
  title: String,
  artist: String,
  isPlaying: Boolean,
  playerSize: Dp,
  progress: Float = 0f,
  modifier: Modifier = Modifier,
) {
  val context = LocalContext.current
  val tier = remember { DevicePerformance.getTier(context) }

  // Physical turntable rotation: smooth acceleration on play & natural coast-to-stop on pause
  var rotationAngle by remember { mutableFloatStateOf(0f) }
  var angularVelocity by remember { mutableFloatStateOf(0f) }
  val currentIsPlaying by rememberUpdatedState(isPlaying)

  LaunchedEffect(Unit) {
    var lastNanos = 0L
    while (true) {
      val playing = currentIsPlaying
      if (!playing && angularVelocity < 0.25f) {
        angularVelocity = 0f
        lastNanos = 0L
        delay(80)
        continue
      }
      withFrameNanos { frameNanos ->
        if (lastNanos != 0L) {
          val dt = ((frameNanos - lastNanos) / 1_000_000_000f).coerceIn(0f, 0.05f)
          val targetVelocity = if (playing) 138f else 0f
          val damping = if (playing) 4.5f else 2.8f
          angularVelocity += (targetVelocity - angularVelocity) * (dt * damping).coerceAtMost(1f)
          rotationAngle = (rotationAngle + angularVelocity * dt) % 360f
        }
        lastNanos = frameNanos
      }
    }
  }

  // Animated LED pulse while playing
  val ledPulse: State<Float>
  if (isPlaying && tier != PerformanceTier.LOW) {
    val infiniteTransition = rememberInfiniteTransition(label = "TurntableFX")
    ledPulse = infiniteTransition.animateFloat(
      initialValue = 0.45f,
      targetValue = 1.0f,
      animationSpec = infiniteRepeatable(
        animation = tween(750, easing = FastOutSlowInEasing),
        repeatMode = RepeatMode.Reverse,
      ),
      label = "LedPulse",
    )
  } else {
    ledPulse = remember(isPlaying) { mutableFloatStateOf(if (isPlaying) 1.0f else 0.3f) }
  }

  // Tone arm anchored below the OMNI-808 hardware block so it never overlaps text:
  // Sweeps from -14f (outer groove at 0%) to +6f (inner groove outside red ring at 100%); parks at -24f when paused
  val clampedProgress = progress.coerceIn(0f, 1f)
  val targetArmAngle = if (isPlaying) 10f + (14f * clampedProgress) else -10f
  val armAngle by animateFloatAsState(
    targetValue = targetArmAngle,
    animationSpec = spring(
      dampingRatio = Spring.DampingRatioNoBouncy,
      stiffness = Spring.StiffnessLow,
    ),
    label = "ToneArmAngle",
  )

  val vinylDiameter = playerSize * 0.80f
  val consoleWidth = playerSize * 0.61f
  val consoleHeight = 52.dp
  val decodeSize = if (tier == PerformanceTier.LOW) 300 else 512

  Box(
    modifier = modifier.size(playerSize),
    contentAlignment = Alignment.Center,
  ) {
    // 1. Static soft radial shadow behind the vinyl disc
    Box(
      modifier = Modifier
        .align(Alignment.CenterStart)
        .padding(start = 6.dp, top = 8.dp)
        .size(vinylDiameter * 1.04f)
        .drawWithCache {
          val shadowBrush = Brush.radialGradient(
            colors = listOf(Color.Black.copy(alpha = 0.58f), Color.Transparent),
            center = Offset(size.width / 2f, size.height / 2f),
            radius = size.width / 2f,
          )
          onDrawBehind { drawCircle(brush = shadowBrush) }
        },
    )

    // 2. Spinning Picture-Disc Vinyl Record
    Box(
      modifier = Modifier
        .align(Alignment.CenterStart)
        .padding(start = 8.dp)
        .size(vinylDiameter)
        .graphicsLayer { rotationZ = rotationAngle }
        .clip(CircleShape)
        .background(Color(0xFF111215)),
      contentAlignment = Alignment.Center,
    ) {
      if (!artworkUri.isNullOrBlank()) {
        AsyncImage(
          model = remember(artworkUri, decodeSize) {
            ImageRequest.Builder(context)
              .data(artworkUri)
              .size(decodeSize, decodeSize)
              .build()
          },
          contentDescription = null,
          contentScale = ContentScale.Crop,
          modifier = Modifier.fillMaxSize(),
        )
      } else {
        Icon(
          painter = painterResource(R.drawable.music_note),
          contentDescription = null,
          tint = Color.White.copy(alpha = 0.45f),
          modifier = Modifier.size(48.dp),
        )
      }

      // Dark Vintage Grooves + Warm Vignette + Anisotropic Sheen
      Spacer(
        modifier = Modifier
          .fillMaxSize()
          .drawWithCache {
            val center = Offset(size.width / 2f, size.height / 2f)
            val radius = size.width / 2f
            val sheenBrush = Brush.sweepGradient(
              colors = listOf(
                Color.White.copy(alpha = 0.02f),
                Color.White.copy(alpha = 0.16f),
                Color.White.copy(alpha = 0.02f),
                Color.White.copy(alpha = 0.14f),
                Color.White.copy(alpha = 0.02f),
              ),
              center = center,
            )
            val grooveRatios =
              if (tier == PerformanceTier.LOW) {
                floatArrayOf(0.95f, 0.86f, 0.77f, 0.68f, 0.59f, 0.50f)
              } else {
                floatArrayOf(0.96f, 0.91f, 0.86f, 0.81f, 0.76f, 0.71f, 0.66f, 0.61f, 0.56f, 0.51f)
              }
            val darkGrooveColor = Color.Black.copy(alpha = 0.48f)
            val darkGrooveStroke = Stroke(width = 2.1f)
            val vintageHighlightColor = Color(0xFFD7C4A3).copy(alpha = 0.07f)
            val vintageHighlightStroke = Stroke(width = 1.0f)
            val outerEdgeStroke = Stroke(width = 5f)
            val vintageVignette = Brush.radialGradient(
              colors = listOf(
                Color(0xFF1A140E).copy(alpha = 0.22f),
                Color(0xFF0E0C0A).copy(alpha = 0.44f),
              ),
              center = center,
              radius = radius,
            )

            onDrawBehind {
              drawCircle(brush = vintageVignette, radius = radius, center = center)
              for (gRatio in grooveRatios) {
                drawCircle(
                  color = darkGrooveColor,
                  radius = radius * gRatio,
                  center = center,
                  style = darkGrooveStroke,
                )
                drawCircle(
                  color = vintageHighlightColor,
                  radius = (radius * gRatio) - 1.5f,
                  center = center,
                  style = vintageHighlightStroke,
                )
              }
              drawCircle(brush = sheenBrush, radius = radius, center = center)
              drawCircle(
                color = Color(0xFF08090C),
                radius = radius - 2.5f,
                center = center,
                style = outerEdgeStroke,
              )
            }
          },
      )

      // Solid Dark Center Label inside Red Accent Ring
      val labelDiameter = vinylDiameter * 0.42f
      Box(
        modifier = Modifier
          .size(labelDiameter)
          .align(Alignment.Center)
          .clip(CircleShape)
          .background(Color(0xFF0D0E12))
          .border(4.5.dp, Color(0xFFD32F2F), CircleShape),
        contentAlignment = Alignment.Center,
      ) {
        Box(
          modifier = Modifier
            .size(16.dp)
            .clip(CircleShape)
            .background(Color(0xFF050507))
            .border(2.dp, Color(0xFFE0E0E0), CircleShape),
        )
      }
    }

    // 3. Connected Yellow Jumper Wires + Retro Docking Backplate + Animated Spark
    Spacer(
      modifier = Modifier
        .align(Alignment.CenterEnd)
        .padding(end = 14.dp)
        .size(width = 96.dp, height = 104.dp)
        .drawWithCache {
          val w = size.width
          val h = size.height
          val wirePath1 = Path().apply {
            moveTo(w * 0.14f, h * 0.26f)
            cubicTo(w * 0.22f, h * 0.02f, w * 0.48f, h * 0.04f, w * 0.56f, h * 0.24f)
          }
          val wirePath2 = Path().apply {
            moveTo(w * 0.36f, h * 0.26f)
            cubicTo(w * 0.46f, h * 0.08f, w * 0.62f, h * 0.14f, w * 0.68f, h * 0.28f)
          }
          val underWire = Path().apply {
            moveTo(w * 0.35f, h * 0.74f)
            cubicTo(w * 0.42f, h * 0.88f, w * 0.58f, h * 0.88f, w * 0.68f, h * 0.76f)
          }
          val wireStroke = Stroke(width = 4.5f, cap = StrokeCap.Round)
          val thinWireStroke = Stroke(width = 3.5f, cap = StrokeCap.Round)

          onDrawBehind {
            // Subtle hardware backplate behind console & tower
            drawRoundRect(
              color = Color(0xFFBFC4CC),
              topLeft = Offset(w * 0.10f, h * 0.20f),
              size = Size(w * 0.66f, h * 0.58f),
              cornerRadius = CornerRadius(10f, 10f),
            )
            // Connected yellow jumper cables
            drawPath(wirePath1, color = Color(0xFFFFB300), style = wireStroke)
            drawPath(wirePath2, color = Color(0xFFFF8F00), style = wireStroke)
            // White lower audio patch cable
            drawPath(underWire, color = Color(0xFFE5E7EB), style = thinWireStroke)
          }
        },
    )

    // 4. Horizontal Retro Capsule + Beige Hardware Deck
    Box(
      modifier = Modifier
        .align(Alignment.CenterEnd)
        .padding(end = 26.dp)
        .width(consoleWidth)
        .height(consoleHeight)
        .clip(RoundedCornerShape(topStart = 26.dp, bottomStart = 26.dp, topEnd = 6.dp, bottomEnd = 6.dp))
        .background(Color(0xFFD8D5CE))
        .border(
          1.2.dp,
          Color.White.copy(alpha = 0.45f),
          RoundedCornerShape(topStart = 26.dp, bottomStart = 26.dp, topEnd = 6.dp, bottomEnd = 6.dp),
        ),
    ) {
      Row(
        modifier = Modifier.fillMaxSize(),
        verticalAlignment = Alignment.CenterVertically,
      ) {
        // Dark Glossy Pill Screen with Cyan LED Marquee & Dual Green Status LEDs
        Box(
          modifier = Modifier
            .weight(1.45f)
            .fillMaxHeight()
            .padding(4.dp)
            .clip(RoundedCornerShape(22.dp))
            .background(Color(0xFF05090B))
            .border(1.dp, Color(0xFF00E5FF).copy(alpha = 0.28f), RoundedCornerShape(22.dp))
            .padding(horizontal = 10.dp),
        ) {
          // Dual glowing green rectangular LEDs in top-right of screen
          Row(
            horizontalArrangement = Arrangement.spacedBy(3.dp),
            modifier = Modifier.align(Alignment.TopEnd).padding(top = 5.dp, end = 2.dp),
          ) {
            Box(
              modifier = Modifier
                .size(width = 6.dp, height = 4.dp)
                .graphicsLayer { alpha = ledPulse.value }
                .clip(RoundedCornerShape(1.dp))
                .background(Color(0xFF00E676)),
            )
            Box(
              modifier = Modifier
                .size(width = 6.dp, height = 4.dp)
                .graphicsLayer { alpha = if (isPlaying) 1f else 0.3f }
                .clip(RoundedCornerShape(1.dp))
                .background(Color(0xFF00E676)),
            )
          }

          val songText = remember(title, artist) {
            "NOW PLAYING: ${title.uppercase()} • ${artist.uppercase()}      "
          }
          Text(
            text = songText,
            color = Color(0xFF4FF8FF),
            fontSize = 10.5.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Monospace,
            maxLines = 1,
            modifier = Modifier
              .align(Alignment.CenterStart)
              .fillMaxWidth()
              .padding(top = 6.dp)
              .basicMarquee(iterations = Int.MAX_VALUE),
          )
        }

        // Beige Hardware Control Block (OMNI-808 + tactile dots + mini dials)
        Column(
          modifier = Modifier
            .weight(0.78f)
            .fillMaxHeight()
            .padding(horizontal = 6.dp, vertical = 4.dp),
          verticalArrangement = Arrangement.SpaceBetween,
          horizontalAlignment = Alignment.CenterHorizontally,
        ) {
          // Top orange indicator dot row
          Row(horizontalArrangement = Arrangement.spacedBy(2.dp)) {
            repeat(5) { idx ->
              Box(
                modifier = Modifier
                  .size(3.dp)
                  .clip(CircleShape)
                  .background(if (idx < 3) Color(0xFFE65100) else Color(0xFF9CA3AF)),
              )
            }
          }
          Text(
            text = "OMNI-808",
            color = Color(0xFF374151),
            fontSize = 8.5.sp,
            fontWeight = FontWeight.Black,
            letterSpacing = 0.8.sp,
          )
          // 3 tiny circular retro dial icons
          Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            repeat(3) {
              Box(
                modifier = Modifier
                  .size(7.dp)
                  .clip(CircleShape)
                  .background(Color(0xFF9CA3AF))
                  .border(1.dp, Color(0xFF4B5563), CircleShape),
              )
            }
          }
        }
      }
    }

    // 5. Right-Side Vertical Retro Hardware Tower + Telescoping Antenna
    Spacer(
      modifier = Modifier
        .align(Alignment.CenterEnd)
        .padding(end = 2.dp, bottom = 14.dp)
        .size(width = 26.dp, height = 146.dp)
        .drawWithCache {
          val w = size.width
          val h = size.height
          onDrawBehind {
            // Vertical beige tower body
            drawRoundRect(
              color = Color(0xFFD5D2CB),
              topLeft = Offset(0f, h * 0.28f),
              size = Size(w * 0.72f, h * 0.70f),
              cornerRadius = CornerRadius(6f, 6f),
            )
            // Speaker grille strip
            drawRoundRect(
              color = Color(0xFF9CA3AF).copy(alpha = 0.45f),
              topLeft = Offset(w * 0.14f, h * 0.34f),
              size = Size(w * 0.24f, h * 0.58f),
              cornerRadius = CornerRadius(2f, 2f),
            )
            // Chrome telescoping antenna on far right
            val antX = w * 0.82f
            drawLine(
              color = Color(0xFF6B7280),
              start = Offset(antX, h * 0.90f),
              end = Offset(antX, h * 0.35f),
              strokeWidth = 5f,
              cap = StrokeCap.Round,
            )
            drawLine(
              color = Color(0xFFE5E7EB),
              start = Offset(antX, h * 0.38f),
              end = Offset(antX, h * 0.04f),
              strokeWidth = 2.6f,
              cap = StrokeCap.Round,
            )
            // Antenna tip cap
            drawCircle(
              color = Color(0xFFF3F4F6),
              radius = 3.5f,
              center = Offset(antX, h * 0.04f),
            )
          }
        },
    )

    // 6. Articulated Chrome Tone Arm anchored BELOW OMNI-808 (never crosses text or red ring)
    val armBoxSize = playerSize * 0.38f
    Spacer(
      modifier = Modifier
        .align(Alignment.BottomEnd)
        .padding(end = 36.dp, bottom = 36.dp)
        .size(armBoxSize)
        .graphicsLayer {
          rotationZ = armAngle
          transformOrigin = TransformOrigin(0.85f, 0.18f)
        }
        .drawWithCache {
          val w = size.width
          val h = size.height
          val pivot = Offset(w * 0.85f, h * 0.18f)
          val head = Offset(w * 0.18f, h * 0.82f)
          onDrawBehind {
            // Chrome tonearm shaft
            drawLine(
              color = Color(0xFFE5E7EB),
              start = pivot,
              end = head,
              strokeWidth = 11f,
              cap = StrokeCap.Round,
            )
            // Subtle metallic highlight along shaft
            drawLine(
              color = Color.White.copy(alpha = 0.65f),
              start = pivot,
              end = head,
              strokeWidth = 3.5f,
              cap = StrokeCap.Round,
            )
            // Black cartridge headshell & fine stylus needle
            drawCircle(color = Color(0xFF181A1F), radius = 14f, center = head)
            drawCircle(color = Color(0xFF00E5FF), radius = 5.5f, center = head)
            // Pivot base mount
            drawCircle(color = Color(0xFF2D3138), radius = 18f, center = pivot)
            drawCircle(color = Color(0xFF9CA3AF), radius = 9f, center = pivot)
          }
        },
    )
  }
}

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
import androidx.compose.ui.geometry.Offset
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
          val targetVelocity = if (playing) 138f else 0f // ~2.6s per full rotation
          val damping = if (playing) 4.5f else 2.8f // realistic motor ramp-up & friction coast-down
          angularVelocity += (targetVelocity - angularVelocity) * (dt * damping).coerceAtMost(1f)
          rotationAngle = (rotationAngle + angularVelocity * dt) % 360f
        }
        lastNanos = frameNanos
      }
    }
  }

  // LED pulsing only while playing
  val ledPulse: State<Float> =
    if (isPlaying && tier != PerformanceTier.LOW) {
      val infiniteTransition = rememberInfiniteTransition(label = "LedPulseTransition")
      infiniteTransition.animateFloat(
        initialValue = 0.45f,
        targetValue = 1.0f,
        animationSpec = infiniteRepeatable(
          animation = tween(800, easing = FastOutSlowInEasing),
          repeatMode = RepeatMode.Reverse,
        ),
        label = "LedPulse",
      )
    } else {
      remember(isPlaying) { mutableFloatStateOf(if (isPlaying) 1.0f else 0.3f) }
    }

  // Tone arm sweeps smoothly from outer edge (-2f) at song start to inner edge (+20f) at song end
  val clampedProgress = progress.coerceIn(0f, 1f)
  val targetArmAngle = if (isPlaying) -2f + (22f * clampedProgress) else -32f
  val armAngle by animateFloatAsState(
    targetValue = targetArmAngle,
    animationSpec = tween(durationMillis = 480, easing = FastOutSlowInEasing),
    label = "ToneArmAngle",
  )

  val vinylDiameter = playerSize * 0.86f
  val deckWidth = playerSize * 0.72f
  val deckHeight = 58.dp
  val decodeSize = if (tier == PerformanceTier.LOW) 300 else 512

  val deckBrush = remember {
    Brush.horizontalGradient(
      colors = listOf(
        Color(0xFF0A0C10),
        Color(0xFF141720),
        Color(0xFFDCDFE5),
        Color(0xFFECEFF4),
      ),
    )
  }

  Box(
    modifier = modifier.size(playerSize),
    contentAlignment = Alignment.Center,
  ) {
    // Static soft radial shadow behind the disc (zero per-frame shadow recomputation)
    Box(
      modifier = Modifier
        .align(Alignment.CenterStart)
        .padding(start = 10.dp, top = 8.dp)
        .size(vinylDiameter * 1.04f)
        .drawWithCache {
          val shadowBrush = Brush.radialGradient(
            colors = listOf(Color.Black.copy(alpha = 0.55f), Color.Transparent),
            center = Offset(size.width / 2f, size.height / 2f),
            radius = size.width / 2f,
          )
          onDrawBehind { drawCircle(brush = shadowBrush) }
        },
    )

    // 1. Spinning Picture-Disc Vinyl Record
    Box(
      modifier = Modifier
        .align(Alignment.CenterStart)
        .padding(start = 12.dp)
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

      // Dark Vintage Vinyl Grooves + Warm Sepia/Charcoal Vignette + Sheen
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
                Color.White.copy(alpha = 0.13f),
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
            val darkGrooveStroke = Stroke(width = 2.2f)
            val vintageHighlightColor = Color(0xFFD7C4A3).copy(alpha = 0.07f)
            val vintageHighlightStroke = Stroke(width = 1.0f)
            val outerEdgeStroke = Stroke(width = 5f)
            val vintageVignette = Brush.radialGradient(
              colors = listOf(
                Color(0xFF1A140E).copy(alpha = 0.22f),
                Color(0xFF0E0C0A).copy(alpha = 0.42f),
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

      // Solid Dark Center Label (cuts image inside the red ring) & Metallic Spindle Hole
      val labelDiameter = vinylDiameter * 0.44f
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
            .size(18.dp)
            .clip(CircleShape)
            .background(Color(0xFF050507))
            .border(2.5.dp, Color(0xFFE0E0E0), CircleShape),
        )
      }
    }

    // 2. Futuristic Capsule Console
    Box(
      modifier = Modifier
        .align(Alignment.CenterEnd)
        .width(deckWidth)
        .height(deckHeight)
        .clip(RoundedCornerShape(29.dp))
        .background(deckBrush)
        .border(1.5.dp, Color.White.copy(alpha = 0.25f), RoundedCornerShape(29.dp)),
    ) {
      Row(
        modifier = Modifier.fillMaxSize(),
        verticalAlignment = Alignment.CenterVertically,
      ) {
        Box(
          modifier = Modifier
            .weight(1.3f)
            .fillMaxHeight()
            .padding(4.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(Color(0xFF050B08))
            .border(1.dp, Color(0xFF00E5FF).copy(alpha = 0.35f), RoundedCornerShape(24.dp))
            .padding(horizontal = 8.dp),
          contentAlignment = Alignment.CenterStart,
        ) {
          Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
          ) {
            val songText = remember(title, artist) {
              "NOW PLAYING: ${title.uppercase()} • ${artist.uppercase()}      "
            }
            Text(
              text = songText,
              color = Color(0xFF00F2FE),
              fontSize = 11.sp,
              fontWeight = FontWeight.Bold,
              fontFamily = FontFamily.Monospace,
              maxLines = 1,
              modifier = Modifier
                .weight(1f)
                .basicMarquee(iterations = Int.MAX_VALUE),
            )

            Spacer(Modifier.width(4.dp))

            Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
              Box(
                modifier = Modifier
                  .size(5.dp)
                  .graphicsLayer { alpha = ledPulse.value }
                  .clip(CircleShape)
                  .background(Color(0xFF00E676)),
              )
              Box(
                modifier = Modifier
                  .size(5.dp)
                  .graphicsLayer { alpha = if (isPlaying) 1f else 0.3f }
                  .clip(CircleShape)
                  .background(Color(0xFF00E676)),
              )
            }
          }
        }

        Column(
          modifier = Modifier
            .weight(0.7f)
            .fillMaxHeight()
            .padding(horizontal = 8.dp, vertical = 6.dp),
          verticalArrangement = Arrangement.Center,
          horizontalAlignment = Alignment.CenterHorizontally,
        ) {
          Text(
            text = "OMNI-808",
            color = Color(0xFF2C3038),
            fontSize = 10.sp,
            fontWeight = FontWeight.Black,
            letterSpacing = 1.sp,
          )
          Text(
            text = "ACOUSTIC CORE",
            color = Color(0xFF6B7280),
            fontSize = 7.sp,
            fontWeight = FontWeight.Bold,
          )
        }
      }
    }

    // 3. Articulated Tone Arm (sweeps from outer groove to inner groove as song progresses)
    val armBoxSize = playerSize * 0.42f
    Spacer(
      modifier = Modifier
        .align(Alignment.CenterEnd)
        .padding(end = 16.dp)
        .size(armBoxSize)
        .graphicsLayer {
          rotationZ = armAngle
          transformOrigin = TransformOrigin(0.85f, 0.2f)
        }
        .drawWithCache {
          val w = size.width
          val h = size.height
          val pivot = Offset(w * 0.85f, h * 0.2f)
          val head = Offset(w * 0.15f, h * 0.85f)
          onDrawBehind {
            drawLine(
              color = Color(0xFFDCDFE5),
              start = pivot,
              end = head,
              strokeWidth = 14f,
              cap = StrokeCap.Round,
            )
            drawCircle(color = Color(0xFF212529), radius = 15f, center = head)
            drawCircle(color = Color(0xFF00E5FF), radius = 6.5f, center = head)
            drawCircle(color = Color(0xFF343A40), radius = 26f, center = pivot)
            drawCircle(color = Color(0xFFADB5BD), radius = 13f, center = pivot)
          }
        },
    )
  }
}

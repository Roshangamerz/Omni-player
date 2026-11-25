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
import coil3.request.crossfade
import echo.music.iad1tya.R

@Composable
fun RetroTurntableVinylPlayer(
  artworkUri: String?,
  title: String,
  artist: String,
  isPlaying: Boolean,
  playerSize: Dp,
  modifier: Modifier = Modifier
) {
  // Only animate vinyl spin & LED pulse when actually playing to save CPU/GPU
  val rotation: State<Float>
  val ledPulse: State<Float>
  if (isPlaying) {
    val infiniteTransition = rememberInfiniteTransition(label = "VinylSpin")
    rotation = infiniteTransition.animateFloat(
      initialValue = 0f,
      targetValue = 360f,
      animationSpec = infiniteRepeatable(
        animation = tween(2600, easing = LinearEasing),
        repeatMode = RepeatMode.Restart
      ),
      label = "VinylRotation"
    )
    ledPulse = infiniteTransition.animateFloat(
      initialValue = 0.45f,
      targetValue = 1.0f,
      animationSpec = infiniteRepeatable(
        animation = tween(800, easing = FastOutSlowInEasing),
        repeatMode = RepeatMode.Reverse
      ),
      label = "LedPulse"
    )
  } else {
    rotation = remember { mutableFloatStateOf(0f) }
    ledPulse = remember { mutableFloatStateOf(0.3f) }
  }

  // Tone arm tracking animation: lowers to -2 deg when playing, rests at -32 deg when paused
  val armAngle by animateFloatAsState(
    targetValue = if (isPlaying) -2f else -32f,
    animationSpec = spring(
      dampingRatio = Spring.DampingRatioLowBouncy,
      stiffness = Spring.StiffnessLow
    ),
    label = "ToneArmAngle"
  )

  val vinylDiameter = playerSize * 0.86f
  val deckWidth = playerSize * 0.72f
  val deckHeight = 58.dp
  val context = LocalContext.current

  val deckBrush = remember {
    Brush.horizontalGradient(
      colors = listOf(
        Color(0xFF0A0C10),
        Color(0xFF141720),
        Color(0xFFDCDFE5),
        Color(0xFFECEFF4)
      )
    )
  }

  Box(
    modifier = modifier.size(playerSize),
    contentAlignment = Alignment.Center
  ) {
    // Static soft radial shadow behind the disc (avoids expensive per-frame dynamic elevation shadow)
    Box(
      modifier = Modifier
        .align(Alignment.CenterStart)
        .padding(start = 10.dp, top = 8.dp)
        .size(vinylDiameter * 1.04f)
        .drawWithCache {
          val shadowBrush = Brush.radialGradient(
            colors = listOf(Color.Black.copy(alpha = 0.55f), Color.Transparent),
            center = Offset(size.width / 2f, size.height / 2f),
            radius = size.width / 2f
          )
          onDrawBehind {
            drawCircle(brush = shadowBrush)
          }
        }
    )

    // 1. Spinning Picture-Disc Vinyl Record (full artwork across disc + vinyl grooves)
    Box(
      modifier = Modifier
        .align(Alignment.CenterStart)
        .padding(start = 12.dp)
        .size(vinylDiameter)
        .graphicsLayer {
          rotationZ = rotation.value
        }
        .clip(CircleShape)
        .background(Color(0xFF111215)),
      contentAlignment = Alignment.Center
    ) {
      // Full-Disc Album Artwork
      if (!artworkUri.isNullOrBlank()) {
        AsyncImage(
          model = remember(artworkUri) {
            ImageRequest.Builder(context)
              .data(artworkUri)
              .size(512, 512)
              .crossfade(false)
              .build()
          },
          contentDescription = null,
          contentScale = ContentScale.Crop,
          modifier = Modifier.fillMaxSize()
        )
      } else {
        Icon(
          painter = painterResource(R.drawable.music_note),
          contentDescription = null,
          tint = Color.White.copy(alpha = 0.45f),
          modifier = Modifier.size(48.dp)
        )
      }

      // Vinyl Tint + Concentric Micro-Grooves + Anisotropic Sheen Overlay
      Spacer(
        modifier = Modifier
          .fillMaxSize()
          .drawWithCache {
            val center = Offset(size.width / 2f, size.height / 2f)
            val radius = size.width / 2f
            val sheenBrush = Brush.sweepGradient(
              colors = listOf(
                Color.White.copy(alpha = 0.02f),
                Color.White.copy(alpha = 0.18f),
                Color.White.copy(alpha = 0.02f),
                Color.White.copy(alpha = 0.15f),
                Color.White.copy(alpha = 0.02f)
              ),
              center = center
            )
            val grooveRatios = floatArrayOf(0.96f, 0.90f, 0.84f, 0.78f, 0.72f, 0.66f, 0.60f, 0.54f)
            val grooveColor = Color.White.copy(alpha = 0.12f)
            val grooveStroke = Stroke(width = 1.6f)
            val outerEdgeStroke = Stroke(width = 4f)
            val tintColor = Color.Black.copy(alpha = 0.30f)

            onDrawBehind {
              drawCircle(color = tintColor, radius = radius, center = center)
              for (gRatio in grooveRatios) {
                drawCircle(
                  color = grooveColor,
                  radius = radius * gRatio,
                  center = center,
                  style = grooveStroke
                )
              }
              drawCircle(brush = sheenBrush, radius = radius, center = center)
              drawCircle(
                color = Color(0xFF0A0B0E),
                radius = radius - 2f,
                center = center,
                style = outerEdgeStroke
              )
            }
          }
      )

      // Signature Red Inner Ring & Metallic Spindle Center Hole
      val labelDiameter = vinylDiameter * 0.44f
      Box(
        modifier = Modifier
          .size(labelDiameter)
          .align(Alignment.Center)
          .clip(CircleShape)
          .border(4.5.dp, Color(0xFFD32F2F), CircleShape),
        contentAlignment = Alignment.Center
      ) {
        Box(
          modifier = Modifier
            .size(18.dp)
            .clip(CircleShape)
            .background(Color(0xFF050507))
            .border(2.5.dp, Color(0xFFE0E0E0), CircleShape)
        )
      }
    }

    // 2. Futuristic Capsule Console (Mounted Horizontally Across)
    Box(
      modifier = Modifier
        .align(Alignment.CenterEnd)
        .width(deckWidth)
        .height(deckHeight)
        .clip(RoundedCornerShape(29.dp))
        .background(deckBrush)
        .border(1.5.dp, Color.White.copy(alpha = 0.25f), RoundedCornerShape(29.dp))
    ) {
      Row(
        modifier = Modifier.fillMaxSize(),
        verticalAlignment = Alignment.CenterVertically
      ) {
        // Left Black Capsule: Glowing Cyan Dot-Matrix LED Ticker
        Box(
          modifier = Modifier
            .weight(1.3f)
            .fillMaxHeight()
            .padding(4.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(Color(0xFF050B08))
            .border(1.dp, Color(0xFF00E5FF).copy(alpha = 0.35f), RoundedCornerShape(24.dp))
            .padding(horizontal = 8.dp),
          contentAlignment = Alignment.CenterStart
        ) {
          Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth()
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
                .basicMarquee(iterations = Int.MAX_VALUE)
            )

            Spacer(Modifier.width(4.dp))

            // Dual Green Status LEDs (animated via graphicsLayer alpha -> zero recompositions)
            Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
              Box(
                modifier = Modifier
                  .size(5.dp)
                  .graphicsLayer { alpha = ledPulse.value }
                  .clip(CircleShape)
                  .background(Color(0xFF00E676))
              )
              Box(
                modifier = Modifier
                  .size(5.dp)
                  .graphicsLayer { alpha = if (isPlaying) 1f else 0.3f }
                  .clip(CircleShape)
                  .background(Color(0xFF00E676))
              )
            }
          }
        }

        // Right Retro Chassis: Hardware Markings & OMNI-808 Branding
        Column(
          modifier = Modifier
            .weight(0.7f)
            .fillMaxHeight()
            .padding(horizontal = 8.dp, vertical = 6.dp),
          verticalArrangement = Arrangement.Center,
          horizontalAlignment = Alignment.CenterHorizontally
        ) {
          Text(
            text = "OMNI-808",
            color = Color(0xFF2C3038),
            fontSize = 10.sp,
            fontWeight = FontWeight.Black,
            letterSpacing = 1.sp
          )
          Text(
            text = "ACOUSTIC CORE",
            color = Color(0xFF6B7280),
            fontSize = 7.sp,
            fontWeight = FontWeight.Bold
          )
        }
      }
    }

    // 3. Yellow Looping Cable (Cached Path)
    Spacer(
      modifier = Modifier
        .align(Alignment.TopEnd)
        .padding(end = 40.dp, top = 20.dp)
        .size(48.dp, 28.dp)
        .drawWithCache {
          val w = size.width
          val h = size.height
          val path = Path().apply {
            moveTo(0f, h)
            cubicTo(w * 0.2f, 0f, w * 0.8f, 0f, w, h)
          }
          val stroke = Stroke(width = 6f, cap = StrokeCap.Round)
          val cableColor = Color(0xFFFFB800)
          onDrawBehind {
            drawPath(path = path, color = cableColor, style = stroke)
          }
        }
    )

    // 4. Tone Arm (Pivot and Stylus Tracking on Record)
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
              cap = StrokeCap.Round
            )
            drawCircle(color = Color(0xFF212529), radius = 15f, center = head)
            drawCircle(color = Color(0xFF00E5FF), radius = 6.5f, center = head)
            drawCircle(color = Color(0xFF343A40), radius = 26f, center = pivot)
            drawCircle(color = Color(0xFFADB5BD), radius = 13f, center = pivot)
          }
        }
    )
  }
}

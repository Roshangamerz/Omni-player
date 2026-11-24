package echo.music.iad1tya.ui.component

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
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
import androidx.compose.ui.draw.shadow
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
  // Vinyl continuous rotation: ~2.2s per revolution when playing
  val infiniteTransition = rememberInfiniteTransition(label = "VinylSpin")
  val rotation by infiniteTransition.animateFloat(
    initialValue = 0f,
    targetValue = if (isPlaying) 360f else 0f,
    animationSpec = infiniteRepeatable(
      animation = tween(2200, easing = LinearEasing),
      repeatMode = RepeatMode.Restart
    ),
    label = "VinylRotation"
  )

  // Tone arm tracking animation: lowers to -2 deg when playing, rests at -32 deg when paused
  val armAngle by animateFloatAsState(
    targetValue = if (isPlaying) -2f else -32f,
    animationSpec = spring(
      dampingRatio = Spring.DampingRatioLowBouncy,
      stiffness = Spring.StiffnessLow
    ),
    label = "ToneArmAngle"
  )

  // LED pulsing
  val ledPulse by infiniteTransition.animateFloat(
    initialValue = 0.5f,
    targetValue = 1.0f,
    animationSpec = infiniteRepeatable(
      animation = tween(800, easing = FastOutSlowInEasing),
      repeatMode = RepeatMode.Reverse
    ),
    label = "LedPulse"
  )

  val vinylDiameter = playerSize * 0.86f
  val deckWidth = playerSize * 0.72f
  val deckHeight = 58.dp

  Box(
    modifier = modifier.size(playerSize),
    contentAlignment = Alignment.Center
  ) {
    // 1. Spinning Vinyl Record
    Box(
      modifier = Modifier
        .align(Alignment.CenterStart)
        .padding(start = 12.dp)
        .size(vinylDiameter)
        .shadow(24.dp, shape = CircleShape, spotColor = Color.Black)
        .graphicsLayer { rotationZ = rotation }
    ) {
      // Obsidian Vinyl Base with Anisotropic Sheen Grooves
      Canvas(modifier = Modifier.fillMaxSize()) {
        val center = Offset(this.size.width / 2f, this.size.height / 2f)
        val radius = this.size.width / 2f

        // Dark obsidian disc body
        drawCircle(
          color = Color(0xFF111215),
          radius = radius,
          center = center
        )

        // Micro-grooves
        val grooveRatios = floatArrayOf(0.96f, 0.92f, 0.88f, 0.84f, 0.80f, 0.76f, 0.72f, 0.68f, 0.64f, 0.60f, 0.56f)
        for (gRatio in grooveRatios) {
          drawCircle(
            color = Color.White.copy(alpha = 0.05f),
            radius = radius * gRatio,
            center = center,
            style = Stroke(width = 1.5f)
          )
        }

        // Anisotropic light reflection sheen (butterfly reflection)
        val sheenBrush = Brush.sweepGradient(
          colors = listOf(
            Color.White.copy(alpha = 0.02f),
            Color.White.copy(alpha = 0.16f),
            Color.White.copy(alpha = 0.02f),
            Color.White.copy(alpha = 0.14f),
            Color.White.copy(alpha = 0.02f)
          ),
          center = center
        )
        drawCircle(
          brush = sheenBrush,
          radius = radius,
          center = center
        )
      }

      // Center Label with Signature Red Accent Band and Album Artwork
      val labelDiameter = vinylDiameter * 0.44f
      Box(
        modifier = Modifier
          .size(labelDiameter)
          .align(Alignment.Center)
          .clip(CircleShape)
          .background(Color(0xFF0F0F12))
          .border(5.dp, Color(0xFFD32F2F), CircleShape), // Signature Red Band
        contentAlignment = Alignment.Center
      ) {
        if (!artworkUri.isNullOrBlank()) {
          AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
              .data(artworkUri)
              .crossfade(true)
              .build(),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize()
          )
        } else {
          Icon(
            painter = painterResource(R.drawable.music_note),
            contentDescription = null,
            tint = Color.White.copy(alpha = 0.6f),
            modifier = Modifier.size(32.dp)
          )
        }

        // Spindle Center Hole
        Box(
          modifier = Modifier
            .size(16.dp)
            .clip(CircleShape)
            .background(Color(0xFF050507))
            .border(2.dp, Color(0xFFE0E0E0), CircleShape)
        )
      }
    }

    // 2. Futuristic Capsule Console (Mounted Horizontally Across)
    Box(
      modifier = Modifier
        .align(Alignment.CenterEnd)
        .width(deckWidth)
        .height(deckHeight)
        .shadow(16.dp, RoundedCornerShape(29.dp), spotColor = Color.Black)
        .clip(RoundedCornerShape(29.dp))
        .background(
          Brush.horizontalGradient(
            colors = listOf(
              Color(0xFF0A0C10),
              Color(0xFF141720),
              Color(0xFFDCDFE5),
              Color(0xFFECEFF4)
            )
          )
        )
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
            val songText = "NOW PLAYING: ${title.uppercase()} • ${artist.uppercase()}      "
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

            // Dual Green Status LEDs
            Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
              Box(
                modifier = Modifier
                  .size(5.dp)
                  .clip(CircleShape)
                  .background(Color(0xFF00E676).copy(alpha = if (isPlaying) ledPulse else 0.3f))
              )
              Box(
                modifier = Modifier
                  .size(5.dp)
                  .clip(CircleShape)
                  .background(Color(0xFF00E676).copy(alpha = if (isPlaying) 1f else 0.3f))
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

    // 3. Yellow Looping Cable (Custom Canvas Drawing)
    Canvas(
      modifier = Modifier
        .align(Alignment.TopEnd)
        .padding(end = 40.dp, top = 20.dp)
        .size(48.dp, 28.dp)
    ) {
      val w = size.width
      val h = size.height
      val path = Path().apply {
        moveTo(0f, h)
        cubicTo(
          w * 0.2f, 0f,
          w * 0.8f, 0f,
          w, h
        )
      }
      drawPath(
        path = path,
        color = Color(0xFFFFB800),
        style = Stroke(width = 6f, cap = StrokeCap.Round)
      )
    }

    // 4. Tone Arm (Pivot and Stylus Tracking on Record)
    val armBoxSize = playerSize * 0.42f
    Box(
      modifier = Modifier
        .align(Alignment.CenterEnd)
        .padding(end = 16.dp)
        .size(armBoxSize)
        .graphicsLayer {
          rotationZ = armAngle
          transformOrigin = TransformOrigin(0.85f, 0.2f)
        }
    ) {
      Canvas(modifier = Modifier.fillMaxSize()) {
        val w = size.width
        val h = size.height
        val pivotX = w * 0.85f
        val pivotY = h * 0.2f

        // Stylus Head Position
        val headX = w * 0.15f
        val headY = h * 0.85f

        // Silver Metal Tonearm Shaft
        drawLine(
          color = Color(0xFFDCDFE5),
          start = Offset(pivotX, pivotY),
          end = Offset(headX, headY),
          strokeWidth = 8f,
          cap = StrokeCap.Round
        )

        // Stylus Cartridge Head
        drawCircle(
          color = Color(0xFF212529),
          radius = 12f,
          center = Offset(headX, headY)
        )
        drawCircle(
          color = Color(0xFF00E5FF),
          radius = 5f,
          center = Offset(headX, headY)
        )

        // Pivot Base Assembly
        drawCircle(
          color = Color(0xFF343A40),
          radius = 24f,
          center = Offset(pivotX, pivotY)
        )
        drawCircle(
          color = Color(0xFFADB5BD),
          radius = 12f,
          center = Offset(pivotX, pivotY)
        )
      }
    }
  }
}

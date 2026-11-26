package echo.music.iad1tya.utils

import com.music.innertube.YouTube
import com.music.innertube.models.SongItem
import echo.music.iad1tya.db.MusicDatabase
import echo.music.iad1tya.db.entities.Playlist
import echo.music.iad1tya.db.entities.PlaylistEntity
import echo.music.iad1tya.models.toMediaMetadata
import java.time.LocalDateTime
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import timber.log.Timber

data class AppleMusicImportResult(
  val playlistTitle: String,
  val importedCount: Int,
  val totalFound: Int,
)

object AppleMusicPlaylistImporter {
  private val client by lazy {
    OkHttpClient.Builder()
      .connectTimeout(15, TimeUnit.SECONDS)
      .readTimeout(20, TimeUnit.SECONDS)
      .build()
  }

  suspend fun importPlaylist(
    playlistUrl: String,
    database: MusicDatabase,
    onProgress: (String) -> Unit = {},
  ): Result<AppleMusicImportResult> =
    withContext(Dispatchers.IO) {
      runCatching {
        val cleanUrl = playlistUrl.trim()
        require(cleanUrl.contains("music.apple.com", ignoreCase = true)) {
          "Please enter a valid Apple Music playlist URL (music.apple.com)"
        }

        onProgress("Fetching Apple Music playlist...")
        val request =
          Request.Builder()
            .url(cleanUrl)
            .header(
              "User-Agent",
              "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36",
            )
            .header("Accept-Language", "en-US,en;q=0.9")
            .build()

        val html =
          client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) error("Failed to load Apple Music page (${response.code})")
            response.body?.string().orEmpty()
          }

        val (title, tracks) = parseTracksFromHtml(html)
        require(tracks.isNotEmpty()) {
          "No tracks found in this Apple Music playlist. Make sure the playlist is public."
        }

        val playlistEntity =
          PlaylistEntity(
            name = title,
            bookmarkedAt = LocalDateTime.now(),
            isEditable = true,
          )
        database.query { insert(playlistEntity) }

        var imported = 0
        tracks.forEachIndexed { index, (trackTitle, artist) ->
          onProgress("Matching track ${index + 1} of ${tracks.size}: $trackTitle")
          val query = if (artist.isNotBlank()) "$trackTitle $artist" else trackTitle
          val matchedSong =
            try {
              YouTube.search(query, YouTube.SearchFilter.FILTER_SONG)
                .getOrNull()
                ?.items
                ?.filterIsInstance<SongItem>()
                ?.firstOrNull()
            } catch (e: Exception) {
              Timber.w(e, "AppleMusicImport: search failed for $query")
              null
            }

          if (matchedSong != null) {
            val metadata = matchedSong.toMediaMetadata()
            database.query {
              insert(metadata)
              addSongToPlaylist(Playlist(playlist = playlistEntity, songCount = 0, songThumbnails = emptyList()), listOf(metadata.id))
            }
            imported++
          }
        }

        AppleMusicImportResult(
          playlistTitle = title,
          importedCount = imported,
          totalFound = tracks.size,
        )
      }
    }

  private fun parseTracksFromHtml(html: String): Pair<String, List<Pair<String, String>>> {
    var playlistTitle = "Apple Music Playlist"
    val tracks = mutableListOf<Pair<String, String>>()

    Regex(
        """<meta[^>]+property=["']og:title["'][^>]+content=["']([^"']+)["']""",
        RegexOption.IGNORE_CASE,
      )
      .find(html)
      ?.groupValues
      ?.getOrNull(1)
      ?.let { playlistTitle = decodeHtml(it).removeSuffix(" - Apple Music").trim() }

    val ldMatches =
      Regex(
          """<script[^>]+type=["']application/ld\+json["'][^>]*>(.*?)</script>""",
          setOf(RegexOption.DOT_MATCHES_ALL, RegexOption.IGNORE_CASE),
        )
        .findAll(html)

    for (m in ldMatches) {
      try {
        val obj = JSONObject(m.groupValues[1].trim())
        if (obj.optString("@type").contains("Playlist", ignoreCase = true)) {
          obj.optString("name").takeIf { it.isNotBlank() }?.let { playlistTitle = it }
          val trackArr = obj.optJSONArray("track") ?: JSONArray()
          for (i in 0 until trackArr.length()) {
            val t = trackArr.optJSONObject(i) ?: continue
            val name = t.optString("name").trim()
            val artist =
              t.optJSONArray("byArtist")?.optJSONObject(0)?.optString("name")?.trim()
                ?: t.optJSONObject("byArtist")?.optString("name")?.trim()
                ?: ""
            if (name.isNotBlank()) tracks.add(name to artist)
          }
        }
      } catch (_: Exception) {}
    }

    if (tracks.isNotEmpty()) return playlistTitle to tracks.distinct()

    Regex(
        """<script[^>]+id=["']serialized-server-data["'][^>]*>(.*?)</script>""",
        setOf(RegexOption.DOT_MATCHES_ALL, RegexOption.IGNORE_CASE),
      )
      .find(html)
      ?.groupValues
      ?.getOrNull(1)
      ?.let { rawJson ->
        val titleArtistRegex =
          Regex(""""title"\s*:\s*"([^"]{1,120})"\s*,\s*"subtitle"\s*:\s*"([^"]{1,120})"""")
        for (match in titleArtistRegex.findAll(rawJson)) {
          val t = decodeHtml(match.groupValues[1])
          val a = decodeHtml(match.groupValues[2])
          if (t.isNotBlank() && !t.equals(playlistTitle, ignoreCase = true)) {
            tracks.add(t to a)
          }
          if (tracks.size >= 150) break
        }
      }

    return playlistTitle to tracks.distinct()
  }

  private fun decodeHtml(text: String): String =
    text
      .replace("&amp;", "&")
      .replace("&quot;", "\"")
      .replace("&#39;", "'")
      .replace("&lt;", "<")
      .replace("&gt;", ">")
}

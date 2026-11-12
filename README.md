# Omni Player 🎵✨

<div align="center">

**Next-Gen Expressive & Apple-Inspired Streaming Music Player for Android & iOS**

*Built with Flutter • Material 3 Expressive UI • 9-Provider Word-Synced Lyrics • Canvas Loops • InnerTube Engine • Native Equalizer*

</div>

---

## 🌟 Highlights & Features

### 🎧 Audio & Core Streaming
- **YouTube Music InnerTube Engine**: Direct client for YouTube Music Home Feeds (`FEmusic_home`), Explore (`FEmusic_explore`), Charts (`FEmusic_charts`), Moods & Genres (`FEmusic_moods_and_genres`), Album/Playlist/Artist browse details, filtered search, and auto-queue radio suggestions.
- **Apple Music Scraper**: Real-time Apple Music RSS Top 100 songs and trending albums across multiple storefronts (US, IN, GB, JP, etc.).
- **JioSaavn & High-Quality FLAC Matching**: Stream matching up to 320kbps MP3 / AAC and Lossless FLAC via custom extension servers.
- **Audio Service Background Playback**: Native media session notification controls with lockscreen playback and artwork.

### 🎤 Synchronized Lyrics (9-Provider Resilient Engine)
- **Word-Level Sync**: Support for millisecond word-by-word synchronized karaoke lyrics (`TTML` & `LRC` format).
- **Multi-Provider Failover**:
  1. BetterLyrics TTML
  2. YouLyPlus (6 rotating KPoe mirror servers)
  3. SimpMusic API
  4. Paxsenix Word-Timed Sync
  5. Unison
  6. KuGou
  7. LRCLib
  8. Netease Cloud Music
  9. JioSaavn Synced
- **AI / Google Translation**: In-app on-the-fly lyric translation to your preferred language.
- **Millisecond Timing Offset**: Adjust lyric sync per track (±50ms to ±3000ms).

### 🎨 Visuals & UI Experience
- **Dual Player Mode**:
  - **Apple-Inspired**: Frosted glass blur, high-contrast typography, interactive liquid progress bar, and floating controls.
  - **Material 3 Expressive**: 10-lobed scalloped starburst play button, dynamic color extraction, and rounded surface containers.
- **Echo Rose & OLED Dark Themes**: Pure `#000000` AMOLED blacks with `#ED5564` Echo Rose accents or Material Dynamic Colors.
- **Looping Canvas Video Artwork**: Smooth looping MP4 video background artwork sourced from Echo Canvas manifest, Tidal videoCover, and Apple Music motion covers.
- **Music Flow (Vertical Reel Discovery)**: Full-bleed vertical swipe music discovery with two-line synced lyrics, canvas background, and quick action rail.
- **Ambient Weather Moods**: Automatic IP & Open-Meteo weather detection mapping real-time local weather to curated mood playlists (Rainy Lofi, Sunny Energy, Chill Night, etc.).

### 🔍 Omni Find (Acoustic Shazam Recognition)
- **Native DejaVu FFT Engine**: 16kHz audio capture with native Kotlin peak extraction and Shazam signature generation (`com.omniplayer.music.ShazamSignatureGenerator`).
- **One-Tap Song Recognition**: Query `amp.shazam.com` to identify music playing in your physical surroundings in seconds.

### 🎚️ Native AudioFX & Equalizer
- **5-Band Graphic Equalizer**: Native Android AudioFX hardware equalizer integration.
- **Bass Boost & Loudness Enhancer**: Hardware-accelerated low-end punch and volume normalization.
- **AutoEq Headphone Profiles**: Browse and load thousands of calibrated EQ profiles for AirPods, Sony WH-1000XM, Sennheiser, and IEMs from `jaakkopasanen/AutoEq`.

### 👥 Social & Cloud
- **Listen Together**: Synchronized group listening via WebSockets (`wss://metroserverx.meowery.eu/ws`) with host playback replication.
- **Universal Song.link Sharing**: Generate cross-platform links (Spotify, Apple Music, YouTube, Deezer, Tidal) for any track.
- **Omni Wrapped & Stats**: Track listening history, play counts, favorite genres, and top artists.
- **Full Backup & Restore**: One-click JSON backup of all playlists, history, liked songs, and settings.
- **Custom Extension Addon Manager**: Plug in custom community stream scrapers and lyrics servers.

---

## 📱 Architecture & Project Structure

```
lib/
├── main.dart                      # App entry point & multi-provider initialization
├── models/
│   ├── track.dart                 # Track model with rich LRC & word-level sync
│   └── echo_models.dart           # Echo home feeds, canvas, DNA, Shazam, and health models
├── services/
│   ├── audio_handler.dart         # Background audio playback service
│   ├── echo_innertube_service.dart# YouTube Music InnerTube & Apple Music client
│   ├── lyrics_service.dart        # 9-provider lyrics resolution & TTML parser
│   ├── canvas_service.dart        # Canvas looping video artwork manager
│   ├── music_dna_service.dart     # Genius backstory & Wikipedia artist bio
│   ├── omni_find_service.dart     # Native ShazamKit acoustic recognition
│   ├── equalizer_service.dart     # Android AudioFX EQ & AutoEq profiles
│   ├── weather_ambient_service.dart # Open-Meteo weather to mood pipeline
│   ├── listen_together_service.dart # Real-time synchronized room listening
│   ├── odesli_service.dart        # Song.link cross-platform share generator
│   ├── stats_service.dart         # Omni Wrapped & listening stats
│   ├── backup_service.dart        # JSON import/export
│   └── extension_manager_service.dart # Custom server addon manager
├── screens/
│   ├── home_shell.dart            # Liquid glass floating bottom dock
│   ├── home_screen.dart           # Dynamic feeds, mood chips, hero carousel
│   ├── music_flow_screen.dart     # Vertical reel discovery feed
│   ├── explore_screen.dart        # Charts, new releases, mood playlists
│   ├── search_screen.dart         # Filtered search & Apple Music top 100
│   ├── now_playing_screen.dart    # Apple & Expressive dual-style player
│   ├── browse_detail_screen.dart  # Album/playlist/artist view
│   ├── omni_find_screen.dart      # Radar Shazam music recognition
│   ├── equalizer_screen.dart      # Graphic EQ & AutoEq headphone curves
│   ├── listen_together_screen.dart# Group listening rooms
│   ├── stats_wrapped_screen.dart  # Omni Wrapped analytics
│   ├── uptime_screen.dart         # 14-endpoint latency monitor
│   └── settings_screen.dart       # App configuration & provider settings
├── theme/
│   └── app_theme.dart             # Dark, AMOLED, Echo Rose, and Material 3 palettes
└── widgets/
    ├── echo_components.dart       # Scalloped buttons, surface cards, DNA bottomsheet
    └── canvas_artwork_player.dart # Looping video canvas player
```

---

## 🛠️ Building & Running

### Prerequisites
- Flutter 3.24+ (Dart 3.5+)
- Android SDK 34 (Java 17)

### Run Locally
```bash
# Get dependencies
flutter pub get

# Run tests
flutter test test/widget_test.dart test/echo_services_test.dart

# Run on connected device
flutter run
```

### Build Release APK
```bash
flutter build apk --release --target-platform android-arm,android-arm64 --split-per-abi
```

---

## 📄 License
This project is for educational and personal use.

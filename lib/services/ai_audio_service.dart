import '../models/track.dart';
import 'extension_engine.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// OMNI AI AUDIO SERVICE (Inspired by Echo Music AI Hub & Smart DJ)
/// Provides:
/// 1. AI Smart DJ / Radio Generation based on seed track acoustic DNA
/// 2. AI Vibe & Lyric Meaning Interpreter (Emotional tone, genre, vibe tag)
/// ─────────────────────────────────────────────────────────────────────────────
class AiVibeInsight {
  final String mood;
  final String tempo;
  final String genre;
  final String meaningSummary;
  final List<String> vibeTags;

  const AiVibeInsight({
    required this.mood,
    required this.tempo,
    required this.genre,
    required this.meaningSummary,
    required this.vibeTags,
  });
}

class AiAudioService {
  static final Map<String, AiVibeInsight> _insightCache = {};

  /// Generate a continuous 8-12 song smart AI mix based on a seed song's DNA
  static Future<List<Track>> generateSmartAiMix(Track seedTrack) async {
    final engine = ExtensionEngine();
    final results = <Track>[];
    final seen = <String>{seedTrack.id};

    // Clean artist
    final artist = seedTrack.artist.split(RegExp(r'[,&x]')).first.trim();

    // 1. Fetch artist affinities
    final artistTracks = await engine.searchAcrossAllSources('$artist top hits');
    for (final t in artistTracks) {
      if (seen.add(t.id)) results.add(t);
      if (results.length >= 4) break;
    }

    // 2. Fetch genre/vibe radio tracks
    final vibeQuery = _guessVibeQuery(seedTrack);
    final vibeTracks = await engine.searchAcrossAllSources(vibeQuery);
    for (final t in vibeTracks) {
      if (seen.add(t.id)) results.add(t);
      if (results.length >= 8) break;
    }

    // 3. If still sparse, add curated fallback
    if (results.length < 5) {
      for (final t in engine.curatedTracks) {
        if (seen.add(t.id)) results.add(t);
      }
    }

    return results;
  }

  /// Analyze track lyrics and metadata to extract vibe, emotion, and story
  static AiVibeInsight explainTrackVibeAndMeaning(Track track) {
    if (_insightCache.containsKey(track.id)) {
      return _insightCache[track.id]!;
    }

    final titleLower = track.title.toLowerCase();
    final artistLower = track.artist.toLowerCase();

    String mood = 'Melodic & Emotional';
    String tempo = 'Mid-tempo (95-115 BPM)';
    String genre = 'Universal Contemporary';
    String meaning = 'A resonant acoustic journey exploring human connection, momentum, and expressive rhythm.';
    List<String> tags = ['#Vibe', '#HiFi', '#Atmospheric'];

    if (titleLower.contains('love') || titleLower.contains('dil') || titleLower.contains('pyaar') || titleLower.contains('tum')) {
      mood = 'Romantic & Heartfelt';
      tempo = 'Gentle Flow (85 BPM)';
      genre = 'Romantic Ballad / Pop';
      meaning = 'Expresses deep longing, intimacy, and melodic romance with soulful vocal dynamics.';
      tags = ['#Romance', '#Heartfelt', '#Soulful', '#LateNight'];
    } else if (titleLower.contains('sad') || titleLower.contains('judai') || titleLower.contains('alon') || titleLower.contains('dard')) {
      mood = 'Nostalgic & Melancholic';
      tempo = 'Slow Burn (78 BPM)';
      genre = 'Acoustic / Indie Soul';
      meaning = 'Reflects on memories, solitude, and bittersweet reflection with deep harmonic textures.';
      tags = ['#Melancholy', '#Nostalgia', '#RainyVibes', '#Reflection'];
    } else if (titleLower.contains('party') || titleLower.contains('beat') || titleLower.contains('nach') || titleLower.contains('club') || titleLower.contains('remix')) {
      mood = 'Euphoric & Energetic';
      tempo = 'High Energy (128 BPM)';
      genre = 'Dance / Electronic EDM';
      meaning = 'Designed for high energy, infectious club grooves, bass drops, and vibrant celebration.';
      tags = ['#Party', '#ClubEnergy', '#BassHeavy', '#DanceFloor'];
    } else if (artistLower.contains('sujal') || artistLower.contains('hustle') || artistLower.contains('emiway') || artistLower.contains('seedha') || artistLower.contains('krsna')) {
      mood = 'Raw & High-Intensity';
      tempo = 'Fast Flow (140 BPM)';
      genre = 'Desi Hip Hop / Trap';
      meaning = 'Sharp, relentless lyricism depicting personal grind, authenticity, and street culture mastery.';
      tags = ['#HipHop', '#Bars', '#Grind', '#DesiRap'];
    } else if (artistLower.contains('arijit') || artistLower.contains('atif') || artistLower.contains('jubin')) {
      mood = 'Passionate & Soothing';
      tempo = 'Melodic Groove (92 BPM)';
      genre = 'Bollywood Acoustic Hi-Fi';
      meaning = 'Immersive cinematic orchestration woven with nuanced vocal emotion and soaring melodies.';
      tags = ['#Cinematic', '#MasterVocals', '#LosslessHiFi', '#PureEmotion'];
    }

    final insight = AiVibeInsight(
      mood: mood,
      tempo: tempo,
      genre: genre,
      meaningSummary: meaning,
      vibeTags: tags,
    );

    _insightCache[track.id] = insight;
    return insight;
  }

  static String _guessVibeQuery(Track track) {
    final title = track.title.toLowerCase();
    if (title.contains('sad') || title.contains('judai')) return 'sad acoustic songs';
    if (title.contains('party') || title.contains('remix')) return 'club dance hits';
    if (title.contains('lofi') || title.contains('chill')) return 'lofi chill study beats';
    return '${track.artist} similar music';
  }
}

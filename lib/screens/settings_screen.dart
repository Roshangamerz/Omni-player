import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_player_service.dart';
import '../services/backup_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/extension_engine.dart';
import '../services/extension_manager_service.dart';
import '../services/lyrics_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_provider.dart';
import '../widgets/echo_components.dart';
import '../widgets/omni_logo.dart';
import 'equalizer_screen.dart';
import 'extensions_screen.dart';
import 'listen_together_screen.dart';
import 'omni_find_screen.dart';
import 'privacy_screen.dart';
import 'stats_wrapped_screen.dart';
import 'uptime_screen.dart';

/// Echo Music Reconstructed Settings Screen (Grouped Translucent Cards + Full Integrations)
class SettingsScreen extends StatefulWidget {
  final AudioPlayerService playerService;
  final ExtensionEngine? extensionEngine;
  final AppTheme theme;

  const SettingsScreen({
    super.key,
    required this.playerService,
    this.extensionEngine,
    required this.theme,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CloudSyncService _cloudSync = CloudSyncService();
  final ExtensionManagerService _extMgr = ExtensionManagerService();
  List<String> _disabledLyrics = [];

  static const Map<String, String> _aiProviders = {
    'OpenRouter': 'https://openrouter.ai/api/v1/chat/completions',
    'OpenAI': 'https://api.openai.com/v1/chat/completions',
    'API Route': 'https://global.api-route.com/v1/chat/completions',
    'Gemini': 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    'Groq': 'https://api.groq.com/openai/v1/chat/completions',
  };

  @override
  void initState() {
    super.initState();
    _cloudSync.init(widget.playerService);
    _extMgr.addListener(_onUpdate);
    widget.playerService.addListener(_onUpdate);
    _loadLyricsPrefs();
  }

  @override
  void dispose() {
    _extMgr.removeListener(_onUpdate);
    widget.playerService.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadLyricsPrefs() async {
    final disabled = await LyricsService.getDisabledProviders();
    if (mounted) setState(() => _disabledLyrics = disabled);
  }

  void _showAddAddonDialog(AppTheme theme) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.isDarkMode ? const Color(0xFF141418) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Add Extension Server',
            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Connect any Echo-compatible 320kbps or Lossless FLAC extension endpoint.',
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              style: TextStyle(color: theme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Server Name (optional)',
                labelStyle: TextStyle(color: theme.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: urlCtrl,
              style: TextStyle(color: theme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Endpoint URL (https://...)',
                labelStyle: TextStyle(color: theme.textSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: theme.primary),
            onPressed: () async {
              final url = urlCtrl.text.trim();
              if (url.isNotEmpty) {
                await _extMgr.addAddon(name: nameCtrl.text, url: url);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save Server'),
          ),
        ],
      ),
    );
  }

  void _showAiSettingsDialog(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    String selectedProvider = prefs.getString('omni_ai_provider') ?? 'OpenRouter';
    final keyCtrl = TextEditingController(text: prefs.getString('omni_ai_key') ?? '');
    final modelCtrl = TextEditingController(text: prefs.getString('omni_ai_model') ?? 'gpt-4o-mini');

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: theme.isDarkMode ? const Color(0xFF141418) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('AI Lyrics Translation',
              style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Google Translate works free with no key. Add an API key below for LLM translation.',
                style: TextStyle(color: theme.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _aiProviders.containsKey(selectedProvider) ? selectedProvider : 'OpenRouter',
                dropdownColor: theme.isDarkMode ? const Color(0xFF18181D) : Colors.white,
                decoration: InputDecoration(
                  labelText: 'AI Provider',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                items: _aiProviders.keys
                    .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDlg(() => selectedProvider = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: modelCtrl,
                style: TextStyle(color: theme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Model ID',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: keyCtrl,
                obscureText: true,
                style: TextStyle(color: theme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'API Key',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: theme.primary),
              onPressed: () async {
                await prefs.setString('omni_ai_provider', selectedProvider);
                await prefs.setString(
                    'omni_ai_endpoint', _aiProviders[selectedProvider] ?? '');
                await prefs.setString('omni_ai_model', modelCtrl.text.trim());
                await prefs.setString('omni_ai_key', keyCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupDialog(AppTheme theme) {
    final importCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.isDarkMode ? const Color(0xFF141418) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Backup & Restore',
            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: theme.primary),
                onPressed: () async {
                  final json = await BackupService.exportBackupJson();
                  await Clipboard.setData(ClipboardData(text: json));
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Full backup JSON copied to clipboard!')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_all_rounded),
                label: const Text('Export Backup to Clipboard'),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: importCtrl,
              maxLines: 3,
              style: TextStyle(color: theme.textPrimary, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Paste backup JSON here to restore...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
          FilledButton.tonal(
            onPressed: () async {
              try {
                final count = await BackupService.importBackupJson(importCtrl.text.trim());
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restored $count sections. Restart app to apply.')),
                  );
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Import failed: $e')));
                }
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _showCloudConnectDialog({required bool isSpotify}) {
    final ctrl = TextEditingController();
    final color = isSpotify ? const Color(0xFF1DB954) : const Color(0xFFFF0033);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141418),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          isSpotify ? 'Connect Spotify' : 'Connect YouTube Music',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: isSpotify ? 'Spotify username or playlist URL' : 'Channel @handle or email',
            hintStyle: const TextStyle(color: Colors.white38),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color),
            onPressed: () async {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                if (isSpotify) {
                  await _cloudSync.connectSpotify(val, widget.playerService);
                } else {
                  await _cloudSync.connectYouTube(val, widget.playerService);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
              }
            },
            child: const Text('Sync'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeProvider.of(context);
    final ps = widget.playerService;

    return Container(
      decoration: BoxDecoration(gradient: theme.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: theme.textPrimary,
          title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
          children: [
            // BRAND BANNER (Keeps Omni Player's own Icon!)
            EchoSurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const OmniLogo(size: 46),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Omni Player',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Echo-Architecture • Lossless, Canvas, ShazamKit, Lyrics+',
                          style: TextStyle(color: theme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 1. APPEARANCE & PLAYER STYLE
            _sectionLabel(theme, 'APPEARANCE & PLAYER'),
            EchoSurfaceCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _themeChip(theme, AppThemeMode.midnightLuxe, '👑 Midnight Luxe', const Color(0xFFE2B170)),
                      _themeChip(theme, AppThemeMode.echoRose, 'Echo Rose', const Color(0xFFF43F5E)),
                      _themeChip(theme, AppThemeMode.oledNeonLime, 'Dark Planty', const Color(0xFF10B981)),
                      _themeChip(theme, AppThemeMode.dim, 'Dim Slate', const Color(0xFF0284C7)),
                      _themeChip(theme, AppThemeMode.pink, 'Neon Pink', const Color(0xFFFF2A85)),
                      _themeChip(theme, AppThemeMode.marvels, "Creator's Choice", const Color(0xFFFF1E42)),
                    ],
                  ),
                  if (ps.themeMode == AppThemeMode.marvels) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final hero in [
                          ('iron_man', 'Iron Man'),
                          ('spider', 'Spider-Verse'),
                          ('panther', 'Black Panther'),
                          ('thor', 'Thor'),
                          ('infinity', 'Infinity'),
                          ('deadpool', 'Deadpool'),
                        ])
                          ChoiceChip(
                            label: Text(hero.$2, style: const TextStyle(fontSize: 12)),
                            selected: ps.marvelHero == hero.$1,
                            selectedColor: theme.primary,
                            onSelected: (_) => ps.setMarvelHero(hero.$1),
                          ),
                      ],
                    ),
                  ],
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Now Playing Style',
                          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600)),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'apple', label: Text('Apple')),
                          ButtonSegment(value: 'vinyl', label: Text('Turntable')),
                          ButtonSegment(value: 'material', label: Text('Material')),
                        ],
                        selected: {
                          ['apple', 'vinyl', 'material'].contains(ps.playerStyle) ? ps.playerStyle : 'apple'
                        },
                        onSelectionChanged: (s) => ps.setPlayerStyle(s.first),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Dark / OLED Mode', style: TextStyle(color: theme.textPrimary)),
                    value: ps.isDarkMode,
                    activeThumbColor: theme.primary,
                    onChanged: ps.toggleDarkMode,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Liquid Glassmorphism Blur', style: TextStyle(color: theme.textPrimary)),
                    subtitle: Text('Frosted glass backdrop surfaces',
                        style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    value: ps.isLiquidGlassEnabled,
                    activeThumbColor: theme.primary,
                    onChanged: ps.toggleLiquidGlass,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Looping Canvas Artwork', style: TextStyle(color: theme.textPrimary)),
                    subtitle: Text('Tidal, EchoCanvas & Apple Motion video loops',
                        style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    value: ps.isCanvasEnabled,
                    activeThumbColor: theme.primary,
                    onChanged: ps.toggleCanvas,
                  ),
                ],
              ),
            ),

            // 2. AUDIO & PLAYBACK
            _sectionLabel(theme, 'AUDIO & PLAYBACK'),
            EchoSurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.equalizer_rounded, color: theme.primary),
                    title: Text('Equalizer & AutoEq Profiles',
                        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text('Native DSP + Headphone Target Curves',
                        style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    trailing: Icon(Icons.chevron_right_rounded, color: theme.textSecondary),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EqualizerScreen()),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.graphic_eq_rounded, color: theme.primary),
                    title: Text('Streaming Quality', style: TextStyle(color: theme.textPrimary)),
                    subtitle: Text(
                      ps.streamingQuality == 'auto'
                          ? 'Automatic (Fastest • Studio 320k / AAC)'
                          : ps.streamingQuality == '320k'
                              ? 'Studio Master (320 kbps)'
                              : ps.streamingQuality == '256k'
                                  ? 'High (256 kbps AAC)'
                                  : 'Data Saver (128 kbps Opus)',
                      style: TextStyle(color: theme.textSecondary, fontSize: 12),
                    ),
                    trailing: DropdownButton<String>(
                      value: ps.streamingQuality,
                      underline: const SizedBox.shrink(),
                      dropdownColor: theme.isDarkMode ? const Color(0xFF1A1A22) : Colors.white,
                      style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                      items: const [
                        DropdownMenuItem(value: 'auto', child: Text('Auto (Studio)')),
                        DropdownMenuItem(value: '320k', child: Text('320 kbps')),
                        DropdownMenuItem(value: '256k', child: Text('256 kbps')),
                        DropdownMenuItem(value: '128k', child: Text('128 kbps')),
                      ],
                      onChanged: (v) {
                        if (v != null) ps.setStreamingQuality(v);
                      },
                    ),
                  ),
                  SwitchListTile(
                    title: Text('Omni Brain Auto-Queue', style: TextStyle(color: theme.textPrimary)),
                    subtitle: Text('Auto-inject related YouTube Music tracks into queue',
                        style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    value: ps.isOmniBrainEnabled,
                    activeThumbColor: theme.primary,
                    onChanged: ps.toggleOmniBrain,
                  ),
                  SwitchListTile(
                    title: Text('Gapless Playback', style: TextStyle(color: theme.textPrimary)),
                    subtitle: Text('Preload upcoming audio tracks for seamless transitions',
                        style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    value: ps.isGaplessEnabled,
                    activeThumbColor: theme.primary,
                    onChanged: ps.toggleGapless,
                  ),
                  SwitchListTile(
                    title: Text('Smart Crossfade (${ps.crossfadeSeconds}s)',
                        style: TextStyle(color: theme.textPrimary)),
                    subtitle: Text('Apple Music DJ beat crossfade between tracks',
                        style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    value: ps.isSmartCrossfade,
                    activeThumbColor: theme.primary,
                    onChanged: ps.toggleSmartCrossfade,
                  ),
                  if (ps.isSmartCrossfade)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Text('1s', style: TextStyle(color: Colors.white38, fontSize: 11)),
                          Expanded(
                            child: Slider(
                              value: ps.crossfadeSeconds.toDouble(),
                              min: 1,
                              max: 12,
                              divisions: 11,
                              activeColor: theme.primary,
                              label: '${ps.crossfadeSeconds}s',
                              onChanged: (v) => ps.setCrossfadeSeconds(v.round()),
                            ),
                          ),
                          const Text('12s', style: TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                    ),
                  SwitchListTile(
                    title: Text('Trim Silence', style: TextStyle(color: theme.textPrimary)),
                    subtitle: Text('Automatically skips empty track lead-in gaps',
                        style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    value: ps.isSilenceTrimEnabled,
                    activeThumbColor: theme.primary,
                    onChanged: ps.toggleSilenceTrim,
                  ),
                  SwitchListTile(
                    title: Text('Lossless Audio Priority', style: TextStyle(color: theme.textPrimary)),
                    subtitle: Text('Prefers FLAC/ALAC sources when available',
                        style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    value: ps.isLosslessEnabled,
                    activeThumbColor: theme.primary,
                    onChanged: ps.toggleLossless,
                  ),
                  SwitchListTile(
                    title: Text('Data Saver Mode', style: TextStyle(color: theme.textPrimary)),
                    subtitle: Text('Disables video Canvas prefetching on cellular',
                        style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    value: ps.isDataSaverEnabled,
                    activeThumbColor: theme.primary,
                    onChanged: ps.toggleDataSaver,
                  ),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_rounded, color: Colors.amberAccent),
                    title: Text('Clear Audio & Memory Cache', style: TextStyle(color: theme.textPrimary)),
                    subtitle: Text('Frees allocated stream buffers and temporary cache',
                        style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 14),
                    onTap: () async {
                      await ps.clearAudioCache();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Audio stream & memory cache cleared!')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // 3. EXTENSIONS (320KBPS & LOSSLESS FLAC SERVERS)
            _sectionLabel(theme, 'EXTENSION SOURCES (320KBPS & FLAC)'),
            EchoSurfaceCard(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 6),
                    title: Text('Prefer Extension Audio',
                        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w700)),
                    subtitle: Text('Stream 320k / Lossless FLAC from custom servers before YT fallback',
                        style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    value: _extMgr.preferExtensionAudio,
                    activeThumbColor: theme.primary,
                    onChanged: _extMgr.setPreferExtensionAudio,
                  ),
                  for (final addon in _extMgr.addons)
                    ListTile(
                      dense: true,
                      title: Text(addon.name, style: TextStyle(color: theme.textPrimary)),
                      subtitle: Text(addon.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: addon.enabled,
                            activeThumbColor: theme.primary,
                            onChanged: (v) => _extMgr.toggleAddon(addon.id, v),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                            onPressed: () => _extMgr.removeAddon(addon.id),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => _showAddAddonDialog(theme),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Custom Server'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ExtensionsScreen(
                                extensionEngine: widget.extensionEngine ?? ExtensionEngine(),
                                theme: theme,
                                isStandalone: true,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.extension_rounded, size: 18),
                          label: const Text('Built-in Sources'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 4. LYRICS PROVIDERS & AI TRANSLATION
            _sectionLabel(theme, 'LYRICS PROVIDERS & AI TRANSLATION'),
            EchoSurfaceCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final p in LyricsService.allProviders)
                        FilterChip(
                          label: Text(p, style: const TextStyle(fontSize: 12)),
                          selected: !_disabledLyrics.contains(p),
                          selectedColor: theme.primary.withValues(alpha: 0.25),
                          checkmarkColor: theme.primary,
                          onSelected: (enabled) async {
                            await LyricsService.setProviderEnabled(p, enabled);
                            await _loadLyricsPrefs();
                          },
                        ),
                    ],
                  ),
                  const Divider(height: 22),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.translate_rounded, color: theme.primary),
                    title: Text('AI Lyrics Translation Settings',
                        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text('OpenRouter, API Route, Gemini, OpenAI or Free Translate',
                        style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                    trailing: Icon(Icons.chevron_right_rounded, color: theme.textSecondary),
                    onTap: () => _showAiSettingsDialog(theme),
                  ),
                ],
              ),
            ),

            // 5. INTEGRATIONS, TOOLS & DATA
            _sectionLabel(theme, 'TOOLS, CLOUD SYNC & SYSTEM'),
            EchoSurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.mic_rounded, color: theme.primary),
                    title: Text('Omni Find (ShazamKit)', style: TextStyle(color: theme.textPrimary)),
                    trailing: Icon(Icons.chevron_right_rounded, color: theme.textSecondary),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => OmniFindScreen(playerService: ps)),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.auto_graph_rounded, color: theme.primary),
                    title: Text('Stats & Omni Wrapped', style: TextStyle(color: theme.textPrimary)),
                    trailing: Icon(Icons.chevron_right_rounded, color: theme.textSecondary),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => StatsWrappedScreen(playerService: ps)),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.groups_rounded, color: theme.primary),
                    title: Text('Listen Together', style: TextStyle(color: theme.textPrimary)),
                    trailing: Icon(Icons.chevron_right_rounded, color: theme.textSecondary),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ListenTogetherScreen(playerService: ps)),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.monitor_heart_outlined, color: theme.primary),
                    title: Text('Service Uptime Monitor', style: TextStyle(color: theme.textPrimary)),
                    trailing: Icon(Icons.chevron_right_rounded, color: theme.textSecondary),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UptimeScreen()),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.stream_rounded, color: Color(0xFF1DB954)),
                    title: Text('Spotify Cloud Sync', style: TextStyle(color: theme.textPrimary)),
                    subtitle: Text(
                      _cloudSync.isSpotifyConnected
                          ? 'Connected: ${_cloudSync.spotifyAccount?.accountName ?? ""}'
                          : 'Sync Spotify playlists',
                      style: TextStyle(color: theme.textSecondary, fontSize: 12),
                    ),
                    onTap: () => _showCloudConnectDialog(isSpotify: true),
                  ),
                  ListTile(
                    leading: const Icon(Icons.smart_display_rounded, color: Color(0xFFFF0033)),
                    title: Text('YouTube Cloud Sync', style: TextStyle(color: theme.textPrimary)),
                    subtitle: Text(
                      _cloudSync.isYouTubeConnected
                          ? 'Connected: ${_cloudSync.youtubeAccount?.accountName ?? ""}'
                          : 'Sync YouTube Music playlists',
                      style: TextStyle(color: theme.textSecondary, fontSize: 12),
                    ),
                    onTap: () => _showCloudConnectDialog(isSpotify: false),
                  ),
                  ListTile(
                    leading: Icon(Icons.backup_rounded, color: theme.primary),
                    title: Text('Backup & Restore (JSON)', style: TextStyle(color: theme.textPrimary)),
                    trailing: Icon(Icons.chevron_right_rounded, color: theme.textSecondary),
                    onTap: () => _showBackupDialog(theme),
                  ),
                  ListTile(
                    leading: Icon(Icons.privacy_tip_outlined, color: theme.textSecondary),
                    title: Text('Privacy & Permissions', style: TextStyle(color: theme.textPrimary)),
                    trailing: Icon(Icons.chevron_right_rounded, color: theme.textSecondary),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => PrivacyScreen(theme: theme)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(AppTheme theme, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        label,
        style: TextStyle(
          color: theme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _themeChip(AppTheme theme, AppThemeMode mode, String label, Color dot) {
    final selected = widget.playerService.themeMode == mode;
    return ChoiceChip(
      avatar: CircleAvatar(backgroundColor: dot, radius: 7),
      label: Text(label),
      selected: selected,
      selectedColor: theme.primary,
      labelStyle: TextStyle(
        color: selected ? theme.primaryForeground : theme.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      onSelected: (_) => widget.playerService.setThemeMode(mode),
    );
  }
}

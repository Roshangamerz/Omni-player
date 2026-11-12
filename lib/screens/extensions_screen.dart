import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/extension_repo.dart';
import '../services/extension_engine.dart';
import '../theme/app_theme.dart';

class ExtensionsScreen extends StatefulWidget {
  final ExtensionEngine extensionEngine;
  final AppTheme theme;
  final bool isStandalone;

  const ExtensionsScreen({
    super.key,
    required this.extensionEngine,
    required this.theme,
    this.isStandalone = false,
  });

  @override
  State<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends State<ExtensionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _loadingUrl;

  final List<_BuiltInSource> _builtInSources = [
    _BuiltInSource(
      id: 'jiosaavn_fast',
      name: 'JioSaavn Hi-Fi (saavn.dev & 320k Direct)',
      description: 'Official high-speed hosted instance & 320k direct master streams — 80M+ tracks',
      icon: Icons.bolt_rounded,
      color: const Color(0xFF00FFC6),
      isEnabled: true,
      version: '3.2.0',
      quality: '320kbps Master',
    ),
    _BuiltInSource(
      id: 'piped_multi',
      name: 'YouTube Piped Multi-Node',
      description: 'Fast direct audio streams via kavin.rocks, smnz.de & moomoo.me',
      icon: Icons.play_circle_fill_rounded,
      color: const Color(0xFFFF0055),
      isEnabled: true,
      version: '2.4.0',
      quality: '256kbps Opus',
    ),
    _BuiltInSource(
      id: 'audius_gateway',
      name: 'Audius 320k Gateway',
      description: 'Decentralized indie catalog with lossless high-speed direct streams',
      icon: Icons.graphic_eq_rounded,
      color: const Color(0xFFCC33FF),
      isEnabled: true,
      version: '1.0.0',
      quality: '320kbps MP3',
    ),
    _BuiltInSource(
      id: 'itunes',
      name: 'Apple iTunes / Apple Music',
      description: 'Worldwide catalog via iTunes Search API',
      icon: Icons.apple_rounded,
      color: const Color(0xFFFC3C44),
      isEnabled: true,
      version: '1.0.0',
      quality: 'Metadata / Previews',
    ),
  ];

  final List<_FeaturedRepo> _featuredRepos = [
    _FeaturedRepo(
      name: 'JioSaavn & Multi-Source Fast API (Recommended)',
      author: 'Roshangamerz',
      url: 'https://raw.githubusercontent.com/Roshangamerz/jiosaavn-apii/refs/heads/main/api-sources.json?token=GHSAT0AAAAAAEF4XYBUFVEFBQHI7EYODLHK2UJVPCQ',
      description: 'Ultra-reliable, high-speed hosted JioSaavn (saavn.dev), Piped YouTube audio nodes, Audius & Apple Music',
      icon: Icons.bolt_rounded,
      color: const Color(0xFF00FFC6),
    ),
    _FeaturedRepo(
      name: 'SoundBound Official',
      author: 'Shabinder Singh',
      url: 'https://gitlab.com/shabinder/soundbound/-/raw/main/Experimental-Sources/sources.json',
      description: 'Official SoundBound experimental sources — Spotify, YouTube resolvers',
      icon: Icons.verified_rounded,
      color: const Color(0xFF2BC5B4),
    ),
    _FeaturedRepo(
      name: 'SoundBound Extensions Lib',
      author: 'Shabinder Singh',
      url: 'https://github.com/Shabinder/soundbound-extensions-lib',
      description: 'Core extension library with lossless stream resolvers',
      icon: Icons.extension_rounded,
      color: const Color(0xFF7C3AED),
    ),
    _FeaturedRepo(
      name: 'LRC Lyrics Engine',
      author: 'LRC Community',
      url: 'https://lrclib.net/api',
      description: 'Time-synced karaoke lyrics for millions of songs',
      icon: Icons.lyrics_rounded,
      color: const Color(0xFFEC4899),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddRepoSheet([String? prefillUrl]) {
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: prefillUrl ?? '');
    final theme = widget.theme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          decoration: BoxDecoration(
            color: theme.isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF5F5F5),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: theme.primary.withValues(alpha: 0.3), width: 1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.add_link_rounded, color: theme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text('Add Source Repository',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                ],
              ),
              const SizedBox(height: 6),
              Text('Enter a GitHub/GitLab repo or raw JSON manifest URL',
                  style: TextStyle(fontSize: 12, color: theme.textSecondary)),
              const SizedBox(height: 20),
              _SheetField(controller: nameCtrl, hint: 'Repository name (optional)', icon: Icons.label_outline_rounded, theme: theme),
              const SizedBox(height: 12),
              _SheetField(controller: urlCtrl, hint: 'https://github.com/user/repo  or  raw JSON URL', icon: Icons.link_rounded, theme: theme, autofocus: prefillUrl == null),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  _QuickChip(label: 'SoundBound Exp.', color: theme.primary, onTap: () => urlCtrl.text = 'https://gitlab.com/shabinder/soundbound/-/raw/main/Experimental-Sources/sources.json'),
                  _QuickChip(label: 'Extensions Lib', color: theme.primary, onTap: () => urlCtrl.text = 'https://github.com/Shabinder/soundbound-extensions-lib'),
                  _QuickChip(label: 'LRC Lyrics', color: const Color(0xFFEC4899), onTap: () => urlCtrl.text = 'https://lrclib.net/api'),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: theme.primaryForeground,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: const Text('Install Repository', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  onPressed: () {
                    final url = urlCtrl.text.trim();
                    final name = nameCtrl.text.trim();
                    if (url.isEmpty) return;
                    Navigator.pop(ctx);
                    _installRepo(url, name.isEmpty ? null : name);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _installRepo(String url, String? customName) async {
    setState(() { _isLoading = true; _loadingUrl = url; });
    final success = await widget.extensionEngine.addRepository(url, customName: customName);
    setState(() { _isLoading = false; _loadingUrl = null; });
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 90),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: success ? Colors.green.shade800.withValues(alpha: 0.95) : Colors.red.shade900.withValues(alpha: 0.95),
      content: Row(
        children: [
          Icon(success ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(success ? 'Repository installed! Music is now available.' : 'Could not load repo. Check the URL and try again.', style: const TextStyle(color: Colors.white))),
        ],
      ),
    ));
    if (success) _tabController.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final repos = widget.extensionEngine.repos;

    Widget body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sources', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                  Text('${_builtInSources.where((s) => s.isEnabled).length + repos.length} active', style: TextStyle(fontSize: 12, color: theme.textSecondary)),
                ],
              ),
              GestureDetector(
                onTap: () => _showAddRepoSheet(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.15),
                    border: Border.all(color: theme.primary.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded, color: theme.primary, size: 16),
                      const SizedBox(width: 6),
                      Text('Add Source', style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: theme.cardBg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.cardBorder),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(color: theme.primary, borderRadius: BorderRadius.circular(18)),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: theme.primaryForeground,
              unselectedLabelColor: theme.textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              tabs: [
                Tab(text: 'Built-in (${_builtInSources.length})'),
                Tab(text: 'Repos (${repos.length})'),
                const Tab(text: 'Discover'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (_isLoading)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.1),
              border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: theme.primary)),
                const SizedBox(width: 10),
                Expanded(child: Text('Fetching repository…', style: TextStyle(color: theme.primary, fontSize: 12, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBuiltInTab(theme),
              _buildReposTab(repos, theme),
              _buildDiscoverTab(theme),
            ],
          ),
        ),
      ],
    );

    if (widget.isStandalone) {
      return Scaffold(
        backgroundColor: theme.scaffoldBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Extensions & Sources',
            style: TextStyle(color: theme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: SafeArea(child: body),
      );
    }
    return body;
  }

  Widget _buildBuiltInTab(AppTheme theme) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, color: theme.primary, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Built-in sources are always available. Toggle ones you don\'t need to save data.', style: TextStyle(fontSize: 11, color: theme.textSecondary))),
            ],
          ),
        ),
        ..._builtInSources.map((source) => _BuiltInSourceCard(source: source, theme: theme, onToggle: (val) => setState(() => source.isEnabled = val))),
      ],
    );
  }

  Widget _buildReposTab(List<ExtensionRepo> repos, AppTheme theme) {
    if (repos.isEmpty) {
      return _EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'No repos added yet',
        subtitle: 'Tap "Add Source" to install a community music repository',
        actionLabel: 'Browse & Install',
        actionColor: theme.primary,
        onAction: () => _tabController.animateTo(2),
        theme: theme,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      itemCount: repos.length,
      itemBuilder: (_, i) => _RepoCard(
        repo: repos[i],
        theme: theme,
        onRemove: () => widget.extensionEngine.removeRepo(repos[i].id),
        onTogglePlugin: (pluginId) => widget.extensionEngine.togglePlugin(pluginId),
      ),
    );
  }

  Widget _buildDiscoverTab(AppTheme theme) {
    final installedUrls = widget.extensionEngine.repos.map((r) => r.url).toSet();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      children: [
        GestureDetector(
          onTap: () => _showAddRepoSheet(),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: theme.primary.withValues(alpha: 0.5), width: 1.5),
              borderRadius: BorderRadius.circular(18),
              color: theme.primary.withValues(alpha: 0.05),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: theme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.add_link_rounded, color: theme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Custom Repository', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.primary)),
                      const SizedBox(height: 2),
                      Text('Paste any GitHub / GitLab / raw JSON URL', style: TextStyle(fontSize: 12, color: theme.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: theme.primary),
              ],
            ),
          ),
        ),
        Text('Featured Sources', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textSecondary, letterSpacing: 0.8)),
        const SizedBox(height: 10),
        ..._featuredRepos.map((repo) {
          final installed = installedUrls.contains(repo.url);
          return _FeaturedRepoCard(repo: repo, theme: theme, isInstalled: installed, isLoading: _isLoading && _loadingUrl == repo.url, onInstall: () => _installRepo(repo.url, repo.name));
        }),
      ],
    );
  }
}

// ── DATA CLASSES ──────────────────────────────────────────────────────────────

class _BuiltInSource {
  final String id, name, description, version, quality;
  final IconData icon;
  final Color color;
  bool isEnabled;
  _BuiltInSource({required this.id, required this.name, required this.description, required this.icon, required this.color, required this.isEnabled, required this.version, required this.quality});
}

class _FeaturedRepo {
  final String name, author, url, description;
  final IconData icon;
  final Color color;
  _FeaturedRepo({required this.name, required this.author, required this.url, required this.description, required this.icon, required this.color});
}

// ── CARDS ─────────────────────────────────────────────────────────────────────

class _BuiltInSourceCard extends StatelessWidget {
  final _BuiltInSource source;
  final AppTheme theme;
  final ValueChanged<bool> onToggle;
  const _BuiltInSourceCard({required this.source, required this.theme, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      isGlass: theme.isGlassEnabled, borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      color: theme.cardBg, borderColor: theme.cardBorder,
      child: Row(
        children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: source.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(source.icon, color: source.color, size: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(source.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                  const SizedBox(width: 6),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: source.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                    child: Text(source.quality, style: TextStyle(color: source.color, fontSize: 9, fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 3),
                Text(source.description, style: TextStyle(fontSize: 11, color: theme.textSecondary), maxLines: 2),
                const SizedBox(height: 3),
                Text('v${source.version}', style: TextStyle(fontSize: 10, color: theme.textSecondary.withValues(alpha: 0.45))),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: source.isEnabled,
              activeTrackColor: source.color.withValues(alpha: 0.5),
              activeThumbColor: Colors.white,
              inactiveThumbColor: Colors.grey.shade400,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
              onChanged: onToggle,
            ),
          ),
        ],
      ),
    );
  }
}

class _RepoCard extends StatefulWidget {
  final ExtensionRepo repo;
  final AppTheme theme;
  final VoidCallback onRemove;
  final ValueChanged<String> onTogglePlugin;
  const _RepoCard({required this.repo, required this.theme, required this.onRemove, required this.onTogglePlugin});
  @override
  State<_RepoCard> createState() => _RepoCardState();
}

class _RepoCardState extends State<_RepoCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final repo = widget.repo;
    final enabledCount = repo.plugins.where((p) => p.isEnabled).length;
    return GlassContainer(
      isGlass: theme.isGlassEnabled, borderRadius: 18,
      padding: const EdgeInsets.all(14),
      color: theme.cardBg, borderColor: theme.cardBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(color: theme.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(11)),
              child: Icon(Icons.cloud_sync_rounded, color: theme.primary, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(repo.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textPrimary)),
                const SizedBox(height: 2),
                Text('By ${repo.author} • $enabledCount/${repo.plugins.length} active', style: TextStyle(fontSize: 11, color: theme.textSecondary)),
              ],
            )),
            if (repo.plugins.isNotEmpty)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: theme.textSecondary, size: 22)),
            if (repo.id != 'soundbound_official')
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, color: Colors.redAccent.withValues(alpha: 0.8), size: 18),
                padding: const EdgeInsets.all(4), constraints: const BoxConstraints(), visualDensity: VisualDensity.compact,
                onPressed: widget.onRemove),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
            child: Text(repo.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: theme.textSecondary.withValues(alpha: 0.55), fontFamily: 'monospace'))),
          if (_expanded && repo.plugins.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            const SizedBox(height: 8),
            ...repo.plugins.map((plugin) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Icon(plugin.type == PluginType.lyrics ? Icons.lyrics_rounded : plugin.type == PluginType.metadata ? Icons.info_outline_rounded : Icons.music_note_rounded, size: 16, color: theme.primary.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plugin.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textPrimary)),
                    Text('v${plugin.version} • ${plugin.description}', style: TextStyle(fontSize: 10, color: theme.textSecondary.withValues(alpha: 0.55)), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                )),
                Transform.scale(
                scale: 0.80,
                child: Switch(
                  value: plugin.isEnabled,
                  activeTrackColor: theme.primary.withValues(alpha: 0.5),
                  activeThumbColor: Colors.white,
                  inactiveThumbColor: Colors.grey.shade400,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                  onChanged: (_) => widget.onTogglePlugin(plugin.id),
                ),
              ),
              ]),
            )),
          ],
        ],
      ),
    );
  }
}

class _FeaturedRepoCard extends StatelessWidget {
  final _FeaturedRepo repo;
  final AppTheme theme;
  final bool isInstalled, isLoading;
  final VoidCallback onInstall;
  const _FeaturedRepoCard({required this.repo, required this.theme, required this.isInstalled, required this.isLoading, required this.onInstall});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      isGlass: theme.isGlassEnabled, borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
      color: theme.cardBg, borderColor: theme.cardBorder,
      child: Row(children: [
        Container(width: 44, height: 44,
          decoration: BoxDecoration(color: repo.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(repo.icon, color: repo.color, size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(repo.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textPrimary)),
            const SizedBox(height: 2),
            Text('by ${repo.author}', style: TextStyle(fontSize: 11, color: repo.color)),
            const SizedBox(height: 3),
            Text(repo.description, style: TextStyle(fontSize: 11, color: theme.textSecondary), maxLines: 2),
          ],
        )),
        const SizedBox(width: 8),
        if (isInstalled)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.withValues(alpha: 0.4))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_rounded, color: Colors.greenAccent, size: 12),
              const SizedBox(width: 4),
              const Text('Active', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ]))
        else if (isLoading)
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: repo.color))
        else
          GestureDetector(
            onTap: onInstall,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: repo.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: repo.color.withValues(alpha: 0.5))),
              child: Text('Install', style: TextStyle(color: repo.color, fontSize: 12, fontWeight: FontWeight.bold)))),
      ]),
    );
  }
}

// ── HELPERS ───────────────────────────────────────────────────────────────────

class _QuickChip extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label, style: TextStyle(fontSize: 11, color: color)), onPressed: onTap, backgroundColor: color.withValues(alpha: 0.1), side: BorderSide(color: color.withValues(alpha: 0.4)), padding: EdgeInsets.zero, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap);
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final AppTheme theme;
  final bool autofocus;
  const _SheetField({required this.controller, required this.hint, required this.icon, required this.theme, this.autofocus = false});
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller, autofocus: autofocus,
      style: TextStyle(color: theme.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textSecondary.withValues(alpha: 0.45), fontSize: 13),
        prefixIcon: Icon(icon, color: theme.textSecondary, size: 18),
        filled: true, fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.cardBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: theme.primary, width: 1.5)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title, subtitle, actionLabel;
  final Color actionColor;
  final VoidCallback onAction;
  final AppTheme theme;
  const _EmptyState({required this.icon, required this.title, required this.subtitle, required this.actionLabel, required this.actionColor, required this.onAction, required this.theme});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.textSecondary.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: theme.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: actionColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}

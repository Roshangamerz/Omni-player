import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_player_service.dart';
import '../services/listen_together_service.dart';
import '../theme/app_theme_provider.dart';
import '../widgets/echo_components.dart';

/// Echo Music "Listen Together" Synced Group Listening Room
class ListenTogetherScreen extends StatefulWidget {
  final AudioPlayerService playerService;

  const ListenTogetherScreen({super.key, required this.playerService});

  @override
  State<ListenTogetherScreen> createState() => _ListenTogetherScreenState();
}

class _ListenTogetherScreenState extends State<ListenTogetherScreen> {
  final ListenTogetherService _lt = ListenTogetherService();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.playerService.userName;
    _lt.addListener(_onUpdate);
    _lt.discoverServer();
    _lt.onRemoteSync = (track, isPlaying, posMs) {
      if (widget.playerService.currentTrack?.id != track.id) {
        widget.playerService.playTrack(track);
      }
      if (isPlaying && !widget.playerService.isPlaying) {
        widget.playerService.resume();
      } else if (!isPlaying && widget.playerService.isPlaying) {
        widget.playerService.pause();
      }
    };
  }

  @override
  void dispose() {
    _lt.removeListener(_onUpdate);
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeProvider.of(context);

    return Container(
      decoration: BoxDecoration(gradient: theme.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: theme.textPrimary,
          title: const Text('Listen Together', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            EchoSurfaceCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _lt.isConnected ? Icons.wifi_tethering_rounded : Icons.groups_rounded,
                        color: _lt.isConnected ? Colors.greenAccent : theme.primary,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lt.isConnected
                                  ? 'Connected • Room ${_lt.roomCode ?? ""}'
                                  : 'Synced Group Playback',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Server: ${_lt.serverName}',
                              style: TextStyle(color: theme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_lt.isConnected && _lt.roomCode != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _lt.roomCode!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Copied room code ${_lt.roomCode}')),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded, size: 18),
                            label: Text('Code: ${_lt.roomCode}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                          onPressed: _lt.disconnect,
                          child: const Text('Leave'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_lt.isConnected)
              EchoSurfaceCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      style: TextStyle(color: theme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        labelStyle: TextStyle(color: theme.textSecondary),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.primary,
                          foregroundColor: theme.primaryForeground,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: _lt.isConnecting
                            ? null
                            : () => _lt.connectAndCreateRoom(_nameCtrl.text.trim()),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        label: Text(_lt.isConnecting ? 'Connecting...' : 'Create Listening Room'),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            style: TextStyle(color: theme.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Enter 6-char room code',
                              hintStyle: TextStyle(color: theme.textSecondary),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.tonal(
                          onPressed: _lt.isConnecting
                              ? null
                              : () {
                                  if (_codeCtrl.text.trim().isNotEmpty) {
                                    _lt.connectAndJoinRoom(
                                        _nameCtrl.text.trim(), _codeCtrl.text.trim());
                                  }
                                },
                          child: const Text('Join'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_lt.logs.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                'ROOM ACTIVITY',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              EchoSurfaceCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final log in _lt.logs)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(log, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

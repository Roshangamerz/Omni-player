import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/track.dart';

/// Reverse-engineered Echo Music "Listen Together" WebSocket Sync Service
class ListenTogetherService extends ChangeNotifier {
  static final ListenTogetherService _instance = ListenTogetherService._internal();
  factory ListenTogetherService() => _instance;
  ListenTogetherService._internal();

  static const String _defaultWsUrl = 'wss://metroserverx.meowery.eu/ws';
  static const String _serverJsonUrl =
      'https://raw.githubusercontent.com/EchoMusicApp/Echo-Music/refs/heads/main/app/server.json';

  WebSocket? _socket;
  String _serverUrl = _defaultWsUrl;
  String _serverName = 'Omni Sync Relay';
  String? _roomCode;
  bool _isHost = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  final List<String> _logs = [];
  void Function(Track track, bool isPlaying, int positionMs)? onRemoteSync;

  String get serverUrl => _serverUrl;
  String get serverName => _serverName;
  String? get roomCode => _roomCode;
  bool get isHost => _isHost;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  List<String> get logs => List.unmodifiable(_logs);

  Future<void> discoverServer() async {
    try {
      final resp = await http.get(Uri.parse(_serverJsonUrl)).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final url = json['serverUrl']?.toString() ?? '';
        final name = json['name']?.toString() ?? '';
        if (url.isNotEmpty) _serverUrl = url;
        if (name.isNotEmpty) _serverName = name;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> connectAndCreateRoom(String username) async {
    return _connect(username: username, create: true);
  }

  Future<bool> connectAndJoinRoom(String username, String code) async {
    return _connect(username: username, create: false, code: code.trim().toUpperCase());
  }

  Future<bool> _connect({
    required String username,
    required bool create,
    String? code,
  }) async {
    await disconnect();
    _isConnecting = true;
    _addLog('Connecting to $_serverName...');
    notifyListeners();

    try {
      _socket = await WebSocket.connect(_serverUrl).timeout(const Duration(seconds: 8));
      _isConnected = true;
      _isConnecting = false;
      _isHost = create;
      if (create) {
        _roomCode = _generateCode();
        _send({'type': 'create_room', 'roomCode': _roomCode, 'username': username});
        _addLog('Created room $_roomCode as $username');
      } else {
        _roomCode = code;
        _send({'type': 'join_room', 'roomCode': _roomCode, 'username': username});
        _addLog('Joined room $_roomCode as $username');
      }

      _socket!.listen(
        (raw) => _handleMessage(raw),
        onDone: () {
          _isConnected = false;
          _addLog('Disconnected from Listen Together relay.');
          notifyListeners();
        },
        onError: (err) {
          _isConnected = false;
          _addLog('Connection error: $err');
          notifyListeners();
        },
      );
      notifyListeners();
      return true;
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      _addLog('Failed to connect: $e');
      notifyListeners();
      return false;
    }
  }

  void broadcastTrackState(Track track, bool isPlaying, int positionMs) {
    if (!_isConnected || _roomCode == null) return;
    _send({
      'type': 'sync_playback',
      'roomCode': _roomCode,
      'track': track.toJson(),
      'isPlaying': isPlaying,
      'positionMs': positionMs,
    });
  }

  void _send(Map<String, dynamic> payload) {
    try {
      _socket?.add(jsonEncode(payload));
    } catch (_) {}
  }

  void _handleMessage(dynamic raw) {
    try {
      if (raw is! String) return;
      final msg = jsonDecode(raw);
      if (msg is! Map<String, dynamic>) return;
      final type = msg['type']?.toString() ?? '';
      if (type == 'room_created' && msg['roomCode'] != null) {
        _roomCode = msg['roomCode'].toString();
        _addLog('Room confirmed: $_roomCode');
      } else if (type == 'user_joined') {
        _addLog('${msg['username'] ?? 'Listener'} joined the room');
      } else if (type == 'sync_playback' && msg['track'] is Map<String, dynamic>) {
        final track = Track.fromJson(msg['track'] as Map<String, dynamic>);
        final playing = msg['isPlaying'] == true;
        final pos = (msg['positionMs'] as num?)?.toInt() ?? 0;
        _addLog('Synced: ${track.title}');
        onRemoteSync?.call(track, playing, pos);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> disconnect() async {
    try {
      await _socket?.close();
    } catch (_) {}
    _socket = null;
    _isConnected = false;
    _isConnecting = false;
    _roomCode = null;
    notifyListeners();
  }

  void _addLog(String msg) {
    _logs.insert(0, msg);
    if (_logs.length > 25) _logs.removeLast();
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    return List.generate(6, (i) => chars[(now ~/ (i + 1) + i * 7) % chars.length]).join();
  }
}

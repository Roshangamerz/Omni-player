import 'package:flutter/material.dart';
import '../models/echo_models.dart';
import '../services/uptime_service.dart';
import '../theme/app_theme_provider.dart';
import '../widgets/echo_components.dart';

/// Echo Music Service Uptime & API Latency Monitor
class UptimeScreen extends StatefulWidget {
  const UptimeScreen({super.key});

  @override
  State<UptimeScreen> createState() => _UptimeScreenState();
}

class _UptimeScreenState extends State<UptimeScreen> {
  late List<ServiceHealthStatus> _services;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _services = UptimeService.initialServices();
    _runChecks();
  }

  Future<void> _runChecks() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _services = _services.map((s) => s.copyWith(isChecking: true)).toList();
    });

    await Future.wait([
      for (int i = 0; i < _services.length; i++)
        UptimeService.checkService(_services[i]).then((updated) {
          if (mounted) {
            setState(() => _services[i] = updated);
          }
        }),
    ]);

    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeProvider.of(context);
    final categories = <String, List<ServiceHealthStatus>>{};
    for (final s in _services) {
      categories.putIfAbsent(s.category, () => []).add(s);
    }

    return Container(
      decoration: BoxDecoration(gradient: theme.bgGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: theme.textPrimary,
          title: const Text('API Uptime Monitor', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            IconButton(
              icon: _checking
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: theme.primary),
                    )
                  : const Icon(Icons.refresh_rounded),
              onPressed: _runChecks,
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            for (final entry in categories.entries) ...[
              Padding(
                padding: const EdgeInsets.only(left: 4, top: 12, bottom: 8),
                child: Text(
                  entry.key.toUpperCase(),
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              EchoSurfaceCard(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final s in entry.value)
                      ListTile(
                        leading: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: s.isChecking
                                ? Colors.amber
                                : s.isOnline
                                    ? const Color(0xFF22C55E)
                                    : Colors.redAccent,
                          ),
                        ),
                        title: Text(
                          s.name,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          s.url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: theme.textSecondary, fontSize: 11),
                        ),
                        trailing: Text(
                          s.isChecking
                              ? 'Checking...'
                              : s.isOnline
                                  ? '${s.latencyMs ?? 0} ms'
                                  : 'Offline',
                          style: TextStyle(
                            color: s.isChecking
                                ? Colors.amber
                                : s.isOnline
                                    ? const Color(0xFF22C55E)
                                    : Colors.redAccent,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
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

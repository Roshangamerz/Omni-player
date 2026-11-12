import 'package:flutter/material.dart';
import '../services/equalizer_service.dart';
import '../theme/app_theme_provider.dart';
import '../widgets/echo_components.dart';

/// Echo Music Native Android Equalizer & AutoEq Headphone Tuning Screen
class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  final EqualizerService _eq = EqualizerService();
  bool _loadingAutoEq = false;

  @override
  void initState() {
    super.initState();
    _eq.addListener(_onUpdate);
    if (!_eq.supported) _eq.init();
  }

  @override
  void dispose() {
    _eq.removeListener(_onUpdate);
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
          title: const Text('Equalizer & AutoEq', style: TextStyle(fontWeight: FontWeight.w800)),
          actions: [
            Switch(
              value: _eq.enabled,
              activeThumbColor: theme.primary,
              onChanged: _eq.supported ? _eq.setEnabled : null,
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            EchoSurfaceCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Active Profile: ${_eq.activePreset}',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (!_eq.supported)
                        const Text('System DSP Fallback',
                            style: TextStyle(color: Colors.amber, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final preset in EqualizerService.builtInPresets.keys)
                        ChoiceChip(
                          label: Text(preset),
                          selected: _eq.activePreset == preset,
                          selectedColor: theme.primary,
                          labelStyle: TextStyle(
                            color: _eq.activePreset == preset
                                ? theme.primaryForeground
                                : theme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) => _eq.applyPreset(preset),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_eq.bands.isNotEmpty)
              EchoSurfaceCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GRAPHIC EQUALIZER (${_eq.bands.length}-BAND)',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 220,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final band in _eq.bands)
                            Column(
                              children: [
                                Text(
                                  '${(band.levelMb / 100).toStringAsFixed(1)}dB',
                                  style: TextStyle(color: theme.textSecondary, fontSize: 10),
                                ),
                                Expanded(
                                  child: RotatedBox(
                                    quarterTurns: 3,
                                    child: Slider(
                                      value: band.levelMb
                                          .toDouble()
                                          .clamp(_eq.minMb.toDouble(), _eq.maxMb.toDouble()),
                                      min: _eq.minMb.toDouble(),
                                      max: _eq.maxMb.toDouble(),
                                      activeColor: theme.primary,
                                      onChanged: (v) => _eq.setBandLevel(band.index, v.round()),
                                    ),
                                  ),
                                ),
                                Text(
                                  band.label,
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            EchoSurfaceCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BASS BOOST & LOUDNESS ENHANCER',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Bass Boost', style: TextStyle(color: theme.textPrimary)),
                      Text('${(_eq.bassBoost / 10).round()}%',
                          style: TextStyle(color: theme.primary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  Slider(
                    value: _eq.bassBoost.toDouble(),
                    min: 0,
                    max: 1000,
                    activeColor: theme.primary,
                    onChanged: (v) => _eq.setBassBoost(v.round()),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Loudness Gain', style: TextStyle(color: theme.textPrimary)),
                      Text('+${(_eq.loudnessGain / 100).toStringAsFixed(1)} dB',
                          style: TextStyle(color: theme.primary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  Slider(
                    value: _eq.loudnessGain.toDouble(),
                    min: 0,
                    max: 1500,
                    activeColor: theme.primary,
                    onChanged: (v) => _eq.setLoudnessGain(v.round()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            EchoSurfaceCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.headphones_rounded, color: theme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'AUTOEQ HEADPHONE PROFILES',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_loadingAutoEq) LinearProgressIndicator(color: theme.primary),
                  for (final hp in EqualizerService.autoEqModels)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(hp.name, style: TextStyle(color: theme.textPrimary)),
                      subtitle: Text('Harman Target Curve • AutoEq GitHub',
                          style: TextStyle(color: theme.textSecondary, fontSize: 11)),
                      trailing: Icon(Icons.tune_rounded, color: theme.primary),
                      onTap: () async {
                        setState(() => _loadingAutoEq = true);
                        final ok = await _eq.applyAutoEqProfile(hp.name, hp.path);
                        if (mounted) {
                          setState(() => _loadingAutoEq = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ok
                                  ? 'Applied AutoEq curve for ${hp.name}'
                                  : 'Could not reach AutoEq GitHub'),
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

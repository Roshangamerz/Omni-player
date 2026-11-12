import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/download_service.dart';
import 'services/equalizer_service.dart';
import 'services/extension_manager_service.dart';
import 'services/omni_find_service.dart';
import 'services/search_cache_service.dart';
import 'services/stats_service.dart';
import 'screens/splash_screen.dart';
import 'services/audio_player_service.dart';
import 'services/extension_engine.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_provider.dart';

import 'services/permission_service.dart';
import 'services/share_receiver_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final extensionEngine = ExtensionEngine();
  final audioPlayerService = AudioPlayerService();

  // Request all permissions needed on startup (Audio, Storage, Notifications)
  AppPermissionService().requestAllPermissions();

  // Initialize direct system share receiver
  ShareReceiverService().init();

  // Parallel asynchronous warmup for instantaneous startup
  final results = await Future.wait([
    extensionEngine.init(),
    audioPlayerService.init(),
    SearchCacheService().init(),
    DownloadService().init(),
    ExtensionManagerService().init(),
    OmniFindService().init(),
    StatsService().init(),
    EqualizerService().init(),
    SharedPreferences.getInstance(),
  ]);

  final prefs = results[8] as SharedPreferences;
  final onboardingDone = prefs.getBool('omni_onboarding_done') ?? false;

  runApp(
    OmniMusicApp(
      extensionEngine: extensionEngine,
      audioPlayerService: audioPlayerService,
      showOnboarding: !onboardingDone,
    ),
  );
}

class OmniMusicApp extends StatefulWidget {
  final ExtensionEngine extensionEngine;
  final AudioPlayerService audioPlayerService;
  final bool showOnboarding;

  const OmniMusicApp({
    super.key,
    required this.extensionEngine,
    required this.audioPlayerService,
    required this.showOnboarding,
  });

  @override
  State<OmniMusicApp> createState() => _OmniMusicAppState();
}

class _OmniMusicAppState extends State<OmniMusicApp> {
  late AppTheme _theme;

  @override
  void initState() {
    super.initState();
    _updateTheme();
    widget.audioPlayerService.addListener(_onServiceChange);
  }

  @override
  void dispose() {
    widget.audioPlayerService.removeListener(_onServiceChange);
    super.dispose();
  }

  void _onServiceChange() {
    setState(() {
      _updateTheme();
    });
  }

  void _updateTheme() {
    _theme = AppTheme(
      mode: widget.audioPlayerService.themeMode,
      isGlassEnabled: widget.audioPlayerService.isGlassEnabled,
      isLiquidGlassEnabled: widget.audioPlayerService.isLiquidGlassEnabled,
      isDarkMode: widget.audioPlayerService.isDarkMode,
      customPrimary: widget.audioPlayerService.customPrimaryColor,
      customBg: widget.audioPlayerService.customBgColor,
      marvelHero: widget.audioPlayerService.marvelHero,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeProvider(
      theme: _theme,
      child: MaterialApp(
        title: 'Omni Music',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: _theme.scaffoldBg,
          fontFamily: 'Inter',
          colorScheme: ColorScheme.dark(
            primary: _theme.primary,
            surface: _theme.scaffoldBg,
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: ZoomPageTransitionsBuilder(),
              TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
            },
          ),
        ),
        home: OmniSplashScreen(
          extensionEngine: widget.extensionEngine,
          audioPlayerService: widget.audioPlayerService,
          showOnboarding: widget.showOnboarding,
        ),
      ),
    );
  }
}

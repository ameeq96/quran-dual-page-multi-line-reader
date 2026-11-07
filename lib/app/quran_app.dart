import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/services/system_ui_service.dart';
import '../core/services/reader_reminder_service.dart';
import '../core/storage/reader_preferences.dart';
import '../features/quran_reader/data/repositories/quran_reader_repository.dart';
import '../features/quran_reader/data/services/quran_asset_resolver.dart';
import '../features/quran_reader/data/services/quran_audio_service.dart';
import '../features/quran_reader/data/services/quran_admin_config_service.dart';
import '../features/quran_reader/data/services/quran_navigation_data_source.dart';
import '../features/quran_reader/data/services/quran_page_insights_data_source.dart';
import '../features/quran_reader/data/services/quran_remote_content_service.dart';
import '../features/quran_reader/data/services/quran_reader_sync_service.dart';
import '../features/quran_reader/data/services/quran_text_data_source.dart';
import '../features/quran_reader/presentation/controllers/quran_reader_controller.dart';
import '../features/quran_reader/presentation/screens/quran_home_screen.dart';
import '../features/quran_reader/presentation/screens/quran_onboarding_screen.dart';
import '../features/quran_reader/presentation/widgets/bootstrap_splash.dart';
import '../features/quran_reader/presentation/widgets/reader_reminder_banner.dart';
import 'app_theme.dart';
import 'reader_localization.dart';

class QuranApp extends StatelessWidget {
  const QuranApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localization = ReaderLocalization.instance;
    return ReaderLocalizationScope(
      localization: localization,
      child: AnimatedBuilder(
        animation: localization,
        builder: (context, _) => MaterialApp(
          title: tr(context, 'Quran Pak Dual Page Reader'),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          locale: localization.locale,
          supportedLocales: const [Locale('en'), Locale('ur')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: localization.textDirection,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child!,
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ReaderReminderBanner(),
                ),
              ],
            ),
          ),
          home: const _AppBootstrap(),
        ),
      ),
    );
  }
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap>
    with WidgetsBindingObserver {
  late final QuranReaderController _controller;
  late final ReaderPreferences _preferences;
  late Future<_BootstrapPrefs> _bootstrapPrefsFuture;
  late Future<void> _bootstrapFuture;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ReaderLocalization.instance.addListener(_refreshReminderLanguage);
    _preferences = ReaderPreferences();
    final adminConfigService = QuranAdminConfigService(
      preferences: _preferences,
    );
    final repository = QuranReaderRepository(
      assetResolver: QuranAssetResolver(),
      navigationDataSource: QuranNavigationDataSource(),
      textDataSource: QuranTextDataSource(),
      pageInsightsDataSource: QuranPageInsightsDataSource(),
      adminConfigService: adminConfigService,
      remoteContentService: QuranRemoteContentService(),
      preferences: _preferences,
    );
    _controller = QuranReaderController(
      repository: repository,
      audioService: QuranAudioService(),
      readerSyncService: QuranReaderSyncService(),
      preferences: _preferences,
    );
    _bootstrapPrefsFuture = _loadBootstrapPrefs();
    _bootstrapFuture = _bootstrap();
  }

  Future<_BootstrapPrefs> _loadBootstrapPrefs() async {
    await ReaderLocalization.instance.load();
    try {
      final settings = await _preferences.loadSettings();
      final onboardingSeen = await _preferences.loadOnboardingSeen();
      _showOnboarding = !onboardingSeen;
      return _BootstrapPrefs(
        nightMode: settings.nightMode,
        showOnboarding: !onboardingSeen,
      );
    } catch (_) {
      return const _BootstrapPrefs(
        nightMode: false,
        showOnboarding: false,
      );
    }
  }

  Future<void> _bootstrap() async {
    await SystemUiService.allowReaderOrientations();
    final prefs = await _bootstrapPrefsFuture;
    if (!mounted) return;
    await ReaderReminderService.instance.initialize();
    if (!mounted) return;
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    await ReaderReminderService.instance.setAppActive(
      lifecycleState == null || lifecycleState == AppLifecycleState.resumed,
    );
    if (!mounted) {
      await ReaderReminderService.instance.setAppActive(false);
      return;
    }
    _showOnboarding = prefs.showOnboarding;
    await _controller.initialize();
  }

  Future<void> _completeOnboarding() async {
    await _preferences.saveOnboardingSeen(true);
    if (!mounted) {
      return;
    }
    setState(() {
      _showOnboarding = false;
    });
  }

  void _refreshReminderLanguage() {
    unawaited(ReaderReminderService.instance.refreshSchedule());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(ReaderReminderService.instance.setAppActive(
      state == AppLifecycleState.resumed,
    ));
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.refreshDownloadPolicy());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(ReaderReminderService.instance.setAppActive(false));
    ReaderLocalization.instance.removeListener(_refreshReminderLanguage);
    _controller.dispose();
    SystemUiService.restoreDefaultUi();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_BootstrapPrefs>(
      future: _bootstrapPrefsFuture,
      builder: (context, snapshot) {
        final prefs = snapshot.data;
        if (prefs == null) {
          return const BootstrapSplash(nightMode: false);
        }

        return FutureBuilder<void>(
          future: _bootstrapFuture,
          builder: (context, bootstrapSnapshot) {
            if (bootstrapSnapshot.connectionState != ConnectionState.done) {
              return BootstrapSplash(nightMode: prefs.nightMode);
            }

            if (bootstrapSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 56),
                          const SizedBox(height: 16),
                          Text(
                            tr(context, 'Unable to prepare the reader.'),
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${bootstrapSnapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed: () => setState(() {
                              _bootstrapFuture = _bootstrap();
                            }),
                            child: Text(tr(context, 'Retry')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            if (_showOnboarding) {
              return QuranOnboardingScreen(
                controller: _controller,
                onComplete: _completeOnboarding,
              );
            }

            return QuranHomeScreen(controller: _controller);
          },
        );
      },
    );
  }
}

class _BootstrapPrefs {
  const _BootstrapPrefs({
    required this.nightMode,
    required this.showOnboarding,
  });

  final bool nightMode;
  final bool showOnboarding;
}

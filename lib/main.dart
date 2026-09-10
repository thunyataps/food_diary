import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/analyze/analyze_repository.dart';
import 'features/analyze/capture_screen.dart';
import 'features/diary/diary_repository.dart';
import 'features/diary/diary_screen.dart';
import 'features/diary/weight_repository.dart';
import 'features/profile/profile_repository.dart';
import 'features/profile/profile_screen.dart';
import 'features/settings/goals_repository.dart';
import 'features/settings/settings_screen.dart';
import 'features/update/update_checker.dart';
import 'features/update/update_downloader.dart';
import 'l10n/generated/app_localizations.dart';
import 'models/user_profile.dart';
import 'models/weight_log.dart';

final _colorScheme = ColorScheme.fromSeed(
  seedColor: const Color(0xFFC1652F),
  brightness: Brightness.light,
).copyWith(surface: const Color(0xFFFAF6F0));

final appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: _colorScheme,
  scaffoldBackgroundColor: _colorScheme.surface,
  appBarTheme: AppBarTheme(
    backgroundColor: _colorScheme.surface,
    foregroundColor: const Color(0xFF2B2620),
    elevation: 0,
    scrolledUnderElevation: 1,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: _colorScheme.primary.withValues(alpha: 0.15),
    surfaceTintColor: Colors.transparent,
  ),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  runApp(const FoodDiaryApp());
}

class FoodDiaryApp extends StatefulWidget {
  const FoodDiaryApp({super.key});

  @override
  State<FoodDiaryApp> createState() => _FoodDiaryAppState();
}

class _FoodDiaryAppState extends State<FoodDiaryApp> {
  final _client = Supabase.instance.client;
  late final _authRepository = AuthRepository(_client);
  late final _analyzeRepository = AnalyzeRepository(_client);
  late final _diaryRepository = DiaryRepository(_client);
  late final _goalsRepository = GoalsRepository(_client);
  late final _weightRepository = WeightRepository(_client);
  late final _profileRepository = ProfileRepository(_client);
  final _updateChecker = UpdateChecker();
  final _updateDownloader = UpdateDownloader();

  Locale? _localeOverride;

  @override
  void initState() {
    super.initState();
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString('locale_code');
    if (code != null && mounted) {
      setState(() => _localeOverride = Locale(code));
    }
  }

  Future<void> _setLocale(Locale? locale) async {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove('locale_code');
    } else {
      await prefs.setString('locale_code', locale.languageCode);
    }
    setState(() => _localeOverride = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: _localeOverride,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: appTheme,
      home: StreamBuilder<AuthState>(
        stream: _authRepository.onAuthStateChange,
        builder: (context, snapshot) {
          final signedIn = _authRepository.currentSession != null;
          if (!signedIn) {
            return LoginScreen(
              authRepository: _authRepository,
              onSignedIn: () => setState(() {}),
            );
          }
          return _HomeShell(
            authRepository: _authRepository,
            analyzeRepository: _analyzeRepository,
            diaryRepository: _diaryRepository,
            goalsRepository: _goalsRepository,
            weightRepository: _weightRepository,
            profileRepository: _profileRepository,
            updateChecker: _updateChecker,
            updateDownloader: _updateDownloader,
            currentLocale: _localeOverride,
            onLocaleChanged: _setLocale,
          );
        },
      ),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell({
    required this.authRepository,
    required this.analyzeRepository,
    required this.diaryRepository,
    required this.goalsRepository,
    required this.weightRepository,
    required this.profileRepository,
    required this.updateChecker,
    required this.updateDownloader,
    required this.currentLocale,
    required this.onLocaleChanged,
  });
  final AuthRepository authRepository;
  final AnalyzeRepository analyzeRepository;
  final DiaryRepository diaryRepository;
  final GoalsRepository goalsRepository;
  final WeightRepository weightRepository;
  final ProfileRepository profileRepository;
  final UpdateChecker updateChecker;
  final UpdateDownloader updateDownloader;
  final Locale? currentLocale;
  final ValueChanged<Locale?> onLocaleChanged;

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _tab = 0;
  late Future<UserProfile?> _profileFuture;
  late Future<WeightLog?> _latestWeightFuture;
  late Future<List<WeightLog>> _recentWeightsFuture;
  late Future<String> _versionFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.profileRepository.fetchProfile();
    _latestWeightFuture = widget.weightRepository.fetchLatestWeight();
    _recentWeightsFuture = widget.weightRepository.fetchRecentWeights();
    _versionFuture = PackageInfo.fromPlatform().then((info) => info.version);
  }

  Future<void> _openGoals() async {
    final currentGoals = await widget.goalsRepository.fetchGoals();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          initialGoals: currentGoals,
          onSave: widget.goalsRepository.saveGoals,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DiaryScreen(
        repository: widget.diaryRepository,
        goalsRepository: widget.goalsRepository,
        weightRepository: widget.weightRepository,
      ),
      CaptureScreen(
        analyzeRepository: widget.analyzeRepository,
        onSave: (items, photoFile, note) async {
          await widget.diaryRepository.saveMealEntry(
            items: items,
            eatenAt: DateTime.now(),
            note: note,
            photoBytes: photoFile != null
                ? await photoFile.readAsBytes()
                : null,
          );
          if (mounted) setState(() => _tab = 0);
        },
      ),
      FutureBuilder<UserProfile?>(
        future: _profileFuture,
        builder: (context, profileSnapshot) {
          return FutureBuilder<WeightLog?>(
            future: _latestWeightFuture,
            builder: (context, weightSnapshot) {
              return FutureBuilder<List<WeightLog>>(
                future: _recentWeightsFuture,
                builder: (context, recentWeightsSnapshot) {
                  return FutureBuilder<String>(
                    future: _versionFuture,
                    builder: (context, versionSnapshot) {
                      return ProfileScreen(
                        email:
                            widget.authRepository.currentSession?.user.email ??
                            '',
                        latestWeightKg: weightSnapshot.data?.weightKg,
                        recentWeights: recentWeightsSnapshot.data ?? [],
                        initialProfile: profileSnapshot.data,
                        onSaveProfile: (profile) async {
                          await widget.profileRepository.saveProfile(profile);
                          if (mounted) {
                            setState(() {
                              _profileFuture = widget.profileRepository
                                  .fetchProfile();
                            });
                          }
                        },
                        onOpenGoals: _openGoals,
                        onSignOut: widget.authRepository.signOut,
                        currentVersion: versionSnapshot.data ?? '0.0.0',
                        onCheckForUpdate: widget.updateChecker.checkForUpdate,
                        onDownloadAndInstall:
                            widget.updateDownloader.downloadAndInstall,
                        currentLocale: widget.currentLocale,
                        onLocaleChanged: widget.onLocaleChanged,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    ];
    return Scaffold(
      body: screens[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.book), label: 'Diary'),
          NavigationDestination(
            icon: Icon(Icons.camera_alt),
            label: 'Add meal',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

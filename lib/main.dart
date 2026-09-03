import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/analyze/analyze_repository.dart';
import 'features/analyze/capture_screen.dart';
import 'features/diary/diary_repository.dart';
import 'features/diary/diary_screen.dart';
import 'features/settings/goals_repository.dart';

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
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Diary',
      theme: appTheme,
      home: StreamBuilder<AuthState>(
        stream: _authRepository.onAuthStateChange,
        builder: (context, snapshot) {
          final signedIn = _authRepository.currentSession != null;
          if (!signedIn) {
            return LoginScreen(authRepository: _authRepository, onSignedIn: () => setState(() {}));
          }
          return _HomeShell(
            authRepository: _authRepository,
            analyzeRepository: _analyzeRepository,
            diaryRepository: _diaryRepository,
            goalsRepository: _goalsRepository,
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
  });
  final AuthRepository authRepository;
  final AnalyzeRepository analyzeRepository;
  final DiaryRepository diaryRepository;
  final GoalsRepository goalsRepository;

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DiaryScreen(
        repository: widget.diaryRepository,
        goalsRepository: widget.goalsRepository,
        onSignOut: widget.authRepository.signOut,
      ),
      CaptureScreen(
        analyzeRepository: widget.analyzeRepository,
        onSave: (items, photoFile, note) async {
          await widget.diaryRepository.saveMealEntry(
            items: items,
            eatenAt: DateTime.now(),
            note: note,
            photoBytes: photoFile != null ? await photoFile.readAsBytes() : null,
          );
          if (mounted) setState(() => _tab = 0);
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
          NavigationDestination(icon: Icon(Icons.camera_alt), label: 'Add meal'),
        ],
      ),
    );
  }
}

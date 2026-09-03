import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/login_screen.dart';
import 'features/analyze/analyze_repository.dart';
import 'features/analyze/capture_screen.dart';
import 'features/diary/diary_repository.dart';
import 'features/diary/diary_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Diary',
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
  });
  final AuthRepository authRepository;
  final AnalyzeRepository analyzeRepository;
  final DiaryRepository diaryRepository;

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

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'providers/task_provider.dart';
import 'providers/flash_provider.dart';
import 'providers/music_provider.dart';
import 'services/music_audio_handler.dart';
import 'screens/home_screen.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

// ─────────────────────────────────────────────────────────────
//  main — call runApp() immediately so Android gets a surface
//  right away, then finish all heavy init inside the widget tree.
// ─────────────────────────────────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop-only setup — never called on Android.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    JustAudioMediaKit.ensureInitialized(
      android: false, iOS: false, macOS: false,
      windows: true, linux: true,
    );
  }

  // Paint a surface immediately — no awaits before this call.
  runApp(const _BootstrapApp());
}

// ─────────────────────────────────────────────────────────────
//  Bootstrap: runs all async init INSIDE the widget tree via
//  FutureBuilder so Android never shows a black screen.
// ─────────────────────────────────────────────────────────────
class _BootstrapApp extends StatelessWidget {
  const _BootstrapApp();

  // Heavy initialisation — runs after the first frame is drawn.
  static Future<_AppDeps> _init() async {
    final audioHandler = await initAudioHandler();

    final taskProvider = TaskProvider();
    await taskProvider.init();

    final flashProvider = FlashProvider();
    await flashProvider.init();

    final musicProvider = MusicProvider(audioHandler: audioHandler);
    await musicProvider.init();

    return _AppDeps(
      taskProvider: taskProvider,
      flashProvider: flashProvider,
      musicProvider: musicProvider,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // Keep the same colour so the splash blends with the real app.
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF3571E9),
          surface: Color(0xFFF7F7F7),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
      ),
      darkTheme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3571E9),
          surface: Color(0xFF0E1115),
        ),
        scaffoldBackgroundColor: const Color(0xFF0E1115),
      ),
      home: FutureBuilder<_AppDeps>(
        future: _init(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Visible error — helps diagnose any remaining crash.
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Startup error:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            // Splash — shown while init runs (usually < 1 s).
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.checklist_rounded,
                        size: 56, color: Color(0xFF3571E9)),
                    SizedBox(height: 24),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF3571E9),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // Init done — hand off to the real app.
          final deps = snapshot.data!;
          return MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: deps.taskProvider),
              ChangeNotifierProvider.value(value: deps.flashProvider),
              ChangeNotifierProvider.value(value: deps.musicProvider),
            ],
            child: const TaskApp(),
          );
        },
      ),
    );
  }
}

// Simple data-holder returned by _init().
class _AppDeps {
  final TaskProvider taskProvider;
  final FlashProvider flashProvider;
  final MusicProvider musicProvider;
  const _AppDeps({
    required this.taskProvider,
    required this.flashProvider,
    required this.musicProvider,
  });
}

// ─────────────────────────────────────────────────────────────
//  The real app (unchanged from before)
// ─────────────────────────────────────────────────────────────
class TaskApp extends StatelessWidget {
  const TaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    final darkMode = context.watch<TaskProvider>().darkMode;

    return MaterialApp(
      title: 'Tasks',
      debugShowCheckedModeBanner: false,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      home: const HomeScreen(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: const Color(0xFF3571E9),
      onPrimary: Colors.white,
      secondary: const Color(0xFF6C757D),
      onSecondary: Colors.white,
      error: const Color(0xFFDC2828),
      onError: Colors.white,
      surface: isDark ? const Color(0xFF1C1C24) : Colors.white,
      onSurface: isDark ? Colors.white : const Color(0xFF1C1C24),
      outline: isDark ? const Color(0xFF2A2A36) : const Color(0xFFE5E5F0),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0E1115) : const Color(0xFFF7F7F7),
      cardTheme: CardThemeData(
        color: isDark ? const Color(0xFF14181F) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark
                ? const Color(0xFF2A2A36)
                : const Color(0xFFE5E5F0),
            width: 1,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      dialogTheme: DialogThemeData(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        surfaceTintColor: Colors.transparent,
        backgroundColor: isDark ? const Color(0xFF14181F) : Colors.white,
        indicatorColor: const Color(0xFF3571E9).withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? const Color(0xFF3571E9)
                : (isDark ? Colors.white60 : Colors.black54),
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? const Color(0xFF14181F) : Colors.white,
        indicatorColor: const Color(0xFF3571E9).withValues(alpha: 0.12),
        selectedIconTheme:
            const IconThemeData(color: Color(0xFF3571E9)),
        unselectedIconTheme: IconThemeData(
          color: isDark ? Colors.white54 : Colors.black45,
        ),
        selectedLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3571E9),
        ),
        unselectedLabelTextStyle: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
      ),
    );
  }
}
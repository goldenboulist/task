import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'providers/task_provider.dart';
import 'providers/flash_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // sqflite requires FFI on desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final taskProvider = TaskProvider();
  await taskProvider.init();

  final flashProvider = FlashProvider();
  await flashProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: taskProvider),
        ChangeNotifierProvider.value(value: flashProvider),
      ],
      child: const TaskApp(),
    ),
  );
}

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
        backgroundColor:
            isDark ? const Color(0xFF14181F) : Colors.white,
        indicatorColor: const Color(0xFF3571E9).withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? const Color(0xFF3571E9)
                : (isDark ? Colors.white60 : Colors.black54),
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor:
            isDark ? const Color(0xFF14181F) : Colors.white,
        indicatorColor: const Color(0xFF3571E9).withValues(alpha: 0.12),
        selectedIconTheme: const IconThemeData(
          color: Color(0xFF3571E9),
        ),
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

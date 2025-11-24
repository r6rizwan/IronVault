// lib/main.dart
// Main entry + app widget for IronVault
// Replaces previous main.dart with correct lifecycle + Riverpod 3.x usage.

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/autolock/auto_lock_provider.dart';
import 'core/theme/theme_provider.dart';
import 'core/utils/encryption_util.dart';
import 'core/providers.dart';

import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/setup_pin_screen.dart';

// Providers moved to `lib/core/providers.dart` to avoid circular imports.

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Lifecycle handler: start auto-lock on background, check and lock on resume
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final autoLock = ref.read(autoLockProvider.notifier);

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background → record timestamp & start timer
      autoLock.markPaused();
    }

    if (state == AppLifecycleState.resumed) {
      // Evaluate if lock needed
      autoLock.evaluateLockOnResume();

      final locked = ref.read(autoLockProvider);
      if (locked) {
        Future.microtask(() {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch themeModeProvider so theme updates live
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'IronVault',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,

      // ---------- Light theme ----------
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey.shade100,
        cardColor: Colors.white,

        // AppBar styling
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black87,
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),

        // Text theme appropriate for light mode
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black87),
        ),

        // Input decoration styling for light mode
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade200,
          hintStyle: TextStyle(color: Colors.grey.shade600),
          labelStyle: TextStyle(color: Colors.grey.shade800),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),

      // ---------- Dark theme ----------
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          elevation: 0,
          foregroundColor: Colors.white,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),

        // Text theme for dark mode
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          hintStyle: TextStyle(color: Colors.grey.shade500),
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade700),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),

      home: const SplashScreen(),
    );
  }
}

/// Small splash flow that creates a master key on first run and routes to setup/login.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final storage = ref.read(secureStorageProvider);
    final key = await storage.readMasterKey();

    // slight delay to show spinner
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    if (key == null) {
      final newKey = EncryptionUtil.generateKeyBase64();
      await storage.writeMasterKey(newKey);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SetupMasterPinScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

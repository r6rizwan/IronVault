// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironvault/core/autolock/auto_lock_provider.dart';
import 'package:ironvault/core/theme/theme_provider.dart';
import 'features/auth/screens/setup_pin_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'core/secure_storage.dart';
import 'core/utils/encryption_util.dart';
import 'data/db/app_db.dart';
import 'data/repositories/credential_repo.dart';

final secureStorageProvider = Provider((ref) => SecureStorage());

final dbProvider = Provider((ref) => AppDb());

final credentialRepoProvider = Provider(
  (ref) => CredentialRepository(
    db: ref.read(dbProvider),
    secureStorage: ref.read(secureStorageProvider),
  ),
);

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final autoLock = ref.read(autoLockProvider.notifier);

    if (state == AppLifecycleState.paused) {
      // App went to background → start auto-lock timer
      autoLock.startTimer();
    }

    if (state == AppLifecycleState.resumed) {
      // App returned → check if we should lock
      final shouldLock = ref.read(autoLockProvider);

      if (shouldLock == true) {
        // Lock the app → go back to Login Screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      } else {
        // User returned before timer expired → cancel timer
        autoLock.cancelTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IronVault',
      debugShowCheckedModeBanner: false,

      // LIGHT THEME
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.grey.shade100,

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
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          bodyLarge: TextStyle(color: Colors.white),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),

          // 🔥 Fix Text Color
          hintStyle: TextStyle(color: Colors.grey.shade400),
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.blueAccent),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),

          // Field text color
          iconColor: Colors.white,
        ),

        cardColor: Colors.white,
      ),

      // DARK THEME
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

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A2A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),

      themeMode: ref.watch(themeModeProvider),

      home: const SplashScreen(),
    );
  }
}

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

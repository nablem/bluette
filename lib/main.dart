import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/main/main_screen.dart';
import 'screens/profile/profile_completion_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  await dotenv.load(fileName: ".env");

  final supabaseUrl = 'https://yhvezloczmjfbdjibqte.supabase.co';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    throw Exception('SUPABASE_ANON_KEY is missing in .env file.');
  }

  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    debug: true,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluette',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/profile_completion': (context) => const ProfileCompletionScreen(),
        '/home': (context) => const MainScreen(),
      },
    );
  }
}

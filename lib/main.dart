// lib/main.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/color/app_colors.dart';
import 'features/auth/admin_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );
  runApp(const AdminApp());
}

final supabase = Supabase.instance.client;

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EzeeWash Admin',
      theme: ThemeData(
        colorScheme: const ColorScheme.light(primary: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
        textTheme: GoogleFonts.alexandriaTextTheme(),
        useMaterial3: true,
      ),
      home: const AdminLoginScreen(),
    );
  }
}

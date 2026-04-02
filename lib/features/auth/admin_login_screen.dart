// lib/features/auth/admin_login_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/color/app_colors.dart';
import '../../main.dart';
import '../home/dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});
  @override State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool _loading  = false;
  bool _obscure  = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final res = await supabase.auth.signInWithPassword(
        email:    _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
      );

      if (res.user == null) throw Exception('Login failed');

      final String userEmail = res.user!.email!;

      if (userEmail != 'abdulaowalasif2001@gmail.com') {
        final teamRes = await supabase.from('team_members')
            .select()
            .eq('email', userEmail)
            .maybeSingle();

        if (teamRes == null) {
          await supabase.auth.signOut();
          setState(() {
            _error   = 'Access denied. You are not on the Manager whitelist.';
            _loading = false;
          });
          return;
        }
      }

      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()));
      }
    } on AuthApiException catch (e) {
      setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _loading = false; });
    }
  }

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(color: Colors.grey.shade400, fontSize: 14),
    prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 32, offset: const Offset(0, 16))],
            ),
            child: Form(
              key: _formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  height: 72, width: 72,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.local_laundry_service, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 28),
                Text('EzeeWash Workspace', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.text)),
                const SizedBox(height: 8),
                Text('Sign in to your Workspace', style: GoogleFonts.inter(fontSize: 15, color: AppColors.subtext)),
                const SizedBox(height: 40),

                if (_error != null) ...[
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.error.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.error.withOpacity(0.2))),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_error!, style: GoogleFonts.inter(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w500))),
                    ]),
                  ),
                  const SizedBox(height: 24),
                ],

                Align(alignment: Alignment.centerLeft, child: Text('Email Address', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text))),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl, keyboardType: TextInputType.emailAddress, style: GoogleFonts.inter(fontSize: 14),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                  decoration: _deco('example@ezeewash.com', Icons.email_outlined),
                ),
                const SizedBox(height: 24),

                Align(alignment: Alignment.centerLeft, child: Text('Password', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.text))),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl, obscureText: _obscure, style: GoogleFonts.inter(fontSize: 14),
                  onFieldSubmitted: (_) => _handleLogin(),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Password is required' : null,
                  decoration: _deco('Enter your password', Icons.lock_outline).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade400, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity, height: 56,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _loading ? null : AppColors.gradient, color: _loading ? AppColors.border : null,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _loading ? [] : [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8))],
                    ),
                    child: ElevatedButton(
                      onPressed: _loading ? null : _handleLogin,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: _loading
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                          : Text('Sign In', style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Contact the Super Admin if you need access.', style: GoogleFonts.inter(fontSize: 13, color: AppColors.subtext), textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/session_store.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.session});
  final SessionStore session;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool loading = false, obscure = true;

  Future<void> submit() async {
    if (username.text.trim().isEmpty || password.text.isEmpty) return;
    setState(() => loading = true);
    try {
      await AuthRepository(widget.session).login(username.text, password.text);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.message), behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.navy, AppColors.green]))),
          Positioned(
              right: -90,
              top: -70,
              child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.gold.withValues(alpha: .11)))),
          SafeArea(
              child: Center(
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                      color: AppColors.gold,
                                      borderRadius: BorderRadius.circular(18)),
                                  child: const Icon(
                                      Icons.qr_code_scanner_rounded,
                                      color: AppColors.navy,
                                      size: 32)),
                              const SizedBox(height: 28),
                              const Text('IHWE ACCESS',
                                  style: TextStyle(
                                      color: AppColors.gold,
                                      letterSpacing: 3,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13)),
                              const SizedBox(height: 8),
                              const Text('Attendance\nControl Centre',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 40,
                                      height: 1.02)),
                              const SizedBox(height: 12),
                              Text(
                                  'Secure event entry and real-time attendance intelligence.',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: .68),
                                      fontSize: 15,
                                      height: 1.5)),
                              const SizedBox(height: 36),
                              Card(
                                  child: Padding(
                                      padding: const EdgeInsets.all(22),
                                      child: Column(children: [
                                        TextField(
                                            controller: username,
                                            textInputAction:
                                                TextInputAction.next,
                                            decoration: const InputDecoration(
                                                labelText: 'Admin username',
                                                prefixIcon: Icon(Icons
                                                    .person_outline_rounded))),
                                        const SizedBox(height: 14),
                                        TextField(
                                            controller: password,
                                            obscureText: obscure,
                                            onSubmitted: (_) => submit(),
                                            decoration: InputDecoration(
                                                labelText: 'Password',
                                                prefixIcon: const Icon(
                                                    Icons.lock_outline_rounded),
                                                suffixIcon: IconButton(
                                                    onPressed: () => setState(
                                                        () =>
                                                            obscure = !obscure),
                                                    icon: Icon(obscure
                                                        ? Icons
                                                            .visibility_outlined
                                                        : Icons
                                                            .visibility_off_outlined)))),
                                        const SizedBox(height: 20),
                                        FilledButton(
                                            onPressed: loading ? null : submit,
                                            child: loading
                                                ? const SizedBox.square(
                                                    dimension: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color:
                                                                Colors.white))
                                                : const Text('SECURE LOGIN')),
                                      ]))),
                              const SizedBox(height: 18),
                              const Center(
                                  child: Text(
                                      'ADMIN ACCESS ONLY  •  9TH IHWE 2026',
                                      style: TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10,
                                          letterSpacing: 1.4,
                                          fontWeight: FontWeight.w800))),
                            ]),
                      )))),
        ]),
      );
}

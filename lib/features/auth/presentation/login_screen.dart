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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const supporterLogos = <String>[
    'assets/images/supporters/ino.png',
    'assets/images/supporters/icoa.png',
    'assets/images/supporters/hiims.png',
    'assets/images/supporters/bharat_development.png',
    'assets/images/supporters/up_tourism.png',
    'assets/images/supporters/agri_tech.png',
    'assets/images/supporters/msme.png',
    'assets/images/supporters/9ihwe1.png',
    'assets/images/supporters/moksha.png',
    'assets/images/supporters/moksha_seva.png',
    'assets/images/supporters/heeealth.png',
  ];

  final username = TextEditingController();
  final password = TextEditingController();
  late final AnimationController marquee;
  bool loading = false, obscure = true;

  @override
  void initState() {
    super.initState();
    marquee = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    )..repeat();
  }

  Future<void> submit() async {
    if (username.text.trim().isEmpty || password.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => loading = true);
    try {
      await AuthRepository(widget.session).login(username.text, password.text);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    marquee.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpen = keyboardHeight > 0;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF062C38), AppColors.navy, AppColors.green],
            stops: [0, .48, 1],
          ),
        ),
        child: Stack(children: [
          const Positioned(
            left: -85,
            top: 170,
            child: _GlowOrb(size: 230, color: Color(0x1425C68A)),
          ),
          const Positioned(
            right: -105,
            top: -85,
            child: _GlowOrb(size: 280, color: Color(0x18F4C542)),
          ),
          SafeArea(
            child: Stack(children: [
              Positioned(
                top: 20,
                left: 24,
                right: 24,
                height: 170,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                  child: Image.asset(
                    'assets/images/ngt_logo.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              ),
              Positioned.fill(
                top: 202,
                bottom: keyboardOpen ? 0 : 132,
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.fromLTRB(
                      22, 8, 22, keyboardOpen ? keyboardHeight + 10 : 10),
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: _loginCard(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                left: 0,
                right: 0,
                bottom: 0,
                height: keyboardOpen ? 0 : 132,
                child: ClipRect(child: _supporterSection()),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _loginCard() => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .98),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white),
          boxShadow: const [
            BoxShadow(
              color: Color(0x52001218),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(22, 19, 22, 22),
        child: AutofillGroup(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.green.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded,
                  color: AppColors.green, size: 23),
            ),
            const SizedBox(height: 9),
            const Text('Admin Sign In',
                style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 19,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            const Text('IHWE Attendance Control',
                style: TextStyle(
                    color: Colors.black45,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: username,
              autofillHints: const [AutofillHints.username],
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Admin username',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: password,
              obscureText: obscure,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => obscure = !obscure),
                  icon: Icon(obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                ),
              ),
            ),
            const SizedBox(height: 17),
            FilledButton.icon(
              onPressed: loading ? null : submit,
              icon: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.login_rounded, size: 19),
              label: Text(loading ? 'SIGNING IN...' : 'SECURE LOGIN'),
            ),
          ]),
        ),
      );

  Widget _supporterSection() => Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          border: const Border(top: BorderSide(color: Colors.white12)),
        ),
        padding: const EdgeInsets.only(top: 9),
        child: Column(children: [
          const Text('SUPPORTED BY',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 9,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          SizedBox(
            height: 78,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: marquee,
                builder: (_, __) {
                  final tileWidth = MediaQuery.sizeOf(context).width / 4;
                  final trackWidth = supporterLogos.length * tileWidth;
                  final fullTrackWidth = trackWidth * 2;
                  return OverflowBox(
                    alignment: Alignment.centerLeft,
                    minWidth: fullTrackWidth,
                    maxWidth: fullTrackWidth,
                    child: Transform.translate(
                      offset: Offset(-marquee.value * trackWidth, 0),
                      child: SizedBox(
                        width: fullTrackWidth,
                        child: Row(
                          children: [
                            ...supporterLogos
                                .map((asset) => _logoTile(asset, tileWidth)),
                            ...supporterLogos
                                .map((asset) => _logoTile(asset, tileWidth)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ]),
      );

  Widget _logoTile(String asset, double tileWidth) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Container(
          width: tileWidth - 10,
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Image.asset(
            asset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
      );
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}

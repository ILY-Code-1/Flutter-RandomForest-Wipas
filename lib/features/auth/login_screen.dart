import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/domain/access_matrix.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/logo.dart';
import '../../core/widgets/widgets.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.sessionExpired = false});

  final bool sessionExpired;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  String? _emailError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    setState(() {
      _error = null;
      _emailError = null;
    });
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _emailError = AuthMessages.invalidEmail);
      return;
    }
    if (_password.text.isEmpty) {
      setState(() => _error = AuthMessages.wrongCredentials);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).signIn(email, _password.text);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = AuthMessages.generic);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fillDemo(String email) {
    _email.text = email;
    _password.text = AppConfig.demoPassword;
    _submit();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (_, next) {
      if (next.status == AuthStatus.signedIn) context.go(Routes.beranda);
    });
    final expired = widget.sessionExpired || auth.sessionExpired;
    final accountMessage = auth.message;
    final credError = _error != null;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: WipasSpace.xl),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: AutofillGroup(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const SizedBox(height: WipasSpace.xxl),
                    Row(children: [
                      const WipasLogo(size: 44),
                      const SizedBox(width: WipasSpace.md),
                      Text('WIPAS', style: WipasText.title.copyWith(color: WipasColors.navy, fontSize: 22, letterSpacing: 1)),
                    ]),
                    const SizedBox(height: WipasSpace.xl),
                    Semantics(header: true, child: Text('Masuk', style: WipasText.title.copyWith(fontSize: 24, fontWeight: FontWeight.w700))),
                    Text('Gunakan akun WIPAS dari administrator.',
                        style: WipasText.body.copyWith(color: WipasColors.textSecondary)),
                    const SizedBox(height: WipasSpace.lg),
                    if (expired) ...[
                      const WipasAlertBanner(
                        kind: AlertKind.info,
                        icon: Icons.schedule,
                        title: 'Sesi berakhir',
                        body: 'Sesi berakhir setelah 24 jam. Silakan masuk kembali.',
                      ),
                      const SizedBox(height: WipasSpace.lg),
                    ],
                    if (accountMessage != null && !credError) ...[
                      WipasAlertBanner(kind: AlertKind.danger, body: accountMessage),
                      const SizedBox(height: WipasSpace.lg),
                    ],
                    WipasTextField(
                      label: 'Email',
                      controller: _email,
                      fieldKey: const Key('login-email'),
                      hint: 'nama@perusahaan.id',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      errorText: _emailError ?? (credError ? '' : null),
                    ),
                    const SizedBox(height: WipasSpace.lg),
                    WipasTextField(
                      label: 'Password',
                      controller: _password,
                      fieldKey: const Key('login-password'),
                      hint: 'Masukkan password',
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      errorText: _error,
                      suffixIcon: IconButton(
                        tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: WipasColors.textSecondary),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: WipasTextButton(label: 'Lupa password?', onPressed: () => context.push(Routes.forgotPassword)),
                    ),
                    const SizedBox(height: WipasSpace.sm),
                    WipasPrimaryButton(key: const Key('login-submit'), label: 'Masuk', loading: _loading, onPressed: _submit),
                    const SizedBox(height: WipasSpace.md),
                    Text('Akun dibuat oleh administrator.',
                        textAlign: TextAlign.center, style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary)),
                    const Spacer(),
                    if (AppConfig.showDemoLogin) ...[
                      const SizedBox(height: WipasSpace.xl),
                      _DemoPanel(onPick: _loading ? null : _fillDemo),
                    ],
                    const SizedBox(height: WipasSpace.lg),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed "Demo prototipe · masuk sebagai" panel (emulator builds only).
class _DemoPanel extends StatelessWidget {
  const _DemoPanel({required this.onPick});
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    final entries = AppConfig.demoAccounts.entries.toList();
    return CustomPaint(
      painter: _DashedBorder(),
      child: Padding(
        padding: const EdgeInsets.all(WipasSpace.md),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Demo prototipe · masuk sebagai',
              style: WipasText.bodySmall.copyWith(color: WipasColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: WipasSpace.sm),
          for (var row = 0; row < entries.length; row += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: WipasSpace.sm),
              child: Row(children: [
                for (var i = row; i < row + 2 && i < entries.length; i++) ...[
                  if (i > row) const SizedBox(width: WipasSpace.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onPick == null ? null : () => onPick!(entries[i].value),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: WipasColors.border),
                        backgroundColor: WipasColors.surface,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                      child: Text(entries[i].key, textAlign: TextAlign.center, style: WipasText.bodySmall.copyWith(fontWeight: FontWeight.w600, color: WipasColors.navy)),
                    ),
                  ),
                ],
              ]),
            ),
        ]),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = WipasColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(WipasRadius.card)));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

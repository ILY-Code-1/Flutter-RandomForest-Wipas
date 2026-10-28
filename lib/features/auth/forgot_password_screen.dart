import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/domain/access_matrix.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/widgets.dart';
import 'auth_controller.dart';

/// Lupa password → sends a Firebase reset email → confirmation.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = 'Masukkan email yang valid, contoh nama@perusahaan.id');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await ref.read(authControllerProvider.notifier).sendPasswordReset(email);
      if (mounted) setState(() => _sent = true);
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: WipasAppBarSub(title: 'Lupa password', onBack: () => context.canPop() ? context.pop() : context.go(Routes.login)),
      body: SafeArea(
        child: _sent ? _confirmation(context) : _form(),
      ),
    );
  }

  Widget _form() => ListView(
        padding: const EdgeInsets.all(WipasSpace.xl),
        children: [
          Text('Atur ulang password', style: WipasText.title.copyWith(fontSize: 22)),
          const SizedBox(height: WipasSpace.sm),
          Text('Masukkan email akun WIPAS. Kami akan mengirim tautan untuk membuat password baru.',
              style: WipasText.body.copyWith(color: WipasColors.textSecondary)),
          const SizedBox(height: WipasSpace.xl),
          WipasTextField(
            label: 'Email',
            controller: _email,
            hint: 'nama@perusahaan.id',
            keyboardType: TextInputType.emailAddress,
            errorText: _error,
            onSubmitted: (_) => _send(),
          ),
          const SizedBox(height: WipasSpace.xl),
          WipasPrimaryButton(label: 'Kirim tautan reset', loading: _loading, onPressed: _send),
        ],
      );

  Widget _confirmation(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(WipasSpace.xl),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: WipasColors.successTint,
                shape: BoxShape.circle,
                border: Border.all(color: WipasColors.successBorder),
              ),
              child: const Icon(Icons.mail_outline, size: 34, color: WipasColors.success),
            ),
            const SizedBox(height: WipasSpace.xl),
            Text('Tautan reset telah dikirim ke email',
                textAlign: TextAlign.center, style: WipasText.title.copyWith(fontSize: 22)),
            const SizedBox(height: WipasSpace.md),
            Text('Periksa kotak masuk dan folder spam Anda, lalu ikuti tautan untuk membuat password baru.',
                textAlign: TextAlign.center, style: WipasText.body.copyWith(color: WipasColors.textSecondary, fontSize: 15)),
            const SizedBox(height: WipasSpace.xl),
            WipasPrimaryButton(label: 'Kembali ke halaman masuk', onPressed: () => context.go(Routes.login)),
            const SizedBox(height: WipasSpace.md),
            WipasSecondaryButton(label: 'Kirim ulang tautan', onPressed: _loading ? null : _send),
          ]),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/theme.dart';
import 'features/auth/auth_controller.dart';
import 'router.dart';

class WipasApp extends ConsumerStatefulWidget {
  const WipasApp({super.key});

  @override
  ConsumerState<WipasApp> createState() => _WipasAppState();
}

class _WipasAppState extends ConsumerState<WipasApp> with WidgetsBindingObserver {
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
    // Enforce the 24-hour session when the app comes back to the foreground.
    if (state == AppLifecycleState.resumed) {
      ref.read(authControllerProvider.notifier).checkSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WIPAS',
      debugShowCheckedModeBanner: false,
      theme: buildWipasTheme(),
      themeMode: ThemeMode.light,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        // Allow text to grow to 130% (design requirement) but not beyond.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
          child: child!,
        );
      },
    );
  }
}

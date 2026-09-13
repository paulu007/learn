import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';
import 'app_shell.dart';
import 'widgets/common_widgets.dart';

void main() {
  runApp(const ProviderScope(child: EApp()));
}

/// E — offline language learning. Your language, your lessons, your pace.
class EApp extends ConsumerWidget {
  const EApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return settings.when(
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.error_outline,
            title: 'Something went wrong',
            message: e.toString(),
          ),
        ),
      ),
      data: (s) {
        final themes = themesOf(s);
        return MaterialApp(
          title: 'E',
          debugShowCheckedModeBanner: false,
          theme: themes.light,
          darkTheme: themes.dark,
          themeMode: themeModeOf(s.themeMode),
          home: const AppShell(),
        );
      },
    );
  }
}

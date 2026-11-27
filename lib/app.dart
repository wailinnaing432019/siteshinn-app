import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_env.dart';
import 'core/l10n/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/error_formatter.dart';
import 'presentation/screens/auth_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/widgets/app_update_dialog.dart';
import 'providers/app_providers.dart';

class SiteShinnApp extends ConsumerStatefulWidget {
  const SiteShinnApp({super.key});

  @override
  ConsumerState<SiteShinnApp> createState() => _SiteShinnAppState();
}

class _SiteShinnAppState extends ConsumerState<SiteShinnApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  bool _updateCheckScheduled = false;

  void _scheduleStartupUpdateCheck(AppLanguage language) {
    if (_updateCheckScheduled || !AppEnv.isCloudConfigured) return;
    _updateCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final navContext = _navigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) return;
      await AppUpdateDialog.maybeCheckOnStartup(
        navContext,
        strings: AppStrings.of(language),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final authUserAsync = ref.watch(authUserProvider);
    final dashboardAsync = ref.watch(dashboardProvider);

    if (settings.isLoaded) {
      _scheduleStartupUpdateCheck(settings.language);
    }

    Widget buildHome() {
      if (!settings.isLoaded) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (AppEnv.isCloudConfigured &&
          authUserAsync.value == null &&
          !settings.offlineGuestMode) {
        return const AuthScreen();
      }

      return dashboardAsync.when(
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) {
          final strings = AppStrings.of(settings.language);
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_rounded, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      AppErrorFormatter.formatError(err, strings),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      children: [
                        FilledButton(
                          onPressed: () => ref.invalidate(dashboardProvider),
                          child: Text(strings.retryBtn),
                        ),
                        OutlinedButton(
                          onPressed: () => ref
                              .read(appSettingsProvider.notifier)
                              .setOfflineGuestMode(true),
                          child: Text(strings.useOfflineBtn),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        data: (dashboard) {
          if (dashboard.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (dashboard.accounts.isEmpty) {
            return const OnboardingScreen();
          }
          return const HomeScreen();
        },
      );
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'SiteShinn (စိုက်ရှင်း)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      darkTheme: AppTheme.darkTheme(),
      themeMode: settings.themeMode,
      home: buildHome(),
    );
  }
}

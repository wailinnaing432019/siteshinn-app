import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../providers/app_providers.dart';
import '../widgets/account_setup_form.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final language = ref.watch(appSettingsProvider.select((s) => s.language));
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SegmentedButton<AppLanguage>(
                    segments: const [
                      ButtonSegment(value: AppLanguage.en, label: Text('EN')),
                      ButtonSegment(
                        value: AppLanguage.my,
                        label: Text('မြန်မာ'),
                      ),
                    ],
                    selected: {language},
                    onSelectionChanged: (selection) {
                      ref
                          .read(appSettingsProvider.notifier)
                          .setLanguage(selection.first);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 88,
                    height: 88,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                strings.welcomeTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                strings.welcomeSubtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              AccountSetupForm(
                initialAccountName: 'Room 5 Expenses',
                submitLabel: strings.setupAccountBtn,
                onSubmit: (name, currency, accountType, openingBalance, members) {
                  return ref
                      .read(dashboardProvider.notifier)
                      .createAccount(
                        name: name,
                        currencyCode: currency,
                        accountType: accountType,
                        openingBalance: openingBalance,
                        memberNames: members,
                      );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

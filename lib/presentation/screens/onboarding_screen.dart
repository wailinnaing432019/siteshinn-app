import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/error_formatter.dart';
import '../../providers/app_providers.dart';
import '../widgets/account_setup_form.dart';
import '../widgets/brand_logo.dart';
import 'join_group_screen.dart';
import 'user_guide_screen.dart';

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const UserGuideScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.help_outline_rounded, size: 18),
                    label: Text(strings.userGuideTitle),
                  ),
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
              const Center(
                child: BrandLogo(size: 88, borderRadius: 24),
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
              if ((ref.watch(dashboardProvider).value?.isCloudMode ?? false) &&
                  (ref.watch(dashboardProvider).value?.localUnmigratedCount ??
                          0) >
                      0) ...[
                Card(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                  child: ListTile(
                    leading: const Icon(Icons.cloud_upload_outlined),
                    title: Text(strings.migrateV1Title),
                    subtitle: Text(
                      strings.migrateV1Body(
                        ref
                            .watch(dashboardProvider)
                            .value!
                            .localUnmigratedCount,
                      ),
                    ),
                    trailing: FilledButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(dashboardProvider.notifier)
                              .migrateLocalToCloud();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(strings.migratedToast)),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  AppErrorFormatter.formatError(e, strings),
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Text(strings.migrateNowBtn),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (ref.watch(dashboardProvider).value?.isCloudMode ?? false) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const JoinGroupScreen(),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.group_add_outlined),
                  label: Text(strings.joinGroupBtn),
                ),
                const SizedBox(height: 16),
              ],
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

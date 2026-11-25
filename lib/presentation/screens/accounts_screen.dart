import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../data/models/account.dart';
import '../../data/models/member.dart';
import '../../providers/app_providers.dart';
import '../widgets/account_setup_form.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final settings = ref.watch(appSettingsProvider);
    final dashboard = ref.watch(dashboardProvider).value;

    final accounts = dashboard?.accounts ?? [];
    final activeAccount = dashboard?.activeAccount;
    final members = dashboard?.members ?? [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        // Accounts List & Switcher
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              strings.switchAccount,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const _CreateAccountScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 18),
              label: Text(strings.createAccount),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...accounts.map((acc) {
          final isSelected = acc.id == activeAccount?.id;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: isSelected
                ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.45)
                : null,
            child: ListTile(
              leading: Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(
                acc.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(acc.currencyCode),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () =>
                    _showEditAccountDialog(context, ref, strings, acc),
              ),
              onTap: () {
                if (!isSelected) {
                  ref.read(dashboardProvider.notifier).switchAccount(acc.id);
                }
              },
            ),
          );
        }),
        const SizedBox(height: 20),

        // Members Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${strings.membersSection} (${members.where((m) => m.isActive).length})',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () => _showAddMemberDialog(context, ref, strings),
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: Text(strings.addMember),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...members.map((member) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: member.isActive
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                ),
              ),
              title: Text(
                member.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration:
                      member.isActive ? null : TextDecoration.lineThrough,
                ),
              ),
              subtitle: member.isActive
                  ? null
                  : Text(
                      strings.inactiveBadge,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
              trailing: PopupMenuButton<String>(
                onSelected: (action) async {
                  if (action == 'rename') {
                    await _showRenameMemberDialog(
                      context,
                      ref,
                      strings,
                      member,
                    );
                  } else if (action == 'toggle') {
                    await ref.read(dashboardProvider.notifier).updateMember(
                          member.copyWith(isActive: !member.isActive),
                        );
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text(strings.edit),
                  ),
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      member.isActive
                          ? strings.deactivateMember
                          : strings.reactivateMember,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 20),

        // Settings Section
        Text(
          strings.settingsSection,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.languageLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<AppLanguage>(
                    segments: const [
                      ButtonSegment(
                        value: AppLanguage.en,
                        label: Text('English'),
                      ),
                      ButtonSegment(
                        value: AppLanguage.my,
                        label: Text('မြန်မာ'),
                      ),
                    ],
                    selected: {settings.language},
                    onSelectionChanged: (sel) {
                      ref
                          .read(appSettingsProvider.notifier)
                          .setLanguage(sel.first);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  strings.themeLabel,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(strings.themeSystem),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(strings.themeLight),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(strings.themeDark),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (sel) {
                      ref
                          .read(appSettingsProvider.notifier)
                          .setThemeMode(sel.first);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // App Brand Card
        Card(
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 44,
                height: 44,
              ),
            ),
            title: const Text(
              'SiteShinn • စိုက်ရှင်း',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text('Version 1.0 • Offline Local Storage'),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddMemberDialog(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
  ) async {
    final controller = TextEditingController();
    final added = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.addMember),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: strings.memberNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.add),
          ),
        ],
      ),
    );
    if (added == true && controller.text.trim().isNotEmpty) {
      await ref.read(dashboardProvider.notifier).addMember(controller.text);
    }
    controller.dispose();
  }

  Future<void> _showRenameMemberDialog(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
    Member member,
  ) async {
    final controller = TextEditingController(text: member.name);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.edit),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: strings.memberNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.save),
          ),
        ],
      ),
    );
    if (saved == true && controller.text.trim().isNotEmpty) {
      await ref
          .read(dashboardProvider.notifier)
          .updateMember(member.copyWith(name: controller.text.trim()));
    }
    controller.dispose();
  }

  Future<void> _showEditAccountDialog(
    BuildContext context,
    WidgetRef ref,
    AppStrings strings,
    Account account,
  ) async {
    final controller = TextEditingController(text: account.name);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.editAccount),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: strings.accountNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.save),
          ),
        ],
      ),
    );
    if (saved == true && controller.text.trim().isNotEmpty) {
      await ref
          .read(dashboardProvider.notifier)
          .updateAccount(account.copyWith(name: controller.text.trim()));
    }
    controller.dispose();
  }
}

class _CreateAccountScreen extends ConsumerWidget {
  const _CreateAccountScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.createAccount)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AccountSetupForm(
          submitLabel: strings.save,
          onSubmit: (name, currency, members) async {
            await ref.read(dashboardProvider.notifier).createAccount(
                  name: name,
                  currencyCode: currency,
                  memberNames: members,
                );
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }
}

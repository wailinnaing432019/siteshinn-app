import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/account.dart';
import '../../data/models/member.dart';
import '../../providers/app_providers.dart';
import '../../services/reminder_service.dart';
import '../widgets/account_setup_form.dart';
import 'personal_ledger_view.dart';

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
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CreateAccountScreen(),
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
                ? Theme.of(context).colorScheme.primaryContainer
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
              subtitle: Text(
                '${acc.isPersonal ? strings.personalAccountType : strings.groupAccountType} • ${acc.currencyCode}',
              ),
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

        if (activeAccount != null && activeAccount.isPersonal) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_outlined),
              title: Text(strings.openingBalanceLabel),
              subtitle: Text(
                AppFormatters.formatAmount(
                  activeAccount.openingBalance,
                  activeAccount.currencyCode,
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => showEditOpeningBalanceDialog(
                  context,
                  ref,
                  strings,
                  activeAccount,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ] else ...[
          // Members Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${strings.membersSection} (${members.where((m) => m.isActive).length})',
                style: Theme.of(context).textTheme.titleMedium
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
                    decoration: member.isActive
                        ? null
                        : TextDecoration.lineThrough,
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
                      await ref
                          .read(dashboardProvider.notifier)
                          .updateMember(
                            member.copyWith(isActive: !member.isActive),
                          );
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(strings.edit)),
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
        ],

        // Daily Reminder & China ROM Alarm Section
        const _ReminderSettingsCard(),
        const SizedBox(height: 20),

        // Settings Section
        Text(
          strings.settingsSection,
          style: Theme.of(context).textTheme.titleMedium
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

class CreateAccountScreen extends ConsumerWidget {
  const CreateAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(strings.createAccount)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AccountSetupForm(
          submitLabel: strings.save,
          onSubmit:
              (name, currency, accountType, openingBalance, members) async {
                await ref
                    .read(dashboardProvider.notifier)
                    .createAccount(
                      name: name,
                      currencyCode: currency,
                      accountType: accountType,
                      openingBalance: openingBalance,
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

class _ReminderSettingsCard extends ConsumerStatefulWidget {
  const _ReminderSettingsCard();

  @override
  ConsumerState<_ReminderSettingsCard> createState() =>
      _ReminderSettingsCardState();
}

class _ReminderSettingsCardState extends ConsumerState<_ReminderSettingsCard> {
  bool _isTestingSound = false;
  Timer? _previewTimer;

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  Future<void> _startTestSound(
    AppSettingsState settings,
    AppStrings strings,
  ) async {
    _previewTimer?.cancel();
    setState(() => _isTestingSound = true);
    _previewTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _isTestingSound = false);
      }
    });

    final allowed = await ReminderService.instance.sendTestReminder(
      alarmMode: settings.alarmMode,
      customAudioPath: settings.customAlarmPath,
      strings: strings,
    );
    if (!allowed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.notifBlockedWarn),
          action: SnackBarAction(
            label: strings.notifSettingsBtn,
            onPressed: () =>
                ReminderService.instance.openNotificationSettings(),
          ),
        ),
      );
    }
  }

  Future<void> _stopTestSound() async {
    _previewTimer?.cancel();
    setState(() => _isTestingSound = false);
    await ReminderService.instance.stopTestSound();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final settings = ref.watch(appSettingsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                strings.reminderSection,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: const TimeOfDay(hour: 19, minute: 0),
                );
                if (picked != null) {
                  await ref
                      .read(appSettingsProvider.notifier)
                      .addAlarm(hour: picked.hour, minute: picked.minute);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(strings.reminderScheduledToast)),
                    );
                  }
                }
              },
              icon: const Icon(Icons.add_alarm_outlined, size: 18),
              label: Text(strings.addAlarmBtn),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                if (settings.alarms.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      strings.noAlarmsYet,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                else
                  ...settings.alarms.map((alarm) {
                    final tod = TimeOfDay(hour: alarm.hour, minute: alarm.minute);
                    return ListTile(
                      leading: const Icon(Icons.access_time_outlined),
                      title: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: tod,
                          );
                          if (picked != null) {
                            await ref
                                .read(appSettingsProvider.notifier)
                                .updateAlarmTime(
                                  alarm.id,
                                  picked.hour,
                                  picked.minute,
                                );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(strings.reminderScheduledToast),
                                ),
                              );
                            }
                          }
                        },
                        child: Text(
                          tod.format(context),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: alarm.enabled
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: alarm.enabled,
                            onChanged: (val) async {
                              await ref
                                  .read(appSettingsProvider.notifier)
                                  .toggleAlarm(alarm.id, val);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content:
                                        Text(strings.reminderScheduledToast),
                                  ),
                                );
                              }
                            },
                          ),
                          IconButton(
                            tooltip: strings.delete,
                            icon: const Icon(Icons.delete_outline, size: 20),
                            onPressed: () => ref
                                .read(appSettingsProvider.notifier)
                                .deleteAlarm(alarm.id),
                          ),
                        ],
                      ),
                    );
                  }),
                const Divider(),
                SwitchListTile(
                  secondary: const Icon(Icons.alarm_outlined),
                  title: Text(strings.alarmModeToggle),
                  subtitle: Text(
                    strings.alarmModeDesc,
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: settings.alarmMode,
                  onChanged: (val) => ref
                      .read(appSettingsProvider.notifier)
                      .setAlarmMode(val),
                ),
                ListTile(
                  leading: const Icon(Icons.music_note_outlined),
                  title: Text(strings.alarmSoundLabel),
                  subtitle: Text(
                    settings.customAlarmName ?? strings.defaultAlarmSound,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (settings.customAlarmPath != null)
                        IconButton(
                          tooltip: strings.resetAlarmSongBtn,
                          icon: const Icon(Icons.close),
                          onPressed: () => ref
                              .read(appSettingsProvider.notifier)
                              .clearCustomAlarmSong(),
                        ),
                      TextButton(
                        onPressed: () async {
                          final picked = await ReminderService.instance
                              .pickAndSaveCustomAlarmSong();
                          if (picked != null) {
                            await ref
                                .read(appSettingsProvider.notifier)
                                .setCustomAlarmSong(
                                  path: picked.path,
                                  name: picked.name,
                                );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(strings.songSavedToast)),
                              );
                            }
                          }
                        },
                        child: Text(strings.pickAlarmSongBtn),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        strings.chinaRomTip,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _startTestSound(settings, strings),
                            icon: const Icon(
                              Icons.volume_up_outlined,
                              size: 18,
                            ),
                            label: Text(strings.testReminderBtn),
                          ),
                          if (_isTestingSound)
                            FilledButton.tonalIcon(
                              onPressed: _stopTestSound,
                              icon: const Icon(
                                Icons.stop_circle_outlined,
                                size: 18,
                              ),
                              label: Text(strings.stopSoundBtn),
                            ),
                          OutlinedButton.icon(
                            onPressed: () => ReminderService.instance
                                .openNotificationSettings(),
                            icon: const Icon(
                              Icons.notifications_outlined,
                              size: 18,
                            ),
                            label: Text(strings.notifSettingsBtn),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                ReminderService.instance.openBatterySettings(),
                            icon: const Icon(
                              Icons.battery_saver_outlined,
                              size: 18,
                            ),
                            label: Text(strings.batterySettingsBtn),
                          ),
                          TextButton.icon(
                            onPressed: () =>
                                ReminderService.instance.openAppSettings(),
                            icon: const Icon(
                              Icons.settings_applications_outlined,
                              size: 18,
                            ),
                            label: Text(strings.appInfoBtn),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

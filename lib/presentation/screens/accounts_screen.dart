import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_env.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/utils/error_formatter.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/account.dart';
import '../../data/models/member.dart';
import '../../providers/app_providers.dart';
import '../../services/app_update_service.dart';
import '../../services/auth_service.dart';
import '../../services/reminder_service.dart';
import '../widgets/account_setup_form.dart';
import '../widgets/app_update_dialog.dart';
import '../widgets/brand_logo.dart';
import 'auth_screen.dart';
import 'join_group_screen.dart';
import 'personal_ledger_view.dart';
import 'user_guide_screen.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final settings = ref.watch(appSettingsProvider);
    final dashboard = ref.watch(dashboardProvider).value;
    final authUser = ref.watch(authUserProvider).value;
    final currentUserId = authUser?.uid ?? AuthService.instance.currentUser?.uid;

    final accounts = dashboard?.accounts ?? [];
    final activeAccount = dashboard?.activeAccount;
    final members = dashboard?.members ?? [];
    final isCloudMode = dashboard?.isCloudMode ?? false;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (AppEnv.isCloudConfigured) ...[
          const _CloudAccountCard(),
          const SizedBox(height: 16),
        ],

        // Accounts List & Switcher
        Text(
          strings.switchAccount,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (isCloudMode) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const JoinGroupScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.group_add_outlined, size: 18),
                  label: Text(
                    strings.joinGroupBtn,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateAccountScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  strings.createAccount,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
          if (isCloudMode &&
              activeAccount != null &&
              activeAccount.inviteCode != null &&
              activeAccount.inviteCode!.isNotEmpty) ...[
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer
                  .withValues(alpha: 0.45),
              child: ListTile(
                leading: const Icon(Icons.vpn_key_outlined),
                title: Text(strings.shareInviteLabel),
                subtitle: SelectableText(
                  activeAccount.inviteCode!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    fontSize: 16,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: activeAccount.inviteCode!),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(strings.inviteCodeCopied)),
                          );
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Share',
                      icon: const Icon(Icons.share_outlined),
                      onPressed: () {
                        SharePlus.instance.share(
                          ShareParams(
                            text:
                                '${activeAccount.name} (${strings.inviteCodeLabel}): ${activeAccount.inviteCode!}',
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

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
            final isYou =
                currentUserId != null && member.userId == currentUserId;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Tooltip(
                message: member.name,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: member.isActive
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Text(
                      member.name.isNotEmpty
                          ? member.name[0].toUpperCase()
                          : '?',
                    ),
                  ),
                  title: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        member.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: member.isActive
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                      if (isYou)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            strings.youBadge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ),
                    ],
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

        // User Guide Card
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.secondaryContainer,
              child: Icon(
                Icons.menu_book_outlined,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
            title: Text(
              strings.userGuideTitle,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(strings.userGuideSubtitle),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserGuideScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // App Brand & Manual Update Check Card
        const _AppBrandAndUpdateCard(),
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
                style: Theme.of(context).textTheme.titleMedium
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
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  )
                else
                  ...settings.alarms.map((alarm) {
                    final tod = TimeOfDay(
                      hour: alarm.hour,
                      minute: alarm.minute,
                    );
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
                          style: Theme.of(context).textTheme.titleMedium
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
                                    content: Text(
                                      strings.reminderScheduledToast,
                                    ),
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
                  onChanged: (val) =>
                      ref.read(appSettingsProvider.notifier).setAlarmMode(val),
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
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
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

class _CloudAccountCard extends ConsumerStatefulWidget {
  const _CloudAccountCard();

  @override
  ConsumerState<_CloudAccountCard> createState() => _CloudAccountCardState();
}

class _CloudAccountCardState extends ConsumerState<_CloudAccountCard> {
  bool _isMigrating = false;

  Future<void> _migrateLocalData(AppStrings strings) async {
    setState(() => _isMigrating = true);
    try {
      await ref.read(dashboardProvider.notifier).migrateLocalToCloud();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(strings.migratedToast)));
      }
    } catch (e) {
      final msg = await AppErrorFormatter.formatErrorAsync(e, strings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isMigrating = false);
    }
  }

  Future<void> _confirmLogout(AppStrings strings) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(strings.logoutBtn),
        content: Text(strings.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(strings.logoutBtn),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.instance.signOut();
    await ref.read(appSettingsProvider.notifier).setOfflineGuestMode(false);
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final authUser =
        ref.watch(authUserProvider).value ?? AuthService.instance.currentUser;
    final dashboard = ref.watch(dashboardProvider).value;
    final localUnmigratedCount = dashboard?.localUnmigratedCount ?? 0;
    final colorScheme = Theme.of(context).colorScheme;

    if (authUser == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.cloud_off_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      strings.offlineModeBadge,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AuthScreen(canPop: true),
                    ),
                  );
                },
                icon: const Icon(Icons.login_rounded, size: 18),
                label: Text(strings.signInToSyncBtn),
              ),
            ],
          ),
        ),
      );
    }

    final rawName = authUser.displayName;
    final displayName = (rawName != null && rawName.trim().isNotEmpty)
        ? rawName.trim()
        : (authUser.email ?? strings.cloudSyncedBadge);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dashboard?.isOfflineFallback == true) ...[
          Card(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              strings.offlineModeBadge,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              strings.offlineBannerText,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonal(
                      onPressed: () =>
                          ref.read(dashboardProvider.notifier).retryOnline(),
                      child: Text(strings.retryOnlineBtn),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Card(
          child: Tooltip(
            message: authUser.email != null
                ? '$displayName (${authUser.email!})'
                : displayName,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(
                          Icons.cloud_done_outlined,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            if (authUser.email != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                authUser.email!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.65,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              size: 14,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              strings.cloudSyncedBadge,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _confirmLogout(strings),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: Text(strings.logoutBtn),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (localUnmigratedCount > 0) ...[
          const SizedBox(height: 8),
          Card(
            color: colorScheme.primaryContainer.withValues(alpha: 0.45),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strings.migrateV1Title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(strings.migrateV1Body(localUnmigratedCount)),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _isMigrating
                        ? null
                        : () => _migrateLocalData(strings),
                    icon: _isMigrating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_rounded, size: 18),
                    label: Text(strings.migrateNowBtn),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AppBrandAndUpdateCard extends ConsumerStatefulWidget {
  const _AppBrandAndUpdateCard();

  @override
  ConsumerState<_AppBrandAndUpdateCard> createState() =>
      _AppBrandAndUpdateCardState();
}

class _AppBrandAndUpdateCardState
    extends ConsumerState<_AppBrandAndUpdateCard> {
  bool _isChecking = false;

  Future<void> _checkUpdates(AppStrings strings) async {
    setState(() => _isChecking = true);
    try {
      final info = await AppUpdateService.instance.checkForUpdate(
        isBurmese: strings.isBurmese,
        throwOnError: true,
      );
      if (!mounted) return;
      if (info != null) {
        await AppUpdateDialog.show(context, info: info, strings: strings);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.upToDateToast)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final message = await AppErrorFormatter.formatErrorAsync(e, strings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const BrandLogo(size: 44, borderRadius: 10),
              title: const Text(
                'SiteShinn • စိုက်ရှင်း',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('v2.1.1 • Wai Linn Naing'),
            ),
            if (AppEnv.isCloudConfigured)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed:
                      _isChecking ? null : () => _checkUpdates(strings),
                  icon: _isChecking
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update_alt_rounded, size: 18),
                  label: Text(
                    _isChecking
                        ? strings.checkingUpdates
                        : strings.checkUpdateBtn,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

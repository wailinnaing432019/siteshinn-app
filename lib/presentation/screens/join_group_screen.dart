import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_formatter.dart';
import '../../data/repositories/budget_data_source.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';

class JoinGroupScreen extends ConsumerStatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  ConsumerState<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends ConsumerState<JoinGroupScreen> {
  final _codeController = TextEditingController();
  final _newNameController = TextEditingController();
  GroupInvitePreview? _preview;
  String? _selectedMemberId; // null => join as new member
  bool _isSearching = false;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _newNameController.text = AuthService.instance.currentDisplayName ?? '';
  }

  @override
  void dispose() {
    _codeController.dispose();
    _newNameController.dispose();
    super.dispose();
  }

  Future<void> _lookupCode() async {
    final strings = ref.read(appStringsProvider);
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isSearching = true;
      _preview = null;
      _selectedMemberId = null;
    });
    try {
      final result =
          await ref.read(dashboardProvider.notifier).previewGroupInvite(code);
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.invalidInviteCode)),
        );
      } else {
        setState(() {
          _preview = result;
          _selectedMemberId = result.unclaimedMembers.isNotEmpty
              ? result.unclaimedMembers.first.id
              : null;
        });
      }
    } catch (e) {
      final msg = await AppErrorFormatter.formatErrorAsync(e, strings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _join() async {
    final strings = ref.read(appStringsProvider);
    if (_preview == null) return;
    if (_selectedMemberId == null && _newNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.requiredField)),
      );
      return;
    }

    setState(() => _isJoining = true);
    try {
      await ref.read(dashboardProvider.notifier).joinGroupByInviteCode(
            code: _codeController.text.trim(),
            memberId: _selectedMemberId,
            displayName: _selectedMemberId == null
                ? _newNameController.text.trim()
                : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.joinedGroupToast)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      final msg = await AppErrorFormatter.formatErrorAsync(e, strings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(strings.joinGroupBtn)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: strings.inviteCodeLabel,
              hintText: 'e.g. RM58K2',
              prefixIcon: const Icon(Icons.qr_code_2_outlined),
            ),
            onSubmitted: (_) => _lookupCode(),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _isSearching ? null : _lookupCode,
            icon: _isSearching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(strings.findGroupBtn),
          ),
          if (_preview != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: const Icon(Icons.group_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _preview!.name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(_preview!.currencyCode),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      strings.claimNameHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<String?>(
                      groupValue: _selectedMemberId,
                      onChanged: (v) => setState(() => _selectedMemberId = v),
                      child: Column(
                        children: [
                          ..._preview!.unclaimedMembers.map(
                            (m) => RadioListTile<String?>(
                              value: m.id,
                              title: Text(m.name),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          RadioListTile<String?>(
                            value: null,
                            title: Text(strings.joinAsNewMember),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    if (_selectedMemberId == null) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: _newNameController,
                        decoration: InputDecoration(
                          labelText: strings.memberNameLabel,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _isJoining ? null : _join,
                      icon: _isJoining
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.login),
                      label: Text(strings.joinGroupBtn),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

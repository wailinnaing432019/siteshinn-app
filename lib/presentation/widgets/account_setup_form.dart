import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_formatter.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/account.dart';
import '../../providers/app_providers.dart';
import '../../services/auth_service.dart';

class AccountSetupForm extends ConsumerStatefulWidget {
  final String initialAccountName;
  final String submitLabel;
  final Future<void> Function(
    String name,
    String currencyCode,
    AccountType accountType,
    double openingBalance,
    List<String> memberNames,
  ) onSubmit;

  const AccountSetupForm({
    super.key,
    this.initialAccountName = '',
    required this.submitLabel,
    required this.onSubmit,
  });

  @override
  ConsumerState<AccountSetupForm> createState() => _AccountSetupFormState();
}

class _AccountSetupFormState extends ConsumerState<AccountSetupForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _accountNameController;
  final _openingBalanceController = TextEditingController(text: '0');
  final List<TextEditingController> _memberControllers = List.generate(
    5,
    (_) => TextEditingController(),
  );
  AccountType _accountType = AccountType.group;
  String _currencyCode = 'MMK';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _accountNameController =
        TextEditingController(text: widget.initialAccountName);
    final defaultMemberName = AuthService.instance.currentDisplayName;
    if (defaultMemberName != null &&
        defaultMemberName.isNotEmpty &&
        _memberControllers.isNotEmpty) {
      _memberControllers.first.text = defaultMemberName;
    }
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _openingBalanceController.dispose();
    for (final c in _memberControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addMemberField() {
    setState(() {
      _memberControllers.add(TextEditingController());
    });
  }

  void _removeMemberField(int index) {
    if (_memberControllers.length <= 2) return;
    setState(() {
      final removed = _memberControllers.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final strings = ref.read(appStringsProvider);

    if (_accountType == AccountType.group) {
      final names = _memberControllers
          .map((c) => c.text.trim())
          .where((n) => n.isNotEmpty)
          .toList();

      if (names.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.needTwoMembers)),
        );
        return;
      }

      setState(() => _isSaving = true);
      try {
        await widget.onSubmit(
          _accountNameController.text.trim(),
          _currencyCode,
          AccountType.group,
          0,
          names,
        );
      } catch (e) {
        final msg = await AppErrorFormatter.formatErrorAsync(e, strings);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg)),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
      return;
    }

    final opening = double.tryParse(
      _openingBalanceController.text.replaceAll(',', '').trim(),
    );
    if (opening == null || opening < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.invalidOpeningBalance)),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSubmit(
        _accountNameController.text.trim(),
        _currencyCode,
        AccountType.personal,
        opening,
        const [],
      );
    } catch (e) {
      final msg = await AppErrorFormatter.formatErrorAsync(e, strings);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.accountTypeLabel,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<AccountType>(
                    segments: [
                      ButtonSegment(
                        value: AccountType.group,
                        icon: const Icon(Icons.group_outlined, size: 18),
                        label: Text(strings.groupAccountType),
                      ),
                      ButtonSegment(
                        value: AccountType.personal,
                        icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                        label: Text(strings.personalAccountType),
                      ),
                    ],
                    selected: {_accountType},
                    onSelectionChanged: (sel) {
                      setState(() {
                        _accountType = sel.first;
                        if (_accountType == AccountType.personal &&
                            _accountNameController.text == 'Room 5 Expenses') {
                          _accountNameController.text = 'My Wallet';
                        } else if (_accountType == AccountType.group &&
                            _accountNameController.text == 'My Wallet') {
                          _accountNameController.text = 'Room 5 Expenses';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _accountType == AccountType.group
                        ? strings.groupAccountDesc
                        : strings.personalAccountDesc,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _accountNameController,
                    decoration: InputDecoration(
                      labelText: strings.accountNameLabel,
                      hintText: _accountType == AccountType.group
                          ? 'e.g. Room 5 Expenses'
                          : 'e.g. My Wallet',
                      prefixIcon: const Icon(Icons.home_work_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? strings.requiredField
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _currencyCode,
                    decoration: InputDecoration(
                      labelText: strings.currencyLabel,
                      prefixIcon: const Icon(Icons.payments_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'MMK', child: Text('MMK (Ks)')),
                      DropdownMenuItem(value: 'THB', child: Text('THB (฿)')),
                      DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                      DropdownMenuItem(value: 'SGD', child: Text('SGD (S\$)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _currencyCode = val);
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  if (_accountType == AccountType.personal) ...[
                    TextFormField(
                      controller: _openingBalanceController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: strings.openingBalanceLabel,
                        suffixText:
                            AppFormatters.symbolForCurrency(_currencyCode),
                        prefixIcon:
                            const Icon(Icons.account_balance_outlined),
                      ),
                      validator: (v) {
                        final val =
                            double.tryParse((v ?? '').replaceAll(',', '').trim());
                        if (val == null || val < 0) {
                          return strings.invalidOpeningBalance;
                        }
                        return null;
                      },
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            strings.initialMembersHint,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addMemberField,
                          icon: const Icon(Icons.person_add_alt_1, size: 18),
                          label: Text(strings.add),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(_memberControllers.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _memberControllers[index],
                                decoration: InputDecoration(
                                  labelText:
                                      '${strings.memberNameLabel} ${index + 1}',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  isDense: true,
                                ),
                              ),
                            ),
                            if (_memberControllers.length > 2) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                onPressed: () => _removeMemberField(index),
                                icon: const Icon(Icons.remove_circle_outline),
                                color: colorScheme.error,
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _isSaving ? null : _submit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }
}

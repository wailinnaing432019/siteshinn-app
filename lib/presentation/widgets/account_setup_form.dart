import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';

class AccountSetupForm extends ConsumerStatefulWidget {
  final String initialAccountName;
  final String submitLabel;
  final Future<void> Function(
    String name,
    String currencyCode,
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
  final List<TextEditingController> _memberControllers = List.generate(
    5,
    (_) => TextEditingController(),
  );
  String _currencyCode = 'MMK';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _accountNameController =
        TextEditingController(text: widget.initialAccountName);
  }

  @override
  void dispose() {
    _accountNameController.dispose();
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
        names,
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
                  TextFormField(
                    controller: _accountNameController,
                    decoration: InputDecoration(
                      labelText: strings.accountNameLabel,
                      hintText: 'e.g. Room 5 Expenses',
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
                  const SizedBox(height: 20),
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

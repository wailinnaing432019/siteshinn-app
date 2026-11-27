import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_formatter.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/expense.dart';
import '../../data/models/member.dart';
import '../../providers/app_providers.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final Expense? existingExpense;

  const AddExpenseScreen({super.key, this.existingExpense});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late TransactionType _txType;
  late ExpenseCategory _category;
  late DateTime _expenseDate;
  String? _paidByMemberId;
  String? _advanceToMemberId;
  late Set<String> _selectedParticipantIds;
  bool _isSaving = false;

  static const _advancePresetsEn = [
    'Grocery advance',
    'Common fund',
    'Mid-cycle payment',
  ];
  static const _advancePresetsMy = [
    'ဈေးဖိုးကြိုပေးငွေ',
    'ဘုံငွေထည့်ငွေ',
    'ကြားဖြတ်ပြန်ဆပ်ငွေ',
  ];

  static const _groupPresetsEn = [
    'Groceries',
    'Meat & Veggies',
    'Rice & Oil',
    'Cooking Gas',
    'Electricity / Water',
  ];
  static const _groupPresetsMy = [
    'ဈေးဖိုး',
    'ဟင်းချက်စရာ',
    'ဆန် / ဆီ',
    'ဂတ်စ် / ထမင်းချက်',
    'မီး / ရေဖိုး',
  ];

  static const _personalExpensePresetsEn = [
    'Lunch / Dinner',
    'Coffee / Snacks',
    'Bus / Grab',
    'Phone Bill / Internet',
    'Shopping',
  ];
  static const _personalExpensePresetsMy = [
    'ထမင်းဖိုး',
    'ကော်ဖီ / မုန့်',
    'ကားခ / Grab',
    'ဖုန်းဘေလ် / အင်တာနက်',
    'ဈေးဝယ်',
  ];

  static const _incomePresetsEn = [
    'Monthly Salary',
    'Freelance / Project',
    'Bonus / Gift',
    'Refund',
  ];
  static const _incomePresetsMy = [
    'လစာ',
    'အပိုဝင်ငွေ',
    'လက်ဆောင် / ဘောနပ်စ်',
    'ပြန်အမ်းငွေ',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingExpense;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _amountController = TextEditingController(
      text: existing != null
          ? (existing.amount == existing.amount.roundToDouble()
                ? existing.amount.toInt().toString()
                : existing.amount.toString())
          : '',
    );
    _txType = existing?.txType ?? TransactionType.expense;
    _category = existing?.category ?? ExpenseCategory.food;
    _expenseDate = existing?.expenseDate ?? DateTime.now();
    _paidByMemberId = existing?.paidByMemberId;
    _advanceToMemberId =
        existing != null && existing.isAdvance && existing.splits.isNotEmpty
            ? existing.splits.first.memberId
            : null;
    _selectedParticipantIds = existing != null && existing.splits.isNotEmpty
        ? existing.splits.map((s) => s.memberId).toSet()
        : <String>{};
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
  }

  Future<void> _save({
    required bool isPersonal,
    required List<Member> availableMembers,
  }) async {
    if (!_formKey.currentState!.validate()) return;
    final strings = ref.read(appStringsProvider);

    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(strings.invalidAmount)));
      return;
    }

    String? payerId;
    var participants = const <String>[];
    final isGroupAdvance = !isPersonal && _txType == TransactionType.advance;
    final rawTitle = _titleController.text.trim();

    if (!isPersonal) {
      payerId =
          _paidByMemberId ??
          (availableMembers.isNotEmpty ? availableMembers.first.id : null);
      if (payerId == null) return;

      if (isGroupAdvance) {
        final receiverId = _advanceToMemberId;
        if (receiverId == null || receiverId == payerId) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.sameMemberAdvanceError)),
          );
          return;
        }
        participants = [receiverId];
      } else {
        if (_selectedParticipantIds.isEmpty) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(strings.needOneMember)));
          return;
        }
        participants = _selectedParticipantIds.toList();
      }
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(dashboardProvider.notifier)
          .saveTransaction(
            existingExpenseId: widget.existingExpense?.id,
            paidByMemberId: payerId,
            txType: isPersonal
                ? _txType
                : (isGroupAdvance
                      ? TransactionType.advance
                      : TransactionType.expense),
            title: isGroupAdvance && rawTitle.isEmpty
                ? strings.advanceDefaultTitle
                : rawTitle,
            category: isGroupAdvance ? ExpenseCategory.other : _category,
            amount: amount,
            expenseDate: _expenseDate,
            participantIds: participants,
          );
      if (mounted) {
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
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);
    final dashboard = ref.watch(dashboardProvider).value;
    final account = dashboard?.activeAccount;
    final isPersonal = account?.isPersonal ?? false;
    final activeMembers = dashboard?.activeMembers ?? [];
    final allMembers = dashboard?.members ?? [];

    final selectableMembers = widget.existingExpense == null
        ? activeMembers
        : allMembers
              .where(
                (m) =>
                    m.isActive ||
                    m.id == widget.existingExpense!.paidByMemberId ||
                    _selectedParticipantIds.contains(m.id),
              )
              .toList();

    if (!isPersonal) {
      if (_paidByMemberId == null && selectableMembers.isNotEmpty) {
        final currentUserId = ref.watch(authUserProvider).value?.uid;
        final myMemberId = dashboard?.memberIdForUser(currentUserId);
        _paidByMemberId =
            (myMemberId != null &&
                selectableMembers.any((m) => m.id == myMemberId))
            ? myMemberId
            : selectableMembers.first.id;
      }
      if ((_advanceToMemberId == null || _advanceToMemberId == _paidByMemberId) &&
          selectableMembers.length > 1) {
        _advanceToMemberId = selectableMembers
            .firstWhere(
              (m) => m.id != _paidByMemberId,
              orElse: () => selectableMembers.first,
            )
            .id;
      }
      if (widget.existingExpense == null &&
          _selectedParticipantIds.isEmpty &&
          activeMembers.isNotEmpty) {
        _selectedParticipantIds = activeMembers.map((m) => m.id).toSet();
      }
    }

    final isGroupAdvance = !isPersonal && _txType == TransactionType.advance;
    final currency = account?.currencyCode ?? 'MMK';
    final parsedAmount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    final perShare = !isPersonal &&
            !isGroupAdvance &&
            _selectedParticipantIds.isNotEmpty &&
            parsedAmount > 0
        ? parsedAmount / _selectedParticipantIds.length
        : 0.0;

    final categories = isPersonal
        ? (_txType == TransactionType.income
              ? ExpenseCategory.incomeCategories
              : ExpenseCategory.personalExpenseCategories)
        : ExpenseCategory.groupExpenseCategories;

    if (!categories.contains(_category)) {
      _category = categories.first;
    }

    final presets = isPersonal
        ? (_txType == TransactionType.income
              ? (strings.isBurmese ? _incomePresetsMy : _incomePresetsEn)
              : (strings.isBurmese
                    ? _personalExpensePresetsMy
                    : _personalExpensePresetsEn))
        : (isGroupAdvance
              ? (strings.isBurmese ? _advancePresetsMy : _advancePresetsEn)
              : (strings.isBurmese ? _groupPresetsMy : _groupPresetsEn));

    final screenTitle = isPersonal
        ? (widget.existingExpense == null
              ? strings.addTransaction
              : strings.editTransaction)
        : (isGroupAdvance
              ? (widget.existingExpense == null
                    ? strings.addAdvance
                    : strings.editAdvance)
              : (widget.existingExpense == null
                    ? strings.addExpense
                    : strings.editExpense));

    return Scaffold(
      appBar: AppBar(title: Text(screenTitle)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isPersonal) ...[
              SegmentedButton<TransactionType>(
                segments: [
                  ButtonSegment(
                    value: TransactionType.expense,
                    icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                    label: Text(strings.expenseLabel),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                    label: Text(strings.incomeLabel),
                  ),
                ],
                selected: {_txType},
                onSelectionChanged: (sel) {
                  setState(() {
                    _txType = sel.first;
                    _category = _txType == TransactionType.income
                        ? ExpenseCategory.salary
                        : ExpenseCategory.food;
                  });
                },
              ),
              const SizedBox(height: 16),
            ] else ...[
              SegmentedButton<TransactionType>(
                segments: [
                  ButtonSegment(
                    value: TransactionType.expense,
                    icon: const Icon(Icons.receipt_long_outlined, size: 18),
                    label: Text(strings.expenseLabel),
                  ),
                  ButtonSegment(
                    value: TransactionType.advance,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: Text(strings.advanceLabel),
                  ),
                ],
                selected: {_txType == TransactionType.advance
                    ? TransactionType.advance
                    : TransactionType.expense},
                onSelectionChanged: (sel) {
                  setState(() => _txType = sel.first);
                },
              ),
              if (isGroupAdvance) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          strings.advanceInfoNote,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],

            // Amount Input
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: widget.existingExpense == null,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                labelText: strings.amountLabel,
                suffixText: AppFormatters.symbolForCurrency(currency),
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final val = double.tryParse((v ?? '').replaceAll(',', ''));
                if (val == null || val <= 0) {
                  return strings.invalidAmount;
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Title Input + Quick Presets
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: strings.titleLabel,
                prefixIcon: const Icon(Icons.receipt_long_outlined),
              ),
              validator: (v) {
                if (isGroupAdvance) return null;
                return (v == null || v.trim().isEmpty)
                    ? strings.requiredField
                    : null;
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: presets.map((preset) {
                return ActionChip(
                  label: Text(preset, style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    setState(() => _titleController.text = preset);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            if (!isPersonal) ...[
              Text(
                isGroupAdvance ? strings.fromMemberLabel : strings.paidByLabel,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectableMembers.map((member) {
                  final selected = _paidByMemberId == member.id;
                  return ChoiceChip(
                    avatar: CircleAvatar(
                      radius: 11,
                      child: Text(
                        member.name.isNotEmpty
                            ? member.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                    label: Text(member.name),
                    selected: selected,
                    onSelected: (_) {
                      setState(() {
                        final prevFrom = _paidByMemberId;
                        _paidByMemberId = member.id;
                        if (isGroupAdvance && _advanceToMemberId == member.id) {
                          _advanceToMemberId = prevFrom != member.id
                              ? prevFrom
                              : selectableMembers
                                  .where((m) => m.id != member.id)
                                  .firstOrNull
                                  ?.id;
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              if (isGroupAdvance) ...[
                Text(
                  strings.toMemberLabel,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectableMembers.map((member) {
                    final selected = _advanceToMemberId == member.id;
                    return ChoiceChip(
                      avatar: CircleAvatar(
                        radius: 11,
                        child: Text(
                          member.name.isNotEmpty
                              ? member.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      label: Text(member.name),
                      selected: selected,
                      onSelected: member.id == _paidByMemberId
                          ? null
                          : (_) {
                              setState(() => _advanceToMemberId = member.id);
                            },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      strings.splitAmongLabel,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedParticipantIds.length ==
                              selectableMembers.length) {
                            _selectedParticipantIds = {_paidByMemberId!};
                          } else {
                            _selectedParticipantIds = selectableMembers
                                .map((m) => m.id)
                                .toSet();
                          }
                        });
                      },
                      child: Text(strings.selectAllMembers),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectableMembers.map((member) {
                    final selected = _selectedParticipantIds.contains(member.id);
                    return FilterChip(
                      label: Text(member.name),
                      selected: selected,
                      onSelected: (value) {
                        setState(() {
                          if (value) {
                            _selectedParticipantIds.add(member.id);
                          } else {
                            _selectedParticipantIds.remove(member.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                if (perShare > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${strings.perPerson}: ${AppFormatters.formatAmount(perShare, currency)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
              ],
            ],

            if (!isGroupAdvance) ...[
              // Category
              Text(
                strings.categoryLabel,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categories.map((cat) {
                  return ChoiceChip(
                    label: Text(strings.categoryName(cat)),
                    selected: _category == cat,
                    onSelected: (_) => setState(() => _category = cat),
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
            ],

            // Date Picker
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              leading: const Icon(Icons.calendar_today_outlined),
              title: Text(strings.dateLabel),
              subtitle: Text(AppFormatters.formatDate(_expenseDate)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickDate,
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: _isSaving
                  ? null
                  : () => _save(
                      isPersonal: isPersonal,
                      availableMembers: selectableMembers,
                    ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(strings.save),
            ),
          ],
        ),
      ),
    );
  }
}

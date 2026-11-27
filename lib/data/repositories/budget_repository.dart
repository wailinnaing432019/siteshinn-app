import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../services/settlement_service.dart';
import '../models/account.dart';
import '../models/expense.dart';
import '../models/member.dart';
import '../models/settlement_cycle.dart';
import '../models/settlement_summary.dart';
import 'budget_data_source.dart';

class PendingSyncOp {
  final int id;
  final String uidScope;
  final String accountId;
  final String opType;
  final String entityId;

  const PendingSyncOp({
    required this.id,
    required this.uidScope,
    required this.accountId,
    required this.opType,
    required this.entityId,
  });
}

class CachedCloudAccountBundle {
  final Account account;
  final List<Member> members;
  final List<SettlementCycle> cycles;
  final List<Expense> expenses;
  final List<SettlementTransfer> transfers;

  const CachedCloudAccountBundle({
    required this.account,
    required this.members,
    required this.cycles,
    required this.expenses,
    required this.transfers,
  });
}

class BudgetRepository implements BudgetDataSource {
  final AppDatabase _dbHelper;
  static const Uuid _uuid = Uuid();

  BudgetRepository({AppDatabase? dbHelper})
      : _dbHelper = dbHelper ?? AppDatabase.instance;

  Future<Database> get _db => _dbHelper.database;

  Future<void> _recordPendingOpIfCached(
    DatabaseExecutor db, {
    required String accountId,
    required String opType,
    required String entityId,
  }) async {
    final rows = await db.query(
      'accounts',
      columns: ['cached_for_uid'],
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    if (rows.isEmpty) return;
    final uid = rows.first['cached_for_uid'] as String?;
    if (uid == null || uid.isEmpty) return;

    await db.insert('pending_sync_ops', {
      'uid_scope': uid,
      'account_id': accountId,
      'op_type': opType,
      'entity_id': entityId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // ---------------- Accounts ----------------

  @override
  Future<List<Account>> getAccounts() async {
    final db = await _db;
    final rows = await db.query('accounts', orderBy: 'created_at ASC');
    return rows.map(Account.fromMap).toList();
  }

  @override
  Future<Account> createAccount({
    required String name,
    required String currencyCode,
    required AccountType accountType,
    double openingBalance = 0,
    List<String> memberNames = const [],
    String? creatorMemberName,
  }) async {
    final db = await _db;
    final now = DateTime.now();
    final account = Account(
      id: _uuid.v4(),
      name: name.trim(),
      currencyCode: currencyCode,
      accountType: accountType,
      openingBalance: openingBalance,
      createdAt: now,
    );

    await db.transaction((txn) async {
      await txn.insert('accounts', account.toMap());

      if (accountType == AccountType.group) {
        for (var i = 0; i < memberNames.length; i++) {
          final trimmed = memberNames[i].trim();
          if (trimmed.isEmpty) continue;
          final member = Member(
            id: _uuid.v4(),
            accountId: account.id,
            name: trimmed,
            isActive: true,
            createdAt: now.add(Duration(milliseconds: i)),
          );
          await txn.insert('members', member.toMap());
        }
      }

      final initialCycle = SettlementCycle(
        id: _uuid.v4(),
        accountId: account.id,
        title: '',
        startDate: now,
        isSettled: false,
      );
      await txn.insert('cycles', initialCycle.toMap());
    });

    return account;
  }

  @override
  Future<void> updateAccount(Account account) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'accounts',
        account.toMap(),
        where: 'id = ?',
        whereArgs: [account.id],
      );
      await _recordPendingOpIfCached(
        txn,
        accountId: account.id,
        opType: 'account_update',
        entityId: account.id,
      );
    });
  }

  // ---------------- Members ----------------

  @override
  Future<List<Member>> getMembers(String accountId) async {
    final db = await _db;
    final rows = await db.query(
      'members',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'created_at ASC',
    );
    return rows.map(Member.fromMap).toList();
  }

  @override
  Future<Member> addMember({
    required String accountId,
    required String name,
  }) async {
    final db = await _db;
    final member = Member(
      id: _uuid.v4(),
      accountId: accountId,
      name: name.trim(),
      isActive: true,
      createdAt: DateTime.now(),
    );
    await db.transaction((txn) async {
      await txn.insert('members', member.toMap());
      await _recordPendingOpIfCached(
        txn,
        accountId: accountId,
        opType: 'member_upsert',
        entityId: member.id,
      );
    });
    return member;
  }

  @override
  Future<void> updateMember(Member member) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'members',
        member.toMap(),
        where: 'id = ?',
        whereArgs: [member.id],
      );
      await _recordPendingOpIfCached(
        txn,
        accountId: member.accountId,
        opType: 'member_upsert',
        entityId: member.id,
      );
    });
  }

  // ---------------- Cycles ----------------

  @override
  Future<SettlementCycle> getOrCreateOpenCycle(String accountId) async {
    final db = await _db;
    final rows = await db.query(
      'cycles',
      where: 'account_id = ? AND is_settled = 0',
      whereArgs: [accountId],
      orderBy: 'start_date DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return SettlementCycle.fromMap(rows.first);
    }

    final cycle = SettlementCycle(
      id: _uuid.v4(),
      accountId: accountId,
      title: '',
      startDate: DateTime.now(),
      isSettled: false,
    );
    await db.insert('cycles', cycle.toMap());
    return cycle;
  }

  @override
  Future<List<SettlementCycle>> getSettledCycles(String accountId) async {
    final db = await _db;
    final rows = await db.query(
      'cycles',
      where: 'account_id = ? AND is_settled = 1',
      whereArgs: [accountId],
      orderBy: 'end_date DESC, start_date DESC',
    );
    return rows.map(SettlementCycle.fromMap).toList();
  }

  @override
  Future<void> closeCycleAndStartNext({
    required SettlementCycle cycle,
    required String settledTitle,
    required List<SettlementTransfer> transfers,
  }) async {
    final db = await _db;
    final now = DateTime.now();

    await db.transaction((txn) async {
      await txn.update(
        'cycles',
        {
          'title': settledTitle.trim(),
          'end_date': now.toIso8601String(),
          'is_settled': 1,
        },
        where: 'id = ?',
        whereArgs: [cycle.id],
      );

      for (final transfer in transfers) {
        await txn.insert('settlement_transfers', transfer.toMap());
      }

      final nextCycle = SettlementCycle(
        id: _uuid.v4(),
        accountId: cycle.accountId,
        title: '',
        startDate: now,
        isSettled: false,
      );
      await txn.insert('cycles', nextCycle.toMap());
      await _recordPendingOpIfCached(
        txn,
        accountId: cycle.accountId,
        opType: 'cycle_close',
        entityId: '${cycle.id}|${nextCycle.id}',
      );
    });
  }

  @override
  Future<List<SettlementTransfer>> getTransfersForCycle({
    required String cycleId,
    required Map<String, Member> memberById,
  }) async {
    final db = await _db;
    final rows = await db.query(
      'settlement_transfers',
      where: 'cycle_id = ?',
      whereArgs: [cycleId],
    );
    return rows.map((row) {
      final fromId = row['from_member_id'] as String;
      final toId = row['to_member_id'] as String;
      final rawPaid = row['is_paid'];
      final isPaid =
          rawPaid is bool ? rawPaid : ((rawPaid as int? ?? 0) == 1);
      return SettlementTransfer(
        id: row['id'] as String,
        cycleId: row['cycle_id'] as String,
        fromMemberId: fromId,
        toMemberId: toId,
        fromMemberName: memberById[fromId]?.name ?? 'Unknown',
        toMemberName: memberById[toId]?.name ?? 'Unknown',
        amount: (row['amount'] as num).toDouble(),
        isPaid: isPaid,
        paidAt: row['paid_at'] != null
            ? DateTime.parse(row['paid_at'] as String)
            : null,
      );
    }).toList();
  }

  @override
  Future<void> markTransferPaid({
    required String transferId,
    required bool isPaid,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update(
        'settlement_transfers',
        {
          'is_paid': isPaid ? 1 : 0,
          'paid_at': isPaid ? DateTime.now().toIso8601String() : null,
        },
        where: 'id = ?',
        whereArgs: [transferId],
      );
      final rows = await txn.rawQuery(
        'SELECT c.account_id FROM settlement_transfers t '
        'INNER JOIN cycles c ON t.cycle_id = c.id '
        'WHERE t.id = ? LIMIT 1',
        [transferId],
      );
      if (rows.isNotEmpty) {
        final accountId = rows.first['account_id'] as String?;
        if (accountId != null) {
          await _recordPendingOpIfCached(
            txn,
            accountId: accountId,
            opType: 'transfer_paid',
            entityId: transferId,
          );
        }
      }
    });
  }

  // ---------------- Expenses & Transactions ----------------

  @override
  Future<List<Expense>> getExpensesForCycle(String cycleId) async {
    final db = await _db;
    final expenseRows = await db.query(
      'expenses',
      where: 'cycle_id = ?',
      whereArgs: [cycleId],
      orderBy: 'expense_date DESC, created_at DESC',
    );
    return _attachSplits(db, expenseRows);
  }

  @override
  Future<List<Expense>> getTransactionsForAccount(String accountId) async {
    final db = await _db;
    final expenseRows = await db.query(
      'expenses',
      where: 'account_id = ?',
      whereArgs: [accountId],
      orderBy: 'expense_date DESC, created_at DESC',
    );
    return _attachSplits(db, expenseRows);
  }

  Future<List<Expense>> _attachSplits(
    Database db,
    List<Map<String, dynamic>> expenseRows,
  ) async {
    if (expenseRows.isEmpty) return [];

    final expenseIds = expenseRows.map((r) => r['id'] as String).toList();
    final placeholders = List.filled(expenseIds.length, '?').join(',');
    final splitRows = await db.query(
      'expense_splits',
      where: 'expense_id IN ($placeholders)',
      whereArgs: expenseIds,
    );

    final splitsByExpense = <String, List<ExpenseSplit>>{};
    for (final row in splitRows) {
      final split = ExpenseSplit.fromMap(row);
      splitsByExpense.putIfAbsent(split.expenseId, () => []).add(split);
    }

    return expenseRows
        .map(
          (row) => Expense.fromMap(
            row,
            splits: splitsByExpense[row['id'] as String] ?? const [],
          ),
        )
        .toList();
  }

  @override
  Future<void> saveTransaction({
    String? existingExpenseId,
    required String accountId,
    required String cycleId,
    String? paidByMemberId,
    TransactionType txType = TransactionType.expense,
    required String title,
    required ExpenseCategory category,
    required double amount,
    required DateTime expenseDate,
    List<String> participantIds = const [],
    required String currencyCode,
  }) async {
    final db = await _db;
    final expenseId = existingExpenseId ?? _uuid.v4();
    final now = DateTime.now();

    final splits = (paidByMemberId != null && participantIds.isNotEmpty)
        ? SettlementService.buildEqualSplits(
            expenseId: expenseId,
            amount: amount,
            participantIds: participantIds,
            currencyCode: currencyCode,
          )
        : const <ExpenseSplit>[];

    final expense = Expense(
      id: expenseId,
      accountId: accountId,
      cycleId: cycleId,
      paidByMemberId: paidByMemberId,
      txType: txType,
      title: title.trim(),
      category: category,
      amount: amount,
      expenseDate: expenseDate,
      createdAt: now,
      splits: splits,
    );

    await db.transaction((txn) async {
      if (existingExpenseId != null) {
        await txn.update(
          'expenses',
          {
            'paid_by_member_id': expense.paidByMemberId,
            'tx_type': expense.txType.key,
            'title': expense.title,
            'category': expense.category.key,
            'amount': expense.amount,
            'expense_date': expense.expenseDate.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [existingExpenseId],
        );
        await txn.delete(
          'expense_splits',
          where: 'expense_id = ?',
          whereArgs: [existingExpenseId],
        );
      } else {
        await txn.insert('expenses', expense.toMap());
      }

      for (final split in splits) {
        await txn.insert('expense_splits', split.toMap());
      }
      await _recordPendingOpIfCached(
        txn,
        accountId: accountId,
        opType: 'expense_upsert',
        entityId: expenseId,
      );
    });
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    final db = await _db;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'expenses',
        columns: ['account_id'],
        where: 'id = ?',
        whereArgs: [expenseId],
        limit: 1,
      );
      await txn.delete('expenses', where: 'id = ?', whereArgs: [expenseId]);
      if (rows.isNotEmpty) {
        final accountId = rows.first['account_id'] as String?;
        if (accountId != null) {
          await _recordPendingOpIfCached(
            txn,
            accountId: accountId,
            opType: 'expense_delete',
            entityId: expenseId,
          );
        }
      }
    });
  }

  // ---------------- Cloud Mirror & Offline Pending Sync ----------------

  Future<List<Account>> getUnmigratedGuestAccounts() async {
    final db = await _db;
    final rows = await db.query(
      'accounts',
      where: 'cached_for_uid IS NULL',
      orderBy: 'created_at ASC',
    );
    return rows.map(Account.fromMap).toList();
  }

  Future<void> removeAccountsByIds(List<String> accountIds) async {
    if (accountIds.isEmpty) return;
    final db = await _db;
    final placeholders = List.filled(accountIds.length, '?').join(',');
    await db.delete(
      'accounts',
      where: 'id IN ($placeholders)',
      whereArgs: accountIds,
    );
  }

  Future<List<PendingSyncOp>> getPendingSyncOps(String uid) async {
    final db = await _db;
    final rows = await db.query(
      'pending_sync_ops',
      where: 'uid_scope = ?',
      whereArgs: [uid],
      orderBy: 'id ASC',
    );
    return rows
        .map(
          (r) => PendingSyncOp(
            id: r['id'] as int,
            uidScope: r['uid_scope'] as String,
            accountId: r['account_id'] as String,
            opType: r['op_type'] as String,
            entityId: r['entity_id'] as String,
          ),
        )
        .toList();
  }

  Future<void> deletePendingSyncOp(int opId) async {
    final db = await _db;
    await db.delete('pending_sync_ops', where: 'id = ?', whereArgs: [opId]);
  }

  Future<Account?> getAccountById(String accountId) async {
    final db = await _db;
    final rows = await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [accountId],
      limit: 1,
    );
    return rows.isEmpty ? null : Account.fromMap(rows.first);
  }

  Future<Member?> getMemberById(String memberId) async {
    final db = await _db;
    final rows = await db.query(
      'members',
      where: 'id = ?',
      whereArgs: [memberId],
      limit: 1,
    );
    return rows.isEmpty ? null : Member.fromMap(rows.first);
  }

  Future<SettlementCycle?> getCycleById(String cycleId) async {
    final db = await _db;
    final rows = await db.query(
      'cycles',
      where: 'id = ?',
      whereArgs: [cycleId],
      limit: 1,
    );
    return rows.isEmpty ? null : SettlementCycle.fromMap(rows.first);
  }

  Future<Expense?> getExpenseById(String expenseId) async {
    final db = await _db;
    final rows = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [expenseId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final attached = await _attachSplits(db, rows);
    return attached.firstOrNull;
  }

  Future<({bool isPaid, DateTime? paidAt})?> getTransferPaymentState(
    String transferId,
  ) async {
    final db = await _db;
    final rows = await db.query(
      'settlement_transfers',
      columns: ['is_paid', 'paid_at'],
      where: 'id = ?',
      whereArgs: [transferId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final rawPaid = rows.first['is_paid'];
    final isPaid = rawPaid is bool ? rawPaid : ((rawPaid as int? ?? 0) == 1);
    final rawAt = rows.first['paid_at'] as String?;
    return (
      isPaid: isPaid,
      paidAt: rawAt != null ? DateTime.tryParse(rawAt) : null,
    );
  }

  Future<void> clearCachedDataForUser(String uid) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete(
        'accounts',
        where: 'cached_for_uid = ?',
        whereArgs: [uid],
      );
      await txn.delete(
        'pending_sync_ops',
        where: 'uid_scope = ?',
        whereArgs: [uid],
      );
    });
  }

  Future<void> replaceCloudCacheForUser({
    required String uid,
    required List<CachedCloudAccountBundle> bundles,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final pendingRows = await txn.query(
        'pending_sync_ops',
        columns: ['account_id'],
        where: 'uid_scope = ?',
        whereArgs: [uid],
      );
      final dirtyAccountIds = pendingRows
          .map((r) => r['account_id'] as String)
          .toSet();

      if (dirtyAccountIds.isEmpty) {
        await txn.delete('accounts', where: 'cached_for_uid IS NOT NULL');
      } else {
        final placeholders = List.filled(dirtyAccountIds.length, '?').join(',');
        await txn.delete(
          'accounts',
          where: 'cached_for_uid IS NOT NULL AND id NOT IN ($placeholders)',
          whereArgs: dirtyAccountIds.toList(),
        );
      }

      for (final bundle in bundles) {
        if (dirtyAccountIds.contains(bundle.account.id)) continue;

        final accMap = bundle.account.toMap()..['cached_for_uid'] = uid;
        await txn.insert(
          'accounts',
          accMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (final m in bundle.members) {
          await txn.insert(
            'members',
            m.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final c in bundle.cycles) {
          await txn.insert(
            'cycles',
            c.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        for (final e in bundle.expenses) {
          await txn.insert(
            'expenses',
            e.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          for (final s in e.splits) {
            await txn.insert(
              'expense_splits',
              s.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
        for (final t in bundle.transfers) {
          await txn.insert(
            'settlement_transfers',
            t.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });
  }
}

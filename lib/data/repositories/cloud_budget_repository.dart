import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../services/auth_service.dart';
import '../../services/settlement_service.dart';
import '../models/account.dart';
import '../models/expense.dart';
import '../models/member.dart';
import '../models/settlement_cycle.dart';
import '../models/settlement_summary.dart';
import 'budget_data_source.dart';
import 'budget_repository.dart';

class CloudBudgetRepository implements BudgetDataSource {
  static const Uuid _uuid = Uuid();
  static const String _inviteChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final Map<String, String> _cycleAccountIds = {};
  final Map<String, String> _expenseAccountIds = {};
  final Map<String, String> _transferAccountIds = {};

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  String get _uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('User must be signed in for cloud operations.');
    }
    return user.uid;
  }

  static String generateInviteCode() {
    final rand = Random.secure();
    return List.generate(
      6,
      (_) => _inviteChars[rand.nextInt(_inviteChars.length)],
    ).join();
  }

  static String migratedIdForUser(String userId, String localId) =>
      _uuid.v5(userId, localId);

  DocumentReference<Map<String, dynamic>> _accountDoc(String accountId) =>
      _db.collection('accounts').doc(accountId);

  CollectionReference<Map<String, dynamic>> _membersCol(String accountId) =>
      _accountDoc(accountId).collection('members');

  CollectionReference<Map<String, dynamic>> _cyclesCol(String accountId) =>
      _accountDoc(accountId).collection('cycles');

  CollectionReference<Map<String, dynamic>> _expensesCol(String accountId) =>
      _accountDoc(accountId).collection('expenses');

  CollectionReference<Map<String, dynamic>> _transfersCol(String accountId) =>
      _accountDoc(accountId).collection('transfers');

  CollectionReference<Map<String, dynamic>> get _invitesCol =>
      _db.collection('invites');

  Future<String> _generateUniqueInviteCode() async {
    for (var i = 0; i < 6; i++) {
      final code = generateInviteCode();
      final doc = await _invitesCol.doc(code).get();
      if (!doc.exists) return code;
    }
    return generateInviteCode();
  }

  Future<void> _syncInviteDoc(Account account) async {
    final code = account.inviteCode?.trim().toUpperCase();
    if (!account.isGroup || code == null || code.isEmpty) return;

    final members = await getMembers(account.id);
    final unclaimed = members
        .where((m) => m.isActive && m.userId == null)
        .map((m) => {'id': m.id, 'name': m.name})
        .toList();

    await _invitesCol.doc(code).set({
      'account_id': account.id,
      'owner_id': account.ownerId ?? _uid,
      'name': account.name,
      'currency_code': account.currencyCode,
      'unclaimed_members': unclaimed,
      'created_at': account.createdAt.toUtc().toIso8601String(),
    });
  }

  Future<void> _syncInviteForAccountId(String accountId) async {
    final snap = await _accountDoc(accountId).get();
    final data = snap.data();
    if (!snap.exists || data == null) return;
    final account = Account.fromMap({...data, 'id': snap.id});
    await _syncInviteDoc(account);
  }

  Future<String?> _resolveAccountIdForCycle(String cycleId) async {
    final cached = _cycleAccountIds[cycleId];
    if (cached != null) return cached;
    final accounts = await getAccounts();
    for (final acc in accounts) {
      final doc = await _cyclesCol(acc.id).doc(cycleId).get();
      if (doc.exists) {
        _cycleAccountIds[cycleId] = acc.id;
        return acc.id;
      }
    }
    return null;
  }

  Future<String?> _resolveAccountIdForExpense(String expenseId) async {
    final cached = _expenseAccountIds[expenseId];
    if (cached != null) return cached;
    final accounts = await getAccounts();
    for (final acc in accounts) {
      final doc = await _expensesCol(acc.id).doc(expenseId).get();
      if (doc.exists) {
        _expenseAccountIds[expenseId] = acc.id;
        return acc.id;
      }
    }
    return null;
  }

  Future<String?> _resolveAccountIdForTransfer(String transferId) async {
    final cached = _transferAccountIds[transferId];
    if (cached != null) return cached;
    final accounts = await getAccounts();
    for (final acc in accounts) {
      final doc = await _transfersCol(acc.id).doc(transferId).get();
      if (doc.exists) {
        _transferAccountIds[transferId] = acc.id;
        return acc.id;
      }
    }
    return null;
  }

  @override
  Future<List<Account>> getAccounts() async {
    final uid = _uid;
    final snap = await _db
        .collection('accounts')
        .where('member_user_ids', arrayContains: uid)
        .get();
    final accounts = snap.docs
        .map((doc) => Account.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
    accounts.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return accounts;
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
    final uid = _uid;
    final now = DateTime.now().toUtc();
    final inviteCode = accountType == AccountType.group
        ? await _generateUniqueInviteCode()
        : null;

    final account = Account(
      id: _uuid.v4(),
      ownerId: uid,
      name: name.trim(),
      currencyCode: currencyCode,
      accountType: accountType,
      openingBalance: openingBalance,
      inviteCode: inviteCode,
      createdAt: now,
    );

    // Commit parent account document first so subcollection security rules
    // evaluating `get(accounts/{id})` see the owner/member immediately.
    await _accountDoc(account.id).set({
      'id': account.id,
      'owner_id': uid,
      'member_user_ids': [uid],
      'name': account.name,
      'currency_code': account.currencyCode,
      'account_type': account.accountType.key,
      'opening_balance': account.openingBalance,
      'invite_code': account.inviteCode,
      'created_at': account.createdAt.toIso8601String(),
    });

    final batch = _db.batch();
    final unclaimedForInvite = <Map<String, dynamic>>[];

    if (accountType == AccountType.group) {
      final cleanNames =
          memberNames.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      var linkedCreator = false;
      final createdMembers = <Member>[];

      for (var i = 0; i < cleanNames.length; i++) {
        final memberName = cleanNames[i];
        final shouldLink = !linkedCreator &&
            ((creatorMemberName != null &&
                    memberName.toLowerCase() ==
                        creatorMemberName.trim().toLowerCase()) ||
                (creatorMemberName == null && i == 0));
        if (shouldLink) linkedCreator = true;

        createdMembers.add(
          Member(
            id: _uuid.v4(),
            accountId: account.id,
            userId: shouldLink ? uid : null,
            name: memberName,
            isActive: true,
            createdAt: now.add(Duration(milliseconds: i)),
          ),
        );
      }

      if (!linkedCreator && createdMembers.isNotEmpty) {
        createdMembers[0] = createdMembers[0].copyWith(userId: uid);
      }

      for (final m in createdMembers) {
        batch.set(_membersCol(account.id).doc(m.id), {
          'id': m.id,
          'account_id': m.accountId,
          'user_id': m.userId,
          'name': m.name,
          'is_active': m.isActive,
          'created_at': m.createdAt.toIso8601String(),
        });
        if (m.userId == null) {
          unclaimedForInvite.add({'id': m.id, 'name': m.name});
        }
      }

      if (inviteCode != null) {
        batch.set(_invitesCol.doc(inviteCode), {
          'account_id': account.id,
          'owner_id': uid,
          'name': account.name,
          'currency_code': account.currencyCode,
          'unclaimed_members': unclaimedForInvite,
          'created_at': account.createdAt.toIso8601String(),
        });
      }
    }

    final initialCycleId = _uuid.v4();
    batch.set(_cyclesCol(account.id).doc(initialCycleId), {
      'id': initialCycleId,
      'account_id': account.id,
      'title': '',
      'start_date': now.toIso8601String(),
      'end_date': null,
      'is_settled': false,
    });
    _cycleAccountIds[initialCycleId] = account.id;

    await batch.commit();
    return account;
  }

  @override
  Future<void> updateAccount(Account account) async {
    await _accountDoc(account.id).update({
      'name': account.name,
      'currency_code': account.currencyCode,
      'opening_balance': account.openingBalance,
      if (account.inviteCode != null) 'invite_code': account.inviteCode,
    });
    await _syncInviteDoc(account);
  }

  Future<GroupInvitePreview?> previewGroupByInviteCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;

    final doc = await _invitesCol.doc(normalized).get();
    final data = doc.data();
    if (!doc.exists || data == null) return null;

    final rawMembers = data['unclaimed_members'] as List<dynamic>? ?? const [];
    final unclaimed = rawMembers.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return (id: m['id'] as String, name: m['name'] as String);
    }).toList();

    return GroupInvitePreview(
      accountId: data['account_id'] as String,
      name: data['name'] as String,
      currencyCode: data['currency_code'] as String? ?? 'MMK',
      unclaimedMembers: unclaimed,
    );
  }

  Future<String> joinGroupByInviteCode({
    required String code,
    String? memberId,
    String? displayName,
  }) async {
    final uid = _uid;
    final normalized = code.trim().toUpperCase();
    final inviteDoc = await _invitesCol.doc(normalized).get();
    final inviteData = inviteDoc.data();
    if (!inviteDoc.exists || inviteData == null) {
      throw StateError('Invalid invite code');
    }

    final accountId = inviteData['account_id'] as String;

    // Step 1: Add self to account.member_user_ids (permitted by isSelfJoiningAccount rule).
    await _accountDoc(accountId).update({
      'member_user_ids': FieldValue.arrayUnion([uid]),
    });

    // Step 2: Claim an unclaimed member slot or create a new member entry.
    final members = await getMembers(accountId);
    final alreadyMember = members.any((m) => m.userId == uid);

    if (!alreadyMember) {
      var claimed = false;
      if (memberId != null) {
        claimed = await _db.runTransaction((txn) async {
          final memberRef = _membersCol(accountId).doc(memberId);
          final snap = await txn.get(memberRef);
          final data = snap.data();
          if (!snap.exists || data == null) return false;
          if (data['user_id'] != null) return false;
          txn.update(memberRef, {'user_id': uid});
          return true;
        });
      }

      if (!claimed) {
        final fallback = AuthService.instance.currentDisplayName ?? 'Member';
        final chosenName =
            (displayName != null && displayName.trim().isNotEmpty)
                ? displayName.trim()
                : fallback;
        final newMemberId = _uuid.v4();
        await _membersCol(accountId).doc(newMemberId).set({
          'id': newMemberId,
          'account_id': accountId,
          'user_id': uid,
          'name': chosenName,
          'is_active': true,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
    }

    await _syncInviteForAccountId(accountId);
    return accountId;
  }

  @override
  Future<List<Member>> getMembers(String accountId) async {
    final snap = await _membersCol(accountId).get();
    final members = snap.docs
        .map((doc) => Member.fromMap({...doc.data(), 'id': doc.id}))
        .toList();
    members.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return members;
  }

  @override
  Future<Member> addMember({
    required String accountId,
    required String name,
  }) async {
    final member = Member(
      id: _uuid.v4(),
      accountId: accountId,
      name: name.trim(),
      isActive: true,
      createdAt: DateTime.now().toUtc(),
    );
    await _membersCol(accountId).doc(member.id).set({
      'id': member.id,
      'account_id': member.accountId,
      'user_id': member.userId,
      'name': member.name,
      'is_active': member.isActive,
      'created_at': member.createdAt.toIso8601String(),
    });
    await _syncInviteForAccountId(accountId);
    return member;
  }

  @override
  Future<void> updateMember(Member member) async {
    await _membersCol(member.accountId).doc(member.id).update({
      'name': member.name,
      'is_active': member.isActive,
      'user_id': member.userId,
    });
    await _syncInviteForAccountId(member.accountId);
  }

  @override
  Future<SettlementCycle> getOrCreateOpenCycle(String accountId) async {
    final snap = await _cyclesCol(accountId).get();
    final cycles = snap.docs.map((doc) {
      _cycleAccountIds[doc.id] = accountId;
      return SettlementCycle.fromMap({...doc.data(), 'id': doc.id});
    }).toList();

    final openCycles = cycles.where((c) => !c.isSettled).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    if (openCycles.isNotEmpty) {
      return openCycles.first;
    }

    final cycle = SettlementCycle(
      id: _uuid.v4(),
      accountId: accountId,
      title: '',
      startDate: DateTime.now().toUtc(),
      isSettled: false,
    );
    await _cyclesCol(accountId).doc(cycle.id).set({
      'id': cycle.id,
      'account_id': cycle.accountId,
      'title': cycle.title,
      'start_date': cycle.startDate.toIso8601String(),
      'end_date': null,
      'is_settled': false,
    });
    _cycleAccountIds[cycle.id] = accountId;
    return cycle;
  }

  @override
  Future<List<SettlementCycle>> getSettledCycles(String accountId) async {
    final snap = await _cyclesCol(accountId).get();
    final settled = <SettlementCycle>[];
    for (final doc in snap.docs) {
      _cycleAccountIds[doc.id] = accountId;
      final c = SettlementCycle.fromMap({...doc.data(), 'id': doc.id});
      if (c.isSettled) settled.add(c);
    }
    settled.sort((a, b) {
      final aEnd = a.endDate ?? a.startDate;
      final bEnd = b.endDate ?? b.startDate;
      return bEnd.compareTo(aEnd);
    });
    return settled;
  }

  @override
  Future<void> closeCycleAndStartNext({
    required SettlementCycle cycle,
    required String settledTitle,
    required List<SettlementTransfer> transfers,
  }) async {
    final now = DateTime.now().toUtc();
    final batch = _db.batch();

    batch.update(_cyclesCol(cycle.accountId).doc(cycle.id), {
      'title': settledTitle.trim(),
      'end_date': now.toIso8601String(),
      'is_settled': true,
    });

    for (final t in transfers) {
      _transferAccountIds[t.id] = cycle.accountId;
      batch.set(_transfersCol(cycle.accountId).doc(t.id), {
        'id': t.id,
        'cycle_id': t.cycleId,
        'from_member_id': t.fromMemberId,
        'to_member_id': t.toMemberId,
        'amount': t.amount,
        'is_paid': t.isPaid,
        'paid_at': t.paidAt?.toIso8601String(),
      });
    }

    final nextCycleId = _uuid.v4();
    _cycleAccountIds[nextCycleId] = cycle.accountId;
    batch.set(_cyclesCol(cycle.accountId).doc(nextCycleId), {
      'id': nextCycleId,
      'account_id': cycle.accountId,
      'title': '',
      'start_date': now.toIso8601String(),
      'end_date': null,
      'is_settled': false,
    });

    await batch.commit();
  }

  SettlementTransfer _mapTransferDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String accountId,
    Map<String, Member> memberById,
  ) {
    _transferAccountIds[doc.id] = accountId;
    final row = doc.data();
    final fromId = row['from_member_id'] as String;
    final toId = row['to_member_id'] as String;
    final rawPaid = row['is_paid'];
    final isPaid = rawPaid is bool ? rawPaid : (rawPaid == 1);
    return SettlementTransfer(
      id: doc.id,
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
  }

  @override
  Future<List<SettlementTransfer>> getTransfersForCycle({
    required String cycleId,
    required Map<String, Member> memberById,
  }) async {
    final accountId = await _resolveAccountIdForCycle(cycleId);
    if (accountId == null) return const [];

    final snap = await _transfersCol(accountId)
        .where('cycle_id', isEqualTo: cycleId)
        .get();

    return snap.docs
        .map((doc) => _mapTransferDoc(doc, accountId, memberById))
        .toList();
  }

  @override
  Future<void> markTransferPaid({
    required String transferId,
    required bool isPaid,
  }) async {
    final accountId = await _resolveAccountIdForTransfer(transferId);
    if (accountId == null) return;
    await _transfersCol(accountId).doc(transferId).update({
      'is_paid': isPaid,
      'paid_at': isPaid ? DateTime.now().toUtc().toIso8601String() : null,
    });
  }

  @override
  Future<List<Expense>> getExpensesForCycle(String cycleId) async {
    final accountId = await _resolveAccountIdForCycle(cycleId);
    if (accountId == null) return const [];

    final snap = await _expensesCol(accountId)
        .where('cycle_id', isEqualTo: cycleId)
        .get();
    final expenses = _mapExpenses(accountId, snap.docs);
    expenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    return expenses;
  }

  @override
  Future<List<Expense>> getTransactionsForAccount(String accountId) async {
    final snap = await _expensesCol(accountId).get();
    final expenses = _mapExpenses(accountId, snap.docs);
    expenses.sort((a, b) => b.expenseDate.compareTo(a.expenseDate));
    return expenses;
  }

  List<Expense> _mapExpenses(
    String accountId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((doc) {
      _expenseAccountIds[doc.id] = accountId;
      final row = doc.data();
      final rawSplits = row['splits'] as List<dynamic>? ?? const [];
      final splits = rawSplits
          .map(
            (s) => ExpenseSplit.fromMap(Map<String, dynamic>.from(s as Map)),
          )
          .toList();
      return Expense.fromMap({...row, 'id': doc.id}, splits: splits);
    }).toList();
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
    final uid = _uid;
    final expenseId = existingExpenseId ?? _uuid.v4();
    final now = DateTime.now().toUtc();
    _expenseAccountIds[expenseId] = accountId;
    _cycleAccountIds[cycleId] = accountId;

    final splits = (paidByMemberId != null && participantIds.isNotEmpty)
        ? SettlementService.buildEqualSplits(
            expenseId: expenseId,
            amount: amount,
            participantIds: participantIds,
            currencyCode: currencyCode,
          )
        : const <ExpenseSplit>[];

    final splitMaps = splits.map((s) => s.toMap()).toList();

    if (existingExpenseId != null) {
      await _expensesCol(accountId).doc(existingExpenseId).update({
        'paid_by_member_id': paidByMemberId,
        'tx_type': txType.key,
        'title': title.trim(),
        'category': category.key,
        'amount': amount,
        'expense_date': expenseDate.toUtc().toIso8601String(),
        'splits': splitMaps,
      });
    } else {
      await _expensesCol(accountId).doc(expenseId).set({
        'id': expenseId,
        'account_id': accountId,
        'cycle_id': cycleId,
        'paid_by_member_id': paidByMemberId,
        'created_by_user_id': uid,
        'tx_type': txType.key,
        'title': title.trim(),
        'category': category.key,
        'amount': amount,
        'expense_date': expenseDate.toUtc().toIso8601String(),
        'created_at': now.toIso8601String(),
        'splits': splitMaps,
      });
    }
  }

  @override
  Future<void> deleteExpense(String expenseId) async {
    final accountId = await _resolveAccountIdForExpense(expenseId);
    if (accountId == null) return;
    await _expensesCol(accountId).doc(expenseId).delete();
  }

  /// Uploads unmigrated local SQLite accounts, members, cycles, expenses,
  /// splits, and settlement transfers into Firebase Cloud Firestore.
  ///
  /// Local IDs are deterministically remapped per user (`UUIDv5(uid, localId)`).
  Future<int> migrateLocalToCloud(BudgetRepository localRepo) async {
    final mapping = await migrateLocalToCloudWithMapping(localRepo);
    return mapping.length;
  }

  /// Same as [migrateLocalToCloud], returning `{localAccountId: cloudAccountId}`
  /// and cleaning up uploaded guest rows so SQLite stays duplicate-free.
  Future<Map<String, String>> migrateLocalToCloudWithMapping(
    BudgetRepository localRepo,
  ) async {
    final uid = _uid;
    final localAccounts = await localRepo.getUnmigratedGuestAccounts();
    if (localAccounts.isEmpty) return const {};

    final existingCloudIds = (await getAccounts()).map((a) => a.id).toSet();
    final mappedAccounts = <String, String>{};
    final migratedLocalIds = <String>[];

    for (final account in localAccounts) {
      final cloudAccountId = migratedIdForUser(uid, account.id);
      if (existingCloudIds.contains(account.id)) {
        mappedAccounts[account.id] = account.id;
        migratedLocalIds.add(account.id);
        continue;
      }
      if (existingCloudIds.contains(cloudAccountId)) {
        mappedAccounts[account.id] = cloudAccountId;
        migratedLocalIds.add(account.id);
        continue;
      }

      final inviteCode =
          account.isGroup ? await _generateUniqueInviteCode() : null;

      // Write parent account doc first so subcollection rules pass `get()`.
      await _accountDoc(cloudAccountId).set({
        'id': cloudAccountId,
        'owner_id': uid,
        'member_user_ids': [uid],
        'name': account.name,
        'currency_code': account.currencyCode,
        'account_type': account.accountType.key,
        'opening_balance': account.openingBalance,
        'invite_code': inviteCode,
        'created_at': account.createdAt.toUtc().toIso8601String(),
      });

      final ops = <void Function(WriteBatch)>[];

      final localMembers = await localRepo.getMembers(account.id);
      final unclaimedForInvite = <Map<String, dynamic>>[];
      var linkedCurrentUser = localMembers.any((m) => m.userId == uid);

      for (final m in localMembers) {
        final cloudMemberId = migratedIdForUser(uid, m.id);
        final shouldLink = !linkedCurrentUser && m.isActive;
        if (shouldLink) linkedCurrentUser = true;
        final assignedUid = shouldLink ? uid : m.userId;

        ops.add((batch) {
          batch.set(_membersCol(cloudAccountId).doc(cloudMemberId), {
            'id': cloudMemberId,
            'account_id': cloudAccountId,
            'user_id': assignedUid,
            'name': m.name,
            'is_active': m.isActive,
            'created_at': m.createdAt.toUtc().toIso8601String(),
          });
        });

        if (m.isActive && assignedUid == null) {
          unclaimedForInvite.add({'id': cloudMemberId, 'name': m.name});
        }
      }

      if (inviteCode != null) {
        ops.add((batch) {
          batch.set(_invitesCol.doc(inviteCode), {
            'account_id': cloudAccountId,
            'owner_id': uid,
            'name': account.name,
            'currency_code': account.currencyCode,
            'unclaimed_members': unclaimedForInvite,
            'created_at': account.createdAt.toUtc().toIso8601String(),
          });
        });
      }

      final openCycle = await localRepo.getOrCreateOpenCycle(account.id);
      final settledCycles = await localRepo.getSettledCycles(account.id);
      final allCycles = [openCycle, ...settledCycles];
      final memberById = {for (final m in localMembers) m.id: m};

      for (final c in allCycles) {
        final cloudCycleId = migratedIdForUser(uid, c.id);
        _cycleAccountIds[cloudCycleId] = cloudAccountId;
        ops.add((batch) {
          batch.set(_cyclesCol(cloudAccountId).doc(cloudCycleId), {
            'id': cloudCycleId,
            'account_id': cloudAccountId,
            'title': c.title,
            'start_date': c.startDate.toUtc().toIso8601String(),
            'end_date': c.endDate?.toUtc().toIso8601String(),
            'is_settled': c.isSettled,
          });
        });

        final expenses = await localRepo.getExpensesForCycle(c.id);
        for (final e in expenses) {
          final cloudExpenseId = migratedIdForUser(uid, e.id);
          _expenseAccountIds[cloudExpenseId] = cloudAccountId;
          final mappedSplits = e.splits
              .map(
                (s) => {
                  'id': migratedIdForUser(uid, s.id),
                  'expense_id': cloudExpenseId,
                  'member_id': migratedIdForUser(uid, s.memberId),
                  'share_amount': s.shareAmount,
                },
              )
              .toList();

          ops.add((batch) {
            batch.set(_expensesCol(cloudAccountId).doc(cloudExpenseId), {
              'id': cloudExpenseId,
              'account_id': cloudAccountId,
              'cycle_id': cloudCycleId,
              'paid_by_member_id': e.paidByMemberId == null
                  ? null
                  : migratedIdForUser(uid, e.paidByMemberId!),
              'created_by_user_id': uid,
              'tx_type': e.txType.key,
              'title': e.title,
              'category': e.category.key,
              'amount': e.amount,
              'expense_date': e.expenseDate.toUtc().toIso8601String(),
              'created_at': e.createdAt.toUtc().toIso8601String(),
              'splits': mappedSplits,
            });
          });
        }

        if (c.isSettled) {
          final transfers = await localRepo.getTransfersForCycle(
            cycleId: c.id,
            memberById: memberById,
          );
          for (final t in transfers) {
            final cloudTransferId = migratedIdForUser(uid, t.id);
            _transferAccountIds[cloudTransferId] = cloudAccountId;
            ops.add((batch) {
              batch.set(_transfersCol(cloudAccountId).doc(cloudTransferId), {
                'id': cloudTransferId,
                'cycle_id': cloudCycleId,
                'from_member_id': migratedIdForUser(uid, t.fromMemberId),
                'to_member_id': migratedIdForUser(uid, t.toMemberId),
                'amount': t.amount,
                'is_paid': t.isPaid,
                'paid_at': t.paidAt?.toIso8601String(),
              });
            });
          }
        }
      }

      // Commit in Firestore-safe batches (max 500 writes per batch).
      for (var i = 0; i < ops.length; i += 400) {
        final batch = _db.batch();
        final end = (i + 400 < ops.length) ? i + 400 : ops.length;
        for (var j = i; j < end; j++) {
          ops[j](batch);
        }
        await batch.commit();
      }

      mappedAccounts[account.id] = cloudAccountId;
      migratedLocalIds.add(account.id);
    }

    await localRepo.removeAccountsByIds(migratedLocalIds);
    return mappedAccounts;
  }

  /// Replays offline edits made inside cached Cloud accounts for [uid] back to Firestore.
  Future<void> syncPendingOpsToCloud(
    String uid,
    BudgetRepository localRepo,
  ) async {
    final ops = await localRepo.getPendingSyncOps(uid);
    if (ops.isEmpty) return;

    for (final op in ops) {
      switch (op.opType) {
        case 'account_update':
          final acc = await localRepo.getAccountById(op.accountId);
          if (acc != null) {
            await updateAccount(acc);
          }
        case 'member_upsert':
          final member = await localRepo.getMemberById(op.entityId);
          if (member != null) {
            await _membersCol(op.accountId).doc(member.id).set({
              'id': member.id,
              'account_id': op.accountId,
              'user_id': member.userId,
              'name': member.name,
              'is_active': member.isActive,
              'created_at': member.createdAt.toUtc().toIso8601String(),
            }, SetOptions(merge: true));
            await _syncInviteForAccountId(op.accountId);
          }
        case 'expense_upsert':
          final expense = await localRepo.getExpenseById(op.entityId);
          if (expense != null) {
            _expenseAccountIds[expense.id] = op.accountId;
            await _expensesCol(op.accountId).doc(expense.id).set({
              'id': expense.id,
              'account_id': op.accountId,
              'cycle_id': expense.cycleId,
              'paid_by_member_id': expense.paidByMemberId,
              'created_by_user_id': expense.createdByUserId ?? uid,
              'tx_type': expense.txType.key,
              'title': expense.title,
              'category': expense.category.key,
              'amount': expense.amount,
              'expense_date': expense.expenseDate.toUtc().toIso8601String(),
              'created_at': expense.createdAt.toUtc().toIso8601String(),
              'splits': expense.splits.map((s) => s.toMap()).toList(),
            });
          }
        case 'expense_delete':
          await _expensesCol(op.accountId).doc(op.entityId).delete();
        case 'cycle_close':
          final parts = op.entityId.split('|');
          if (parts.length == 2) {
            final closed = await localRepo.getCycleById(parts[0]);
            final next = await localRepo.getCycleById(parts[1]);
            final members = await localRepo.getMembers(op.accountId);
            final memberById = {for (final m in members) m.id: m};
            final transfers = await localRepo.getTransfersForCycle(
              cycleId: parts[0],
              memberById: memberById,
            );
            if (closed != null && next != null) {
              final batch = _db.batch();
              batch.set(_cyclesCol(op.accountId).doc(closed.id), {
                'id': closed.id,
                'account_id': op.accountId,
                'title': closed.title,
                'start_date': closed.startDate.toUtc().toIso8601String(),
                'end_date': closed.endDate?.toUtc().toIso8601String(),
                'is_settled': true,
              });
              for (final t in transfers) {
                batch.set(_transfersCol(op.accountId).doc(t.id), {
                  'id': t.id,
                  'cycle_id': t.cycleId,
                  'from_member_id': t.fromMemberId,
                  'to_member_id': t.toMemberId,
                  'amount': t.amount,
                  'is_paid': t.isPaid,
                  'paid_at': t.paidAt?.toUtc().toIso8601String(),
                });
              }
              batch.set(_cyclesCol(op.accountId).doc(next.id), {
                'id': next.id,
                'account_id': op.accountId,
                'title': next.title,
                'start_date': next.startDate.toUtc().toIso8601String(),
                'end_date': null,
                'is_settled': false,
              });
              await batch.commit();
            }
          }
        case 'transfer_paid':
          final state = await localRepo.getTransferPaymentState(op.entityId);
          if (state != null) {
            await _transfersCol(op.accountId).doc(op.entityId).update({
              'is_paid': state.isPaid,
              'paid_at': state.paidAt?.toUtc().toIso8601String(),
            });
          }
      }
      await localRepo.deletePendingSyncOp(op.id);
    }
  }

  /// Mirrors the current signed-in user's Cloud accounts into local SQLite so
  /// offline fallback and post-logout offline access retain all data cleanly.
  Future<void> mirrorToLocal(BudgetRepository localRepo) async {
    final uid = _uid;
    final accounts = await getAccounts();
    final bundles = <CachedCloudAccountBundle>[];

    for (final account in accounts) {
      final members = await getMembers(account.id);
      final memberById = {for (final m in members) m.id: m};
      final cyclesSnap = await _cyclesCol(account.id).get();
      final cycles = cyclesSnap.docs.map((doc) {
        _cycleAccountIds[doc.id] = account.id;
        return SettlementCycle.fromMap({...doc.data(), 'id': doc.id});
      }).toList();

      final expensesSnap = await _expensesCol(account.id).get();
      final expenses = _mapExpenses(account.id, expensesSnap.docs);

      final transfersSnap = await _transfersCol(account.id).get();
      final transfers = transfersSnap.docs
          .map((doc) => _mapTransferDoc(doc, account.id, memberById))
          .toList();

      bundles.add(
        CachedCloudAccountBundle(
          account: account,
          members: members,
          cycles: cycles,
          expenses: expenses,
          transfers: transfers,
        ),
      );
    }

    await localRepo.replaceCloudCacheForUser(uid: uid, bundles: bundles);
  }
}

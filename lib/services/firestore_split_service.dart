import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/splitwise_models.dart';
import 'auth_service.dart';
import 'splitwise_storage_service.dart';

class FirestoreSplitService {
  static final FirestoreSplitService _instance = FirestoreSplitService._internal();
  factory FirestoreSplitService() => _instance;
  FirestoreSplitService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // ─── Group CRUD ─────────────────────────────────────────────────────────────

  /// Create a new Split Group in Firestore and sync locally
  Future<void> createGroup(SplitwiseGroupModel group) async {
    try {
      final currentUser = AuthService().currentUser;
      final createdBy = currentUser?.uid ?? '';
      final userEmail = currentUser?.email ?? '';
      final updatedGroup = group.copyWith(
        createdBy: createdBy,
        memberUids: currentUser != null ? [currentUser.uid] : [],
        memberEmails: userEmail.isNotEmpty ? [userEmail] : [],
        inviteCode: group.inviteCode.isNotEmpty
            ? group.inviteCode
            : '${group.name.replaceAll(' ', '').toUpperCase().substring(0, group.name.length >= 3 ? 3 : group.name.length)}-${(1000 + (group.id.hashCode % 8999).abs())}',
      );

      final docRef = _firestore.collection('splitGroups').doc(group.id);
      await docRef.set(updatedGroup.toJson());

      // Create initial activity log
      await logActivity(
        groupId: group.id,
        type: 'MEMBER_JOINED',
        actorId: createdBy,
        actorName: currentUser?.displayName ?? 'You',
        title: 'Group Created',
        body: '${currentUser?.displayName ?? 'A user'} created ${group.name}',
      );

      // Save locally
      await SplitwiseStorageService.addGroup(updatedGroup);
    } catch (e) {
      debugPrint('Error creating group in Firestore: $e');
      // Fallback local save
      await SplitwiseStorageService.addGroup(group);
    }
  }

  /// Join an existing Split group using a 6-character Invite Code (e.g. GOA-8492)
  Future<bool> joinGroupWithInviteCode(String inviteCode) async {
    final cleanCode = inviteCode.trim().toUpperCase();
    if (cleanCode.isEmpty) return false;

    try {
      final currentUser = AuthService().currentUser;
      if (currentUser == null) return false;

      final query = await _firestore
          .collection('splitGroups')
          .where('inviteCode', isEqualTo: cleanCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return false;

      final doc = query.docs.first;
      final group = SplitwiseGroupModel.fromJson(doc.data());

      final memberUids = List<String>.from(group.memberUids);
      final memberNames = List<String>.from(group.members);
      final memberEmails = List<String>.from(group.memberEmails);

      final userName = currentUser.displayName ?? 'New Member';
      final userEmail = currentUser.email ?? '';

      bool changed = false;

      if (!memberUids.contains(currentUser.uid)) {
        memberUids.add(currentUser.uid);
        changed = true;
      }
      if (!memberNames.contains(userName)) {
        memberNames.add(userName);
        changed = true;
      }
      if (userEmail.isNotEmpty && !memberEmails.contains(userEmail)) {
        memberEmails.add(userEmail);
        changed = true;
      }

      if (changed) {
        await doc.reference.update({
          'memberUids': memberUids,
          'members': memberNames,
          'memberEmails': memberEmails,
        });

        await logActivity(
          groupId: group.id,
          type: 'MEMBER_JOINED',
          actorId: currentUser.uid,
          actorName: userName,
          title: '$userName joined the group',
          body: '$userName joined ${group.name} using invite code',
        );

        final updatedGroup = group.copyWith(
          members: memberNames,
          memberUids: memberUids,
          memberEmails: memberEmails,
        );
        await SplitwiseStorageService.addGroup(updatedGroup);
      }

      return true;
    } catch (e) {
      debugPrint('Error joining group with code: $e');
      return false;
    }
  }

  /// Real-time stream of all Split Groups the user belongs to
  Stream<List<SplitwiseGroupModel>> streamUserGroups() {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) {
      return Stream.fromFuture(SplitwiseStorageService.loadGroups());
    }

    return _firestore
        .collection('splitGroups')
        .where('memberIds', arrayContains: currentUser.displayName ?? 'You')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SplitwiseGroupModel.fromJson(doc.data()))
          .toList();
    });
  }

  // ─── Expense CRUD ────────────────────────────────────────────────────────────

  /// Add Expense to Firestore & trigger Activity Log
  Future<void> addExpense(SplitwiseExpenseModel expense, String actorName) async {
    try {
      final currentUser = AuthService().currentUser;
      final actorId = currentUser?.uid ?? 'local';

      final expenseRef = _firestore
          .collection('splitGroups')
          .doc(expense.splitwiseGroupId)
          .collection('expenses')
          .doc(expense.id);

      final expData = expense.toJson();
      expData['createdBy'] = actorId;
      expData['createdAt'] = FieldValue.serverTimestamp();
      expData['updatedAt'] = FieldValue.serverTimestamp();

      await expenseRef.set(expData);

      // Log activity in Firestore
      await logActivity(
        groupId: expense.splitwiseGroupId,
        type: 'EXPENSE_CREATED',
        actorId: actorId,
        actorName: actorName,
        title: '$actorName added an expense',
        body: '${expense.title} • ₹${expense.amount.toStringAsFixed(0)}\nPaid by ${expense.primaryPayer}',
        expenseId: expense.id,
        amount: expense.amount,
      );

      // Local storage fallback sync
      await SplitwiseStorageService.addExpense(expense);
    } catch (e) {
      debugPrint('Error adding expense to Firestore: $e');
      await SplitwiseStorageService.addExpense(expense);
    }
  }

  /// Update Expense in Firestore & trigger Activity Log
  Future<void> updateExpense({
    required SplitwiseExpenseModel newExpense,
    required SplitwiseExpenseModel oldExpense,
    required String actorName,
  }) async {
    try {
      final currentUser = AuthService().currentUser;
      final actorId = currentUser?.uid ?? 'local';

      final expenseRef = _firestore
          .collection('splitGroups')
          .doc(newExpense.splitwiseGroupId)
          .collection('expenses')
          .doc(newExpense.id);

      final expData = newExpense.toJson();
      expData['updatedAt'] = FieldValue.serverTimestamp();

      await expenseRef.update(expData);

      String changeSummary = newExpense.title;
      if (oldExpense.amount != newExpense.amount) {
        changeSummary += '\n₹${oldExpense.amount.toStringAsFixed(0)} → ₹${newExpense.amount.toStringAsFixed(0)}';
      }

      await logActivity(
        groupId: newExpense.splitwiseGroupId,
        type: 'EXPENSE_UPDATED',
        actorId: actorId,
        actorName: actorName,
        title: '$actorName updated an expense',
        body: changeSummary,
        expenseId: newExpense.id,
        amount: newExpense.amount,
        previousAmount: oldExpense.amount,
      );

      await SplitwiseStorageService.updateExpense(newExpense);
    } catch (e) {
      debugPrint('Error updating expense in Firestore: $e');
      await SplitwiseStorageService.updateExpense(newExpense);
    }
  }

  /// Delete Expense from Firestore & trigger Activity Log
  Future<void> deleteExpense({
    required String groupId,
    required String expenseId,
    required String title,
    required double amount,
    required String actorName,
  }) async {
    try {
      final currentUser = AuthService().currentUser;
      final actorId = currentUser?.uid ?? 'local';

      await _firestore
          .collection('splitGroups')
          .doc(groupId)
          .collection('expenses')
          .doc(expenseId)
          .delete();

      await logActivity(
        groupId: groupId,
        type: 'EXPENSE_DELETED',
        actorId: actorId,
        actorName: actorName,
        title: '$actorName deleted an expense',
        body: '$title • ₹${amount.toStringAsFixed(0)}',
        expenseId: expenseId,
        amount: amount,
      );

      await SplitwiseStorageService.deleteExpense(expenseId);
    } catch (e) {
      debugPrint('Error deleting expense from Firestore: $e');
      await SplitwiseStorageService.deleteExpense(expenseId);
    }
  }

  // ─── Settlement CRUD ─────────────────────────────────────────────────────────

  /// Record a Settlement Payment in Firestore & Activity Log
  Future<void> addSettlement(SplitwiseSettlementModel settlement, String actorName) async {
    try {
      final currentUser = AuthService().currentUser;
      final actorId = currentUser?.uid ?? 'local';

      final settlementRef = _firestore
          .collection('splitGroups')
          .doc(settlement.groupId)
          .collection('settlements')
          .doc(settlement.id);

      await settlementRef.set(settlement.toJson());

      await logActivity(
        groupId: settlement.groupId,
        type: 'PAYMENT_CREATED',
        actorId: actorId,
        actorName: actorName,
        title: '$actorName recorded a payment',
        body: '₹${settlement.amount.toStringAsFixed(0)} paid to ${settlement.receiverName}',
        amount: settlement.amount,
      );
    } catch (e) {
      debugPrint('Error adding settlement: $e');
    }
  }

  // ─── Activity Log Stream ─────────────────────────────────────────────────────

  /// Create Activity entry in `splitGroups/{groupId}/activities`
  Future<void> logActivity({
    required String groupId,
    required String type,
    required String actorId,
    required String actorName,
    required String title,
    required String body,
    String? expenseId,
    double? amount,
    double? previousAmount,
  }) async {
    try {
      final activityRef = _firestore
          .collection('splitGroups')
          .doc(groupId)
          .collection('activities')
          .doc();

      final activity = SplitwiseActivityModel(
        id: activityRef.id,
        groupId: groupId,
        type: type,
        actorId: actorId,
        actorName: actorName,
        title: title,
        body: body,
        expenseId: expenseId,
        amount: amount,
        previousAmount: previousAmount,
        createdAt: DateTime.now(),
      );

      await activityRef.set(activity.toJson());
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }

  /// Stream group activities for real-time in-app Activity Feed
  Stream<List<SplitwiseActivityModel>> streamGroupActivities(String groupId) {
    return _firestore
        .collection('splitGroups')
        .doc(groupId)
        .collection('activities')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => SplitwiseActivityModel.fromJson(doc.data()))
          .toList();
    });
  }
}

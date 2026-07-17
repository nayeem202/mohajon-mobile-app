import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/services/firestore_paths.dart';
import '../models/investment.dart';
import '../models/investment_category.dart';
import '../models/investment_member.dart';
import '../models/payout.dart';

class InvestmentService {
  InvestmentService(this._ref);

  final Ref _ref;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  String get _shopId => _ref.read(shopIdProvider);

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      FirestorePaths(_firestore, _shopId).collection(name);

  CollectionReference<Map<String, dynamic>> get _investmentsCol =>
      _col('investments');
  CollectionReference<Map<String, dynamic>> get _membersCol =>
      _col('investment_members');
  CollectionReference<Map<String, dynamic>> get _investorsCol =>
      _col('investors');
  CollectionReference<Map<String, dynamic>> get _payoutsCol =>
      _col('payouts');
  CollectionReference<Map<String, dynamic>> get _categoriesCol =>
      _col('investment_categories');

  Stream<List<Investment>> watchInvestments() {
    return _investmentsCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => Investment.fromJson(doc.id, doc.data())).toList());
  }

  Stream<Investment?> watchInvestmentById(String id) {
    return _investmentsCol.doc(id).snapshots().map(
        (doc) => doc.exists ? Investment.fromJson(doc.id, doc.data()!) : null);
  }

  Stream<List<InvestmentMember>> watchMembers(String investmentId) {
    return _membersCol
        .where('investmentId', isEqualTo: investmentId)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => InvestmentMember.fromJson(doc.id, doc.data())).toList());
  }

  Stream<List<Payout>> watchPayouts(String investmentId) {
    return _payoutsCol
        .where('investmentId', isEqualTo: investmentId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => Payout.fromJson(doc.id, doc.data())).toList());
  }

  Stream<List<Payout>> watchPayoutsByInvestor(String investorId) {
    return _payoutsCol
        .where('investorId', isEqualTo: investorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => Payout.fromJson(doc.id, doc.data())).toList());
  }

  Stream<List<InvestmentCategory>> watchCategories() {
    return _categoriesCol
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => InvestmentCategory.fromJson(doc.id, doc.data()))
            .toList());
  }

  Future<void> seedDefaultCategories() async {
    for (final cat in InvestmentCategory.defaults) {
      final doc = _categoriesCol.doc(cat.id);
      final existing = await doc.get();
      if (!existing.exists) {
        await doc.set({
          ...cat.toJson(),
          'shopId': _shopId,
        });
      }
    }
  }

  Future<Investment> createInvestment({
    required String title,
    String description = '',
    required String categoryId,
    required String categoryName,
    required String profitShareMethod,
    String notes = '',
    required List<MemberInput> members,
  }) async {
    final now = DateTime.now();
    final investmentId = const Uuid().v4();
    final totalInvestment =
        members.fold<double>(0, (sum, m) => sum + m.investmentAmount);

    final totalShares = members.fold<double>(
        0, (sum, m) => sum + (profitShareMethod == 'fixed' ? m.sharePercentage : 0));

    final memberDocs = <InvestmentMember>[];
    for (final input in members) {
      final sharePct = profitShareMethod == 'proportional' && totalInvestment > 0
          ? (input.investmentAmount / totalInvestment) * 100
          : profitShareMethod == 'fixed'
              ? (input.sharePercentage ?? 0.0)
              : 0.0;

      memberDocs.add(InvestmentMember(
        id: const Uuid().v4(),
        investmentId: investmentId,
        investorId: input.investorId,
        investmentAmount: input.investmentAmount,
        shopId: _shopId,
        sharePercentage: sharePct,
        profit: 0,
        loss: 0,
        paidAmount: 0,
        remainingAmount: input.investmentAmount,
      ));
    }

    await _firestore.runTransaction((transaction) async {
      final investmentRef = _investmentsCol.doc(investmentId);
      transaction.set(investmentRef, {
        'title': title,
        'shopId': _shopId,
        'description': description,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'totalInvestment': totalInvestment,
        'profitShareMethod': profitShareMethod,
        'notes': notes,
        'createdBy': _userId,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
        'status': 'active',
        'roi': 0,
        'totalProfit': 0,
        'totalPaid': 0,
        'outstanding': totalInvestment,
      });

      for (final member in memberDocs) {
        transaction.set(_membersCol.doc(member.id), member.toJson());
      }

      for (final input in members) {
        final investorRef = _investorsCol.doc(input.investorId);
        transaction.update(investorRef, {
          'totalInvestment': FieldValue.increment(input.investmentAmount),
          'investmentCount': FieldValue.increment(1),
          'outstanding': FieldValue.increment(input.investmentAmount),
        });
      }
    });

    return Investment(
      id: investmentId,
      title: title,
      shopId: _shopId,
      description: description,
      categoryId: categoryId,
      categoryName: categoryName,
      totalInvestment: totalInvestment,
      profitShareMethod: profitShareMethod,
      notes: notes,
      createdBy: _userId,
      createdAt: now,
      updatedAt: now,
      status: 'active',
      roi: 0,
      totalProfit: 0,
      totalPaid: 0,
      outstanding: totalInvestment,
    );
  }

  Future<Payout> recordPayout({
    required String investmentId,
    required String investorId,
    required double amount,
    String note = '',
  }) async {
    final payoutId = const Uuid().v4();
    final now = DateTime.now();

    await _firestore.runTransaction((transaction) async {
      final payoutRef = _payoutsCol.doc(payoutId);
      transaction.set(payoutRef, {
        'investmentId': investmentId,
        'investorId': investorId,
        'amount': amount,
        'shopId': _shopId,
        'note': note,
        'createdBy': _userId,
        'createdAt': Timestamp.fromDate(now),
      });

      final membersQuery = await _membersCol
          .where('investmentId', isEqualTo: investmentId)
          .where('investorId', isEqualTo: investorId)
          .limit(1)
          .get();

      if (membersQuery.docs.isNotEmpty) {
        final memberDoc = membersQuery.docs.first;
        final member = InvestmentMember.fromJson(memberDoc.id, memberDoc.data());
        final newPaid = member.paidAmount + amount;
        final newRemaining = member.remainingAmount - amount;
        transaction.update(memberDoc.reference, {
          'paidAmount': newPaid,
          'remainingAmount': newRemaining,
        });
      }

      final investmentRef = _investmentsCol.doc(investmentId);
      transaction.update(investmentRef, {
        'totalPaid': FieldValue.increment(amount),
        'outstanding': FieldValue.increment(-amount),
        'updatedAt': Timestamp.fromDate(now),
      });

      final investorRef = _investorsCol.doc(investorId);
      transaction.update(investorRef, {
        'outstanding': FieldValue.increment(-amount),
      });
    });

    return Payout(
      id: payoutId,
      investmentId: investmentId,
      investorId: investorId,
      amount: amount,
      shopId: _shopId,
      note: note,
      createdBy: _userId,
      createdAt: now,
    );
  }

  Future<void> updateInvestmentProfit({
    required String investmentId,
    required double totalProfit,
  }) async {
    final now = DateTime.now();
    final membersQuery =
        await _membersCol.where('investmentId', isEqualTo: investmentId).get();
    final members = membersQuery.docs
        .map((doc) => InvestmentMember.fromJson(doc.id, doc.data()))
        .toList();

    final investmentDoc = await _investmentsCol.doc(investmentId).get();
    if (!investmentDoc.exists) return;
    final investment = Investment.fromJson(investmentId, investmentDoc.data()!);

    await _firestore.runTransaction((transaction) async {
      for (final member in members) {
        final shareAmount = totalProfit * (member.sharePercentage / 100);
        final profitAmount = shareAmount > 0 ? shareAmount : 0.0;
        final lossAmount = shareAmount < 0 ? shareAmount.abs() : 0.0;

        transaction.update(_membersCol.doc(member.id), {
          'profit': profitAmount,
          'loss': lossAmount,
          'remainingAmount': member.investmentAmount + profitAmount - member.paidAmount,
        });

        transaction.update(_investorsCol.doc(member.investorId), {
          'totalProfit': FieldValue.increment(profitAmount),
          'totalLoss': FieldValue.increment(lossAmount),
          if (profitAmount > 0)
            'outstanding': FieldValue.increment(profitAmount),
        });
      }

      final roi = investment.totalInvestment > 0
          ? (totalProfit / investment.totalInvestment) * 100
          : 0.0;

      transaction.update(_investmentsCol.doc(investmentId), {
        'totalProfit': totalProfit,
        'roi': roi,
        'outstanding': investment.totalInvestment + totalProfit - investment.totalPaid,
        'updatedAt': Timestamp.fromDate(now),
      });
    });
  }

  Future<void> deleteInvestment(String id) async {
    await _firestore.runTransaction((transaction) async {
      final membersQuery = await _membersCol.where('investmentId', isEqualTo: id).get();
      for (final doc in membersQuery.docs) {
        final member = InvestmentMember.fromJson(doc.id, doc.data());
        transaction.update(_investorsCol.doc(member.investorId), {
          'totalInvestment': FieldValue.increment(-member.investmentAmount),
          'investmentCount': FieldValue.increment(-1),
          'outstanding': FieldValue.increment(-member.remainingAmount),
        });
        transaction.delete(doc.reference);
      }

      final payoutsQuery = await _payoutsCol.where('investmentId', isEqualTo: id).get();
      for (final doc in payoutsQuery.docs) {
        transaction.delete(doc.reference);
      }

      transaction.delete(_investmentsCol.doc(id));
    });
  }
}

class MemberInput {
  const MemberInput({
    required this.investorId,
    required this.investmentAmount,
    this.sharePercentage = 0,
  });

  final String investorId;
  final double investmentAmount;
  final double sharePercentage;
}

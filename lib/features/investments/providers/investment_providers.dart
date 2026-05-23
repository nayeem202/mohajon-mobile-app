import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_bootstrap.dart';
import '../../../core/app/app_providers.dart';
import '../../../core/models/sale.dart';
import '../../../core/models/shop_profile.dart';
import '../../../core/services/firestore_paths.dart';
import '../../customers/providers/customer_providers.dart';
import '../../settings/providers/shop_profile_providers.dart';

final investmentServiceProvider = Provider<InvestmentService>(
  (ref) => InvestmentService(ref),
);

final investmentOverviewProvider = Provider<InvestmentOverview>((ref) {
  final sales = ref.watch(salesStreamProvider).value ?? const <Sale>[];
  final profile = ref.watch(shopProfileProvider).value;
  final owners = profile?.effectiveOwners ??
      const <ShopOwner>[
        ShopOwner(ownerId: 'local-owner', name: 'Owner', investmentAmount: 0),
      ];

  final grossProfit = sales.fold<double>(
    0,
    (sum, sale) => sum + (sale.profit > 0 ? sale.profit : 0),
  );
  final grossLoss = sales.fold<double>(
    0,
    (sum, sale) => sum + (sale.profit < 0 ? sale.profit.abs() : 0),
  );
  final netProfit = grossProfit - grossLoss;
  final totalInvestment = owners.fold<double>(
    0,
    (sum, owner) => sum + owner.investmentAmount,
  );
  final ownerShares = owners.map((owner) {
    final shareRatio = owners.length == 1
        ? 1.0
        : totalInvestment <= 0
        ? 0.0
        : owner.investmentAmount / totalInvestment;
    return OwnerInvestmentShare(
      owner: owner,
      shareRatio: shareRatio,
      profitAmount: netProfit * shareRatio,
    );
  }).toList(growable: false);

  return InvestmentOverview(
    owners: owners,
    totalInvestment: totalInvestment,
    grossProfit: grossProfit,
    grossLoss: grossLoss,
    netProfit: netProfit,
    totalSales: sales.length,
    ownerShares: ownerShares,
  );
});

class InvestmentService {
  InvestmentService(this._ref);

  final Ref _ref;

  Future<void> saveOwners(List<ShopOwner> owners) async {
    if (!AppBootstrap.firebaseReady) {
      throw StateError('Firebase is not configured.');
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null || authUser.isAnonymous) {
      throw StateError('Sign in before updating owners.');
    }

    if (owners.isEmpty) {
      throw StateError('Add at least one owner.');
    }

    final normalizedOwners = <ShopOwner>[];
    for (var index = 0; index < owners.length; index++) {
      final owner = owners[index];
      final trimmedName = owner.name.trim();
      if (trimmedName.isEmpty) {
        throw StateError('Owner ${index + 1} name is required.');
      }
      final double investmentAmount = owner.investmentAmount < 0
          ? 0.0
          : owner.investmentAmount;
      if (owners.length > 1 && investmentAmount <= 0) {
        throw StateError(
          'Each owner investment must be greater than 0 for profit sharing.',
        );
      }
      normalizedOwners.add(
        ShopOwner(
          ownerId: owner.ownerId.trim().isEmpty
              ? (index == 0 ? authUser.uid : 'owner_${index + 1}')
              : owner.ownerId.trim(),
          name: trimmedName,
          investmentAmount: investmentAmount,
        ),
      );
    }

    final shopId = _ref.read(shopIdProvider);
    final shopDoc = FirestorePaths(FirebaseFirestore.instance, shopId).shopDoc;
    await shopDoc.set({
      'shopId': shopId,
      'ownerUserId': normalizedOwners.first.ownerId,
      'owners': normalizedOwners.map((owner) => owner.toJson()).toList(),
      'ownerCount': normalizedOwners.length,
      'totalInvestment': normalizedOwners.fold<double>(
        0,
        (sum, owner) => sum + owner.investmentAmount,
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class InvestmentOverview {
  const InvestmentOverview({
    required this.owners,
    required this.totalInvestment,
    required this.grossProfit,
    required this.grossLoss,
    required this.netProfit,
    required this.totalSales,
    required this.ownerShares,
  });

  final List<ShopOwner> owners;
  final double totalInvestment;
  final double grossProfit;
  final double grossLoss;
  final double netProfit;
  final int totalSales;
  final List<OwnerInvestmentShare> ownerShares;
}

class OwnerInvestmentShare {
  const OwnerInvestmentShare({
    required this.owner,
    required this.shareRatio,
    required this.profitAmount,
  });

  final ShopOwner owner;
  final double shareRatio;
  final double profitAmount;
}

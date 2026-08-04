import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/shop_profile.dart';
import '../../../core/services/api_client.dart';
import '../models/investment.dart';
import '../models/investment_category.dart';
import '../models/investment_member.dart';
import '../models/payout.dart';

class InvestmentService {
  InvestmentService(Ref ref) : _api = ApiClient(ref.read(localDatabaseProvider));

  final ApiClient _api;

  static const _pollInterval = Duration(seconds: 8);

  Stream<List<Investment>> watchInvestments() {
    return pollStream<List<Investment>>(() async {
      final data = await _api.getJson('/api/v1/investments');
      final list = data is List ? data : const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((json) => Investment.fromJson('', json))
          .toList();
    }, _pollInterval);
  }

  Stream<Investment?> watchInvestmentById(String id) {
    return pollStream<Investment?>(() async {
      try {
        final json = await _api.get('/api/v1/investments/$id');
        return Investment.fromJson('', json);
      } on ApiException catch (error) {
        if (error.statusCode == 404) return null;
        rethrow;
      }
    }, _pollInterval);
  }

  Stream<List<InvestmentMember>> watchMembers(String investmentId) {
    return pollStream<List<InvestmentMember>>(() async {
      final json = await _api.get('/api/v1/investments/$investmentId');
      final members = (json['members'] as List?)?.whereType<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];
      return members
          .map((member) => InvestmentMember.fromJson('', member))
          .toList();
    }, _pollInterval);
  }

  Stream<List<Payout>> watchPayouts(String investmentId) {
    return pollStream<List<Payout>>(() async {
      final data = await _api.getJson('/api/v1/investments/$investmentId/payouts');
      final list = data is List ? data : const [];
      final payouts = list
          .whereType<Map<String, dynamic>>()
          .map((json) => Payout.fromJson('', json))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return payouts;
    }, _pollInterval);
  }

  Stream<List<Payout>> watchPayoutsByInvestor(String investorId) {
    return pollStream<List<Payout>>(() async {
      final data = await _api.getJson('/api/v1/investors/$investorId/payouts');
      final list = data is List ? data : const [];
      final payouts = list
          .whereType<Map<String, dynamic>>()
          .map((json) => Payout.fromJson('', json))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return payouts;
    }, _pollInterval);
  }

  Stream<List<InvestmentCategory>> watchCategories() {
    return pollStream<List<InvestmentCategory>>(() async {
      final data = await _api.getJson('/api/v1/investments/categories/all');
      final list = data is List ? data : const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((json) =>
              InvestmentCategory.fromJson(json['id'] as String? ?? '', json))
          .toList();
    }, _pollInterval);
  }

  Future<void> seedDefaultCategories() async {
    final data = await _api.getJson('/api/v1/investments/categories/all');
    final existing = data is List ? data : const [];
    if (existing.isNotEmpty) return;
    for (final cat in InvestmentCategory.defaults) {
      try {
        await _api.post('/api/v1/investments/categories', {
          'name': cat.name,
          'icon': cat.icon,
          'color': cat.color,
        });
      } catch (_) {
        // Best-effort seeding; the server rejects duplicates on retry.
      }
    }
  }

  Future<void> saveOwners(List<ShopOwner> owners) async {
    await _api.put('/api/v1/shops/me', {
      'owners': owners.map((owner) => owner.toJson()).toList(),
    });
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
    final investmentId = const Uuid().v4();
    final totalInvestment = members.fold<double>(
      0,
      (sum, m) => sum + m.investmentAmount,
    );

    final json = await _api.post('/api/v1/investments', {
      'investmentId': investmentId,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'totalInvestment': totalInvestment,
      'profitShareMethod': profitShareMethod,
      'notes': notes,
      'members': [
        for (final input in members)
          {
            'investorId': input.investorId,
            'investmentAmount': input.investmentAmount,
            'sharePercentage': input.sharePercentage,
          },
      ],
    });

    return Investment.fromJson('', json);
  }

  Future<Payout> recordPayout({
    required String investmentId,
    required String investorId,
    required double amount,
    String note = '',
  }) async {
    final json = await _api.post('/api/v1/investments/$investmentId/payouts', {
      'investorId': investorId,
      'amount': amount,
      'note': note,
    });
    return Payout.fromJson('', json);
  }

  Future<void> updateInvestmentProfit({
    required String investmentId,
    required double totalProfit,
  }) async {
    final investment = await _api.get('/api/v1/investments/$investmentId');
    final totalInvestment =
        (investment['totalInvestment'] as num?)?.toDouble() ?? 0;
    final roi = totalInvestment > 0
        ? (totalProfit / totalInvestment) * 100
        : 0.0;
    await _api.post('/api/v1/investments/$investmentId/profit', {
      'roi': roi,
      'totalProfit': totalProfit,
    });
  }

  Future<void> deleteInvestment(String id) async {
    await _api.delete('/api/v1/investments/$id');
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

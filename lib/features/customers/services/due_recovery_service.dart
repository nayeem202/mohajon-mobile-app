import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/models/customer.dart';
import '../../../core/models/payment.dart';
import '../../../core/models/sale.dart';
import '../../../core/offline/local_database.dart';
import '../../../core/services/api_client.dart';
import '../../../core/utils/network_guard.dart';

enum DueFollowUpChannel { whatsapp, sms, call }

class DueFollowUp {
  const DueFollowUp({
    required this.id,
    required this.channel,
    required this.createdAt,
    this.note = '',
    this.status = 'opened',
    this.statusChangedAt,
    this.failureReason = '',
    this.providerMessageId = '',
  });

  final String id;
  final DueFollowUpChannel channel;
  final DateTime createdAt;
  final String note;
  final DateTime? statusChangedAt;
  final String failureReason;
  final String providerMessageId;
  /// Local launch status. WhatsApp/SMS deep links cannot confirm delivery;
  /// they only confirm that the handoff to the external app succeeded.
  final String status;

  factory DueFollowUp.fromJson(Map<dynamic, dynamic> json) => DueFollowUp(
        id: (json['id'] ?? '') as String,
        channel: DueFollowUpChannel.values.firstWhere(
          (value) => value.name == json['channel'],
          orElse: () => DueFollowUpChannel.whatsapp,
        ),
        createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
            DateTime.now(),
        note: (json['note'] ?? '') as String,
        status: (json['status'] ?? 'opened') as String,
        statusChangedAt: json['statusChangedAt'] == null
            ? null
            : DateTime.tryParse(json['statusChangedAt'].toString()),
        failureReason: (json['failureReason'] ?? '') as String,
        providerMessageId: (json['providerMessageId'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'channel': channel.name,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
        'status': status,
        'statusChangedAt': statusChangedAt?.toIso8601String(),
        'failureReason': failureReason,
        'providerMessageId': providerMessageId,
      };

  DueFollowUp copyWith({
    String? status,
    DateTime? statusChangedAt,
    String? failureReason,
    String? providerMessageId,
  }) {
    return DueFollowUp(
      id: id,
      channel: channel,
      createdAt: createdAt,
      note: note,
      status: status ?? this.status,
      statusChangedAt: statusChangedAt ?? this.statusChangedAt,
      failureReason: failureReason ?? this.failureReason,
      providerMessageId: providerMessageId ?? this.providerMessageId,
    );
  }
}

class DueRecoveryPlan {
  const DueRecoveryPlan({
    this.promisedPaymentDate,
    this.snoozedUntil,
    this.followUps = const [],
    this.updatedAt,
  });

  final DateTime? promisedPaymentDate;
  final DateTime? snoozedUntil;
  final List<DueFollowUp> followUps;
  final DateTime? updatedAt;

  bool get isSnoozed =>
      snoozedUntil != null && snoozedUntil!.isAfter(DateTime.now());

  factory DueRecoveryPlan.fromJson(Map<dynamic, dynamic> json) {
    final rawFollowUps = json['followUps'];
    return DueRecoveryPlan(
      promisedPaymentDate: DueRecoveryService._date(json['promisedPaymentDate']),
      snoozedUntil: DueRecoveryService._date(json['snoozedUntil']),
      updatedAt: DueRecoveryService._date(json['updatedAt']),
      followUps: rawFollowUps is List
          ? rawFollowUps
              .whereType<Map>()
              .map(DueFollowUp.fromJson)
              .toList()
          : const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'promisedPaymentDate': promisedPaymentDate?.toIso8601String(),
        'snoozedUntil': snoozedUntil?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'followUps': followUps.map((item) => item.toJson()).toList(),
      };

  DueRecoveryPlan copyWith({
    Object? promisedPaymentDate = _keep,
    Object? snoozedUntil = _keep,
    List<DueFollowUp>? followUps,
    Object? updatedAt = _keep,
  }) {
    return DueRecoveryPlan(
      promisedPaymentDate: identical(promisedPaymentDate, _keep)
          ? this.promisedPaymentDate
          : promisedPaymentDate as DateTime?,
      snoozedUntil: identical(snoozedUntil, _keep)
          ? this.snoozedUntil
          : snoozedUntil as DateTime?,
      followUps: followUps ?? this.followUps,
      updatedAt: identical(updatedAt, _keep)
          ? this.updatedAt
          : updatedAt as DateTime?,
    );
  }
}

const _keep = Object();

class DueRiskProfile {
  const DueRiskProfile({required this.score, required this.label});

  final int score;
  final String label;
}

class DueRecoveryService {
  DueRecoveryService(this._ref);

  final Ref _ref;

  LocalDatabase get _db => _ref.read(localDatabaseProvider);
  String get _shopId => _ref.read(shopIdProvider);
  ApiClient get _api => ApiClient(_db);

  String _key(String customerId) => 'dueRecovery.$_shopId.$customerId';

  DueRecoveryPlan getPlan(String customerId) {
    final raw = _db.settings.get(_key(customerId));
    if (raw is Map) return DueRecoveryPlan.fromJson(raw);
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) return DueRecoveryPlan.fromJson(decoded);
      } catch (_) {
        // Ignore corrupt local state and return a clean plan.
      }
    }
    return const DueRecoveryPlan();
  }

  Future<void> savePlan(String customerId, DueRecoveryPlan plan) async {
    final timestamped = plan.copyWith(updatedAt: DateTime.now());
    await _db.settings.put(_key(customerId), timestamped.toJson());
    if (!await isConnected()) return;
    try {
      await _api.put(
        '/api/v1/customers/$customerId/due-recovery',
        {
          'promisedPaymentDate': timestamped.promisedPaymentDate?.toIso8601String(),
          'snoozedUntil': timestamped.snoozedUntil?.toIso8601String(),
        },
      );
    } catch (_) {
      // The local record remains the retry queue when the network is down.
    }
  }

  Future<void> setPromiseDate(String customerId, DateTime? date) async {
    final plan = getPlan(customerId).copyWith(promisedPaymentDate: date);
    await savePlan(customerId, plan);
  }

  Future<void> snooze(String customerId, Duration duration) async {
    final plan = getPlan(customerId).copyWith(
      snoozedUntil: DateTime.now().add(duration),
    );
    await savePlan(customerId, plan);
  }

  Future<void> clearSnooze(String customerId) async {
    await savePlan(customerId, getPlan(customerId).copyWith(snoozedUntil: null));
  }

  Future<void> addFollowUp({
    required String customerId,
    required DueFollowUpChannel channel,
    String note = '',
    String status = 'opened',
    String failureReason = '',
    String providerMessageId = '',
  }) async {
    final current = getPlan(customerId);
    final item = DueFollowUp(
      id: const Uuid().v4(),
      channel: channel,
      createdAt: DateTime.now(),
      note: note.trim(),
      status: status,
      statusChangedAt: DateTime.now(),
      failureReason: failureReason.trim(),
      providerMessageId: providerMessageId.trim(),
    );
    await savePlan(
      customerId,
      current.copyWith(followUps: [item, ...current.followUps]),
    );
    if (await isConnected()) {
      try {
        await _api.post(
          '/api/v1/customers/$customerId/due-recovery/follow-ups',
          {
            'id': item.id,
            'channel': channel.name,
            'note': note.trim(),
            'status': status,
            'failureReason': failureReason.trim(),
            'providerMessageId': providerMessageId.trim(),
          },
        );
      } catch (_) {
        // Local history is retained until the next explicit refresh.
      }
    }
  }

  Future<void> updateFollowUpStatus({
    required String customerId,
    required String followUpId,
    required String status,
    String failureReason = '',
    String providerMessageId = '',
  }) async {
    const allowed = {'queued', 'sent', 'delivered', 'opened', 'failed'};
    final normalized = status.trim().toLowerCase();
    if (!allowed.contains(normalized)) {
      throw StateError('Unsupported follow-up status.');
    }
    final current = getPlan(customerId);
    final index = current.followUps.indexWhere((item) => item.id == followUpId);
    if (index < 0) throw StateError('Follow-up was not found.');
    final updated = current.followUps[index].copyWith(
      status: normalized,
      statusChangedAt: DateTime.now(),
      failureReason: failureReason.trim(),
      providerMessageId: providerMessageId.trim(),
    );
    final followUps = [...current.followUps]..[index] = updated;
    await savePlan(customerId, current.copyWith(followUps: followUps));
    if (!await isConnected()) return;
    try {
      await _api.patch(
        '/api/v1/customers/$customerId/due-recovery/follow-ups/$followUpId/status',
        {
          'status': normalized,
          'failureReason': failureReason.trim(),
          'providerMessageId': providerMessageId.trim(),
        },
      );
    } catch (_) {
      // The local status remains the offline source of truth until refresh.
    }
  }

  /// Pushes any local recovery state first, then reads the server copy.
  /// This ordering protects records created offline before the first login
  /// on a second device.
  Future<void> refreshFromServer(String customerId) async {
    if (!await isConnected()) return;
    final hasLocal = _db.settings.containsKey(_key(customerId));
      final local = getPlan(customerId);
      try {
        final remote = await _api.get(
          '/api/v1/customers/$customerId/due-recovery',
        );
        if (!hasLocal) {
        await _db.settings.put(
          _key(customerId),
          DueRecoveryPlan.fromJson(remote).toJson(),
        );
          return;
        }
      final remoteUpdatedAt = _date(remote['updatedAt']);
      final localIsStale = remoteUpdatedAt != null &&
          (local.updatedAt == null || remoteUpdatedAt.isAfter(local.updatedAt!));
      if (!localIsStale) {
        await _api.put(
          '/api/v1/customers/$customerId/due-recovery',
          {
            'promisedPaymentDate': local.promisedPaymentDate?.toIso8601String(),
            'snoozedUntil': local.snoozedUntil?.toIso8601String(),
          },
        );
      }
      for (final item in local.followUps) {
        await _api.post(
          '/api/v1/customers/$customerId/due-recovery/follow-ups',
          {
            'id': item.id,
            'channel': item.channel.name,
            'note': item.note,
            'status': item.status,
            'failureReason': item.failureReason,
            'providerMessageId': item.providerMessageId,
          },
        );
      }
      final remoteAfterPush = await _api.get(
        '/api/v1/customers/$customerId/due-recovery',
      );
      final remotePlan = DueRecoveryPlan.fromJson(remoteAfterPush);
      await _db.settings.put(_key(customerId), remotePlan.toJson());
    } catch (_) {
      // Local data is the offline source of truth until the next retry.
    }
  }

  DueRiskProfile risk({
    required Customer customer,
    required double due,
    required List<Sale> sales,
    required List<Payment> payments,
  }) {
    if (due <= 0) return const DueRiskProfile(score: 0, label: 'Clear');
    final unpaidSales = sales.where((sale) => sale.dueAmount > 0).toList();
    final oldest = unpaidSales.isEmpty
        ? DateTime.now()
        : unpaidSales.map((sale) => sale.createdAt).reduce(
              (a, b) => a.isBefore(b) ? a : b,
            );
    final ageDays = DateTime.now().difference(oldest).inDays;
    final totalPaid = payments.fold<double>(0, (sum, item) => sum + item.amount);
    var score = 20;
    if (due >= 5000) score += 25;
    if (due >= 15000) score += 15;
    if (ageDays >= 14) score += 15;
    if (ageDays >= 30) score += 15;
    if (totalPaid == 0 && unpaidSales.isNotEmpty) score += 10;
    final plan = getPlan(customer.customerId);
    if (plan.promisedPaymentDate != null &&
        plan.promisedPaymentDate!.isBefore(DateTime.now())) {
      score += 15;
    }
    score = score.clamp(0, 100);
    return DueRiskProfile(
      score: score,
      label: score >= 70 ? 'High risk' : score >= 40 ? 'Watch' : 'Low risk',
    );
  }

  static Future<bool> openSms({
    required String phone,
    required String message,
  }) async {
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': message},
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openCall(String phone) {
    return launchUrl(
      Uri(scheme: 'tel', path: phone),
      mode: LaunchMode.externalApplication,
    );
  }

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.tryParse(value.toString());
}

final dueRecoveryServiceProvider = Provider<DueRecoveryService>((ref) {
  return DueRecoveryService(ref);
});

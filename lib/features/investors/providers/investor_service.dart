import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/services/api_client.dart';
import '../models/investor.dart';

class InvestorService {
  InvestorService(Ref ref) : _api = ApiClient(ref.read(localDatabaseProvider));

  final ApiClient _api;

  static const _pollInterval = Duration(seconds: 8);

  Stream<List<Investor>> watchAll() {
    return pollStream<List<Investor>>(() async {
      final data = await _api.getJson('/api/v1/investors');
      final list = data is List ? data : const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((json) => Investor.fromJson('', json))
          .toList();
    }, _pollInterval);
  }

  Stream<Investor?> watchById(String id) {
    return pollStream<Investor?>(() async {
      try {
        final json = await _api.get('/api/v1/investors/$id');
        return Investor.fromJson('', json);
      } on ApiException catch (error) {
        if (error.statusCode == 404) return null;
        rethrow;
      }
    }, _pollInterval);
  }

  Future<Investor> save({
    String? id,
    required String name,
    String phone = '',
    String email = '',
    String address = '',
    String photoUrl = '',
    String notes = '',
    File? photoFile,
  }) async {
    if (photoFile != null) {
      photoUrl = await _uploadPhoto(photoFile);
    }

    final json = await _api.post('/api/v1/investors', {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'photoUrl': photoUrl,
      'notes': notes,
    });
    return Investor.fromJson('', json);
  }

  Future<Investor> update({
    required String id,
    String? name,
    String? phone,
    String? email,
    String? address,
    String? photoUrl,
    String? notes,
    File? photoFile,
  }) async {
    if (photoFile != null) {
      photoUrl = await _uploadPhoto(photoFile);
    }

    final json = await _api.put('/api/v1/investors/$id', {
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'photoUrl': photoUrl,
      'notes': notes,
    });
    return Investor.fromJson('', json);
  }

  Future<void> delete(String id) async {
    throw UnsupportedError(
      'Investor information is protected and cannot be deleted.',
    );
  }

  Future<String> _uploadPhoto(File file) async {
    final json = await _api.uploadFile('/api/v1/files', file);
    final url = (json['url'] ?? '').toString();
    if (url.isEmpty) {
      throw const ApiException(500, 'UPLOAD_FAILED', 'Photo upload failed.');
    }
    return url.startsWith('http') ? url : '${AppConfig.apiBaseUrl}$url';
  }
}

import 'dart:io';

import '../config/app_config.dart';
import '../offline/local_database.dart';
import 'api_client.dart';

/// Uploads local files and keeps already-uploaded URLs unchanged.
class FileUploadService {
  FileUploadService(LocalDatabase db) : _api = ApiClient(db);

  final ApiClient _api;

  Future<String?> uploadIfNeeded(String? path) async {
    if (path == null || path.isEmpty || path.startsWith('http')) return path;
    final json = await _api.uploadFile('/api/v1/files', File(path));
    final url = (json['url'] ?? '').toString();
    if (url.isEmpty) throw StateError('Image upload failed.');
    return url.startsWith('http') ? url : '${AppConfig.apiBaseUrl}$url';
  }
}

import 'dart:io';

import 'package:flutter/services.dart';

class DeviceSession {
  const DeviceSession({
    required this.sessionId,
    required this.platform,
    required this.deviceName,
    required this.model,
    required this.manufacturer,
    required this.osVersion,
    required this.locationLabel,
    required this.latitude,
    required this.longitude,
  });

  final String sessionId;
  final String platform;
  final String deviceName;
  final String model;
  final String manufacturer;
  final String osVersion;
  final String locationLabel;
  final double? latitude;
  final double? longitude;

  Map<String, Object?> toMap() {
    return {
      'sessionId': sessionId,
      'platform': platform,
      'deviceName': deviceName,
      'model': model,
      'manufacturer': manufacturer,
      'osVersion': osVersion,
      'locationLabel': locationLabel,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class DeviceSessionService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.inventory_1/device_session',
  );

  Future<DeviceSession> currentSession() async {
    if (!Platform.isAndroid) {
      return DeviceSession(
        sessionId: 'desktop-${Platform.operatingSystem}',
        platform: Platform.operatingSystem,
        deviceName: Platform.localHostname,
        model: Platform.operatingSystem,
        manufacturer: '',
        osVersion: Platform.operatingSystemVersion,
        locationLabel: 'Location unavailable',
        latitude: null,
        longitude: null,
      );
    }

    final result = await _channel.invokeMapMethod<String, dynamic>(
      'getCurrentSession',
    );
    final data = result ?? const <String, dynamic>{};
    return DeviceSession(
      sessionId: (data['sessionId'] ?? 'android-device').toString(),
      platform: (data['platform'] ?? 'Android').toString(),
      deviceName: (data['deviceName'] ?? 'Android device').toString(),
      model: (data['model'] ?? '').toString(),
      manufacturer: (data['manufacturer'] ?? '').toString(),
      osVersion: (data['osVersion'] ?? '').toString(),
      locationLabel: (data['locationLabel'] ?? 'Location unavailable')
          .toString(),
      latitude: _toDouble(data['latitude']),
      longitude: _toDouble(data['longitude']),
    );
  }

  double? _toDouble(Object? value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}

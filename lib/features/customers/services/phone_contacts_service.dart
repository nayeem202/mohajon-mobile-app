import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class PhoneContactRecord {
  const PhoneContactRecord({required this.name, required this.phone});

  final String name;
  final String phone;
}

class PhoneContactsPermissionDenied implements Exception {
  const PhoneContactsPermissionDenied();
}

/// Android contacts are read through the app Activity channel so importing is
/// not dependent on a third-party plugin registering on a reused Flutter
/// engine. Other platforms retain the package implementation.
class PhoneContactsService {
  static const _channel = MethodChannel(
    'com.example.inventory_1/phone_contacts',
  );

  Future<List<PhoneContactRecord>> readContacts() async {
    if (Platform.isAndroid) return _readAndroidContacts();
    return _readPluginContacts();
  }

  Future<List<PhoneContactRecord>> _readAndroidContacts() async {
    try {
      final rawContacts =
          await _channel.invokeListMethod<Object?>('readPhoneContacts') ??
          const <Object?>[];
      return [
            for (final raw in rawContacts)
              if (raw is Map)
                PhoneContactRecord(
                  name: (raw['name']?.toString() ?? '').trim(),
                  phone: (raw['phone']?.toString() ?? '').trim(),
                ),
          ]
          .where(
            (contact) => contact.name.isNotEmpty && contact.phone.isNotEmpty,
          )
          .toList();
    } on PlatformException catch (error) {
      if (error.code == 'contacts_permission_denied') {
        throw const PhoneContactsPermissionDenied();
      }
      rethrow;
    }
  }

  Future<List<PhoneContactRecord>> _readPluginContacts() async {
    final permission = await FlutterContacts.permissions.request(
      PermissionType.read,
    );
    if (permission != PermissionStatus.granted &&
        permission != PermissionStatus.limited) {
      throw const PhoneContactsPermissionDenied();
    }
    final contacts = await FlutterContacts.getAll(
      properties: {ContactProperty.phone},
    );
    return contacts
        .map(
          (contact) => PhoneContactRecord(
            name: (contact.displayName ?? '').trim(),
            phone: contact.phones.isEmpty
                ? ''
                : contact.phones.first.number.trim(),
          ),
        )
        .where((contact) => contact.name.isNotEmpty && contact.phone.isNotEmpty)
        .toList();
  }
}

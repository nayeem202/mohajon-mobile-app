import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/services/firestore_paths.dart';
import '../models/investor.dart';

class InvestorService {
  InvestorService(this._ref);

  final Ref _ref;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseStorage get _storage => FirebaseStorage.instance;
  String get _userId =>
        (_ref.read(localDatabaseProvider).settings.get('activeUserId') as String?) ?? 'unknown';
  String get _shopId => _ref.read(shopIdProvider);
  CollectionReference<Map<String, dynamic>> get _investorsCol =>
      FirestorePaths(_firestore, _shopId).collection('investors');

  Stream<List<Investor>> watchAll() {
    return _investorsCol
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => Investor.fromJson(doc.id, doc.data())).toList());
  }

  Stream<Investor?> watchById(String id) {
    return _investorsCol.doc(id).snapshots().map(
        (doc) => doc.exists ? Investor.fromJson(doc.id, doc.data()!) : null);
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

    final now = DateTime.now();
    final investorId = id ?? const Uuid().v4();
    final investor = Investor(
      id: investorId,
      name: name,
      shopId: _shopId,
      phone: phone,
      email: email,
      address: address,
      photoUrl: photoUrl,
      notes: notes,
      totalInvestment: 0,
      totalProfit: 0,
      totalLoss: 0,
      outstanding: 0,
      investmentCount: 0,
      createdAt: now,
    );

    await _investorsCol.doc(investorId).set(investor.toJson());
    return investor;
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
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (phone != null) data['phone'] = phone;
    if (email != null) data['email'] = email;
    if (address != null) data['address'] = address;
    if (notes != null) data['notes'] = notes;
    if (photoFile != null) {
      data['photoUrl'] = await _uploadPhoto(photoFile);
    }
    if (photoUrl != null) data['photoUrl'] = photoUrl;

    await _investorsCol.doc(id).update(data);

    final doc = await _investorsCol.doc(id).get();
    return Investor.fromJson(id, doc.data()!);
  }

  Future<void> delete(String id) async {
    await _investorsCol.doc(id).delete();
  }

  Future<String> _uploadPhoto(File file) async {
    final ref = _storage.ref('investors/$_shopId/${const Uuid().v4()}');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }
}

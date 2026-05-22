import 'package:cloud_firestore/cloud_firestore.dart';

class FirestorePaths {
  FirestorePaths(this.firestore, this.shopId);

  final FirebaseFirestore firestore;
  final String shopId;

  DocumentReference<Map<String, dynamic>> get shopDoc =>
      firestore.collection('shops').doc(shopId);

  CollectionReference<Map<String, dynamic>> collection(String name) {
    return firestore.collection('shops').doc(shopId).collection(name);
  }
}

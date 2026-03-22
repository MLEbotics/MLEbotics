import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Save a run session to the user's history (all fields optional except mode+startTime)
  Future<void> saveRunSession({
    required String mode,
    required DateTime startTime,
    String? notes,
    Duration? duration,
    double? distanceKm,
    int? avgHeartRate,
    int? maxHeartRate,
    int? avgCadence,
    double? paceKmh,
  }) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('runs').add({
      'mode': mode,
      'startTime': Timestamp.fromDate(startTime),
      'notes': notes ?? '',
      'durationSeconds': duration?.inSeconds,
      'distanceKm': distanceKm,
      'avgHeartRate': avgHeartRate,
      'maxHeartRate': maxHeartRate,
      'avgCadence': avgCadence,
      'paceKmh': paceKmh,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get all run sessions for the current user, newest first
  Stream<QuerySnapshot> getRunHistory() {
    if (_uid == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(_uid)
        .collection('runs')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Delete a single run session by its document ID
  Future<void> deleteRunSession(String docId) async {
    if (_uid == null) return;
    await _db
        .collection('users')
        .doc(_uid)
        .collection('runs')
        .doc(docId)
        .delete();
  }

  /// Save user profile info
  Future<void> saveProfile(String displayName) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).set({
      'displayName': displayName,
      'email': FirebaseAuth.instance.currentUser?.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

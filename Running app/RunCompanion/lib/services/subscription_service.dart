import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum SubscriptionTier { free, premium }

class SubscriptionStatus {
  final SubscriptionTier tier;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final bool onTrial;
  final String? stripeSubscriptionId;

  const SubscriptionStatus({
    this.tier = SubscriptionTier.free,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.onTrial = false,
    this.stripeSubscriptionId,
  });

  bool get isPremium => tier == SubscriptionTier.premium;

  static const SubscriptionStatus free = SubscriptionStatus();
}

class SubscriptionService {
  SubscriptionService._();
  static final instance = SubscriptionService._();

  /// $10 USD/month. CAD displayed as approx (rate embedded for display only;
  /// Stripe always charges in USD).
  static const double priceUsd = 10.00;
  static const double cadRate = 1.39; // approximate as of Feb 2026
  static double get priceCad => priceUsd * cadRate;

  final ValueNotifier<SubscriptionStatus> status = ValueNotifier(
    const SubscriptionStatus(),
  );

  StreamSubscription<DocumentSnapshot>? _sub;

  /// Start listening to the user's subscription document in Firestore.
  void startListening() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subscription')
        .doc('status')
        .snapshots()
        .listen((snap) {
          if (!snap.exists) {
            status.value = const SubscriptionStatus();
            return;
          }
          final data = snap.data()!;
          final tierStr = data['tier'] as String? ?? 'free';
          final tier = tierStr == 'premium'
              ? SubscriptionTier.premium
              : SubscriptionTier.free;
          final endTs = data['currentPeriodEnd'] as Timestamp?;
          status.value = SubscriptionStatus(
            tier: tier,
            currentPeriodEnd: endTs?.toDate(),
            cancelAtPeriodEnd: data['cancelAtPeriodEnd'] as bool? ?? false,
            onTrial: data['onTrial'] as bool? ?? false,
            stripeSubscriptionId: data['stripeSubscriptionId'] as String?,
          );
        }, onError: (e) => debugPrint('SubscriptionService error: $e'));
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
  }

  /// Optimistically mark premium after a successful Stripe payment.
  /// A Firebase webhook will overwrite this with authoritative data.
  Future<void> markPremiumOptimistic({
    required String stripeSubscriptionId,
    int trialDays = 30,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final periodEnd = DateTime.now().add(Duration(days: trialDays));
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subscription')
        .doc('status')
        .set({
          'tier': 'premium',
          'stripeSubscriptionId': stripeSubscriptionId,
          'currentPeriodEnd': Timestamp.fromDate(periodEnd),
          'cancelAtPeriodEnd': false,
          'onTrial': trialDays > 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  /// Called after cancellation is confirmed — does NOT delete; sets flag.
  Future<void> markCancelPending() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('subscription')
        .doc('status')
        .set({
          'cancelAtPeriodEnd': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import '../services/subscription_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _service = SubscriptionService.instance;
  bool _loading = false;
  String? _error;

  Future<void> _startCheckout() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 1 — Ask Firebase Function to create a Stripe subscription + PaymentIntent
      final callable = FirebaseFunctions.instance.httpsCallable(
        'createStripeSubscription',
      );
      final result = await callable.call({
        'priceId': 'price_MONTHLY_10_USD', // replace with your Stripe price ID
      });
      final clientSecret = result.data['clientSecret'] as String;
      final subscriptionId = result.data['subscriptionId'] as String;

      // 2 — Present Stripe payment sheet (Card, Google Pay, Apple Pay)
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Running Companion',
          allowsDelayedPaymentMethods: false,
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'US',
            currencyCode: 'usd',
            testEnv: true, // set false in production
          ),
          applePay: const PaymentSheetApplePay(merchantCountryCode: 'US'),
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(primary: Color(0xFF00796B)),
          ),
          billingDetailsCollectionConfiguration:
              const BillingDetailsCollectionConfiguration(
                name: CollectionMode.always,
                email: CollectionMode.always,
              ),
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      // 3 — Optimistically mark premium + 30-day trial; webhook will confirm
      await _service.markPremiumOptimistic(
        stripeSubscriptionId: subscriptionId,
        trialDays: 30,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Welcome to Premium! Your 30-day free trial starts now 🎉',
            ),
            backgroundColor: Color(0xFF00796B),
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.pop(context);
      }
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        // user dismissed sheet — not an error
      } else {
        setState(() => _error = e.error.localizedMessage ?? e.toString());
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelSubscription() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel subscription?'),
        content: const Text(
          'You keep Premium until the end of the billing period. No refunds are issued for partial months.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Premium'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _loading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'cancelStripeSubscription',
      );
      await callable.call({
        'subscriptionId': _service.status.value.stripeSubscriptionId ?? '',
      });
      await _service.markCancelPending();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Subscription canceled. You keep access until period end.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F7),
      appBar: AppBar(
        title: const Text('Plans & Billing'),
        backgroundColor: const Color(0xFF00796B),
        foregroundColor: Colors.white,
      ),
      body: ValueListenableBuilder<SubscriptionStatus>(
        valueListenable: _service.status,
        builder: (context, status, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _PricingHeader(status: status),
                const SizedBox(height: 24),

                // Free tier
                _PlanCard(
                  name: 'Free',
                  badgeColor: Colors.grey.shade600,
                  price: '\$0',
                  period: 'forever',
                  isCurrentPlan: !status.isPremium,
                  features: const [
                    _Feature('Robot follow + pace modes', true),
                    _Feature('Voice commands (owner-only)', true),
                    _Feature('Garmin BLE telemetry', true),
                    _Feature('Run history (last 10 runs)', true),
                    _Feature('Cloud module updates', true),
                    _Feature('Unlimited run history', false),
                    _Feature('AI coach (full sessions)', false),
                    _Feature('Alert Ahead — SMS broadcasts', false),
                    _Feature('Priority firmware OTAs', false),
                    _Feature('Partner + race integrations', false),
                  ],
                ),
                const SizedBox(height: 16),

                // 30-day trial banner (only for non-premium)
                if (!status.isPremium)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B5E20), Color(0xFF00796B)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.card_giftcard,
                          color: Colors.white,
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Try Premium FREE for 30 days — no charge until trial ends.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Premium tier
                _PlanCard(
                  name: 'Premium',
                  badgeColor: const Color(0xFF00796B),
                  price: '\$10 USD',
                  period:
                      '/month  (~\$${SubscriptionService.priceCad.toStringAsFixed(2)} CAD)',
                  priceNote:
                      'Charged in USD. CAD approximate. First 30 days free.',
                  isCurrentPlan: status.isPremium,
                  highlight: true,
                  features: const [
                    _Feature('Everything in Free', true),
                    _Feature('Unlimited run history', true),
                    _Feature('AI coach (full sessions)', true),
                    _Feature('Alert Ahead — SMS broadcasts', true),
                    _Feature('Priority firmware OTAs', true),
                    _Feature('Partner + race integrations', true),
                  ],
                ),
                const SizedBox(height: 28),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // Action button
                if (!status.isPremium) ...[
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00796B),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _loading ? null : _startCheckout,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.star_rounded),
                    label: Text(
                      _loading ? 'Processing...' : 'Start 30-Day Free Trial',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.credit_card, size: 15, color: Colors.black45),
                      SizedBox(width: 4),
                      Text(
                        'Card',
                        style: TextStyle(fontSize: 11, color: Colors.black45),
                      ),
                      SizedBox(width: 14),
                      Icon(
                        Icons.g_mobiledata_rounded,
                        size: 20,
                        color: Colors.black45,
                      ),
                      Text(
                        'Google Pay',
                        style: TextStyle(fontSize: 11, color: Colors.black45),
                      ),
                      SizedBox(width: 14),
                      Icon(Icons.apple, size: 15, color: Colors.black45),
                      SizedBox(width: 3),
                      Text(
                        'Apple Pay',
                        style: TextStyle(fontSize: 11, color: Colors.black45),
                      ),
                    ],
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Color(0xFF00796B),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Premium Active',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        if (status.currentPeriodEnd != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            status.cancelAtPeriodEnd
                                ? 'Access until ${_fmtDate(status.currentPeriodEnd!)}'
                                : 'Renews ${_fmtDate(status.currentPeriodEnd!)}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!status.cancelAtPeriodEnd) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _loading ? null : _cancelSubscription,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel Subscription'),
                    ),
                  ],
                ],

                const SizedBox(height: 24),
                const _BillingFooter(),
              ],
            ),
          );
        },
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PricingHeader extends StatelessWidget {
  const _PricingHeader({required this.status});
  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.star_rounded, size: 48, color: Color(0xFF00796B)),
        const SizedBox(height: 8),
        Text(
          status.isPremium ? 'You\'re on Premium' : 'Upgrade your run',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Unlock the full Running Companion experience.',
          style: TextStyle(color: Colors.black54),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _Feature {
  final String label;
  final bool included;
  const _Feature(this.label, this.included);
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.badgeColor,
    required this.price,
    required this.period,
    required this.isCurrentPlan,
    required this.features,
    this.highlight = false,
    this.priceNote,
  });

  final String name;
  final Color badgeColor;
  final String price;
  final String period;
  final bool isCurrentPlan;
  final bool highlight;
  final List<_Feature> features;
  final String? priceNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: highlight
            ? Border.all(color: const Color(0xFF00796B), width: 2)
            : Border.all(color: Colors.grey.shade200),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: Colors.teal.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Spacer(),
                if (isCurrentPlan)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Current plan',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF00796B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    period,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ),
              ],
            ),
            if (priceNote != null) ...[
              const SizedBox(height: 2),
              Text(
                priceNote!,
                style: const TextStyle(fontSize: 11, color: Colors.black38),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...features.map(
              (f) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      f.included ? Icons.check_circle_rounded : Icons.remove,
                      size: 18,
                      color: f.included
                          ? const Color(0xFF00796B)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      f.label,
                      style: TextStyle(
                        color: f.included ? Colors.black87 : Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BillingFooter extends StatelessWidget {
  const _BillingFooter();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Divider(),
        SizedBox(height: 8),
        Text(
          '• Billed monthly. Cancel anytime.\n'
          '• All charges in USD via Stripe secure payment.\n'
          '• CAD equivalent shown for reference only (approx. ×1.39).\n'
          '• No refunds for partial billing periods.\n'
          '• Manage billing via the app or stripe.com.',
          style: TextStyle(fontSize: 11, color: Colors.black45, height: 1.8),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;

/// Pre-order screen for the dedicated pacer robot (~$10,000 USD).
class RobotPreOrderScreen extends StatefulWidget {
  const RobotPreOrderScreen({super.key});

  @override
  State<RobotPreOrderScreen> createState() => _RobotPreOrderScreenState();
}

class _RobotPreOrderScreenState extends State<RobotPreOrderScreen> {
  bool _loading = false;
  String? _error;
  bool _ordered = false;

  // $10,000 USD pre-order
  static const double _priceUsd = 10000.00;
  static const double _cadRate = 1.39;
  static double get _priceCad => _priceUsd * _cadRate;

  Future<void> _placeOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Call Firebase Function to create a $10,000 PaymentIntent
      final callable = FirebaseFunctions.instance.httpsCallable(
        'createRobotPreOrderIntent',
      );
      final result = await callable.call({
        'amountCents': 1000000, // $10,000.00 USD in cents
        'currency': 'usd',
      });
      final clientSecret = result.data['clientSecret'] as String;

      // Present Stripe payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Running Companion',
          allowsDelayedPaymentMethods: false,
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: 'US',
            currencyCode: 'usd',
            testEnv: true,
          ),
          applePay: const PaymentSheetApplePay(merchantCountryCode: 'US'),
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(primary: Color(0xFF37474F)),
          ),
          billingDetailsCollectionConfiguration:
              const BillingDetailsCollectionConfiguration(
                name: CollectionMode.always,
                email: CollectionMode.always,
                address: AddressCollectionMode.full,
              ),
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      if (mounted) setState(() => _ordered = true);
    } on StripeException catch (e) {
      if (e.error.code != FailureCode.Canceled) {
        setState(() => _error = e.error.localizedMessage ?? e.toString());
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Pre-Order RunBot'),
        backgroundColor: const Color(0xFF37474F),
        foregroundColor: Colors.white,
      ),
      body: _ordered ? _successView() : _orderView(),
    );
  }

  Widget _successView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 80,
              color: Color(0xFF00796B),
            ),
            const SizedBox(height: 20),
            const Text(
              'Pre-Order Confirmed! 🎉',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Thank you for pre-ordering your RunBot.\n\n'
              'We will email you shipping details when your unit is ready.\n\n'
              '30-day return policy applies from the date of delivery.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00796B),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _orderView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product hero
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF263238), Color(0xFF37474F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.smart_toy, color: Colors.white, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'RunBot — Dedicated Pacer Robot',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your personal 4-wheel autonomous pacing companion for outdoor runs.',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '\$10,000 USD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '~\$${_priceCad.toStringAsFixed(0)} CAD',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade700,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Pre-Order',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Specs
          _SectionCard(
            icon: Icons.build_circle_outlined,
            title: 'What\'s included',
            children: const [
              _SpecRow(Icons.settings_remote, '4-wheel ESP32 robot chassis'),
              _SpecRow(Icons.gps_fixed, 'GPS module (NEO-9M) + 4G modem'),
              _SpecRow(Icons.sensors, 'LiDAR + ultrasonic obstacle avoidance'),
              _SpecRow(Icons.speaker, 'Bluetooth speaker for voice alerts'),
              _SpecRow(
                Icons.inventory_2,
                'Locking aid station payload bay (water, gels, jacket)',
              ),
              _SpecRow(
                Icons.battery_charging_full,
                'High-capacity 18650 battery pack (4–6 hr runtime)',
              ),
              _SpecRow(Icons.wifi, 'Wi-Fi + LTE dual connectivity'),
              _SpecRow(Icons.cloud_sync, 'OTA firmware updates via app'),
            ],
          ),
          const SizedBox(height: 16),

          // Return policy
          _SectionCard(
            icon: Icons.assignment_return_outlined,
            title: '30-Day Return Policy',
            children: const [
              _PolicyRow('Full refund within 30 days of delivery date.'),
              _PolicyRow(
                'Robot must be returned in original packaging, undamaged.',
              ),
              _PolicyRow('Return shipping label provided free of charge.'),
              _PolicyRow(
                'Refund processed within 5–10 business days of receipt.',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Trial badge
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: const [
                Icon(Icons.card_giftcard, color: Color(0xFF00796B)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Includes a 30-day Premium subscription trial — full AI coach, unlimited history, and SMS alerts.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Delivery note
          const Text(
            'Estimated delivery: Q3 2026. You will not be charged until your unit ships.',
            style: TextStyle(fontSize: 12, color: Colors.black45),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),

          // Order button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF37474F),
              padding: const EdgeInsets.symmetric(vertical: 18),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _loading ? null : _placeOrder,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.shopping_cart_checkout),
            label: Text(
              _loading ? 'Processing...' : 'Pre-Order for \$10,000 USD',
            ),
          ),
          const SizedBox(height: 8),
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
              Icon(Icons.g_mobiledata_rounded, size: 20, color: Colors.black45),
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
          const SizedBox(height: 28),

          const Text(
            'Prices in USD. CAD shown as approximate (×1.39). You are charged at time of shipment.\n'
            'By placing a pre-order you agree to the RunBot Terms of Sale and 30-day return policy.',
            style: TextStyle(fontSize: 11, color: Colors.black38, height: 1.7),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.children,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF37474F)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.teal),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Color(0xFF00796B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

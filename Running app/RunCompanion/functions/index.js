/**
 * Firebase Cloud Functions — Stripe subscription billing
 *
 * Required environment variables (set via Firebase secrets):
 *   STRIPE_SECRET_KEY   — your Stripe secret key (sk_live_... or sk_test_...)
 *   STRIPE_WEBHOOK_SECRET — from the Stripe Dashboard webhook endpoint
 *
 * Set them with:
 *   firebase functions:secrets:set STRIPE_SECRET_KEY
 *   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
 */

const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

const STRIPE_SECRET_KEY = defineSecret('STRIPE_SECRET_KEY');
const STRIPE_WEBHOOK_SECRET = defineSecret('STRIPE_WEBHOOK_SECRET');

// ─── createRobotPreOrderIntent ────────────────────────────────────────────────
// Creates a $10,000 USD PaymentIntent for the dedicated pacer robot pre-order.
exports.createRobotPreOrderIntent = onCall(
  { secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be logged in.');
    }
    const uid = request.auth.uid;
    const email = request.auth.token.email;
    const { amountCents, currency } = request.data;

    if (!amountCents || amountCents < 100) {
      throw new HttpsError('invalid-argument', 'Invalid amount.');
    }

    const stripe = require('stripe')(STRIPE_SECRET_KEY.value());

    // Look up or create Stripe customer
    const userRef = db.collection('users').doc(uid);
    const userSnap = await userRef.get();
    const userData = userSnap.exists ? userSnap.data() : {};
    let customerId = userData.stripeCustomerId;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email,
        metadata: { firebaseUid: uid },
      });
      customerId = customer.id;
      await userRef.set({ stripeCustomerId: customerId }, { merge: true });
    }

    // Create a PaymentIntent — capture_method: manual so charge happens at ship
    const intent = await stripe.paymentIntents.create({
      amount: amountCents,
      currency: currency || 'usd',
      customer: customerId,
      capture_method: 'manual',
      setup_future_usage: 'off_session',
      metadata: { firebaseUid: uid, type: 'robot_preorder' },
      description: 'RunBot Dedicated Pacer Robot — Pre-Order',
    });

    // Record pre-order in Firestore
    await db.collection('users').doc(uid).collection('orders').add({
      type: 'robot_preorder',
      amountUsd: amountCents / 100,
      stripePaymentIntentId: intent.id,
      status: 'pending',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { clientSecret: intent.client_secret };
  }
);

// ─── createStripeSubscription ─────────────────────────────────────────────────
// Called from the app when the user taps "Upgrade to Premium".
// Returns { clientSecret, subscriptionId } for the Flutter Stripe SDK.
exports.createStripeSubscription = onCall(
  { secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be logged in.');
    }

    const uid = request.auth.uid;
    const email = request.auth.token.email;
    const priceId = request.data.priceId; // e.g. price_MONTHLY_10_USD

    if (!priceId) {
      throw new HttpsError('invalid-argument', 'priceId is required.');
    }

    const stripe = require('stripe')(STRIPE_SECRET_KEY.value());

    // Look up or create a Stripe customer tied to this Firebase user
    const userRef = db.collection('users').doc(uid);
    const userSnap = await userRef.get();
    const userData = userSnap.exists ? userSnap.data() : {};

    let customerId = userData.stripeCustomerId;
    if (!customerId) {
      const customer = await stripe.customers.create({
        email: email,
        metadata: { firebaseUid: uid },
      });
      customerId = customer.id;
      await userRef.set({ stripeCustomerId: customerId }, { merge: true });
    }

    // Create the subscription with payment_behavior = 'default_incomplete'
    // so Stripe returns a PaymentIntent we can confirm on the client.
    const subscription = await stripe.subscriptions.create({
      customer: customerId,
      items: [{ price: priceId }],
      payment_behavior: 'default_incomplete',
      payment_settings: {
        save_default_payment_method: 'on_subscription',
        payment_method_types: ['card', 'google_pay', 'apple_pay'],
      },
      trial_period_days: 30,
      expand: ['latest_invoice.payment_intent'],
      currency: 'usd',
      metadata: { firebaseUid: uid },
    });

    const paymentIntent =
      subscription.latest_invoice.payment_intent;

    return {
      subscriptionId: subscription.id,
      clientSecret: paymentIntent.client_secret,
    };
  }
);

// ─── cancelStripeSubscription ─────────────────────────────────────────────────
exports.cancelStripeSubscription = onCall(
  { secrets: [STRIPE_SECRET_KEY] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Must be logged in.');
    }
    const { subscriptionId } = request.data;
    if (!subscriptionId) {
      throw new HttpsError('invalid-argument', 'subscriptionId is required.');
    }
    const stripe = require('stripe')(STRIPE_SECRET_KEY.value());
    // Cancel at period end (user keeps access until renewal date)
    await stripe.subscriptions.update(subscriptionId, {
      cancel_at_period_end: true,
    });
    return { success: true };
  }
);

// ─── stripeWebhook ────────────────────────────────────────────────────────────
// Stripe calls this to confirm payment + update Firestore authoritatively.
// Register this URL in the Stripe Dashboard as a webhook endpoint:
//   https://us-central1-running-companion-a935f.cloudfunctions.net/stripeWebhook
exports.stripeWebhook = onRequest(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (req, res) => {
    const stripe = require('stripe')(STRIPE_SECRET_KEY.value());
    const sig = req.headers['stripe-signature'];
    let event;
    try {
      event = stripe.webhooks.constructEvent(
        req.rawBody,
        sig,
        STRIPE_WEBHOOK_SECRET.value()
      );
    } catch (err) {
      console.error('Webhook signature failed:', err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    const data = event.data.object;

    switch (event.type) {
      case 'invoice.paid': {
        const uid = data.subscription_details?.metadata?.firebaseUid
          || (await _uidFromCustomer(db, data.customer));
        if (uid) {
          const periodEnd = new Date(data.lines.data[0].period.end * 1000);
          await db
            .collection('users').doc(uid)
            .collection('subscription').doc('status')
            .set({
              tier: 'premium',
              stripeSubscriptionId: data.subscription,
              stripeCustomerId: data.customer,
              currentPeriodEnd: admin.firestore.Timestamp.fromDate(periodEnd),
              cancelAtPeriodEnd: false,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        break;
      }
      case 'invoice.payment_failed': {
        const uid = await _uidFromCustomer(db, data.customer);
        if (uid) {
          await db
            .collection('users').doc(uid)
            .collection('subscription').doc('status')
            .set({
              paymentFailed: true,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        break;
      }
      case 'customer.subscription.deleted': {
        const uid = data.metadata?.firebaseUid
          || await _uidFromCustomer(db, data.customer);
        if (uid) {
          await db
            .collection('users').doc(uid)
            .collection('subscription').doc('status')
            .set({
              tier: 'free',
              cancelAtPeriodEnd: false,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        break;
      }
      case 'customer.subscription.updated': {
        const uid = data.metadata?.firebaseUid
          || await _uidFromCustomer(db, data.customer);
        if (uid) {
          await db
            .collection('users').doc(uid)
            .collection('subscription').doc('status')
            .set({
              cancelAtPeriodEnd: data.cancel_at_period_end,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        break;
      }
    }

    res.json({ received: true });
  }
);

async function _uidFromCustomer(db, customerId) {
  const snap = await db
    .collection('users')
    .where('stripeCustomerId', '==', customerId)
    .limit(1)
    .get();
  return snap.empty ? null : snap.docs[0].id;
}

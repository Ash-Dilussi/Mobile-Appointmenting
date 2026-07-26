// lib/functions/src/stripeWebhook.ts
//
// Stripe webhook handler for subscription events.
// Deploy with: firebase deploy --only functions
//
// PREREQUISITES:
// 1. npm install stripe firebase-admin
// 2. Set STRIPE_WEBHOOK_SECRET in Cloud Functions environment config
// 3. Configure Stripe to send events to this endpoint via dashboard or CLI:
//    stripe listen --forward-to localhost:5001/bookly/us-central1/stripeWebhook
//
// HANDLER SUMMARY:
// - customer.subscription.created/updated → activate/upgrade plan
// - customer.subscription.deleted → downgrade to free

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import Stripe from 'stripe';

admin.initializeApp();
const db = admin.firestore();

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
});

const WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET!;

// ── Stripe Webhook Handler ────────────────────────────────────────────────────

export const stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'];

  if (!sig || typeof sig !== 'string') {
    console.error('Missing stripe-signature header');
    res.status(400).json({ error: 'Missing signature' });
    return;
  }

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, WEBHOOK_SECRET);
  } catch (err) {
    console.error('Webhook signature verification failed:', err);
    res.status(400).json({ error: 'Invalid signature' });
    return;
  }

  try {
    switch (event.type) {
      case 'customer.subscription.created':
      case 'customer.subscription.updated': {
        const sub = event.data.object as Stripe.Subscription;
        await handleSubscriptionChange(sub);
        break;
      }

      case 'customer.subscription.deleted': {
        const sub = event.data.object as Stripe.Subscription;
        await handleSubscriptionCancelled(sub);
        break;
      }

      case 'invoice.payment_failed': {
        // Optionally notify user or mark subscription as past_due
        const invoice = event.data.object as Stripe.Invoice;
        console.warn('Payment failed for subscription:', invoice.subscription);
        break;
      }

      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    res.json({ received: true });
  } catch (err) {
    console.error('Error processing webhook:', err);
    res.status(500).json({ error: 'Webhook handler failed' });
  }
});

// ── Subscription Change Handler ─────────────────────────────────────────────

async function handleSubscriptionChange(sub: Stripe.Subscription) {
  const institutionId = sub.metadata.institutionId;
  const tier = sub.metadata.tier; // 'pro' | 'enterprise'

  if (!institutionId || !tier) {
    console.error('Missing metadata on subscription:', sub.id);
    return;
  }

  const expiresAt = sub.current_period_end
    ? admin.firestore.Timestamp.fromMillis(sub.current_period_end * 1000)
    : null;

  await db
    .collection('institutions')
    .doc(institutionId)
    .collection('subscription')
    .doc('plan')
    .set(
      {
        tier,
        expiresAt,
        stripeSubscriptionId: sub.id,
        status: sub.status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  console.log(`Subscription updated: ${institutionId} → ${tier}`);
}

// ── Subscription Cancelled Handler ───────────────────────────────────────────

async function handleSubscriptionCancelled(sub: Stripe.Subscription) {
  const institutionId = sub.metadata.institutionId;

  if (!institutionId) {
    console.error('Missing institutionId on cancelled subscription:', sub.id);
    return;
  }

  await db
    .collection('institutions')
    .doc(institutionId)
    .collection('subscription')
    .doc('plan')
    .set(
      {
        tier: 'free',
        expiresAt: null,
        stripeSubscriptionId: null,
        status: 'cancelled',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

  console.log(`Subscription cancelled: ${institutionId} → free`);
}

// ─────────────────────────────────────────────────────────────────────────────
// PADDLE WEBHOOK HANDLER (alternative to Stripe)
//
// To use Paddle instead of Stripe:
// 1. Create a Paddle webhook handler similar to the above
// 2. Map Paddle subscription states to your tier model
// 3. Replace stripeWebhook export with paddleWebhook
//
// Paddle events to handle:
// - subscription.created
// - subscription.updated
// - subscription.cancelled
// - subscription.payment_failed
// ─────────────────────────────────────────────────────────────────────────────

// export const paddleWebhook = functions.https.onRequest(async (req, res) => {
//   const signature = req.headers['paddle-signature'];
//   // Verify Paddle webhook signature using your Paddle webhook secret
//   // Process subscription events similarly to Stripe handler above
//   res.json({ received: true });
// });
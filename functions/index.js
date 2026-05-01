// ═══════════════════════════════════════════════════════════════════════
// Cloud Functions for SarkariSewa
// ─────────────────────────────────────────────────────────────────────
// 1. sendPushNotification (callable, admin-only) — broadcast to all_users
// 2. onBattleCompleted    (Firestore trigger)   — decide winner, award coins
// 3. onPaymentApproved    (Firestore trigger)   — server-side coin top-up
// 4. expireStaleBattles   (scheduled, every 6h) — cancel `active` battles
//                                                 older than 7 days
// 5. dailyStreakReminder  (scheduled, 13:15 UTC = 19:00 NPT) — push to
//                                                 users who haven't
//                                                 opened the app today
// ═══════════════════════════════════════════════════════════════════════
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onDocumentUpdated }  = require("firebase-functions/v2/firestore");
const { onSchedule }         = require("firebase-functions/v2/scheduler");
const { logger }             = require("firebase-functions");
const admin                  = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// ── Helpers ────────────────────────────────────────────────────────────
async function sendFcmToUser(uid, notification) {
  try {
    const userSnap = await db.collection("users").doc(uid).get();
    const token = userSnap.data()?.fcmToken;
    if (!token) {
      logger.info(`No FCM token for ${uid}; skipping push.`);
      return;
    }
    await admin.messaging().send({
      token,
      notification,
      android: { priority: "high" },
    });
  } catch (err) {
    // Push failures must NEVER break the main transaction.
    logger.warn("FCM send failed", { uid, err: err.message });
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 1. sendPushNotification — admin broadcast
// ═══════════════════════════════════════════════════════════════════════
exports.sendPushNotification = onCall(
  { region: "asia-south1", enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }

    const userDoc = await db.collection("users").doc(request.auth.uid).get();
    const role = userDoc.data()?.role;
    if (!userDoc.exists || (role !== "admin" && role !== "super_admin")) {
      throw new HttpsError(
        "permission-denied",
        "Only admins can send push notifications."
      );
    }

    const { title, body, imageUrl } = request.data || {};
    if (!title || !body || typeof title !== "string" || typeof body !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "Title and body are required strings."
      );
    }
    if (title.length > 100 || body.length > 500) {
      throw new HttpsError("invalid-argument", "Title or body too long.");
    }

    const message = {
      topic: "all_users",
      notification: { title, body, ...(imageUrl ? { imageUrl } : {}) },
      android: { priority: "high" },
    };
    const messageId = await admin.messaging().send(message);
    return { success: true, messageId };
  }
);

// ═══════════════════════════════════════════════════════════════════════
// 2. onBattleCompleted — server-side winner determination
// ─────────────────────────────────────────────────────────────────────
// Fires when a battle document is updated. If status just transitioned to
// 'completed' (i.e. the second player submitted their score) AND winnerUid
// is still null (we haven't already processed it), determine the winner
// and award coins atomically.
//
// Reward model:
//   Winner: +50 coins, win counter +1
//   Loser:  +10 coins (consolation), loss counter +1
//   Tie:    both get +25 coins, draw counter +1
//
// Idempotency: we only act when winnerUid is null, so re-runs (e.g. if
// the function retries) won't double-award.
// ═══════════════════════════════════════════════════════════════════════
exports.onBattleCompleted = onDocumentUpdated(
  { region: "asia-south1", document: "battles/{battleId}" },
  async (event) => {
    const before = event.data?.before?.data();
    const after  = event.data?.after?.data();
    if (!before || !after) return;

    const justCompleted = before.status !== "completed" && after.status === "completed";
    if (!justCompleted) return;
    if (after.winnerUid !== null && after.winnerUid !== undefined) {
      // Already processed; idempotent skip.
      return;
    }

    const initiatorUid   = after.initiatorUid;
    const opponentUid    = after.opponentUid;
    const initiatorScore = Number(after.initiatorScore ?? 0);
    const opponentScore  = Number(after.opponentScore  ?? 0);

    if (!initiatorUid || !opponentUid) {
      logger.warn("Battle missing player UIDs", { battleId: event.params.battleId });
      return;
    }

    let winnerUid = null;
    let isTie     = false;
    if (initiatorScore > opponentScore) {
      winnerUid = initiatorUid;
    } else if (opponentScore > initiatorScore) {
      winnerUid = opponentUid;
    } else {
      isTie = true;
    }

    const battleRef = event.data.after.ref;
    const initRef   = db.collection("users").doc(initiatorUid);
    const oppRef    = db.collection("users").doc(opponentUid);

    const winReward  = 50;
    const lossReward = 10;
    const tieReward  = 25;

    try {
      await db.runTransaction(async (tx) => {
        // Stamp the battle with the result.
        tx.update(battleRef, {
          winnerUid: isTie ? null : winnerUid,
          isTie,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        if (isTie) {
          tx.update(initRef, {
            coins:    admin.firestore.FieldValue.increment(tieReward),
            "battleStats.draws": admin.firestore.FieldValue.increment(1),
          });
          tx.update(oppRef, {
            coins:    admin.firestore.FieldValue.increment(tieReward),
            "battleStats.draws": admin.firestore.FieldValue.increment(1),
          });
        } else {
          const loserUid = winnerUid === initiatorUid ? opponentUid : initiatorUid;
          const winnerRef = winnerUid === initiatorUid ? initRef : oppRef;
          const loserRef  = winnerUid === initiatorUid ? oppRef  : initRef;

          tx.update(winnerRef, {
            coins:               admin.firestore.FieldValue.increment(winReward),
            "battleStats.wins":  admin.firestore.FieldValue.increment(1),
          });
          tx.update(loserRef, {
            coins:                admin.firestore.FieldValue.increment(lossReward),
            "battleStats.losses": admin.firestore.FieldValue.increment(1),
          });

          // Log transactions for the wallet history.
          tx.set(db.collection("transactions").doc(), {
            uid:         winnerUid,
            type:        "battle_win",
            coins:       winReward,
            amount:      0,
            description: `🏆 Battle won: ${after.testTitle || "Mock Test"} (+${winReward} coins)`,
            createdAt:   admin.firestore.FieldValue.serverTimestamp(),
          });
          tx.set(db.collection("transactions").doc(), {
            uid:         loserUid,
            type:        "battle_loss",
            coins:       lossReward,
            amount:      0,
            description: `Battle played: ${after.testTitle || "Mock Test"} (+${lossReward} coins)`,
            createdAt:   admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      });
    } catch (err) {
      logger.error("Battle reward transaction failed", err);
      return;
    }

    // Fire push notifications (best-effort, outside transaction).
    const testTitle = after.testTitle || "Mock Test";
    if (isTie) {
      await Promise.all([
        sendFcmToUser(initiatorUid, {
          title: "Battle ended in a tie 🤝",
          body:  `${testTitle} — both scored ${initiatorScore}. +${tieReward} coins each.`,
        }),
        sendFcmToUser(opponentUid, {
          title: "Battle ended in a tie 🤝",
          body:  `${testTitle} — both scored ${opponentScore}. +${tieReward} coins each.`,
        }),
      ]);
    } else {
      const loserUid = winnerUid === initiatorUid ? opponentUid : initiatorUid;
      await Promise.all([
        sendFcmToUser(winnerUid, {
          title: "🏆 You won a battle!",
          body:  `+${winReward} coins for crushing ${testTitle}.`,
        }),
        sendFcmToUser(loserUid, {
          title: "Battle complete",
          body:  `Better luck next time — +${lossReward} coins for participating.`,
        }),
      ]);
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════
// 3. onPaymentApproved — server-side coin top-up
// ─────────────────────────────────────────────────────────────────────
// Fires when payment_requests doc is updated. If status changed from
// pending → approved, credit the user's coins and log the transaction.
//
// This complements the existing client-side `approvePaymentRequest`
// helper, but running it server-side has two benefits:
//   1. The admin client can be simpler — just flip status to 'approved'.
//   2. Idempotent: only fires when status actually changes.
//
// Idempotency: skip if `creditedAt` is already set on the request.
// ═══════════════════════════════════════════════════════════════════════
exports.onPaymentApproved = onDocumentUpdated(
  { region: "asia-south1", document: "payment_requests/{requestId}" },
  async (event) => {
    const before = event.data?.before?.data();
    const after  = event.data?.after?.data();
    if (!before || !after) return;
    if (before.status === "approved" || after.status !== "approved") return;
    if (after.creditedAt) return; // already credited

    const uid    = after.uid;
    const coins  = Number(after.coins  ?? 0);
    const amount = Number(after.amount ?? 0);
    if (!uid || coins <= 0) return;

    const userRef    = db.collection("users").doc(uid);
    const requestRef = event.data.after.ref;

    try {
      await db.runTransaction(async (tx) => {
        tx.update(userRef, {
          coins: admin.firestore.FieldValue.increment(coins),
        });
        tx.update(requestRef, {
          creditedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        tx.set(db.collection("transactions").doc(), {
          uid,
          type:        "topup",
          coins,
          amount,
          description: `Bank Transfer Approved: +${coins} SS Coins for Rs ${amount}`,
          createdAt:   admin.firestore.FieldValue.serverTimestamp(),
        });
      });
    } catch (err) {
      logger.error("Payment credit transaction failed", err);
      return;
    }

    await sendFcmToUser(uid, {
      title: "Coins credited 🪙",
      body:  `+${coins} SS Coins for your top-up of Rs ${amount} have been added to your wallet.`,
    });
  }
);

// ═══════════════════════════════════════════════════════════════════════
// 4. expireStaleBattles — cancel battles the opponent never played
// ─────────────────────────────────────────────────────────────────────
// Runs every 6 hours. Finds battles in `active` status (initiator played,
// opponent hasn't) older than 7 days and flips them to `expired`. Notifies
// the initiator that the opponent failed to respond and refunds them a
// small participation reward (10 coins) so the battle wasn't wasted.
// ═══════════════════════════════════════════════════════════════════════
exports.expireStaleBattles = onSchedule(
  {
    region:   "asia-south1",
    schedule: "every 6 hours",
    timeZone: "Asia/Kathmandu",
  },
  async () => {
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
    );

    const snap = await db.collection("battles")
      .where("status",    "==", "active")
      .where("createdAt", "<",  cutoff)
      .limit(200) // safety cap; future runs will sweep the rest
      .get();

    if (snap.empty) {
      logger.info("expireStaleBattles: nothing to do.");
      return;
    }

    logger.info(`expireStaleBattles: expiring ${snap.size} battle(s).`);

    // Process in chunks of ~50 because we're doing a few writes per battle.
    const refundCoins = 10;
    let processed = 0;

    for (const doc of snap.docs) {
      const data = doc.data();
      const initiatorUid = data.initiatorUid;
      try {
        await db.runTransaction(async (tx) => {
          tx.update(doc.ref, {
            status:    "expired",
            expiredAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          if (initiatorUid) {
            tx.update(db.collection("users").doc(initiatorUid), {
              coins: admin.firestore.FieldValue.increment(refundCoins),
            });
            tx.set(db.collection("transactions").doc(), {
              uid:         initiatorUid,
              type:        "battle_expired",
              coins:       refundCoins,
              amount:      0,
              description: `Battle expired (opponent didn't play): +${refundCoins} coins refund`,
              createdAt:   admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        });
        if (initiatorUid) {
          await sendFcmToUser(initiatorUid, {
            title: "Battle expired ⌛",
            body:  `Your opponent didn't play in time. +${refundCoins} coins refunded.`,
          });
        }
        processed++;
      } catch (err) {
        logger.warn("expireStaleBattles: failed for battle", {
          battleId: doc.id, err: err.message,
        });
      }
    }

    logger.info(`expireStaleBattles: completed ${processed}/${snap.size}.`);
  }
);

// ═══════════════════════════════════════════════════════════════════════
// 5. dailyStreakReminder — nudge users who haven't opened today
// ─────────────────────────────────────────────────────────────────────
// Runs once daily at 19:00 Asia/Kathmandu (13:15 UTC). Targets users who:
//   - have a streak >= 1 (so we're protecting an existing streak)
//   - have an `fcmToken` (otherwise the push has nowhere to go)
//   - whose `lastActiveAt` is before today's local midnight (i.e. they
//     haven't opened the app yet today)
// Sends a "Don't break your streak!" push.
//
// Performance: batched in chunks of 500 reads, sends pushes in parallel
// with a max-concurrency of 50. Streaks longer than 1 are framed as
// "you're on a 7-day run!" — anchoring the loss aversion.
// ═══════════════════════════════════════════════════════════════════════
exports.dailyStreakReminder = onSchedule(
  {
    region:   "asia-south1",
    schedule: "0 19 * * *",
    timeZone: "Asia/Kathmandu",
  },
  async () => {
    // Today's local midnight (Asia/Kathmandu = UTC+5:45). Convert via
    // the same timezone the schedule fires in.
    const now = new Date();
    const offsetMs = 5.75 * 60 * 60 * 1000;
    const local = new Date(now.getTime() + offsetMs);
    const todayStart = new Date(Date.UTC(
      local.getUTCFullYear(), local.getUTCMonth(), local.getUTCDate()
    ) - offsetMs);
    const todayStartTs = admin.firestore.Timestamp.fromDate(todayStart);

    // Two-step query: streak > 0, and lastActiveAt < todayStart.
    // Firestore can't combine these with disjunctions, so we query by
    // streak > 0 and filter lastActiveAt client-side. Cap reads.
    const snap = await db.collection("users")
      .where("streak", ">=", 1)
      .limit(2000)
      .get();

    if (snap.empty) return;

    const candidates = snap.docs.filter((d) => {
      const data = d.data();
      const last = data.lastActiveAt;
      if (!data.fcmToken) return false;
      if (!last) return false;
      return last.toMillis() < todayStartTs.toMillis();
    });

    if (candidates.length === 0) {
      logger.info("dailyStreakReminder: no users at risk.");
      return;
    }

    logger.info(`dailyStreakReminder: pinging ${candidates.length} users.`);

    // Send in parallel batches of 50 to avoid FCM rate limits.
    const concurrency = 50;
    let sent = 0;
    for (let i = 0; i < candidates.length; i += concurrency) {
      const chunk = candidates.slice(i, i + concurrency);
      await Promise.all(chunk.map(async (doc) => {
        const data   = doc.data();
        const streak = (data.streak || 1) | 0;
        const name   = (data.name || "").split(" ")[0] || "there";
        try {
          await admin.messaging().send({
            token: data.fcmToken,
            notification: {
              title: `Don't break your ${streak}-day streak 🔥`,
              body:  streak === 1
                ? `Hey ${name}, open SarkariSewa today to keep going!`
                : `Hey ${name}, you're on a ${streak}-day run — one quick lesson keeps it alive.`,
            },
            android: { priority: "high" },
          });
          sent++;
        } catch (err) {
          // Token may be stale; remove it so we don't keep retrying.
          if (
            err.code === "messaging/registration-token-not-registered" ||
            err.code === "messaging/invalid-registration-token"
          ) {
            await doc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() })
              .catch(() => {});
          } else {
            logger.warn("dailyStreakReminder: send failed", {
              uid: doc.id, err: err.message,
            });
          }
        }
      }));
    }

    logger.info(`dailyStreakReminder: sent ${sent}/${candidates.length}.`);
  }
);

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {sendEmail, sendVerificationEmail} from "./email";

admin.initializeApp();

const db = admin.firestore();

interface UserData {
  displayName: string;
  email: string;
  friendRequestsReceived?: string[];
  friendRequestsSent?: string[];
  friendIds?: string[];
}

interface PendingInvite {
  inviterUserId: string;
  inviterName: string;
  inviterEmail: string;
  inviteeEmail: string;
  createdAt: admin.firestore.Timestamp;
  status: "pending" | "converted";
}

interface DeviceTokens {
  tokens: string[];
  updatedAt: admin.firestore.Timestamp;
}

// Helper function to send push notification
async function sendPushNotification(
  userId: string,
  title: string,
  body: string,
  data?: Record<string, string>
): Promise<void> {
  const tokenDoc = await db.collection("deviceTokens").doc(userId).get();
  if (!tokenDoc.exists) {
    console.log(`No device tokens found for user ${userId}`);
    return;
  }

  const tokenData = tokenDoc.data() as DeviceTokens;
  const tokens = tokenData.tokens || [];

  if (tokens.length === 0) {
    console.log(`Empty token array for user ${userId}`);
    return;
  }

  const message: admin.messaging.MulticastMessage = {
    tokens: tokens,
    notification: {
      title: title,
      body: body,
    },
    data: data,
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log(`Sent ${response.successCount} notifications to user ${userId}`);

    // Clean up invalid tokens
    if (response.failureCount > 0) {
      const invalidTokens: string[] = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          const errorCode = resp.error?.code;
          if (
            errorCode === "messaging/invalid-registration-token" ||
            errorCode === "messaging/registration-token-not-registered"
          ) {
            invalidTokens.push(tokens[idx]);
          }
        }
      });

      if (invalidTokens.length > 0) {
        await db.collection("deviceTokens").doc(userId).update({
          tokens: admin.firestore.FieldValue.arrayRemove(...invalidTokens),
        });
        console.log(`Removed ${invalidTokens.length} invalid tokens for user ${userId}`);
      }
    }
  } catch (error) {
    console.error(`Error sending notification to user ${userId}:`, error);
  }
}

// 1. Trigger when a user receives a friend request
export const onFriendRequestReceived = functions.firestore
  .document("users/{userId}")
  .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const beforeData = change.before.data() as UserData;
    const afterData = change.after.data() as UserData;

    const beforeRequests = beforeData.friendRequestsReceived || [];
    const afterRequests = afterData.friendRequestsReceived || [];

    // Find new friend request senders
    const newRequests = afterRequests.filter((id) => !beforeRequests.includes(id));

    if (newRequests.length === 0) {
      return null;
    }

    console.log(`User ${userId} received ${newRequests.length} new friend request(s)`);

    // Get the user's email and name for the notification
    const userEmail = afterData.email;

    // Process each new request
    for (const senderId of newRequests) {
      // Get sender info
      const senderDoc = await db.collection("users").doc(senderId).get();
      if (!senderDoc.exists) {
        console.log(`Sender ${senderId} not found`);
        continue;
      }

      const senderData = senderDoc.data() as UserData;
      const senderName = senderData.displayName;

      // Send push notification
      await sendPushNotification(
        userId,
        "New Friend Request",
        `${senderName} sent you a friend request`,
        {type: "friend_request", senderId: senderId}
      );

      // Send email notification
      const subject = "New Friend Request on Frinder";
      const html = `
        <h2>New Friend Request</h2>
        <p><strong>${senderName}</strong> sent you a friend request on Frinder!</p>
        <p>Open the Frinder app to accept or decline the request.</p>
        <br>
        <p style="color: #888;">The Frinder Team</p>
      `;
      const text = `${senderName} sent you a friend request on Frinder! Open the app to respond.`;

      await sendEmail(userEmail, subject, html, text);
    }

    return null;
  });

// 2. Trigger when a pending invite is created (for non-existent users)
export const onInviteCreated = functions.firestore
  .document("pendingInvites/{inviteId}")
  .onCreate(async (snap) => {
    const invite = snap.data() as PendingInvite;

    console.log(`Processing invite from ${invite.inviterName} to ${invite.inviteeEmail}`);

    const subject = `${invite.inviterName} invited you to Frinder`;
    const html = `
      <h2>You've Been Invited to Frinder!</h2>
      <p><strong>${invite.inviterName}</strong> (${invite.inviterEmail}) wants to connect with you on Frinder.</p>
      <p>Frinder is a fun app that helps you find and locate your friends in real-time.</p>
      <br>
      <p>Download Frinder and sign up with this email address (${invite.inviteeEmail}) to automatically connect with ${invite.inviterName}.</p>
      <br>
      <p style="color: #888;">The Frinder Team</p>
    `;
    const text = `${invite.inviterName} (${invite.inviterEmail}) invited you to Frinder! Download the app and sign up with ${invite.inviteeEmail} to connect.`;

    await sendEmail(invite.inviteeEmail, subject, html, text);

    return null;
  });

// 3. Trigger when a new auth user is created — send a custom verification email
export const sendVerificationEmailOnSignup = functions.auth.user().onCreate(async (user) => {
  // Only email/password accounts need verification — Google/Apple are already verified
  if (user.emailVerified || !user.email) return null;

  const displayName = user.displayName || user.email.split("@")[0];
  try {
    await sendVerificationEmail(user.email, displayName);
  } catch (error) {
    console.error("Failed to send verification email on signup:", error);
  }
  return null;
});

// 4. HTTPS endpoint for resending the custom verification email from the iOS app
export const resendVerificationEmail = functions.https.onRequest(async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  // Validate Firebase ID token
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    res.status(401).json({error: "Unauthorized"});
    return;
  }

  let uid: string;
  try {
    const decoded = await admin.auth().verifyIdToken(authHeader.split("Bearer ")[1]);
    uid = decoded.uid;
  } catch {
    res.status(401).json({error: "Invalid token"});
    return;
  }

  try {
    const userRecord = await admin.auth().getUser(uid);
    if (!userRecord.email) {
      res.status(400).json({error: "No email address on account"});
      return;
    }
    if (userRecord.emailVerified) {
      // Already verified — no need to resend
      res.status(200).json({success: true});
      return;
    }
    const displayName = userRecord.displayName || userRecord.email.split("@")[0];
    await sendVerificationEmail(userRecord.email, displayName);
    res.status(200).json({success: true});
  } catch (error) {
    console.error("resendVerificationEmail error:", error);
    res.status(500).json({error: "Failed to send verification email"});
  }
});

// 5. Trigger when a new user signs up - convert pending invites to friend requests
export const onUserCreated = functions.firestore
  .document("users/{userId}")
  .onCreate(async (snap, context) => {
    const userId = context.params.userId;
    const userData = snap.data() as UserData;
    const userEmail = userData.email.toLowerCase();

    console.log(`New user created: ${userId} (${userEmail})`);

    // Find pending invites for this email
    const invitesSnapshot = await db
      .collection("pendingInvites")
      .where("inviteeEmail", "==", userEmail)
      .where("status", "==", "pending")
      .get();

    if (invitesSnapshot.empty) {
      console.log(`No pending invites for ${userEmail}`);
      return null;
    }

    console.log(`Found ${invitesSnapshot.size} pending invite(s) for ${userEmail}`);

    const batch = db.batch();

    for (const inviteDoc of invitesSnapshot.docs) {
      const invite = inviteDoc.data() as PendingInvite;
      const inviterId = invite.inviterUserId;

      // Add friend request from inviter to new user
      const userRef = db.collection("users").doc(userId);
      const inviterRef = db.collection("users").doc(inviterId);

      batch.update(userRef, {
        friendRequestsReceived: admin.firestore.FieldValue.arrayUnion(inviterId),
      });

      batch.update(inviterRef, {
        friendRequestsSent: admin.firestore.FieldValue.arrayUnion(userId),
      });

      // Mark invite as converted
      batch.update(inviteDoc.ref, {
        status: "converted",
      });

      console.log(`Converted invite from ${inviterId} to friend request for ${userId}`);
    }

    await batch.commit();
    console.log(`Successfully converted ${invitesSnapshot.size} invite(s) to friend requests`);

    return null;
  });

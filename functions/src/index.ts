import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import sgMail from "@sendgrid/mail";

admin.initializeApp();

const db = admin.firestore();

// Initialize SendGrid with API key from environment
const sendgridApiKey = process.env.SENDGRID_API_KEY;
if (sendgridApiKey) {
  sgMail.setApiKey(sendgridApiKey);
}

const FROM_EMAIL = "noreply@frinder.app"; // Update to your verified sender

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

// Helper function to send email via SendGrid
async function sendEmail(
  to: string,
  subject: string,
  html: string,
  text: string
): Promise<void> {
  if (!sendgridApiKey) {
    console.error("SendGrid API key not configured");
    return;
  }

  const msg = {
    to: to,
    from: FROM_EMAIL,
    subject: subject,
    text: text,
    html: html,
  };

  try {
    await sgMail.send(msg);
    console.log(`Email sent to ${to}`);
  } catch (error) {
    console.error(`Error sending email to ${to}:`, error);
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

  let link: string;
  try {
    const actionCodeSettings: admin.auth.ActionCodeSettings = {
      url: "https://frinder.me/verify",
    };
    link = await admin.auth().generateEmailVerificationLink(user.email, actionCodeSettings);
  } catch (error) {
    console.error("Failed to generate verification link:", error);
    return null;
  }

  const subject = "Welcome to Frinder 👋 — please verify your email";

  const html = `
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:#f0f4f8;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4f8;padding:40px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width:520px;background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">

          <!-- Header -->
          <tr>
            <td style="background:linear-gradient(135deg,#1a73e8 0%,#0d47a1 100%);padding:40px 48px;text-align:center;">
              <img src="https://frinder.me/assets/frinder-icon.jpg" width="72" height="72"
                   style="border-radius:18px;display:block;margin:0 auto 16px;border:3px solid rgba(255,255,255,0.3);" alt="Frinder">
              <h1 style="color:#ffffff;margin:0;font-size:30px;font-weight:700;letter-spacing:-0.5px;">Frinder</h1>
              <p style="color:rgba(255,255,255,0.75);margin:6px 0 0;font-size:15px;">Find your friends</p>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:44px 48px 36px;">
              <h2 style="color:#1a1a2e;margin:0 0 14px;font-size:22px;font-weight:700;">
                Hey ${displayName}! 🎉
              </h2>
              <p style="color:#4a4a6a;margin:0 0 14px;font-size:16px;line-height:1.65;">
                Welcome to <strong>Frinder</strong> — we're thrilled to have you on board!
                You're just one step away from finding your friends on the radar.
              </p>
              <p style="color:#4a4a6a;margin:0 0 36px;font-size:16px;line-height:1.65;">
                Tap the button below to confirm your email address and get started:
              </p>

              <!-- CTA Button -->
              <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 auto 36px;">
                <tr>
                  <td align="center" style="border-radius:12px;background:#1a73e8;">
                    <a href="${link}"
                       style="display:inline-block;padding:17px 38px;color:#ffffff;text-decoration:none;font-size:17px;font-weight:600;border-radius:12px;letter-spacing:-0.2px;white-space:nowrap;">
                      Verify your email by clicking here &rarr;
                    </a>
                  </td>
                </tr>
              </table>

              <p style="color:#9a9ab0;margin:0;font-size:13px;line-height:1.6;">
                Button not working? Paste this link into your browser:<br>
                <a href="${link}" style="color:#1a73e8;word-break:break-all;font-size:12px;">${link}</a>
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background:#f8f9fc;padding:22px 48px;border-top:1px solid #eef0f6;text-align:center;">
              <p style="color:#b0b0c8;margin:0;font-size:12px;line-height:1.6;">
                You're receiving this because you just signed up for <strong>Frinder</strong>.<br>
                If you didn't create an account, you can safely ignore this email.
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;

  const text = `Hey ${displayName}! Welcome to Frinder 🎉\n\nPlease verify your email address to get started:\n${link}\n\nIf you didn't sign up for Frinder, you can safely ignore this email.`;

  await sendEmail(user.email, subject, html, text);
  return null;
});

// 4. Trigger when a new user signs up - convert pending invites to friend requests
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

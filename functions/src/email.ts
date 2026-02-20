import * as admin from "firebase-admin";
import sgMail from "@sendgrid/mail";

export const FROM = {email: "noreply@frinder.me", name: "Your Friends at Frinder"};

// Send an email via SendGrid. Reads the API key at call time so tests can
// set process.env.SENDGRID_API_KEY before calling.
export async function sendEmail(
  to: string,
  subject: string,
  html: string,
  text: string
): Promise<void> {
  const apiKey = process.env.SENDGRID_API_KEY;
  if (!apiKey) {
    console.error("SendGrid API key not configured");
    return;
  }
  sgMail.setApiKey(apiKey);

  try {
    await sgMail.send({to, from: FROM, subject, text, html});
    console.log(`Email sent to ${to}`);
  } catch (error: any) {
    const body = error?.response?.body;
    console.error(`Error sending email to ${to}: status=${error?.code}`, JSON.stringify(body));
  }
}

// Generate a Firebase verification link and send the branded Frinder email.
export async function sendVerificationEmail(email: string, displayName: string): Promise<void> {
  const actionCodeSettings: admin.auth.ActionCodeSettings = {
    url: "https://frinder.me/verify",
  };
  const link = await admin.auth().generateEmailVerificationLink(email, actionCodeSettings);

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

  await sendEmail(email, subject, html, text);
}

// Mocks are hoisted before imports by Jest — jest.fn() is available globally here.
jest.mock("@sendgrid/mail", () => ({
  __esModule: true,
  default: {
    setApiKey: jest.fn(),
    send: jest.fn().mockResolvedValue([{statusCode: 202}]),
  },
}));

jest.mock("firebase-admin", () => ({
  auth: jest.fn().mockReturnValue({
    generateEmailVerificationLink: jest
      .fn()
      .mockResolvedValue("https://frinder.me/verify?oobCode=TESTCODE"),
  }),
}));

import sgMail from "@sendgrid/mail";
import * as admin from "firebase-admin";
import {sendEmail, sendVerificationEmail, FROM} from "./email";

const send = sgMail.send as jest.Mock;
// admin.auth() always returns the same mock object (mockReturnValue)
const generateLink = admin.auth().generateEmailVerificationLink as jest.Mock;

beforeEach(() => {
  process.env.SENDGRID_API_KEY = "test-api-key";
  jest.clearAllMocks();
  // Restore default implementations after clearAllMocks clears call history
  send.mockResolvedValue([{statusCode: 202}]);
  generateLink.mockResolvedValue("https://frinder.me/verify?oobCode=TESTCODE");
});

// ─────────────────────────────────────────────
// sendEmail
// ─────────────────────────────────────────────
describe("sendEmail", () => {
  it("sends with the correct FROM name and address", async () => {
    await sendEmail("user@example.com", "Subject", "<p>html</p>", "text");
    expect(send).toHaveBeenCalledWith(
      expect.objectContaining({from: FROM})
    );
  });

  it("sends to the correct recipient", async () => {
    await sendEmail("recipient@test.com", "Subject", "<p>html</p>", "text");
    expect(send).toHaveBeenCalledWith(
      expect.objectContaining({to: "recipient@test.com"})
    );
  });

  it("passes through the subject and body", async () => {
    await sendEmail("u@example.com", "My Subject", "<b>html</b>", "plain text");
    expect(send).toHaveBeenCalledWith(
      expect.objectContaining({subject: "My Subject", html: "<b>html</b>", text: "plain text"})
    );
  });

  it("does not send if SENDGRID_API_KEY is not set", async () => {
    delete process.env.SENDGRID_API_KEY;
    await sendEmail("user@example.com", "Sub", "<p>html</p>", "text");
    expect(send).not.toHaveBeenCalled();
  });
});

// ─────────────────────────────────────────────
// sendVerificationEmail
// ─────────────────────────────────────────────
describe("sendVerificationEmail", () => {
  it("sends to the correct email address", async () => {
    await sendVerificationEmail("alice@example.com", "Alice");
    expect(send).toHaveBeenCalledWith(
      expect.objectContaining({to: "alice@example.com"})
    );
  });

  it("sends from The Frinder Team", async () => {
    await sendVerificationEmail("bob@example.com", "Bob");
    expect(send).toHaveBeenCalledWith(
      expect.objectContaining({
        from: expect.objectContaining({name: "The Frinder Team 🌍🧭"}),
      })
    );
  });

  it("includes the display name in the email body", async () => {
    await sendVerificationEmail("carol@example.com", "Carol");
    const {html, text} = send.mock.calls[0][0];
    expect(html).toContain("Carol");
    expect(text).toContain("Carol");
  });

  it("includes the verification link in the email", async () => {
    await sendVerificationEmail("dave@example.com", "Dave");
    const {html, text} = send.mock.calls[0][0];
    expect(html).toContain("https://frinder.me/verify?oobCode=TESTCODE");
    expect(text).toContain("https://frinder.me/verify?oobCode=TESTCODE");
  });

  it("uses frinder.me/verify as the continue URL when generating the link", async () => {
    await sendVerificationEmail("eve@example.com", "Eve");
    expect(generateLink).toHaveBeenCalledWith(
      "eve@example.com",
      expect.objectContaining({url: "https://frinder.me/verify"})
    );
  });

  it("includes Frinder branding in the email", async () => {
    await sendVerificationEmail("frank@example.com", "Frank");
    const {html} = send.mock.calls[0][0];
    expect(html).toContain("Frinder");
    expect(html).toContain("frinder.me/assets/frinder-icon.jpg");
  });
});

#!/usr/bin/env node

const {
  legalUpdatedEmail,
  premiumCancelledEmail,
  premiumExpiredEmail,
  premiumExpiringEmail,
  premiumPurchasedEmail
} = require("../lib/emailTemplates.js");

const resendApiKey = process.env.RESEND_API_KEY;
const to = process.env.TEST_EMAIL_TO || "066sakura@gmail.com";
const from = "Kuusi <hi@kuusi.app>";
const now = Date.now();
const sampleExpiresAt = now + 7 * 24 * 60 * 60 * 1000;

const templates = [
  ["premium_purchased", premiumPurchasedEmail(sampleExpiresAt)],
  ["premium_cancelled", premiumCancelledEmail(sampleExpiresAt)],
  ["premium_expiring", premiumExpiringEmail(sampleExpiresAt)],
  ["premium_expired", premiumExpiredEmail()],
  ["legal_updated", legalUpdatedEmail({
    body: "We have updated the Kuusi Terms of Service and Privacy Policy. These changes clarify how Premium subscriptions and account data are handled.",
    effectiveAt: {
      toMillis: () => now
    },
    privacyURL: "https://kuusi.app/privacy",
    termsURL: "https://kuusi.app/terms",
    title: "Important update to Kuusi terms"
  })]
];

async function main() {
  if (!resendApiKey) {
    throw new Error("RESEND_API_KEY is required");
  }

  for (const [type, payload] of templates) {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${resendApiKey}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        from,
        to: [to],
        subject: `[${type}] ${payload.subject}`,
        html: payload.html,
        text: payload.text
      })
    });

    const responseText = await response.text();
    if (!response.ok) {
      throw new Error(`${type} failed: ${response.status} ${responseText}`);
    }

    console.log(`${type}: ${responseText}`);
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});

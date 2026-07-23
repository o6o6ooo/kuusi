import {strict as assert} from "node:assert";
import {describe, it} from "node:test";
import {Timestamp} from "firebase-admin/firestore";
import {
  legalUpdatedEmail,
  premiumCancelledEmail,
  premiumExpiredEmail,
  premiumExpiringEmail,
  premiumPurchasedEmail
} from "../src/emailTemplates";

const expiresDate = Date.UTC(2026, 0, 15, 12);

describe("Functions email templates", () => {
  it("builds Premium lifecycle emails with user-facing dates", () => {
    const purchased = premiumPurchasedEmail(expiresDate);
    const cancelled = premiumCancelledEmail(expiresDate);
    const expiring = premiumExpiringEmail(expiresDate);
    const expired = premiumExpiredEmail();

    assert.match(purchased.subject, /purchase is confirmed/i);
    assert.match(purchased.text, /15 January 2026/);
    assert.match(cancelled.text, /continue using Premium until 15 January 2026/);
    assert.match(expiring.text, /ends on 15 January 2026/);
    assert.match(expired.text, /returned to the free plan/);
  });

  it("escapes legal announcement HTML and linkifies safe URLs", () => {
    const email = legalUpdatedEmail({
      title: "Terms <update>",
      body: "Read <carefully> at https://kuusi.app/terms",
      effectiveAt: Timestamp.fromMillis(expiresDate),
      termsURL: "https://kuusi.app/terms",
      privacyURL: null
    });

    assert.match(email.html, /Terms &lt;update&gt;/);
    assert.match(email.html, /Read &lt;carefully&gt;/);
    assert.match(email.html, /href="https:\/\/kuusi\.app\/terms"/);
    assert.doesNotMatch(email.html, /Read <carefully>/);
    assert.match(email.text, /Effective date: 15 January 2026/);
  });
});

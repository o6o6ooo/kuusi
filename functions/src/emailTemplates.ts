import { Timestamp } from "firebase-admin/firestore";

export type EmailPayload = {
  html: string;
  subject: string;
  text: string;
};

const supportEmail = "hi@kuusi.app";
const appURL = "https://kuusi.app";
const iconURL = "https://kuusi.app/kuusi-light.png";

export function premiumPurchasedEmail(expiresDate: number): EmailPayload {
  const expiresLabel = formatDate(expiresDate);
  return buildEmail({
    title: "Premium purchase confirmed",
    subject: "Your Kuusi Premium purchase is confirmed",
    intro: "Thank you for purchasing Kuusi Premium.",
    body: [
      `Your Premium access is active until ${expiresLabel}.`,
      "You can manage or cancel your subscription from your Apple account settings."
    ],
    footer: "This is an important account email about your Kuusi subscription."
  });
}

export function premiumCancelledEmail(expiresDate: number): EmailPayload {
  const expiresLabel = formatDate(expiresDate);
  return buildEmail({
    title: "Premium cancellation confirmed",
    subject: "Your Kuusi Premium cancellation is confirmed",
    intro: "Your Kuusi Premium subscription has been cancelled.",
    body: [
      `You can continue using Premium until ${expiresLabel}.`,
      "After that, your account will return to the free plan unless you renew."
    ],
    footer: "This is an important account email about your Kuusi subscription."
  });
}

export function premiumExpiringEmail(expiresDate: number): EmailPayload {
  const expiresLabel = formatDate(expiresDate);
  return buildEmail({
    title: "Premium access ending soon",
    subject: "Your Kuusi Premium access is ending soon",
    intro: "Your Kuusi Premium access is ending soon.",
    body: [
      `Your current Premium access ends on ${expiresLabel}.`,
      "After that, your account will return to the free plan unless you renew."
    ],
    footer: "This is an important account email about your Kuusi subscription."
  });
}

export function premiumExpiredEmail(): EmailPayload {
  return buildEmail({
    title: "Premium access ended",
    subject: "Your Kuusi Premium access has ended",
    intro: "Your Kuusi Premium access has ended.",
    body: [
      "Your account has returned to the free plan.",
      "You can renew Premium from the Kuusi app at any time."
    ],
    footer: "This is an important account email about your Kuusi subscription."
  });
}

export function legalUpdatedEmail(input: {
  body: string;
  effectiveAt?: Timestamp;
  privacyURL: string | null;
  termsURL: string | null;
  title: string;
}): EmailPayload {
  const body = [
    input.body,
    ...(input.effectiveAt ? [`Effective date: ${formatDate(input.effectiveAt.toMillis())}`] : []),
    ...(input.termsURL ? [`Terms: ${input.termsURL}`] : []),
    ...(input.privacyURL ? [`Privacy Policy: ${input.privacyURL}`] : [])
  ];

  return buildEmail({
    title: input.title,
    subject: input.title,
    intro: "Kuusi has an important legal update.",
    body,
    footer: "This is an important legal update about Kuusi."
  });
}

function buildEmail(input: {
  body: string[];
  footer: string;
  intro: string;
  subject: string;
  title: string;
}): EmailPayload {
  const text = [
    input.intro,
    "",
    ...input.body.flatMap((line) => [line, ""]),
    `If you have any questions, reply to this email or contact ${supportEmail}.`,
    "",
    input.footer,
    "",
    `Kuusi: ${appURL}`
  ].join("\n").trim();

  return {
    subject: input.subject,
    text,
    html: renderHTML(input)
  };
}

function renderHTML(input: {
  body: string[];
  footer: string;
  intro: string;
  title: string;
}): string {
  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="color-scheme" content="light dark">
    <meta name="supported-color-schemes" content="light dark">
    <title>${escapeHTML(input.title)}</title>
    <style>
      @media (prefers-color-scheme: dark) {
        .email-body { background: #1E2633 !important; }
        .email-card { background: #2A3140 !important; border-color: #435064 !important; }
        .email-divider { border-color: #435064 !important; }
        .email-title, .email-copy, .email-brand { color: #DCE2EA !important; }
        .email-link { color: #8EA9D5 !important; }
        .email-muted { color: #A8B0BC !important; }
      }
    </style>
  </head>
  <body class="email-body" style="margin:0; padding:0; background:#F2F8FF; color:#2A3140; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" class="email-body" style="background:#F2F8FF; padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" class="email-card" style="max-width:560px; background:#FFFFFF; border:1px solid #DCEAF5; border-radius:8px; overflow:hidden;">
            <tr>
              <td class="email-divider" style="padding:26px 32px 18px; border-bottom:1px solid #DCEAF5;">
                <table role="presentation" cellspacing="0" cellpadding="0">
                  <tr>
                    <td style="padding:0 12px 0 0;">
                      <img src="${iconURL}" width="44" height="44" alt="Kuusi" style="display:block; width:44px; height:44px; border-radius:10px;">
                    </td>
                    <td>
                      <div class="email-brand" style="font-size:22px; line-height:28px; font-weight:700; color:#2A3140;">Kuusi</div>
                    </td>
                  </tr>
                </table>
              </td>
            </tr>
            <tr>
              <td style="padding:30px 32px 12px;">
                <h1 class="email-title" style="margin:0 0 18px; font-size:24px; line-height:32px; font-weight:700; color:#2A3140;">${escapeHTML(input.title)}</h1>
                <p class="email-copy" style="margin:0 0 18px; font-size:16px; line-height:25px; color:#2A3140;">${escapeHTML(input.intro)}</p>
                ${input.body.map((line) => `<p class="email-copy" style="margin:0 0 16px; font-size:16px; line-height:25px; color:#2A3140;">${linkify(escapeHTML(line))}</p>`).join("")}
                <p class="email-copy" style="margin:10px 0 0; font-size:16px; line-height:25px; color:#2A3140;">If you have any questions, reply to this email or contact <a class="email-link" href="mailto:${supportEmail}" style="color:#5C9BD1; text-decoration:underline;">${supportEmail}</a>.</p>
              </td>
            </tr>
            <tr>
              <td style="padding:18px 32px 30px;">
                <p class="email-muted" style="margin:0 0 14px; font-size:13px; line-height:20px; color:#727C8D;">${escapeHTML(input.footer)}</p>
                <p class="email-muted" style="margin:0; font-size:13px; line-height:20px; color:#727C8D;"><a class="email-link" href="${appURL}" style="color:#5C9BD1; text-decoration:underline;">${appURL}</a></p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function formatDate(value: number): string {
  return new Intl.DateTimeFormat("en-GB", {
    dateStyle: "long",
    timeZone: "Europe/London"
  }).format(new Date(value));
}

function escapeHTML(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function linkify(value: string): string {
  return value.replace(
    /(https:\/\/[^\s<]+)/g,
    '<a class="email-link" href="$1" style="color:#5C9BD1; text-decoration:underline;">$1</a>'
  );
}

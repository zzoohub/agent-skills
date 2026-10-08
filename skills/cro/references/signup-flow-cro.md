# Signup Flow CRO

Signup and registration: account creation, trial start, waitlist. After the account exists → `references/onboarding-cro.md`; e-commerce accounts → `references/checkout-cro.md`; card-upfront trials → `references/paywall-upgrade-cro.md`.

## Leak signatures

- **Google sign-in fails in Instagram, Facebook or TikTok traffic** → Google blocks OAuth in embedded in-app browsers (`disallowed_useragent`), and passkeys for your domain mostly fail there too. Confirm: auth errors by user agent. Fix: in in-app browsers (detected by user agent), hide Google and passkey buttons and lead with an emailed one-time code, or offer "open in browser"; a magic link opens in another browser and loses the session.
- **"Link expired" from company domains** → email security scanners open one-time links before the user does. Confirm: first clicks seconds after sending. Fix: one-time codes, or a link whose landing page needs a click before it spends the token.
- **Sign in with Apple users never activate** → mail to their relay addresses bounces. Confirm: bounces on @privaterelay.appleid.com addresses. Fix: register every sending domain with Apple's private email relay and authenticate it (SPF, DKIM).
- **Drop at the password field** → composition rules reject good passwords, or paste is blocked. Confirm: errors by rule. Fix (below).
- **Drop at verification** → verification blocks first use. Confirm: verify-step drop and time to verify. Fix (below).
- **Exits at "email already registered"** → returning users who signed up another way. Confirm: those addresses' original sign-in method. Fix: name that method and offer sign-in in place. Break when account enumeration matters (finance, health, high-value accounts): show a neutral "check your email" and email that address a sign-in code.
- **Mobile drop at one field** → wrong keyboard, autofill or autocomplete attributes. Confirm: field drop by device. Fix.
- **Signups rise, activation falls** → a lower-intent audience, or a promise the product doesn't keep. Confirm: activation by source. Not a win until activation holds.

## Judgment calls

- **Defer company, role and team size to onboarding**, where the answer can change what the user sees. Break when sales routes on a field: check the enrichment tool's match rate before removing it.
- **Verify at the first action that needs it**, not before first use. Verification protects against throwaway and fake accounts, spam sent through you, bounces that hurt your sender reputation, and repeat free trials; when you defer it, gate those actions (sending, invites, exports, billing) behind it, rate-limit unverified accounts, block disposable domains, and watch fake-account share and bounce rate as guardrails.
- **Passwords**: length and a blocklist only, no composition rules (NIST SP 800-63B-4); allow paste and password managers; offer passkeys.
- **Multi-step** helps when answers branch the path or the first step captures an email for recovery. Break when it only splits the same effort.

## Field set (redesign only)

Each field with why it is asked now: used before the next value moment, routed on, or legally required. Everything else moves to onboarding or progressive profiling. Each removed field or step names what it protected (routing, fraud, consent, deliverability) and its replacement (enrichment, deferred verification, a later question). Labels and errors appear as copy direction only.

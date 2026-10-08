# Checkout CRO

Cart, checkout, payment and cart recovery, for e-commerce and SaaS purchases. Price-display law → pricing; subscription consent and renewal law → churn-prevention; recovery-email cadence and copy → copywriting (each via that capability, if available). Segment orders placed by AI agents out of funnel rates. Subscription purchases: the on-screen terms check in `references/paywall-upgrade-cro.md`. EU consumer e-commerce falls under the European Accessibility Act (since 28 June 2025; microenterprises exempt), so checkout accessibility failures are legal defects as well as lost orders.

## Leak signatures

- **Drop at payment** → declines, 3-D Secure challenges or fraud-rule rejections. Confirm: failures by decline code, payment method, issuer country and device, before any layout change. Fix in the payment provider's settings and retry logic.
- **Exits where shipping or the total appears** → costs revealed late. Confirm: exit-poll answers and the drop at the step where costs first show. Show estimated shipping and fees in the cart; mandatory fees belong in the first price shown.
- **Exits at an account wall** → a forced account. Confirm: drop at the login or create-account step. Fix: guest checkout. Break when the order needs an account (subscriptions, digital delivery, regulated goods): create it passwordless, after payment.
- **Exits right after the coupon field** → coupon hunting. Confirm: exits to search after focusing the field. Collapse the field behind a link; apply known promotions automatically.
- **Exits at delivery options** → slow or vague delivery. Confirm: exit-poll answers by destination. Show an estimated delivery date rather than a span of business days, where carrier data allows.
- **Mobile under-converts** → partly a base rate: mobile carts are abandoned more often, and many mobile journeys finish on desktop. Confirm: compare with the device's own history and like-for-like segments before blaming the design. Fix input (address autocomplete, billing defaulting to shipping), wallets and speed where mobile still lags.

## Judgment calls

- **Wallets, BNPL and express pay**: test presence vs absence on conversion, AOV and net payment cost. Ignore user-level comparisons: wallet users self-select.
- **Recovery** needs the email, so ask for it first; send a deep link back to the exact cart, judged against a no-message holdout. Incentives only for first-time buyers or high-value carts; escalating discounts teach buyers to abandon. Triggers here; cadence and copy → copywriting.

## Never

Statutes and regulators: the copywriting capability's dark-pattern anti-catalog, if available.
- Pre-checked add-ons, insurance or donations (sneak into basket).
- Drip pricing: mandatory fees that appear only late in checkout.

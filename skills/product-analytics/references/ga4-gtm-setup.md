# GA4 & GTM Setup Guide

## Table of Contents

1. [When to Use This Reference](#when-to-use-this-reference)
2. [GA4 vs PostHog: When to Use Which](#ga4-vs-posthog-when-to-use-which)
3. [GA4 Setup Essentials](#ga4-setup-essentials)
4. [GTM: When It's Worth It](#gtm-when-its-worth-it)
5. [UTM Parameter Strategy](#utm-parameter-strategy)
6. [GA4 + PostHog Dual Setup Tips](#ga4--posthog-dual-setup-tips)
7. [Validation Checklist](#validation-checklist)
8. [Consent Mode v2 (mandatory for EEA/UK ad+measurement traffic since March 2024)](#consent-mode-v2-mandatory-for-eeauk-admeasurement-traffic-since-march-2024)
9. [Server-Side GTM (recommended for production)](#server-side-gtm-recommended-for-production)


## When to Use This Reference

Use when deciding whether to add GA4/GTM to your analytics stack, designing UTM strategy, or configuring a dual PostHog + GA4 setup. For PostHog-first stacks, GA4 is optional — use it primarily for SEO attribution and Google Ads integration where PostHog falls short.

> **EEA / UK compliance (mandatory since March 2024):** Any site serving Google ad / measurement traffic from the European Economic Area must implement **Consent Mode v2**. GA4 + Google Ads will drop data from non-consenting EEA users without it. See "Consent Mode v2" section below before going live in EU/UK.

> **Server-side GTM:** For accurate conversion tracking under post-ATT (iOS 14.5) app-tracking limits and browser tracking prevention (Safari ITP / Firefox ETP), and to reduce client-side script load, prefer **server-side GTM** for any production deployment. Client-side GTM still works for low-stakes setups.

---

## GA4 vs PostHog: When to Use Which

| Need | Use GA4 | Use PostHog |
|------|---------|-------------|
| Google Ads attribution | Yes | No (no native integration) |
| SEO traffic analysis | Yes (Search Console integration) | Partial |
| Product analytics (retention, funnels) | No | Yes |
| Session replay | No | Yes |
| Feature flags / experiments | No | Yes |
| Privacy-first (EU, no cookie banner) | No | Yes (cookieless mode) |

For most products: **PostHog is the primary analytics tool.** GA4 supplements it for acquisition channel attribution and Google ecosystem integration.

### Do You Even Need GA4?

GA4's main value comes from two integrations PostHog can't replace:
1. **Google Search Console** — Which search queries drive traffic, landing page CTR, indexing status
2. **Google Ads** — Conversion tracking for ad optimization

If you're not running Google Ads, the only reason to add GA4 is Search Console integration. Weigh that against the complexity of maintaining two analytics tools.

---

## GA4 Setup Essentials

### Key Steps

1. **Create GA4 property** at analytics.google.com — get the Measurement ID (G-XXXXXXXXXX)
2. **Install** via gtag.js snippet, GTM, or Next.js `<Script>` component
3. **Enable Enhanced Measurement** — free automatic tracking for scrolls, outbound clicks, site search, file downloads
4. **Mark key events** — toggle "Mark as key event" for `signup_completed`, `purchase` events (GA4 renamed "conversions" → "key events" in March 2024; "conversions" now means Google-Ads-side conversions only)
5. **Link Search Console** — GA4 Admin > Product links > Search Console

For SPAs (Next.js, React), the default is Enhanced Measurement's **"Page changes based on browser history events"** (on by default), which sends a `page_view` on each history change. Only if that misses your routing, turn it off and send the page view manually on route change (`page_path` in `config` is the Universal-Analytics-era pattern — GA4 reads `page_location`):
```ts
export function trackPageView(url: string) {
  if (typeof window.gtag === 'function') {
    window.gtag('event', 'page_view', {
      page_location: new URL(url, window.location.origin).href,
      page_title: document.title,
    });
  }
}
```

### Custom Events

GA4 uses the same event naming convention as PostHog (object_action, lowercase, underscores):
```js
gtag('event', 'signup_completed', { method: 'email', source: 'hero_cta' });

// Ecommerce purchase
gtag('event', 'purchase', {
  transaction_id: 'T_12345',
  value: 29.99,
  currency: 'USD',
  items: [{ item_id: 'plan_pro', item_name: 'Pro Plan', price: 29.99 }]
});
```

---

## GTM: When It's Worth It

Google Tag Manager is a container that manages all tracking scripts without code changes.

**Use GTM when:**
- Running multiple tracking tools (GA4 + PostHog + ad pixels)
- Non-technical team needs to add/modify tracking
- Complex event tracking that changes frequently

**Skip GTM when:**
- PostHog-only stack with no ad pixels
- Simple setup with just GA4 + PostHog installed via code
- Performance-critical pages where every script matters

If using GTM, add both GA4 and PostHog as tags triggered on "All Pages". Push custom events via `window.dataLayer.push()`.

---

## UTM Parameter Strategy

UTM parameters are the bridge between marketing efforts and analytics. They work in both GA4 and PostHog.

### UTM Parameter Definitions

| Parameter | Purpose | Example |
|-----------|---------|---------|
| `utm_source` | Where traffic comes from | `twitter`, `newsletter`, `google` |
| `utm_medium` | Marketing medium | `social`, `email`, `cpc`, `organic` |
| `utm_campaign` | Campaign name | `launch_2025`, `black_friday` |
| `utm_content` | Differentiates creative/links | `hero_cta`, `footer_link`, `variant_b` |
| `utm_term` | Paid search keywords | `saas_analytics`, `product_tool` |

### Naming Conventions

- All lowercase: `twitter` not `Twitter`
- Underscores for spaces: `black_friday` not `black-friday` or `black friday`
- Be specific: `blog_footer_cta` not `cta1`
- Consistent across team: document all UTMs in tracking plan

### UTM Templates by Channel

```
# Social media posts
?utm_source=twitter&utm_medium=social&utm_campaign={campaign}&utm_content={post_topic}

# Email campaigns
?utm_source=newsletter&utm_medium=email&utm_campaign={campaign}&utm_content={section}

# Paid search
?utm_source=google&utm_medium=cpc&utm_campaign={campaign}&utm_term={keyword}

# Partner/guest posts
?utm_source={partner_name}&utm_medium=referral&utm_campaign={campaign}

# Product Hunt
?utm_source=producthunt&utm_medium=referral&utm_campaign=launch_2025
```

### UTM in PostHog

PostHog automatically captures UTM parameters as person properties:
- `$initial_utm_source`, `$initial_utm_medium`, etc. (first touch)
- Available for segmentation in retention, funnels, and cohorts

Use these to segment retention by acquisition channel — organic users almost always retain better than paid.

---

## GA4 + PostHog Dual Setup Tips

Running both tools means double the tracking code but not double the work. Keep it clean:

1. **GA4 for acquisition, PostHog for product.** Don't replicate product analytics in GA4 — its retention and funnel tools are inferior to PostHog.
2. **Share event names.** Use the same event naming convention (object_action, lowercase, underscores) in both tools for consistency.
3. **UTMs bridge the gap.** GA4 captures UTM attribution automatically. PostHog captures initial UTMs as person properties. Together they give full-funnel attribution.
4. **Don't duplicate funnels.** Build acquisition funnels (visit > signup) in GA4. Build product funnels (signup > Aha Moment > retention) in PostHog.
5. **GA4 for Google Ads only.** If you're not running Google Ads, GA4's main value is Search Console integration. Consider whether that alone justifies the setup.

---

## Validation Checklist

After setup, verify everything works:

- [ ] GA4 Realtime report shows your visits
- [ ] Enhanced measurement events appear in GA4 Events report
- [ ] Custom events fire on correct triggers (use GA4 DebugView)
- [ ] Conversions are marked and recording
- [ ] Search Console is linked and showing data
- [ ] UTM parameters are captured correctly (check GA4 Traffic acquisition report)
- [ ] GTM Preview mode shows tags firing correctly (if using GTM)
- [ ] PostHog and GA4 are not double-counting (compare session counts)
- [ ] No PII leaking in event parameters
- [ ] Cookie consent banner works correctly with GTM consent mode (if required)

---

## Consent Mode v2 (mandatory for EEA/UK ad+measurement traffic since March 2024)

Without Consent Mode v2, GA4 drops EEA data from non-consenting users and Google Ads loses conversion signal — which usually shows up as a sudden 30-50% reporting drop.

**Required signals from your consent banner to Google's consent state:**

| Signal | Granted = | Denied = |
|---|---|---|
| `ad_storage` | Ads cookies allowed | No ad cookies; conversion modeling only |
| `analytics_storage` | GA cookies allowed | No analytics cookies; behavioral modeling only |
| `ad_user_data` (v2) | Send user data to Google for ads | No user data sent |
| `ad_personalization` (v2) | Personalized ads allowed | Non-personalized only |

Implementation:
- Default all to `denied` before consent
- Update to `granted` only after explicit user opt-in
- Most CMPs (Cookiebot, OneTrust, Iubenda, Termly, Klaro, Cookieyes) ship Consent Mode v2 templates for GTM
- Use **Advanced Consent Mode** (sends cookieless pings to Google for behavioral modeling); Basic Consent Mode blocks pings entirely until consent

## Server-Side GTM (recommended for production)

Why: moves tag execution off the client (better Core Web Vitals), bypasses ITP/ETP cookie limits, and gives you a server-side data-layer you control before forwarding to GA4/Ads/Meta CAPI/etc.

Setup: deploy a Server Container (Cloud Run — the default for GTM's automatic provisioning; App Engine is the legacy option; or self-host) → point your subdomain (e.g., `gtm.yourapp.com`) at it → switch your client GTM to send to the server container instead of directly to Google.

Pairs naturally with **Meta Conversions API (CAPI)** for ad attribution recovery.

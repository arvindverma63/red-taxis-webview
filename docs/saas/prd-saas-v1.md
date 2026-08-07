Red Taxi SaaS PRD – 7‑Day Trial & Pricing Adjustments
1. Purpose & Overview

This PRD updates the Red Taxi SaaS platform to:

Shorten the free trial from 14 days to 7 days, adjusting grace periods and lock‑out timelines accordingly.
Ensure it’s never cheaper to stay on a lower tier and stack add‑ons than to upgrade to the next tier.
Provide an admin panel for editing plan and add‑on prices.
Integrate Clerk.com for authentication using the ixartz SaaS boilerplate.
Launch with four plans—Solo, Team, Fleet and Enterprise—with bolt‑on bundles while noting alternative pricing models for future phases.

2. Target Users & Goals
Taxi/Mini‑cab operators ranging from small fleets (5 drivers) to large enterprise networks.
Platform administrators managing pricing and subscriptions.
Goals: deliver a self‑service signup with a risk‑free trial; maintain clear tiered pricing; prevent pricing arbitrage; enable dynamic price changes; leverage Clerk/ixartz for modern UX.

3. Pricing & Plan Structure

Plans (modifiable via admin):

Plan	Base price (monthly)	Annual price (per month)	Drivers included	Monthly bookings	Key entitlements
Solo	£199/mo	£159/mo	5 drivers	1,500 bookings	Core booking & dispatch, basic reports, driver app
Team	£389/mo	£311/mo	20 drivers	5,000 bookings	All Solo features + advanced reports, payment links, WhatsApp notifications
Fleet	£799/mo	£639/mo	50 drivers	15,000 bookings	All Team features + priority support
Enterprise	Custom	Custom	Unlimited drivers	Unlimited bookings	All Fleet features + dedicated support

A 20 % annual discount applies across all plans.

Bolt‑on bundles (Solo–Fleet plans): +5 drivers (£89/mo), +500 bookings (£60/mo), +2000 bookings (£200/mo), +5000 bookings (£400/mo), SMS packs (500 at £25/mo; 2k at £75/mo; 5k at £150/mo), Web Portal (£109/mo), Custom Domain (£65/mo), API access (£109/mo). WhatsApp is metered at ~£0.01/msg.

Fair‑pricing rule: total cost of lower tier + required bolt‑ons must always exceed the price of the next tier. For example, three driver‑add‑ons (15 drivers) plus Solo base (£466) is more than Team’s £389; pricing must be adjusted accordingly.

Alternative models such as per‑booking, hybrid (base + per booking), and per‑driver are documented for future phases. The tiered model remains the v1 launch recommendation.

4. Trial & Subscription Lifecycle (Revised)
Day 0: Signup via Clerk triggers a 7‑day trial; status ActiveTrial.
Day 4: Email & in‑app reminder (“3 days left”).
Day 5: Banner/modal (“2 days left”).
Day 7: Trial ends; enter a 3‑day grace period. Email prompts payment; modal appears at login.
Day 10: Soft lock if no payment; user has read‑only access and sees full‑screen lock message; exit survey displayed.
Day 17: Hard lock after 7 days of soft lock; no access.
Day 47: Data deletion after 30 days in hard lock; tenant record and Stripe customer archived.

These transitions (ActiveTrial→GracePeriod→SoftLocked→HardLocked→Deleted) follow the existing state machine but with adjusted dates.

5. Signup & Onboarding Flow
Pricing page: shows plan cards, cost calculator and bolt‑on toggles; “Start Free Trial” CTA.
Sign‑up form: implemented with Clerk (name, email, password, company details). Creates tenant record (status ActiveTrial, selected plan, optional bolt‑ons, trial expiry = now + 7 days).
Onboarding wizard: collects tariffs, drivers, vehicles, settings and optional payment details; progress stored in Tenant.OnboardingProgress.
Dashboard access: via subdomain dispatch.{slug}.{platformDomain}. Plans with custom domain support can map DNS names.
Subscription management: user can add payment and manage subscription through Stripe; upgrades are immediate and prorated, downgrades and add‑on removals occur at the next billing cycle.

6. Usage Metering & Limits
Bookings: increment on each CreateBooking; reset monthly; warnings at 80 % and blocks at 100 %.
SMS: decrement on send; when depleted, queue messages and prompt purchase.
WhatsApp: metered usage; billed monthly via Stripe.
Drivers: enforce maximum active drivers; deactivated drivers don’t count.

Hangfire (or similar) jobs send reminders, enforce locks, reset counters and trigger data deletion.

7. Administration & Pricing Management

Admin panel functions:

Plan & Add‑on management: create/edit plans and add‑ons (name, description, price, allowances, Stripe product IDs).
Fair‑pricing validator: ensure no combination of lower‑tier + add‑ons is cheaper than the next tier; block invalid changes.
Usage dashboard: view tenants by plan, usage statistics, revenue, churn; target upsell campaigns.
Subscription management: inspect and adjust individual tenant subscriptions (discounts, trial extensions, locks).
Content & email management: update pricing page copy, bolt‑on descriptions and email templates.
Audit logging: record admin actions with timestamps and user IDs.

When prices change, the system syncs updates to Stripe, validates fairness, leaves existing subscriptions unchanged unless migrated, and clears caches to refresh the pricing page.

8. Business Rules & Edge Cases
Upsell triggers at 80 % of quotas, driver limits, SMS depletion, prolonged Solo over‑usage, or bolt‑on costs exceeding 20 % of the next tier.
Downgrades take effect at the next billing cycle; users must remove excess drivers/bookings or bolt‑ons first.
Data is deleted 30 days after hard lock; send final reminder beforehand.
Exit survey presented at soft lock; responses stored for analysis.
Comply with GDPR/UK data laws; provide data export/delete options.
Initial launch uses GBP and UK as default currency/country.

9. Technical Considerations
Backend: ASP.NET Core with per‑tenant databases; an ITenantConnectionResolver selects the correct DB via subdomain/custom domain/JWT.
Front‑end: Next.js with Tailwind UI (ixartz boilerplate) integrated with Clerk and Stripe.
APIs: Provide POST /signup and other endpoints for booking/dispatch; update responses with usage quotas and lock status.
Background jobs: use Hangfire or equivalent for reminder emails, lock transitions, counter resets and deletion.
Data model: extend Tenant to include plan allowances, bolt‑on counts and price revision version; maintain enums for SubscriptionPlan and TenantStatus.
Security: enforce email verification; secure Stripe webhooks; prevent overposting; comply with GDPR.
10. Acceptance Criteria
New sign‑ups get a 7‑day trial; reminders and lock‑outs follow the revised timeline.
Pricing validation ensures stacking add‑ons never undercuts upgrading to the next tier.
Admin UI allows editing plans/add‑ons and enforces pricing fairness; changes propagate to Stripe.
Users can sign up via Clerk, complete onboarding and access their dispatch console; a tenant record is created and the trial starts.
Users can add payment and manage subscriptions; upgrades are immediate; downgrades occur at next billing cycle with appropriate checks.
Booking/SMS/WhatsApp/driver usage is tracked and enforced; warnings and blocks appear at defined thresholds.
Grace, soft lock, hard lock and deletion states work as specified; exit survey data is collected and retained.

11. References
Pricing tables and bundles.
Entitlement dimensions and alternative pricing models.
Trial lifecycle and tenant fields.
Execution plan for foundational tasks and Stripe integration.
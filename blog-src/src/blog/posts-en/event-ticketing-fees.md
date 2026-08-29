---
title: "Event Ticketing Fees: What Organizers Really Pay"
seoTitle: "Event Ticketing Fees: What Organizers Really Pay [2026]"
description: "A practical breakdown of every fee charged by online ticketing platforms: platform fee, payment processing, service fee. With 3 real-world scenarios and 5 levers to bring them down."
date: 2026-04-04
updated: 2026-04-19
category: "Cost analysis"
image: "/blog/assets/img/posts/commissioni-biglietteria-eventi/hero.webp"
imageAlt: "Abstract bar chart with stylized coins representing the fees charged by a ticketing platform"
toc: true
tags: ["post", "commissioni", "pricing", "costi"]
lang: en
itSlug: "commissioni-biglietteria-eventi"
relatedPosts:
  - eventbrite-alternatives
  - online-ticketing-guide
faqs:
  - q: "Why are the advertised fees different from what actually gets charged?"
    a: "Because a single transaction can involve up to 4 independent layers of fees: (1) the ticketing <strong>platform fee</strong>, (2) the <strong>payment processing fee</strong> charged by the PSP (Stripe, PayPal), (3) an optional <strong>service fee</strong> billed to the attendee as a separate line item, and (4) <strong>currency conversion</strong> on foreign payments. The final bill is the sum of all four, but pricing pages typically mention only the first one."
  - q: "Who should pay the fee: the organizer or the attendee?"
    a: "It depends on your pricing strategy. <strong>Absorbing it as the organizer</strong> keeps the price clean for the attendee (read: a lower checkout abandonment rate). <strong>Passing it on as a service fee</strong> protects your margin but can increase drop-off by 5-15% depending on the sector. For training and B2B events it's usually more profitable to absorb it; for festivals and low-ticket events, passing it on is the industry norm."
  - q: "At what monthly volume does a flat subscription beat a variable fee?"
    a: "Rule of thumb: the <strong>break-even point sits between €2,500 and €4,000 of monthly GMV</strong>. Above €4,000/month with an average ticket over €30, a flat subscription (€29–€79/month) with a direct PSP saves on average 3-5% of GMV compared to a 4-6% commission. Below €2,500/month, the variable fee is cheaper because you don't pay a subscription during low-volume months."
  - q: "Can Stripe fees be negotiated?"
    a: "Yes, above a certain volume threshold. Stripe applies its standard rate (~1.5% for EU cards) up to roughly €50,000/month of GMV. Above that threshold you can request custom pricing (typically 1.1–1.3%). The same applies to other PSPs. To get it, contact Stripe sales directly with your volume figures — it doesn't go through the ticketing platform."
  - q: "What happens to the fees in case of a refund?"
    a: "It depends on the PSP. <strong>Stripe</strong> does not return the fixed fee (€0.25) or the percentage fee on a refund — it's a dead loss for the organizer. <strong>PayPal</strong> historically returned the fee, but since 2019 it has aligned its policy with Stripe. Some ticketing platforms add a <em>refund processing fee</em> of €1-€2 per refund: check this specific point in the T&Cs before signing."
  - q: "Can I deduct ticketing fees as a business cost?"
    a: "In most jurisdictions, yes — ticketing fees are an ordinary, fully deductible operating expense (the 'third-party services' line in your income statement). The platform and the PSP issue monthly invoices you can use as proof of cost. Tax treatment and any VAT/sales-tax recovery depend on where your business and the platform are based, so confirm the specifics with your accountant."
---

> **In short:** the total cost of an online ticketing platform isn't just the monthly subscription you see on the website. There are up to four layers of fees that stack on top of each other, and the gap between the "marketing" figure and the "month-end invoice" figure can be 3-6% of your revenue. This guide breaks the bill down line by line, with three real numerical scenarios and five practical levers to cut the total in half.

---

## The 4 cost items of a ticketing platform

Let's start by putting things in order. Every time an attendee pays for a ticket, the money passes through up to **four layers of fees** before it lands in your account. Each has its own economic logic, its own beneficiary, and above all its own weight that pricing pages don't always make clear.

### 1. Platform fee

This is the fee the ticketing platform keeps for the SaaS service it provides: registration page, check-in, dashboard, support. It typically ranges between **2% and 7%** depending on the plan and volume. Some platforms don't charge it if you're on a flat subscription (that's the case with Ticketto on the Pro/Business plans).

### 2. Payment processing fee (the PSP's fee)

This is the fee charged by the Payment Service Provider (Stripe, PayPal) to actually process the payment. On standard Stripe for EU cards it's **1.5% + €0.25** per transaction. This fee is **independent** of the platform fee: you pay both.

Watch out for the **PSP-in-the-middle trick**: some ticketing platforms don't use Stripe directly but run their own aggregator gateway that keeps a 0.5-1% margin on top of Stripe. The real cost of the payment becomes 2-2.5% instead of 1.5%. It's only visible if you read the T&Cs carefully.

### 3. Service fee (charged to the attendee)

This is a fee that some platforms — Eventbrite being the best-known example — **charge to the attendee** as a separate line at checkout, on top of the ticket price. Example: €30 ticket + €2.50 service fee = €32.50 total. The organizer still receives a clean €30, but the economic cost is pushed onto the attendee. On platforms that apply it, it ranges between **2% and 5%**.

This model has upsides for the organizer (clean margin) but creates friction at checkout: it's one of the main drivers of abandonment (+5-15% compared to a single, all-in price).

### 4. Currency conversion / FX fee

If your event sells to attendees in other countries using currencies other than EUR, the PSP adds an **FX fee of 1-2%** for the conversion. On Stripe it's around 1.5% for non-EUR conversions. Negligible if your whole audience pays in your home currency, but it matters for international conventions and B2B online courses with attendees abroad.

---

## 3 real numerical scenarios

Enough theory. Here's how these percentages translate into real figures across three typical cases.

### Scenario A — B2B training course

**Setup**: 1 course per month, 100 attendees, €200 ticket. Monthly GMV €20,000.

| Item | Commission-based platform (e.g. 6% + €1 fixed) | Flat subscription + direct Stripe |
|---|---|---|
| Platform fee | €1,200 | **€79 (Pro plan)** |
| Per-ticket fixed fee | €100 | €0 |
| Stripe (1.5% + €0.25 × 100) | — | €300 + €25 = **€325** |
| **Monthly total** | **€1,300** | **€404** |
| **Effective cost on GMV** | 6.5% | 2.0% |

**Difference**: €896/month of recovered margin, or **€10,752/year**. Equivalent to the cost of a part-time junior salary or one extra corporate event per year.

### Scenario B — Corporate convention

**Setup**: 4 conventions per year, 400 attendees per event, €120 ticket. Annual GMV €192,000.

| Item | Commission-based 4.5% + €0.99 | Business subscription + Stripe |
|---|---|---|
| Platform fee | €8,640 | **€948 (12×€79)** |
| Per-ticket fixed | €1,584 | €0 |
| Stripe (1.5% + €0.25 × 1,600) | — | €2,880 + €400 = **€3,280** |
| **Annual total** | **€10,224** | **€4,228** |
| **Cost on GMV** | 5.3% | 2.2% |

**Difference**: €5,996/year saved, i.e. the cost of two executive trips or six months of ads.

### Scenario C — Music festival

**Setup**: 1 festival/year, 2,000 attendees, €35 ticket (plus a service fee on the attendee if you choose that model). GMV €70,000.

In this scenario the **checkout conversion rate** matters too. Those who pass the service fee onto the attendee (~€2-3 extra) see a 10% drop-off compared to those who absorb the fee and show a clean price.

| Item | Commission-based with service fee | Flat subscription, clean price |
|---|---|---|
| Actual sales (after drop-off) | 1,800 tickets (~€63,000 GMV) | 2,000 tickets (€70,000 GMV) |
| Fees | €0 (paid by the attendee) | €79 × 6 setup months + Stripe €1,550 = €2,024 |
| **Gross margin for organizer** | **€63,000** | **€67,976** |

Even by absorbing the fees out of your own pocket, the final margin can be **higher** thanks to lower checkout drop-off. The takeaway: always measure the whole funnel, not just the fee.

---

## Absorb or pass on: a strategic choice

Deciding where the fee lands isn't trivial. Here are the pros and cons of the two options, with guidance on when each is preferable.

**Absorbing the fee (organizer pays)**
- ✅ Displayed price = price the attendee pays → no surprises at checkout
- ✅ Higher conversion rate (up to +10-15% on tickets under €50)
- ✅ Brand transparency
- ❌ Slightly lower net margin

**Passing it on as a service fee (attendee pays)**
- ✅ Clean margin for the organizer
- ✅ Suited to large events where the cost is perceived as "standard"
- ❌ Higher drop-off at checkout
- ❌ Less clean user experience, potential brand damage

**Rule of thumb**:
- B2B training events and premium courses → **absorb** (the user expects a fixed, clear price)
- Festivals, concerts, entertainment events → **pass it on** (it's the industry norm, culturally accepted)
- Free events → not applicable (no fees)

---

## 5 concrete levers to cut the total

Actions you can take **this week** to lower the total cost, in order of impact.

1. **Switch to a flat-subscription model above €25K GMV/year.** As shown in the scenarios, the break-even point is around €25-30K of annual GMV. Above that, a flat subscription (€29-€79/month) systematically beats the variable fee.
2. **Choose a platform with a direct PSP.** If the platform uses an aggregator gateway in the middle, you're paying 0.5-1% more "for nothing". Look for solutions that connect directly to Stripe or PayPal.
3. **Negotiate custom rates with the PSP.** Above €50K GMV/month, Stripe and its competitors offer custom pricing. A call to their commercial sales team can save you 0.2-0.4% on processed volume. That's money that flows straight back into your margin, effortlessly.
4. **Optimize your hardware mix.** Every euro spent on dedicated QR scanners is a euro you don't get back. Use your staff's smartphones ([operational guide here](/en/blog/event-check-in-with-smartphone/)) and cut your TCO by hundreds of euros per event.
5. **Consider switching.** If you're using Eventbrite or a competitor with 5-7% fees, the potential one-year saving often covers the migration cost many times over. We've compared the leading [Eventbrite alternatives](/en/blog/eventbrite-alternatives/) so you have the data to decide.

---

## Flat subscription vs commission: the break-even

If there's one slide to save from this whole article, it's this one.

| Monthly GMV | Variable fee (5% avg) | Pro subscription (€29) + Stripe | Business subscription (€79) + Stripe |
|---|---|---|---|
| €1,000 | €50 | €44 | €94 |
| €2,500 | €125 | €67 | €117 |
| **€4,000** | **€200** | **€89** ⭐ | €139 |
| €10,000 | €500 | €179 | €229 |
| €25,000 | €1,250 | €404 | €454 ⭐ |
| €50,000 | €2,500 | €779 | €829 |

**How to read it**:
- Below €2,500/month: the variable fee is still cheaper
- €2,500–€4,000/month: the Pro plan starts to pay off
- **Above €4,000/month**: a flat subscription saves at least 50-60% of the cost
- Above €25,000/month: move to Business for dedicated support and higher limits

---

## Conclusion

The "marketing" price of a ticketing platform is almost always different from the real cost on your invoice. The difference lies in the 4 fee items that stack up: platform, PSP, service fee, FX. Knowing the value of each — and who really pays it — is the foundation for choosing the right platform and for negotiating better terms where possible.

If your current platform fee is above 3-4% and your volume is meaningful, switching to a flat subscription repays the migration cost in less than 2 months. Ticketto uses the flat-subscription model (€0, €29 or €79/month) with direct Stripe and **zero platform fees** — the only variable cost is the standard PSP fee. [Try Ticketto free](/app.html#signup) for two months, then run the numbers.

If you want to frame the decision within a broader framework (not just fees, but also features and compliance), start with our [online ticketing guide](/en/blog/online-ticketing-guide/).

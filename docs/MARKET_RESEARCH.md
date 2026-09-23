# What to build next, and why

Research done September 2026, after Kept was submitted. The question asked: what is genuinely
under-served, with evidence, rather than what is easy to build.

Sources are linked at the bottom. Where a claim is a judgement rather than a finding, it says so.

---

## First, the thing that changes everything

**The bottleneck is not the app. It is that nobody sees it.**

In 2020 the hard part for a solo developer was learning Swift fast enough to ship. In 2026 the
hard part is finding users after launch. Median solo-developer app income sits at nothing to a
few hundred dollars a month, and it takes twelve to eighteen months to cover build costs.

Two consequences follow, and they are the whole strategy:

1. **Pick a niche where search demand exists and the incumbents are weak.** App Store keyword
   competition is far softer than Google's, and a solo developer can realistically rank first
   for a valuable term with a few weeks of focused effort. That is the single biggest lever
   available without a marketing budget.
2. **Charge what the audience already pays.** Subscriptions earn roughly four and a half times
   the lifetime revenue of a one-time purchase, but one-time still wins for genuine utilities:
   Procreate Pocket at $4.99 is the best-selling iPad app, Wipr 2 is a top-fifteen paid iPhone
   app in the US, Things 3 sells at $9.99. The mistake is not one-time pricing. The mistake is
   $0.99, which needs sixty sales to clear fifty dollars instead of three.

## The test a niche has to pass

The most workable screen found in the research: **the top three apps rate below 4.3 stars, and
users explicitly ask for missing features in the reviews.** That combination means people are
paying, staying, and unhappy. That is a wedge. High ratings mean the incumbent is fine and you
are competing on marketing you do not have.

## Why Kept was the wrong pick

Stated plainly so the mistake is not repeated. Habit trackers are named directly in 2026
guidance as a category solo developers should stop being pointed at. Apple has also announced a
crackdown on low-quality apps in categories it considers saturated, naming dating, flashlight,
sound effects, wallpaper, simple timers and fortune telling. Habit tracking is one tier away
from that list.

The incumbents are also strong, which fails the screen above: HabitKit sits near 4.9 stars,
Streaks is an Apple Design Award winner. Kept is a good app in a category where being good is
not enough.

---

## Candidates, with what the evidence actually showed

### Rejected: RSU and equity vesting tracker

Appeared in research as under-served. It is not, any more. At least five iOS apps exist:
Vestward, RSU Tracker (Vesting & Value), Stocking, RSYou and Rovia. One of them already markets
itself as running "privately on-device with no account required", which is our exact angle
taken. Discarded.

### Rejected: low-FODMAP and IBS

Real suffering, real willingness to pay, active communities. But it fails on three counts. Low
FODMAP Diet A to Z holds 4.8 stars across 8,800 reviews, so the screen fails outright. The food
data itself is Monash-licensed, so a competing database carries accuracy and licensing risk.
And a medical diet app invites exactly the regulated-industry questions App Review just asked
about, on an account with no history. Wrong first fight.

### Rejected: freelancer quarterly tax

Crowded (Bonsai, SnapTax, Keeper, Hurdlr, QuickBooks Solopreneur, Self Employed: Income & Tax),
and tax calculation carries liability that a solo developer should not casually accept.

### Recommended: rent and expense tracking for the one-to-five property landlord

This one passes on evidence rather than vibes.

**The pain is pricing, and it is documented.** Landlordy runs $14.99 to $99.99 a month.
Landlord Studio is repeatedly described as pricey. AppFolio is called "actively a poor fit" for
landlords below 150 units, with a floor near $298 a month and a 50-unit minimum that "punishes
small portfolios". The recurring phrase across reviews is paying enterprise prices for
capabilities you do not need.

**The under-served slice is specific.** Someone with one to five rentals does not need tenant
screening, online rent collection, maintenance ticketing or a web portal. They need to know what
came in, what went out, and what goes on Schedule E in April. Every incumbent sells them a
platform when they want a ledger.

**The wedge is the one we have already proven we can build.** Pay once, works offline, no
account, nothing leaves the device. For someone tracking their own rental income that privacy
claim is not a nice-to-have, it is the pitch. It is also the exact architecture Kept already
demonstrates, so the engineering is known-good rather than speculative.

**The price should be $19.99 one-time, not $0.99.** This audience is currently paying fifteen
to a hundred dollars every month. Against that, twenty dollars once is an easy yes, and it
reframes the goal: fifty dollars is three sales, not sixty. Raising the price is a better answer
to "I need volume" than chasing volume.

**There is somewhere to tell people.** r/landlord and r/realestateinvesting are large, active,
and full of exactly this complaint. That is a real distribution channel, which Kept never had.

**Scope for a first version.** Properties and units; rent due and rent received; expenses by
Schedule E category; receipt photos; mileage; a year-end summary that exports to CSV and PDF.
No bank connections, no payments, no tenant portal. Frame it as record-keeping, never as tax
advice, which keeps it clear of the liability that sank the tax-calculator idea.

**Honest risks.** The category is finance-adjacent, so App Review will ask questions, though far
milder ones than a medical app would draw. Schedule E categories change and need a yearly check.
And the audience is smaller than a consumer category, which is the point: smaller and reachable
beats large and invisible.

### Worth knowing about, harder to reach: apps designed for people over 65

Research describes close to zero apps built for this group with large text, simple navigation,
voice-first interaction and medication reminders, against a large and growing population. The
opportunity is real. The problem is distribution: this audience does not browse the App Store,
so you are selling to their adult children, and that is a marketing problem rather than an ASO
one. Park it unless a direct channel exists.

---

## Recommendation

1. **Finish getting Kept approved.** It is nearly free now and permanently clears the
   new-account friction. Treat it as paying for review history, not as a product.
2. **Build the landlord ledger next**, at $19.99 one-time, positioned explicitly against
   monthly-subscription incumbents.
3. **Do the keyword work before writing code**, not after. Decide the exact search terms to win,
   and let those shape the name and the feature list.

## Sources

- Cubed: [Can a Solo Developer Still Make Money on the App Store in 2026?](https://blog.cubed.run/can-a-solo-developer-still-make-money-on-the-app-store-in-2026-5569fc66474f)
- AppOpportunity: [Indie App Revenue Models 2026](https://appopportunity.com/blog/indie-app-revenue-models-2026), [7 Underserved App Store Niches Worth Building In](https://appopportunity.com/blog/underserved-app-niches-2026)
- NicheMetric: [10 Underserved App Markets in 2026](https://www.nichemetric.com/blog/underserved-app-markets-2026)
- BigIdeasDB: [30 Most Profitable Mobile App Ideas for 2026](https://bigideasdb.com/profitable-mobile-app-ideas-2026)
- ASO World: [App Store Search Algorithm 2026](https://asoworld.com/insight/app-store-search-algorithm-2026-what-actually-decides-your-keyword-ranking/)
- MobileAction: [ASO keyword research in 2026](https://www.mobileaction.co/blog/aso-keyword-research/)
- AppTweak: [ASO news and App Store updates 2026](https://www.apptweak.com/en/aso-blog/app-store-optimization-news-app-store-updates)
- Landlord Studio: [7 Best Property Management Apps 2026](https://www.landlordstudio.com/blog/best-property-management-apps)
- [Landlordy pricing](https://landlordy.com/)
- RenPro: [AppFolio vs RentRedi pricing, fees and complaints](https://renpro.com/appfolio-vs-rentredi/)
- Shuk Rentals: [Property Management Software for Small Landlords 2026](https://www.shukrentals.com/learn/property-management-software-for-small-landlords)
- App Store: [Low FODMAP Diet A to Z](https://apps.apple.com/us/app/low-fodmap-diet-a-to-z/id1356683228), [Monash FODMAP Diet](https://apps.apple.com/us/app/monash-fodmap-diet/id586149216)
- App Store RSU trackers: [Vestward](https://apps.apple.com/fr/app/rsu-tracker-vestward/id6791787914), [RSU Tracker: Vesting & Value](https://apps.apple.com/us/app/rsu-tracker-vesting-value/id6797072605), [RSYou](https://apps.apple.com/us/app/rsyou-rsu-tracker/id6758635452)
- Stuff: [Best paid iPhone and iPad apps](https://www.stuff.tv/features/best-iphone-and-ipad-apps-paid/)

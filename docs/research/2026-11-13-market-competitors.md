# Competitor & market research — where MorkvaCRM should go

*Language: English · [Українська](2026-11-13-market-competitors.uk.md).*

*Researched 2026-11-13. Live web sweep (8 researchers) → adversarial re-check of the swept prices
and load-bearing claims against vendor pages (9 checkers) → completeness critic → red-team of this
report (strategy skeptic + evidence auditor). Prices are what vendor pages showed on 2026-11-13
unless marked **(3p)** = third-party capture only. Rows marked **(critic)** got a single pass, not
the adversarial re-check; Softr's price was not read from its own page. Raw research JSON is not committed; key sources
are linked inline and in §11.*

---

## 0. TL;DR — the direction

**Recommended hypothesis: "Trello-simple, Airtable-capable operations CRM for micro product
businesses" — orders → production → materials → customers on cards, with costs that calculate
themselves, a mobile app, and an AI that does the data entry for you.**

It is a **hypothesis to validate, not a proven winner**: the maker-specific demand evidence is a
handful of English threads plus our one origin customer. §8 puts a cheap validation gate first.

- **Who (beachhead):** 1–10 person make-to-order and small-batch product businesses whose order
  flow is custom or B2B — furniture, merch for companies, print, made-to-order apparel, small
  wholesale — that today run on **Trello and/or spreadsheets**. Instagram-retail sellers who live
  on Nova Poshta + messengers are a *later* target (they need integrations we don't have).
- **Market order:** decided by the gate (§8). Ukraine-first needs Ukrainian localization (the app
  is English-only today); the English-speaking maker market pays more ($20–49/mo norm) and needs
  no localization.
- **Why them:** every sales CRM assumes a B2B deal pipeline (the #1 horizontal complaint);
  maker/MRP tools have the costing logic but rigid schemas and weak mobile, the self-serve $20–49
  band is thin (Stocksmith, Inventora) and larger tools sit at $99+/mo or contracts (Katana
  contract-only, inFlow + $499 onboarding); Trello users were disrupted by the 2025 redesign and
  Airtable by its Sep 2026 acquisition. Our engine (collections + references + rollups + formulas)
  already models "material cost per unit" and an orders board.
- **Not a sales CRM.** Head-on against Pipedrive/HubSpot/Bigin we would likely lose on
  email/calendar/phone sync and $7/seat prices; against AI-native CRMs (Attio, Day.ai,
  Lightfield) on passive capture and funding; against vertical tools (Jobber, HoneyBook, Fresha)
  on payments and booking infrastructure.
- **Runner-up: offline field CRM for small route sellers / distributors** (1–10 reps). It hits
  two strong demand signals and pays 5–10× more per account than makers; it lost on **build cost
  and readiness** (maps, geocoding, check-ins before the first sale), not on demand. If the gate
  shows maker willingness to pay ≤ $10/mo, it becomes the lead.
- **Honest caveats:** the Ukrainian maker niche is **not empty** — HugeProfit (free tier,
  production module for sewing workshops) and KeyCRM (manufacturing module, $19 flat) are
  fixed-model incumbents with Nova Poshta/Prom/Checkbox integrations. And there are **two launch
  blockers** outside the product: the assistant runs on the free Gemini tier (fine for
  development, not for paying customers or EU users), and the app has no localization.

**Next three moves** (detail in §8): (1) validation gate — rebuild 3 real maker workflows in
HugeProfit/KeyCRM + 10 maker interviews; (2) date reminders + CSV/Sheets import +
finish Trello import; (3) store-published mobile release with billing, on paid Gemini.

---

## 1. Method and evidence quality

| Step | What | Result |
|---|---|---|
| Sweep | 7 segment researchers + 1 demand-side miner (Reddit, G2/Capterra cons, HN, UA reviews), live search only | 63 player rows, 15 pain points |
| Verify | 8 file skeptics re-fetched vendor pricing pages + 1 checker on 8 load-bearing claims | 198 verdicts: 148 confirmed, 33 corrected, 1 refuted, 16 unverifiable |
| Critic | Completeness critic with live checks | 18 missing players, 11 missing segments, 12 open questions |
| Red-team | Strategy skeptic + evidence auditor on this report | Fixes applied: thesis downgraded to hypothesis, launch blockers added, roadmap ranked |

Reliability notes:
- **Vendor prices are reliable.** The one refuted row (Attio "~$29/user") is fixed below.
  Unverifiable: Pipedrive (US page 403 — USD prices from two consistent captures; the EU-rendered
  vendor page shows €14/€24/€49/€69 annual), Trello (page wouldn't load — consistent across 2026
  third-party write-ups), Odoo and Zoho (geo-priced), Sitniks (403).
- **Strategy claims were the weak part** and several were corrected: offline is *not* unique
  (AppSheet, Jobber, Pipedrive mobile, Salesforce, Sortly, Map My Customers do it); cheap formulas
  are *not* unique (Grist $8 with Python formulas; Bigin Premier $12 with formula and lookup
  fields); the Ukrainian maker niche has incumbents (HugeProfit, KeyCRM).
- **Demand evidence** is mostly 2025–2026 Reddit/HN threads; several posts are possibly
  vendor-seeded (flagged where used). Treat demand as directional, not sized. No market sizing
  was done (§10).

---

## 2. Market map

| Segment | Entry price band | What wins there | Attractiveness for us |
|---|---|---|---|
| Horizontal SMB sales CRM | $7–24/seat; real tier $35–60 | Email/calendar/phone sync, pipeline UX, ecosystem | **Low** head-on; source of disappointed users |
| Flexible DB / no-code used as CRM | $5–12/seat; relational power $20–45 | Templates, polish, relations/formulas | **High** — our natural home |
| Maker / inventory / MRP | $19–49/mo micro; $99–350+/mo real | Costing logic, channel order import (Etsy/Shopify; NP in UA) | **High as a wedge**, not as an MRP |
| Ukrainian / regional CRMs | $19 flat, UAH 0–1,500/mo, free tiers common | Nova Poshta, Prom/Rozetka, messengers, Checkbox, unlimited users | **Medium** — only the maker/ops sub-niche |
| Field / outside sales | $49–109/seat; quote-only above | Maps, routes, check-ins, offline, manager visibility | **Runner-up** |
| Messenger-first & AI-native | $25–45/seat; AI on credits | Chat inbox + AI agents; passive capture | **Low** head-on; sets AI expectations |
| Vertical service (trades, freelancers, beauty, RE) | $29–79/mo solo, $149–529 teams | Payments, booking pages, telephony, AI receptionist | **Low** head-on; proves templates aren't enough |
| *Not swept, flagged by critic:* AI app builders, AppSheet/Glide, Grist/Teable, CRM-in-Gmail | $0–25 | "Build exactly my CRM" | **Threat** to watch (§6) |

---

## 3. Segments in detail

Column key: **Model** = how flexible the data is. **Off** = offline editing on mobile.
**vs us** = the line that matters for positioning.

### 3.1 Horizontal small-business CRMs

| Player | For | Model | Entry pricing | Off | AI | vs us |
|---|---|---|---|---|---|---|
| [Pipedrive](https://www.pipedrive.com/en/pricing) | 2–50 rep B2B sales teams | Fixed deals/people/orgs + custom fields | Lite $14, Growth $39, Premium $59, Ultimate $79 /seat annual **(3p)**; EU page €14/€24/€49/€69; no free plan, 14-day trial | Yes, mobile (moves, notes, activities) | AI assistant, Nova meeting intel (Sep 2026), MCP server | Best pipeline UX; can't model orders/materials |
| [HubSpot](https://www.hubspot.com/pricing/crm) | Solo → mid-market | Fixed objects; custom objects Enterprise | Free 2 users / 1k contacts; Starter $7 promo ($20 list); Pro $90 + $1,500 onboarding | No documented offline; cached access at best | Breeze, Agent Builder, credits $0.01; outcome pricing since 14 Apr 2026 | Steep tier cliff; offline idea "Not Currently Planned" |
| [Bigin (Zoho)](https://www.bigin.com/pricing.html) | 1–10 person, off spreadsheets | Fixed modules, 10/25/50 custom fields; formula/lookup fields | Free 1 user/500 rec; $7/$12/$18 annual | No offline mode per FAQ search snippet (unverified) | Zia on credits; MCP on Free | Cheapest credible rival; 31 templates, none for makers |
| [Zoho CRM](https://www.zoho.com/crm/comparison.html) | SMB willing to configure | 10 custom modules on Standard; rollups Enterprise+ | Free 3 users; Standard ≈ INR 800 (geo-priced) | Unclear | Zia agents (token-billed) | Flexible but complex, admin needed |
| [Attio](https://attio.com/pricing) | Startups, founder-led sales | Flexible objects; custom objects Pro+ | Free 3 users/3 objects; Plus $40/workspace incl. 1 user (+$35); Pro $100 (+$79); Ultra $1,000 | Real-time only | Ask Attio, agents, formulas (Pro+, Jul 2026) | Closest model; formulas and custom objects gated at $100 |
| [folk](https://www.folk.app/pricing) | Relationship teams | Contacts/companies; custom objects Premium | $24 / $48 / $80+ per member annual | Not stated | Magic fields, assistants | Custom objects at $48 |
| [Close](https://www.close.com/pricing) | Phone/email inside sales | Lead-centric | $9–19 Solo → $139 Scale (custom objects) | — | Chloe AI | Calling-first, not ops |
| [Capsule](https://capsulecrm.com/pricing/) | Small service teams | Fixed + custom fields | Free 2 users/250 contacts; $18/$36/$54 | Unverified | AI connectors (Growth+) | Automations only from $36 |
| [Less Annoying CRM](https://www.lessannoyingcrm.com/pricing) | Non-technical micro | Fixed core | $15/user, one plan | Not documented | None | Simplicity benchmark; app only since Jun 2026 |
| [Freshsales](https://www.freshworks.com/crm/pricing/) | SMB sales | Fixed | $9/$39/$59 annual; **free plan dropped Jul 2026** | — | Freddy agent $49/100 sessions | Freemium shrinking at the low end |
| [Salesforce Starter](https://www.salesforce.com/small-business/pricing/) | Small business | Fixed | $25/user; Pro Suite $100 | Yes (admin-enabled) | Agentforce | Big-brand anchor at $25 |
| [Twenty](https://twenty.com/pricing) | Technical startups | Unlimited custom objects, TS functions | Pro $9, Org $39 /user annual; self-host free | No official app | Agents, MCP | Cheap flexible schema exists — but web-only, dev-oriented |

**Takeaways:** custom objects are the upsell wall ($48–139/seat); simple cross-record rollups are
rare at entry tiers (Attio's formulas are Pro+, Zoho rollups Enterprise+). AI is credit-metered
everywhere. Email/calendar integration is likely decisive in sales-CRM bake-offs (our judgement;
no data found).

### 3.2 Flexible-database / no-code tools used as a CRM

| Player | For | Model | Entry pricing | Off | AI | vs us |
|---|---|---|---|---|---|---|
| [Trello](https://trello.com/pricing) | Simple kanban, "poor man's CRM" | Boards/lists/cards; no relations/formulas | Free (10 collaborators/workspace, 250 Butler runs); Standard $5 (custom fields, 1k runs); Premium $10 (Table view, unlimited runs) **(3p)** | Mobile only; open low-priority iOS sync bug TRELLO-1075 ("Gathering Impact") | Atlassian AI | **Our origin and #1 acquisition channel.** 2025 redesign backlash; a Trello PM: "changing Trello to become an entirely different product" |
| [Airtable](https://airtable.com/pricing) | Ops teams, moving up-market | Full relational, formulas, rollups, scripting | Free 1k rec/base; Team $20; Business $45 /editor annual | **None** (requires internet) | AI on credits, agents | Model parity target. **Acquired by Bending Spoons (closed 4 Sep 2026), layoffs Oct 2026**; Softr/Gridfox run migrate-off campaigns |
| [Notion](https://www.notion.com/pricing) | Docs-first founders | DBs with relations/rollups/formulas | Plus $10, Business $20 annual | Partial (downloaded pages) | Full AI on Business | 4,140 CRM templates; DIY CRMs "decay" (§5) |
| [monday CRM](https://monday.com/crm/pricing) | SMB sales on monday | Boards + connect/mirror columns | €12/€17/€28 /seat annual, **3-seat minimum** | Unverified | AI columns, agents | Solo pays for 3 seats; 250 automations on Standard |
| [ClickUp](https://clickup.com/pricing) | "Everything app" | Tasks + custom fields incl. rollups | Free; Core $9; Business $17 | Unverified | Brain credits | Clutter; setup burden |
| [SmartSuite](https://www.smartsuite.com/pricing) | Ops teams | Relational | $15 (min 3) / $32 (min 5) | Weak app | AI (coming) | Seat minimums |
| [Fibery](https://fibery.com/pricing) | Product/ops teams | Relational, JS automations Pro | Free ≤10 users; $12/$20/$40 | — | AI | JS automations peer |
| [Baserow](https://baserow.io/pricing) / [NocoDB](https://nocodb.com/pricing) | Self-host, devs | Relational | $10–12/user; NocoDB flat $108/mo unlimited seats | No app | AI fields / BYO key | Open-source price floor; no mobile |
| [Grist](https://www.getgrist.com/pricing/) **(critic)** | Small teams, NGOs | Relational, **Python formulas** | Free (10 members, 5k rec/doc); Pro $8 annual | — | AI assistant | Sets the formulas bar at $8 — formulas alone aren't a moat |
| [Teable](https://teable.ai/pricing) **(critic)** | Airtable-like + AI | Relational | Free 1k rows; ≈$13/seat | — | AI chat, **Telegram "IM bot" agent** | Telegram-native assistant on a flexible DB is doable |
| [Google AppSheet](https://about.appsheet.com/pricing/) **(critic)** | Workspace orgs building field apps | Apps over Sheets | $5 / $10 (included in most Workspace plans) / $20 | **Yes, background sync** | Gemini | **Kills "offline-first" as a headline**; but it's an app *builder*, not a ready CRM |
| [Glide](https://www.glideapps.com/pricing) / [Softr](https://www.softr.io/pricing) / [Zoho Creator](https://www.zoho.com/creator/pricing.html) **(critic)** | Sheet → app builders | Apps + own DB | Glide from $25/mo (2 members, 2 apps); Creator $8/user | Varies | AI builders | The "build it yourself" path for our users |

**Takeaways:** nobody combines Trello-level simplicity and mobile with Airtable-level
relations/rollups at Trello-level price. Usage caps (records, automation runs) — not seats — are
where users hit walls. Two migration windows: Trello (redesign, May 2025 — aging) and Airtable
(acquisition, Sep 2026 — fresh).

### 3.3 Small product / maker businesses

| Player | For | Model | Pricing | Off | AI | vs us |
|---|---|---|---|---|---|---|
| [Stocksmith (ex-Craftybase)](https://stocksmith.io/pricing) | Small-batch makers (now leads with cosmetics/food) | Fixed materials → recipes → batches → orders | Pro from $20; Studio $41–49; Indie $99; Business $199 | No app | Read-only AI beta on $199 | Has costing in the $20–49 band; rigid object ordering; rebrand 1 Jul 2026 (features unchanged) |
| [Katana](https://www.katanamrp.com/pricing/) | SMB manufacturers | Fixed MRP | Free 30 SKUs; then **annual contract only** | Warehouse/shop-floor apps | Forecasting, AI chat, MCP | Left self-serve; individual reviews report 4× price hikes |
| [inFlow](https://www.inflowinventory.com/) | Established wholesalers | Fixed ERP | $99–699/mo + **$499 onboarding**; AI $39/mo add-on; MCP $49/mo | Scanning app | Paid add-on | Too heavy for micro |
| [Inventora](https://inventora.com/) | Candle/soap/textile makers | Fixed maker model | $23 / $48 / $120 /mo | — | AI invoice import | Closest small-maker peer; rigid |
| [Sortly](https://www.sortly.com/) | Item tracking | Folders + 1–20 custom fields | Free 100 items; $49/$149/$299 list | **Yes** | — | Offline mobile but no costing; a review cites a "300% price increase" |
| [Zoho Inventory](https://www.zoho.com/inventory/) | E-com, light assembly | Fixed; composite items | Free; $29/$79/$129 per org | — | — | No real BOM |
| [Odoo](https://www.odoo.com/pricing) | All-in-one ERP | Modular; Studio on Custom | One app free; Standard ≈€15/user (geo) | — | Agentic AI (Custom) | Needs a consultant |
| [MRPeasy](https://www.mrpeasy.com/) | 10–200 staff manufacturers | Fixed MRP | $49–149/user | — | — | Per-user pricing pain |

**Takeaways:** usage-metered, not per-seat, is the norm here. Every tool has a fixed
materials→BOM→batch→order schema; nobody offers a free-form model at a low tier. Spreadsheets are
the real status quo — Craftybase used free apparel cost-per-unit sheets as its top of funnel.

### 3.4 Ukraine and regional

| Player | For | Model | Pricing | AI | vs us |
|---|---|---|---|---|---|
| [KeyCRM](https://keycrm.app/pricing) | UA online/Instagram/marketplace sellers | Fixed orders/leads/products; **manufacturing module** (producers, production statuses), per-product cost price; no BOM | $19/mo: 200 orders, 2k leads, 20k messages, **unlimited users**; +$9 per block; marketplace import +$19; phone-number channels $15–25 | AI call analysis | Popular local option (brand searches +48%, 2023→2025); reviews cite stability, weak customization |
| [HugeProfit](https://h-profit.com/) | Micro product sellers | Fixed; **production module for sewing workshops/handmade** (tech cards, raw-material write-off, COGS) | **Free forever** 50 sales/mo; UAH 349/799/1,499 | — | **The most direct UA rival for our origin user.** Fixed model, free tier, 40k+ users |
| [SalesDrive](https://salesdrive.ua/prices/) | High-volume e-shops | Fixed | UAH 791/mo (1–2 users); UAH 361/user (3–9) | — | "Limited customization, dated UI" (editorial) |
| [KeepinCRM](https://keepincrm.com/prices) | FOP micro-business, small producers | Fixed + production + formula fields | Free 1 user; UAH 349/extra user | — | Price change announced for 1 Dec 2026 |
| [LP-CRM](https://lp-crm.biz/) | Dropshippers, landing sellers | Fixed order-centric | $0–999/mo ladder | — | Fastest brand-search growth (+309%, small base) |
| [Uspacy](https://uspacy.ua/prices/) | UA SMB teams ≤100 (Bitrix24 replacement) | CRM + "smart objects" (user-defined entities) | Free ≤5 users; UAH 327/653 /user | Summaries; MCP (paid) | Nearest UA flexible-schema rival, team-ops oriented |
| [RO App (ex-RemOnline)](https://roapp.com.ua/) | Repair, service, made-to-order | Fixed vertical + POS | €9–29/mo (3 users) → €899 | AI replies, MCP | Service/POS niche |
| [NetHunt](https://nethunt.com/pricing) | Gmail-centric B2B | Folders (custom entities) | $24–84/user | MCP on all plans | Ukrainian team, global sales CRM |
| [Kommo](https://www.kommo.com/) | Messenger sellers | Fixed | $25/$35/$45 /user, 6-month terms | AI agents on credits | amoCRM brand searches −22% (2023→2025) |

**Takeaways:** two pricing norms — flat/usage with unlimited users (KeyCRM, HugeProfit) and
per-seat in UAH. Typical spend is put at UAH 500–1,200/mo (a single unsourced column by a CRM
co-founder). Order-heavy sellers expect Nova Poshta/Ukrposhta, Prom/Rozetka,
Instagram/Telegram/Viber, Monobank/LiqPay, Checkbox. Bitrix24 left on 1 Jun 2023, but Uspacy's
founder says the mass migration "didn't materialize" — "local origin" helps but is not decisive.
None of the local CRM pages we checked (KeyCRM, SalesDrive, HugeProfit, KeepinCRM) shows an
assistant that edits arbitrary records behind a confirm gate (absence not provable; KeyCRM's AI
chat agents found so far are third-party).

### 3.5 Field / outside sales

| Player | Pricing | Offline | Note |
|---|---|---|---|
| [Badger Maps](https://www.badgermapping.com/) | $58/$95 /user annual | **No** (KB: needs connection) | Voice-to-CRM still "Coming soon"; MCP server |
| [SPOTIO](https://spotio.com/) | Quote only; "designed for teams of 5+" | Only "Download My Day" (B2C) | DASH dictate → confirm screen → save (GA Apr 2026) |
| [Map My Customers](https://mapmycustomers.com/) | $99+ /user, 5–35 seat minimums | Yes | AI Field Agent voice debriefs |
| [SalesRabbit](https://salesrabbit.com/) | $49–75/user + paid implementation | Yes | Door-to-door |
| [Repsly](https://www.repsly.com/) / [Pepperi](https://www.pepperi.com/) | Quote, annual upfront | Pepperi yes | CPG / distribution order-taking |
| [Salesforce Maps](https://www.salesforce.com/editions-pricing/sales-cloud/salesforce-maps/) | $75–150 add-on | Yes | On top of Sales Cloud |

**Takeaways:** small distributors with 1–10 route sellers are priced out (quote-only, seat
minimums at Map My Customers) and underserved by Bigin/Pipedrive (no routing; Bigin reportedly no
offline). The pattern "dictate → AI fills fields → rep confirms" is becoming the field-AI norm
(SPOTIO DASH shipped, Map My Customers live, Badger still beta) and maps directly onto Ask
Morkva's confirm gate. Ukrainian field-sales apps (1C/BAS mobile-agent tools) were not swept.

### 3.6 Messenger-first and AI-native

| Player | Pricing | What AI does | vs us |
|---|---|---|---|
| [Kommo](https://www.kommo.com/) | $25–45/user (6-mo terms) | Chat agents move leads in WhatsApp/IG/Telegram | Messenger is where UA makers sell |
| [respond.io](https://respond.io/) / [Wati](https://www.wati.io/) / [Trengo](https://trengo.com/pricing) | $79–349/mo; $39–199/mo; €119–599/mo + €0.25–0.30/AI conversation | Inbox agents | Inbox is a product of its own — don't build |
| [Attio](https://attio.com/pricing) / [Day.ai](https://day.ai/pricing) / [Lightfield](https://lightfield.com/pricing) / [Clarify](https://www.clarify.ai/pricing) | Attio above; Day.ai $24–800/agent; Lightfield $89/user → $999–2,999/workspace (calculated fields Enterprise-only); Clarify free unlimited seats, $50/mo flat | Passive capture of email/calendar/meetings, NL query, agents | Funded ($22–116M), US B2B sales. Their moat (passive capture) we shouldn't chase |
| HubSpot Breeze / Zoho Zia / Salesforce Agentforce | Credits, per-result ($0.50/resolved chat) | Agents in workflows | AI is bundled, metered, and table stakes |

**Takeaways:** "AI that answers" is table stakes; **AI that safely acts on records with a visible
confirm step is the 2026 pattern** (Pipedrive Nova proposes updates for review, SPOTIO DASH
confirm screen). Users complain about unpredictable credit costs. MCP servers became common in
2026 (Bigin free tier, Pipedrive, Badger, Katana, inFlow, NetHunt, Uspacy, RO App).

### 3.7 Vertical service tools (for the vertical-vs-universal question)

Jobber ($29–529/mo), Housecall Pro ($59–329), HoneyBook ($29–129 + 2.7% card fees), Dubsado
($335–525/yr), Bonsai ($9–59/user), Fresha (UAH 164–246/member + marketplace fee), Square
Appointments (Free/$29/$69), Follow Up Boss ($58–833). What they really charge for is
**outside-world infrastructure** — payments, booking pages, quotes/e-sign, telephony, AI
receptionist — not their data model. Their review complaints (rigid fields, shallow reporting,
tier cliffs) are exactly our strengths, but templates alone can't replace them. Offline is no
longer rare even here (Jobber shipped offline work in Mar 2026).

---

## 4. Pricing benchmarks (what our buyer compares us with)

| Anchor | Price |
|---|---|
| Trello Standard / Premium | $5 / $10 per user (annual) **(3p)** |
| Notion Plus · Airtable Team | $10 · $20 per user |
| Bigin Express · HubSpot Starter promo | $7 per user |
| KeyCRM (UA) | $19/mo flat, unlimited users |
| HugeProfit (UA) | Free ≤50 sales/mo; UAH 349–1,499/mo |
| Typical UA CRM spend (one CRM co-founder's column, unsourced) | UAH 500–1,200/mo; one 2024 KeyCRM review calls >1,200 "one of the most expensive" |
| Maker costing tools (English market) | $20–49/mo micro; $99+ real production |
| Stated willingness to pay (Reddit) | Solo cleaner <$20/mo total (possibly promo post); print house "up to $10/mo"; chair maker "basic version free"; roofing dispatch: per-user is a "dealbreaker" (post later deleted) |

Pattern: micro buyers anchor on **$5–20 per month in total**, dislike per-seat for occasional
users, and get burned by sudden hikes (individual reviews: Sortly "300%", Katana "4×"; one
HoneyBook thread on AI-tied pricing). **Note the tension:** the makers' own stated WTP is the
lowest in the study — this is what the §8 gate must test.

---

## 5. Demand side — what users actually complain about

| # | Pain (signal) | Who | Our fit |
|---|---|---|---|
| 1 | **CRMs force a B2B sales pipeline** (strong, horizontal). Solo cleaner "gave up after two weeks because it kept asking me to set up sales pipelines I don't have" (post flagged as possible clickbait in replies) | Service, recurring-client, maker businesses | ✅ user-defined collections |
| 2 | **Maker/MTO: the CRM stops at the lead** (strong, but ~4 English threads). Order → production → delivery, cost per unit and suppliers live in Excel/Notion; chair maker wants "order status, product status (made, in the paint shop…) web+app"; print house with 60 orders/day | Custom apparel, merch, print, furniture, micro-bakery | ✅ core fit — template + calc fields |
| 3 | **DIY Notion/Airtable CRMs decay** (strong). "tried building one like 4 times… looks great… never use it" — fragile relations, no reminders, builder must maintain | Freelancers, founders, small teams | ✅ ready templates + AI setup; ⚠ needs reminders |
| 4 | **Per-seat pricing and tier paywalls** (strong) | Teams of 3–10, contractor networks | ⚠ pricing undecided (§9) |
| 5 | **Spreadsheets break** (strong): one bad sort, many editors, no reminders | Solo, micro, 4–8 person teams | ✅ import + structure |
| 6 | **"Who needs a follow-up today?"** (strong) — reminders, reorder-cycle lapse alerts | Service, distributors, founder-sellers | ❌ **scheduled/date triggers deferred** |
| 7 | **Messengers are the real CRM** (strong) — WhatsApp/Viber/Telegram/IG hold orders, CRM can't see them | Non-US SMBs incl. Ukraine | ❌ no channel integration (needs module network) |
| 8 | **Logging takes too many clicks** (strong) → shadow Excel, stale data | Sales reps | ✅ AI data entry with confirm; mobile |
| 9 | **Complexity / setup overwhelm**; Odoo/Zoho/Airtable need a consultant (strong) | Non-technical owners | ✅ if onboarding is AI-assisted + templates |
| 10 | Mobile/offline gaps in the field (medium) | Field reps, route sellers, outage-prone markets (UA) | ✅ offline-first (a strength, not a headline) |
| 11 | Vendor lock-in and disruption: redesigns, acquisitions (medium) | Trello/Airtable users | ✅ open JSON export — market it |
| 12 | UA: local CRMs pricey for single sellers, seasonal volume spikes, unstable integrations, "triggers didn't work for over a year" (medium) | UA marketplace sellers | ✅ predictable pricing, reliable automations |

**Switching triggers:** missed follow-up that cost a job (single post, top reply calls it fake);
spreadsheet corruption; a second person needs to edit; a tier paywall; renewal shows unused
features; failed rep rollout; order volume across channels outgrows memory; scaling a
make-to-order business; vendor disruption (Trello redesign, Airtable acquisition).

---

## 6. Where we stand — differentiators after verification

**Holds up:**
- **User-defined collections + references + formulas + rollups at an entry price, with a mobile
  app** (Flutter; not yet store-published, and Android/iOS builds of the automation runtime are
  not yet verified). Others gate this at $48–139/seat (Attio, folk, Close, HubSpot) or offer it
  without a real mobile app (Grist, Twenty, Baserow, NocoDB) or without a CRM out of the box
  (AppSheet, Glide).
- **Non-sales operations data** (orders, production, materials, unit cost) — no sales CRM models
  it; maker tools model it rigidly.
- **AI that acts on any card behind a confirm gate** — matches the 2026 pattern; none of the
  Ukrainian CRMs we checked shows it; maker tools have read-only or paid-add-on AI.
- **Sandboxed JS automations with a consent manifest** — rare at SMB price (Fibery Pro, Airtable
  scripting, Twenty TS functions are the peers).
- **Open data / JSON export** as an answer to lock-in fear.

**Weaker than we thought (don't headline):**
- *Offline-first* — real advantage over Airtable, Notion, Attio, Badger, Baserow (and reportedly
  Bigin); but AppSheet ($5), Pipedrive mobile, Salesforce, Jobber, Sortly, Map My Customers do
  it. Use it as a proof point for field/workshop use, not as the tagline, and not before the
  hands-on test (§10).
- *Cheap formulas* — Grist ($8, Python formulas) and Bigin Premier ($12, formula/lookup fields)
  exist; Twenty ($9) has unlimited custom objects and TS functions. The moat is the
  **combination** with mobile, templates and AI, not formulas alone.
- *"Nobody serves the Ukrainian maker"* — false: HugeProfit and KeyCRM do, with fixed models.

**Real gaps** vs what this buyer expects: reminders/date triggers; any external integration
(Telegram, Nova Poshta, Etsy/Shopify, Gmail); public intake forms; calendar view; file fields;
comments; pricing/billing; store-published mobile apps; team sharing (in progress);
**Ukrainian localization**.

**Launch blockers outside the feature list:**
- **Gemini free tier.** Staying on Spark with the free Gemini tier is a deliberate development
  choice (owner decision, 2026-11-10). The assistant defaults to `gemini-3.5-flash-lite`,
  the app's own throttle at `rpm = 12` under the free tier's 15 RPM per-project limit, and
  `dataUse = free`
  (`lib/api/assistant/assistant_config.dart`). Per the Gemini API terms, unpaid-tier content may
  be used to improve Google's products with human review, sensitive/personal data shouldn't be
  submitted, and only paid services may be offered to users in the EEA/UK/Switzerland. Cards hold
  customer personal data → paying customers need the paid tier, which means linking billing.
- **Spark plan.** Scheduled triggers, server push and a Telegram bot webhook need Cloud Functions
  on Blaze (`future-epics.md`).

**New threat the sweep missed:** AI app builders (Base44 — owned by Wix, Glide, Softr AI) and
"vibe-coded" in-house CRMs — reported by the WSJ in 2026 and visible on Reddit ("why are people
still buying instead of building"). The replies name the real costs: maintenance, security,
integrations, the builder leaving. Our answer: *describe your business → get a working,
maintained, mobile workspace* — the build-your-own experience without owning the code.

---

## 7. Direction

### 7.1 Recommended hypothesis: the operations CRM for micro product businesses

**Positioning line (draft):** *"Your workshop on cards — orders, production, materials and
customers in one place, with costs that calculate themselves. Tell the assistant what happened;
it fills the cards."* (Add "works on your phone, even offline" only after the store release and
the §10 offline test.)

**Target:** 1–10 person make-to-order and small-batch product businesses with a custom or B2B
order flow (furniture, merch for companies, print, made-to-order apparel, small wholesale) on
Trello or spreadsheets. Secondary: any small ops-heavy business whose process isn't a sales
pipeline (studios, workshops, repair).

**Why it leads (and how strong the case is):**
1. **Demand:** signals #1, #3 and #5 are horizontal (any non-pipeline small business); #2 is the
   only maker-specific signal, from about 4 English threads whose stated WTP is ≤ $10/mo or free.
   Directionally supportive, not proof.
2. **Competitors are structurally misfit:** sales CRMs don't model ops; maker tools are rigid;
   flexible DBs lack mobile or templates; UA incumbents are fixed-model.
3. **Lowest build-to-value distance:** it is what the engine already does (the apparel template
   is literally this).
4. **Acquisition windows:** Trello redesign refugees (aging) and post-acquisition Airtable users
   (fresh, but a different, English-market, higher-end buyer).
5. **Unit economics are unproven:** $5–20/mo total is plausibly compatible with Firestore +
   Gemini flash-lite costs, but launch needs Blaze and paid Gemini; measure cost per active
   workspace before fixing a price.

**How we beat HugeProfit/KeyCRM:** where their fixed model breaks — custom production stages,
made-to-order with per-unit material costing by size/color, mixed businesses — plus AI data entry
and Trello-like UX. This is **untested**; the gate (§8) tests it.

**Main risk:** for makers who sell through Instagram/Telegram and ship with Nova Poshta, the
missing waybill and messenger order intake will likely be a day-1 dealbreaker — which makes that
part of the segment overlap the rejected "UA order CRM head-on". Hence the target above starts
with custom/B2B order flows.

### 7.2 Runner-up: offline field CRM for small route sellers / distributors

**Lost on build cost and readiness, not demand.** Credibility needs a maps view, geocoding and
check-ins before the first sale, and Ukrainian distribution incumbents (1C/BAS mobile-agent apps)
were not swept. It hits two strong signals (#6 follow-ups, #8 click-heavy logging), the buyer at
1–10 reps is the owner, and it pays roughly 5–10× more per account than makers ($49–109/seat vs
$5–20 total). Badger is online-only and Bigin reportedly so; incumbents are quote-only with seat
minimums. **Re-score it after the maker gate; if maker WTP comes back ≤ $10/mo, it becomes the
lead.** Everything built for the recommended path (offline, orders, AI voice notes with confirm,
reminders) carries over.

### 7.3 Rejected

| Option | Why not |
|---|---|
| Horizontal sales CRM | Likely lose on email/calendar/phone sync; $7/seat incumbents; AI table stakes already |
| AI-native B2B sales CRM | Funded US players; passive capture is their moat |
| UA e-commerce order CRM head-on | KeyCRM/HugeProfit/SalesDrive integrations + free tiers; we'd be a worse KeyCRM |
| Vertical service (trades, beauty, RE, freelancers) | Payments/booking/telephony infrastructure; well-funded players valued at $1B+ (HoneyBook $2.4B, Fresha $1B+) |
| Personal CRM for reps | Value is passive contact sync; reps rarely pay; IT blocks |
| Messenger inbox CRM | Its own category (Kommo, respond.io); integrate a channel, don't build an inbox |

---

## 8. Roadmap implications (vs `docs/plan/future-epics.md`)

Backend tags: **[client]** = fits today's client-only Spark setup; **[Blaze]** = needs Cloud
Functions / paid plan.

### Next three, in order
1. **Validation gate** (no code). Rebuild 3 real maker workflows (apparel origin + 2 others) in
   HugeProfit and KeyCRM; interview 10 makers (UA and English). Proceed **UA-first** only if ≥ 5
   hit a break in the fixed model that we fix and ≥ 3 commit to the UAH 400–700 price; otherwise
   lead with the English maker market ($20–49 norm), or with the runner-up if maker WTP is
   ≤ $10/mo.
2. **Daily-use + acquisition basics:** **date reminders** from date fields — local
   notifications on mobile **[client]**, but they only reach users once the mobile app ships (item
   3), and on web they fire only while a tab is open (closed-tab web push needs a server
   **[Blaze]**); **CSV import** **[client]** and **Google Sheets import** **[client, plus an extra
   Sheets OAuth scope beyond sign-in]**; finish the **Trello
   import** in progress **[client]**.
3. **Launchable app:** store-published Android/iOS release (App Check, mobile build items still
   open) with **billing**; move the assistant to **paid Gemini** with per-workspace metering
   **[Blaze]**.

### After the gate (ranked; scope depends on its result)
4. **Ukrainian localization** — UI strings, number/date/UAH formats, templates and the
   assistant's prompt **[client]**. Prerequisite for UA-first.
5. **AI onboarding: "describe your business → generated collections, fields, views, sample
   cards"** — built on Ask Morkva + templates **[client + paid Gemini]**. Answers DIY decay (#3),
   setup overwhelm (#9) and the vibe-coding threat.
6. **Maker template pack** — apparel workshop (materials by color/size, production runs, cost per
   unit, orders board), print shop, furniture, small wholesale, with inventory-deduction
   automations shipped as modules **[client]**.
7. **Team sharing** (in progress) with free view/occasional users **[client]**.
8. **Module network access**, then first-party integration modules: Telegram notifications
   (outbound only is simpler; a bot that receives messages needs a webhook **[Blaze]**) → Nova
   Poshta waybill → Etsy/Shopify order import for the English market.
9. **Server-side scheduled triggers** (reorder-cycle lapse, "3 days before due" across devices)
   **[Blaze]**.
10. **Public intake / order form** that creates a card **[Blaze or hosted page]**.

### Keep, lower priority
- **Airtable import** — different buyer (ops teams, $20–45/editor), English market only.
- **Calendar view** — production schedule and due dates; after reminders.
- **File fields / Storage** — product photos and tech cards; already planned for the end.
- **Comments feed** — planned; fine after the above.
- **Dashboard view polish** — a multi-metric dashboard on top of Epic 6's roll-up objects
  (charts, period filters), if interviews show reporting is a buying reason.
- **MCP server** — common in 2026 (even Bigin's free tier); cheap credibility once Ask Morkva's
  repository-bound tools exist. Not a buying reason for makers yet.

### Push back / reshape
- **Public JS-module marketplace** → reshape into a **curated first-party module catalog**
  (integrations + maker automations). Non-developers install, they don't author. Avoids the iOS
  2.5.2 risk and the empty-marketplace problem.
- **Full formula engine** — current formulas/rollups cover the target jobs.
- **Real-time CRDT collaboration** — last-write-wins with a warning is fine for 1–10 people.
- **Admin feature flags** — build only as needed to enforce pricing tiers.

### Missing entirely from the roadmap
- **Pricing, billing and payment rail** (§9).
- **Paid Gemini + Blaze migration** with cost metering (launch blocker, §6).
- **Ukrainian localization** (if UA-first).
- **Gmail / Google Calendar context** — cheap given Google-only sign-in; only if we move toward
  sales use.
- **Marketing the export** ("your data, open JSON, any time") as an anti-lock-in message.

---

## 9. Pricing recommendation (first cut)

- **Per workspace, flat, not per seat.** Unlimited viewers; paid editors beyond the first.
  Matches UA norms (KeyCRM, HugeProfit) and the per-seat complaint.
- **Free tier:** 1 editor + unlimited viewers, a **monthly quota of new cards** (grows with the
  business, like KeyCRM/HugeProfit order quotas — unlike a total-card cap), all field types and
  calculated fields, a small AI allowance. Don't gate the data model — it's the wedge against
  Attio/folk/HubSpot.
- **Paid:** around **$9–15/month (≈ UAH 400–700 at 45.4 UAH/USD on 2026-11-13; near HugeProfit's UAH
  349–799 tiers)** per workspace — second and later editors,
  higher monthly quota, reminders/automations, AI allowance, integration modules; a higher tier
  for bigger teams. Re-price for the English market if the gate points there ($20–49 norm).
- **AI:** included allowance with a visible meter; no surprise overage.
- **Never** a seat minimum; publish prices; no sudden hikes.

To validate: Gemini (paid) + Firestore cost per active workspace at 1k/10k cards; **payment rail**
for a Ukraine-based seller — merchant of record (Paddle, Lemon Squeezy or similar) vs local
acquiring (WayForPay/LiqPay/Monobank) for UAH, and whether Stripe is available (third-party
sources say it doesn't onboard UA-registered businesses; not verified); net revenue after 15–30%
app-store fees on a $9 plan.

---

## 10. Viability check and open questions

Not done in this study — needed before committing a year of roadmap:
1. **Required scale:** target MRR ÷ $9–15 = paying workspaces needed, and the free-to-paid
   conversion that implies.
2. **Niche size:** top-down count of UA (and English-market) micro product businesses on
   spreadsheets/Trello (e.g. FOP counts × share in light manufacturing/handmade), with sources.
3. **Capacity:** realistic epics per quarter against §8; the ranked list assumes one at a time.
4. **War-time risks for UA-first:** owner/staff availability (mobilization), closures and
   relocation (EU-relocated customers bring GDPR + paid-Gemini requirements), UAH volatility,
   outages (an upside for offline, a risk for everything else).
5. **Hands-on offline test** of AppSheet, Glide, Zoho Creator, Pipedrive mobile vs ours (edit
   conflicts, sync recovery) before using offline in marketing.
6. **Distribution:** Trello/Airtable migration content, maker communities (Instagram/Telegram
   sellers, Prom/Rozetka sellers), template marketplaces, accountants. No CAC data collected.
7. **Integration order** (inside the interviews): Telegram vs Nova Poshta vs Checkbox vs Monobank.
8. **Not covered:** Ukrainian field-sales/distribution apps (1C/BAS mobile agents); Polish/Baltic
   CRMs beyond spot checks (Livespace 79–399 PLN/user/mo net; Raynet $19–48/user annual, $21–57
   monthly, 5 custom fields on entry); Microsoft Lists/Power Apps; Khatabook/Vyapar-style free
   mobile billing apps; Telegram Mini App shops; data residency/GDPR for EU buyers;
   invoicing/e-invoicing (Peppol, UA fiscal receipts) as expansion requirements.

---

## 11. Key sources

- Trello redesign: [The Register, 6 Aug 2025](https://www.theregister.com/2025/08/06/trello_redesign_as_bad_as/) ·
  [Slate, Aug 2025](https://slate.com/technology/2025/08/trello-app-update-big-tech-ai-google-microsoft-apple.html) ·
  Free cap: [Atlassian Community](https://community.atlassian.com/t5/Trello-articles/Update-on-Collaborator-Limit-for-Free-Trello-Workspaces/ba-p/2628752) ·
  Butler quotas: [Atlassian support](https://support.atlassian.com/trello/docs/butler-quotas-and-limits/) ·
  Custom fields: [Atlassian support](https://support.atlassian.com/trello/docs/using-custom-fields/) ·
  Sync bug: [TRELLO-1075](https://jira.atlassian.com/browse/TRELLO-1075)
- Airtable acquisition: [SiliconANGLE, 4 Aug 2026](https://siliconangle.com/2026/08/04/bending-spoons-acquire-productivity-software-startup-airtable-1-285b/) ·
  close: [Business Wire, 4 Sep 2026](https://www.financialcontent.com/article/bizwire-2026-9-4-bending-spoons-completes-the-acquisition-of-airtable) ·
  layoffs: [InformationWeek, 15 Oct 2026](https://www.informationweek.com/it-strategy/airtable-s-post-acquisition-layoffs-put-vendor-risk-in-focus) ·
  no offline: [Airtable support](https://support.airtable.com/docs/what-are-the-technical-requirements-for-using-airtable)
- Offline: [Pipedrive](https://support.pipedrive.com/en/article/do-the-mobile-apps-work-offline) ·
  [HubSpot idea "Not Currently Planned"](https://community.hubspot.com/t/offline-mobile-app-access/576) ·
  [Badger KB](https://www.badgermapping.com/knowledgebase/does-badger-work-offline/) ·
  [AppSheet pricing](https://about.appsheet.com/pricing/)
- AI pricing and patterns: [HubSpot outcome pricing, Apr 2026](https://www.hubspot.com/company-news/hubspots-customer-agent-and-prospecting-agent-now-you-pay-when-the-task-is-complete) ·
  [Attio formula attributes, Jul 2026](https://attio.com/changelog/2026/formula-attributes-are-here) ·
  [SPOTIO DASH confirm flow](https://support.spotio.com/hc/en-us/articles/39393147551383-DASH-Your-AI-Co-Pilot-for-Field-Sales) ·
  [Freshsales free plan removal](https://www.usagepricing.com/blueprint/activity/freshworks-2026-07-21-freshsales-free-plan-dropped) ·
  [Gemini API terms](https://aistudio.google.com/docs/terms)
- Makers: [Craftybase → Stocksmith](https://craftybase.com/blog/craftybase-is-becoming-stocksmith) ·
  [Katana pricing](https://www.katanamrp.com/pricing/) ·
  [KeyCRM manufacturing module](https://help.keycrm.app/en/orders/how-to-use-the-manufacturing-module) ·
  [HugeProfit production](https://h-profit.com/)
- Ukraine: [finance.ua brand searches 2023→2025](https://finance.ua/ua/goodtoknow/top-crm-system-ukrainy-2025-shcho-zminylosia-za-dva-roky) ·
  [Forbes UA on Bitrix24 migration](https://forbes.ua/business/vazhko-vidpustiti-36-servisiv-yakimi-ukrainski-kompanii-mozhut-zaminiti-rosiyski-1s-bitrix24-ta-yclients-velika-ta-detalna-pidbirka-27032024-19869) ·
  [epravda CRM column, Jul 2025](https://epravda.com.ua/biznes/vse-shcho-biznesu-potribno-znati-pro-crm-809464/) ·
  [KeyCRM pricing help](https://help.keycrm.app/en/first-time-using-key-crm/our-pricing-what-s-the-cost-of-using-crm)
- Demand threads (via Reddit archive): r/smallbusiness 1xgdcy5 (pipeline misfit; possibly promo),
  r/CRM 1w2mw2a (rep rebellion), r/Notion 1rwzxwg (DIY decay), r/smallbusiness 1lscdhd (chair
  maker), r/Airtable 1hy0o30 (print house), r/Notion 1u26ywg (custom apparel), r/CRM 1xg4cuu
  (WhatsApp agency), [HN Craftplan micro-bakery](https://news.ycombinator.com/item?id=46847690).

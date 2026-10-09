# App Store search strategy

Research from `scripts/keyword_research.py` (the **Keyword research** workflow), US App
Store, October 2026. For each term: total ratings of the top ten apps (a demand proxy), the
median (how established they are), and how many of the ten name the term.

| Term | Top-10 ratings | Median | Naming it | Verdict |
| --- | ---: | ---: | ---: | --- |
| calorie counter | 3.9M | 99,071 | 7/10 | Owned by MyFitnessPal, Lose It!, Cal AI. Skip. |
| meal tracker | 4.2M | 150,825 | 1/10 | Same giants. Skip. |
| macro tracker | 3.9M | 99,045 | 4/10 | Same giants. Skip. |
| protein tracker | 3.8M | 99,003 | 4/10 | Hard, but "protein" combines with other words. Subtitle. |
| food diary | 3.3M | 2,456 | 5/10 | Four of ten have under 10 ratings. **Target: subtitle.** |
| food journal | 2.5M | 4,047 | 4/10 | Two of ten under 10 ratings. Keyword "journal". |
| ai food tracker | 3.1M | 55,816 | 0/10 | Nobody names it; "ai" + "food" + "tracker" covered. |
| supplement tracker | 0.3M | 20 | 6/10 | Mostly apps with under 125 ratings. **Target: name + "tracker".** |
| vitamin tracker | 0.2M | 71 | 4/10 | Mostly tiny apps. **Target: keyword.** |
| creatine tracker | 0.1M | 2 | 6/10 | Every top app has 12 ratings or fewer. **Target: keyword.** |
| fiber tracker | 2.5M | 56 | 6/10 | Tiny apps rank. Keyword. |
| caffeine tracker | 1,306 | 17 | 9/10 | Tiny niche, trivial to rank. Keyword. |
| gut health tracker | 18,357 | 560 | 5/10 | Small apps. Keywords "gut" + "health". |

Every top-ten app across these searches is free; paid apps are rare. A $0.99 price converts
fewer browsers than "free", which is worth testing against a free download with a one-time
unlock.

## Resulting metadata (2.1)

- Name: `Fuelprint: Food & Supplements`, unchanged to keep search history.
- Subtitle: `AI Food Diary & Protein Log`.
- Keywords: `tracker,vitamin,creatine,fiber,caffeine,gut,health,calorie,counter,macro,meal,journal,water,mood`.
- Description leads with "AI food diary and supplement tracker", vitamins, creatine, and
  "Pay once. No subscription.", the clearest difference from every competitor above.

## Standing out

- **No subscription.** Every large competitor charges monthly. Say it in the promotional text
  and first line.
- **Bring your own AI.** Competitors run their own models on your data; Fuelprint sends to the
  assistant you already use, and only when you choose.
- **Paste your notes.** People who already keep a food diary in Notes can bring a month in at
  once; no other app in these results does.
- **Ratings.** In the supplement, vitamin and creatine niches, twenty good ratings is enough
  for the top three. Ask happy users from the support page and, after a few uses, with
  `SKStoreReviewController` (not yet in the app).

Re-run the workflow before each release; rankings move.

## 2.3: positioning as an AI nutrition coach and assistant

Research for "ai" terms, October 2026 (same method as above):

| Term | Top-10 ratings | Median | Naming it |
| --- | ---: | ---: | ---: |
| ai assistant | 16.2M | 276,222 | 3/10 |
| ai nutrition | 2.4M | 1,382 | 5/10 |
| ai coach | 2.0M | 2,605 | 5/10 |
| ai protein tracker | 533k | 95 | 5/10 |
| ai food log | 484k | 7,396 | 1/10 |
| ai diet coach | 459k | 6,411 | 1/10 |
| ai health coach | 439k | 2,570 | 4/10 |
| ai nutrition coach | 433k | 44 | 6/10 |
| ai diet assistant | 277k | 4,212 | 0/10 |
| ai health assistant | 276k | 7 | 4/10 |
| ai nutrition assistant | 210k | 1,492 | 3/10 |
| ai supplement tracker | 140k | 1 | 5/10 |
| ai food diary | 44k | 800 | 4/10 |

"ai assistant" alone belongs to the general chatbots. Everything nutrition- or health-specific
has small competitors, so 2.3 renames the store listing:

- Name: `Fuelprint: AI Nutrition Coach`
- Subtitle: `Food & Supplement Assistant`
- Keywords: `tracker,protein,health,diet,calorie,meal,log,diary,vitamin,creatine,voice,scanner,label,gut,glp`

"Dietitian" and "nutritionist" score well but are left out: Fuelprint is neither, and both are
protected professional titles.

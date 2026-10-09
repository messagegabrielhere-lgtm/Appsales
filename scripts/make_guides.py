#!/usr/bin/env python3
# Run on the day 2.3 is approved: the new guides describe 2.3 features (Speak, Scan label,
# Send to an AI App, Trends).
"""Writes the search-friendly guide pages in docs/guides from NEW_GUIDES, refreshes the "More
guides" list on every guide page and the home page, and rewrites sitemap.xml.

Run from the repository root: python3 scripts/make_guides.py
"""
import datetime
import html
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE = "https://messagegabrielhere-lgtm.github.io/Appsales/"
APP = "https://apps.apple.com/app/id6814644588"
ICON = SITE + "Kept/Assets.xcassets/AppIconPreview.imageset/AppIconPreview@3x.png"
TODAY = datetime.date.today().isoformat()

# Every guide, in the order the lists show them: (slug, link text).
ALL = [
    ("ai-nutrition-coach", "An AI nutrition coach that uses your own data"),
    ("ai-food-diary", "How to use AI as your food diary"),
    ("voice-food-diary", "Voice food diary: log what you eat by talking"),
    ("nutrition-label-scanner", "Nutrition label scanner: log a label from a photo"),
    ("send-food-log-to-ai", "Send your food log to ChatGPT, Grok, Claude or Gemini"),
    ("supplement-tracker", "A supplement and vitamin tracker that works with AI"),
    ("creatine-tracker", "Creatine tracker: make the daily dose stick"),
    ("bloating-food-diary", "Bloating and IBS food diary: find your patterns"),
    ("glp1-food-log", "A food log for GLP-1 medications: protein, fiber and water"),
    ("notes-food-diary", "Turn your Notes app food diary into AI insights"),
]

NEW_GUIDES = {
    "ai-nutrition-coach": {
        "title": "AI Nutrition Coach for iPhone: Ask AI About Your Own Food Log",
        "description": "An AI nutrition coach is only as good as what it knows about you. Log food, drinks and supplements in seconds, then ask AI for calories, protein, patterns and plans based on your own data.",
        "h1": "An AI nutrition coach that uses your own data",
        "body": """
<p>General AI assistants give general answers. Ask "how much protein should I eat?" and you get a range for everyone. Ask with two weeks of what you actually ate, your weight and your goal, and you get an answer about you.</p>
<h2>What makes an AI coach useful</h2>
<ul>
<li><strong>Your real log,</strong> with times: meals, drinks, supplements, workouts, sleep and how you felt.</li>
<li><strong>Your profile:</strong> age, height, weight, activity, goals, diet and medications.</li>
<li><strong>A focused question:</strong> protein, a weekly review, gut health, energy, a meal plan for tomorrow.</li>
<li><strong>Numbers you can track,</strong> so the next answer can say whether things improved.</li>
<li><strong>Your choice of AI,</strong> including one that runs privately on your phone.</li>
</ul>
<h2>On iPhone</h2>
<p><a href="../../../">Fuelprint</a> is an AI nutrition coach and food &amp; supplement assistant. Log by voice, text or a label photo, pick one of fifteen questions, and get an answer from Apple Intelligence on your iPhone, or send it to Grok, ChatGPT, Claude or Gemini. Daily calories, protein and fiber from the answer can be charted in Trends.</p>
<p class="muted">AI answers can be wrong and are not medical advice. Talk to a doctor or dietitian before changing your diet, supplements or medication.</p>
""",
    },
    "voice-food-diary": {
        "title": "Voice Food Diary: Log What You Eat by Talking (iPhone)",
        "description": "Keep a food diary by speaking. Say what you ate and drank, and it's split into entries on your iPhone, then ask AI for calories, protein and patterns.",
        "h1": "Voice food diary: just say what you ate",
        "body": """
<p>Most people quit food diaries because typing every meal is tedious. Saying it takes a few seconds: "two eggs and toast with black coffee, then five grams of creatine and a thirty minute walk."</p>
<h2>What makes a voice food log work</h2>
<ul>
<li><strong>Speak naturally.</strong> A good voice diary splits a run-on sentence into separate entries: food, drinks, supplements and activity.</li>
<li><strong>Review before saving.</strong> Speech recognition mishears things, so you should see the entries and fix any before they're added.</li>
<li><strong>Keep it private.</strong> On iPhone, speech can be recognized on the device, so your words never leave your phone.</li>
<li><strong>Log past days.</strong> Start with "yesterday" to log yesterday.</li>
</ul>
<h2>On iPhone</h2>
<p>In <a href="../../../">Fuelprint</a>, tap <strong>Speak</strong> on Today and talk through your meal or your whole day. Fuelprint turns "a Dr Pepper and 1.5 liters of water" into the right entries, recognized on your iPhone, and opens them for a quick check before you tap Add. Then Ask AI estimates calories, protein and fiber from what you said.</p>
""",
    },
    "nutrition-label-scanner": {
        "title": "Nutrition Label Scanner: Log Calories and Protein From a Photo",
        "description": "Photograph a Nutrition Facts or Supplement Facts label and log its calories, protein and doses in seconds, read privately on your iPhone.",
        "h1": "Nutrition label scanner: log a label from a photo",
        "body": """
<p>Packaged food and supplements already tell you their numbers. A label scanner reads the panel so you don't retype it, and works for anything with a label, even when a barcode database doesn't know the product.</p>
<h2>Getting a clean scan</h2>
<ol>
<li>Lay the package flat in good light and fill the frame with the Nutrition Facts or Supplement Facts panel.</li>
<li>Check the serving size: the numbers are per serving, so log two servings if you had two.</li>
<li>For supplements, check each dose was read, especially on wide panels with two columns.</li>
</ol>
<h2>On iPhone</h2>
<p>In <a href="../../../">Fuelprint</a>, tap <strong>Scan label</strong> on Today, take or choose a photo, and the calories, protein, carbs, fat, fiber or supplement doses become one line you can edit before adding. The photo is read on your iPhone and isn't saved or uploaded.</p>
""",
    },
    "send-food-log-to-ai": {
        "title": "How to Send Your Food Log to ChatGPT, Grok, Claude or Gemini",
        "description": "Get calorie, protein and pattern analysis from the AI you already use. How to send a food and supplement log to ChatGPT, Grok, Claude or Gemini on iPhone.",
        "h1": "Send your food log to ChatGPT, Grok, Claude or Gemini",
        "body": """
<p>General AI assistants are good at estimating calories and protein from plain descriptions and spotting patterns across weeks of food, sleep and mood. They need two things from you: a clean log, and a clear question.</p>
<h2>What to send</h2>
<ul>
<li><strong>Dates and times</strong> for each meal, drink, supplement and workout.</li>
<li><strong>A short profile:</strong> age, height, weight, goals and anything relevant like medications or allergies.</li>
<li><strong>One question,</strong> such as "estimate my daily protein" or "what's different on days I feel bloated?"</li>
<li><strong>A request for numbers in a fixed format,</strong> so you can chart them afterwards.</li>
</ul>
<h2>Getting it into the app</h2>
<p>Assistant apps often open on an empty chat when you follow a link, so the most reliable way on iPhone is the share sheet: share the text and pick the Grok, ChatGPT, Claude or Gemini app, and it arrives in the message box. Very long logs work best as a text file the assistant can read.</p>
<h2>On iPhone</h2>
<p><a href="../../../">Fuelprint</a> builds the prompt for you: pick a period from today to all time, pick one of fifteen questions, and tap <strong>Send to AI</strong>, then <strong>Send to an AI App</strong>. When the answer comes back, copy it and tap Paste to chart its daily calories, protein and fiber in Trends. Fuelprint is not affiliated with these AI services.</p>
""",
    },
    "bloating-food-diary": {
        "title": "Bloating and IBS Food Diary: Find Your Patterns With AI",
        "description": "A bloating and IBS food diary that's quick enough to keep. Log meals, drinks and symptoms, then ask AI what your worst days have in common.",
        "h1": "Bloating and IBS food diary: find your patterns",
        "body": """
<p>Doctors and dietitians often ask people with bloating or IBS to keep a food and symptom diary for a few weeks. The hard part is keeping it up, and then making sense of it.</p>
<h2>What to write down</h2>
<ul>
<li>Everything you eat and drink, with rough times. Portions help but aren't essential.</li>
<li>How you feel and when: bloating, pain, digestion, energy, on a simple scale.</li>
<li>Sleep, stress, alcohol, coffee and supplements, which often matter as much as food.</li>
</ul>
<h2>Finding patterns</h2>
<p>After two to four weeks, compare your worst days with your best ones. An AI assistant can read a month of entries at once and list foods, timings or habits that show up before bad days. Treat what it finds as questions to take to your doctor or dietitian, not a diagnosis.</p>
<h2>On iPhone</h2>
<p>In <a href="../../../">Fuelprint</a>, log meals by typing, speaking or pasting a list, and rate how you feel with a tap. The <strong>Gut health</strong> question in Ask AI sends your log to the assistant you choose, and the <strong>Doctor visit summary</strong> gives you something to bring to your appointment.</p>
<p class="muted">Not medical advice. See a doctor about ongoing digestive symptoms, and urgently for blood in your stool, weight loss you can't explain, or severe pain.</p>
""",
    },
    "glp1-food-log": {
        "title": "Food Log for GLP-1 Medications: Track Protein, Fiber and Water",
        "description": "Eating less on a GLP-1 medication makes protein, fiber and water easier to miss. A simple food log helps you and your doctor see what you're actually getting.",
        "h1": "A food log for GLP-1 medications",
        "body": """
<p>People taking GLP-1 medications often eat much less, which makes it easier to fall short on protein, fiber and fluids without noticing. Many care teams suggest keeping a simple record of what you eat and drink.</p>
<h2>What's worth tracking</h2>
<ul>
<li><strong>Protein</strong> at each meal, since smaller meals can leave you short.</li>
<li><strong>Fiber and water,</strong> which affect digestion.</li>
<li><strong>How you feel</strong> after meals: fullness, nausea, energy.</li>
<li><strong>Supplements</strong> your doctor has recommended, if any.</li>
</ul>
<h2>On iPhone</h2>
<p>In <a href="../../../">Fuelprint</a>, log meals in a few words, by voice, or by scanning a label, and add water with one tap. Ask AI's <strong>Protein check</strong> and <strong>Nutrition estimate</strong> questions estimate your daily protein, fiber and calories, and Trends charts them over time. Add your medication to My Profile so answers take it into account.</p>
<p class="muted">Not medical advice. Follow your prescriber's guidance on diet, and talk to them before changing what you eat or taking new supplements.</p>
""",
    },
}


def more_guides(current, prefix):
    items = "\n".join(
        f'    <li><a href="{prefix}{slug}/">{html.escape(text)}</a></li>'
        for slug, text in ALL if slug != current
    )
    return f"  <h2>More guides</h2>\n  <ul>\n{items}\n  </ul>"


def page(slug, guide):
    url = f"{SITE}docs/guides/{slug}/"
    title = html.escape(guide["title"])
    description = html.escape(guide["description"])
    ld = json.dumps({
        "@context": "https://schema.org", "@type": "Article", "headline": guide["title"],
        "description": guide["description"], "publisher": {"@type": "Organization", "name": "Pioneer I LLC"},
        "datePublished": TODAY, "mainEntityOfPage": url,
    })
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="{description}">
<link rel="canonical" href="{url}">
<meta name="apple-itunes-app" content="app-id=6814644588">
<meta property="og:type" content="article">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{description}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{ICON}">
<link rel="stylesheet" href="../../_style.css">
<script type="application/ld+json">{ld}</script>
</head>
<body>
<main>
  <p class="muted"><a href="../../../">Fuelprint</a> · Guides</p>
  <h1>{html.escape(guide["h1"])}</h1>
{guide["body"].strip()}
  <p><a class="button" href="{APP}">Get Fuelprint on the App Store</a></p>
{more_guides(slug, "../")}
  <footer class="muted">© 2026 Pioneer I LLC · <a href="../../privacy/">Privacy policy</a> · <a href="../../support/">Support</a></footer>
</main>
</body>
</html>
"""


LIST_PATTERN = re.compile(r"  <h2>More guides</h2>\n  <ul>\n.*?\n  </ul>", re.S)


def main():
    guides = ROOT / "docs" / "guides"
    for slug, guide in NEW_GUIDES.items():
        folder = guides / slug
        folder.mkdir(parents=True, exist_ok=True)
        (folder / "index.html").write_text(page(slug, guide))

    for slug, _ in ALL:
        path = guides / slug / "index.html"
        text = path.read_text()
        new = LIST_PATTERN.sub(lambda _: more_guides(slug, "../"), text)
        path.write_text(new)

    home = ROOT / "index.html"
    text = home.read_text()
    items = "\n".join(f'    <li><a href="docs/guides/{slug}/">{html.escape(t)}</a></li>' for slug, t in ALL)
    text = re.sub(r'(    <li><a href="docs/guides/[^\n]*</li>\n)+', items + "\n", text, count=1)
    home.write_text(text)

    urls = [("", "1.0"), ("docs/support/", "0.6"), ("docs/privacy/", "0.4")]
    urls += [(f"docs/guides/{slug}/", "0.7") for slug, _ in ALL]
    lines = [f"  <url><loc>{SITE}{path}</loc><lastmod>{TODAY}</lastmod><priority>{p}</priority></url>" for path, p in urls]
    (ROOT / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + "\n".join(lines) + "\n</urlset>\n")


if __name__ == "__main__":
    main()

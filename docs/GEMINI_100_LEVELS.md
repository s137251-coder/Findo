# One hundred levels

A design and a prompt for taking Findo from twenty levels to a hundred.

Levels 1 to 20 are already specified — see `GEMINI_PROMPTS.md` (1–10) and
`GEMINI_LEVELS_11_20.md` (11–20). This document covers the eighty that follow,
and it re-thinks what "harder" means, because the lever the first twenty levels
used runs out at level 20.

---

## Read this before generating anything

Three facts decide the whole design. Two are limits the real artwork already
exposed; the third will decide how the game ships.

### She cannot get any smaller than 68 px

A standing figure is about a third as wide as she is tall. At 66 px her tap
target is 23 px wide and `tool/level_data.py` rejects the level, because a
finger is not a mouse pointer. Levels 17 to 19 already sit on that floor.

So from roughly level 40 onward, **shrinking her is not available**. Difficulty
has to come from somewhere else.

### She cannot hide *behind* anything

The map ships without her and the game draws her on top of it at run time. That
is what lets a level hide her somewhere new on a replay — but it also means she
is never occluded. No crate in front of her, no half-hidden-behind-a-pillar.
Every hiding place shows her whole.

So difficulty cannot come from occlusion either.

### What is left — and it is enough

| Lever | How it scales | Ceiling |
| --- | --- | --- |
| Crowd size | 180 → 900 figures | legibility |
| **Decoys** | 0 → 18 near-misses | this is the main lever |
| Palette camouflage | neutral → yellow- or violet-dominant scenes | one accent per scene |
| Ambient light | daylight → dusk → night, with her tinted to match | `--tint` caps at 0.55 |
| Clock | 150 s → 45 s | frustration |

**Decoys are the idea this document turns on.** A decoy is a figure who shares
*one* of her three signatures — brown braids, a yellow sleeveless top, a violet
skirt — or, later, *two*. Never all three. A crowd with fourteen one-trait and
three two-trait decoys is genuinely hard to search at any figure size, because
every glance lands on something that is almost right. That is how a printed
Where's-Wally page stays hard on a page you can see all of at once.

### The size problem you will hit before level 100

Nineteen maps are 18.5 MB. A hundred would be about **98 MB of maps**, and the
signed bundle would go from 72.8 MB to roughly **150 MB**.

Play's install-time limit is 200 MB, so it would be *accepted* — but a 150 MB
download costs you installs, and on a metered connection it costs you a lot of
them. Two ways out, in order of preference:

1. **Play Asset Delivery.** Ship the first 20–25 levels in the base bundle
   (~80 MB) and the rest as on-demand asset packs, fetched when the player
   reaches them. This is the right answer and it is real work — Flutter needs
   the packs wired up and the level loader taught to wait on a download.
2. **Compress harder.** Dropping WebP quality from 92 to 86 takes roughly a
   third off with little visible loss at these palettes. Worth about 30 MB.
   Cheap, and not enough on its own.

Decide this before generating eighty images, not after.

---

## The ladder

Ten bands of ten. Her height is fixed at 68 px from band 5 on; from there the
crowd figures shrink to match her, so she is exactly the same size as everyone
around her.

| Band | Levels | Crowd | Figure size | Findo | 1-trait decoys | 2-trait decoys | Light | Time |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 1–10 | 180–300 | 1/16 | 130 → 108 px | 0 | 0 | day | 150 → 130 s |
| 2 | 11–20 | 320–420 | 1/18 | 106 → 92 px | 2 | 0 | day, one dusk | 130 → 115 s |
| 3 | 21–30 | 440–520 | 1/20 | 90 → 82 px | 4 | 0 | day | 115 → 105 s |
| 4 | 31–40 | 540–600 | 1/22 | 80 → 74 px | 6 | 1 | day | 105 → 100 s |
| 5 | 41–50 | 620–680 | 1/26 | 72 → 68 px | 8 | 1 | day | 100 → 95 s |
| 6 | 51–60 | 700–760 | 1/30 | 68 px | 10 | 2 | day, indoor | 95 → 90 s |
| 7 | 61–70 | 780–840 | 1/30 | 68 px | 12 | 2 | **yellow-dominant** | 90 → 85 s |
| 8 | 71–80 | 860–900 | 1/30 | 68 px | 14 | 3 | **violet-dominant** | 85 → 75 s |
| 9 | 81–90 | 900 | 1/30 | 68 px | 16 | 3 | dusk and night | 75 → 65 s |
| 10 | 91–100 | 900 | 1/30 | 68 px | 18 | 4 | night, both accents | 65 → 45 s |

At 1/30 of a 2048 px map every figure is 68 px tall and about 23 px wide. Nine
hundred of them fill about a third of the canvas, which is as dense as the
style stays readable. Past band 6 the crowd stops growing and the **decoys**
carry the ramp.

Bands 7 and 8 are where the palette does the work: a sunflower field makes a
yellow top ordinary, a lavender festival makes a violet skirt ordinary. Neither
scene needs a single extra person to be much harder than the one before it.

---

## The master prompt

Paste this **once per session**, then ask for images one at a time by replying
with a level number. Ten per session — one band — then start a fresh session and
paste it again. Image models drift over a long conversation, and a band is the
natural unit because its parameters do not change within it.

Replace the four bracketed values from the ladder table above.

```
You are producing artwork for a mobile hidden-object game called Findo. It
works like a printed "Where's Wally" book: each level is one big crowded scene,
and one specific girl is hidden somewhere in it. The player pans and
pinch-zooms to find her.

HOW WE WILL WORK
Generate exactly ONE image per reply, and nothing else. No commentary, no
description, no alternatives. I will reply with the next level number when I am
ready. Keep every rule below identical across every image so that all of them
read as pages from the same book.

STYLE - identical in every image
Flat vector illustration. High-angle three-quarter aerial view, looking down at
roughly 55 degrees, so both the ground and the fronts of buildings are visible.
Every object and every person drawn with a uniform thick black outline of the
same weight. Solid flat colour fills only: no gradients, no airbrushing, no
soft shading, no photographic texture, no drop shadows, no glow, no blur, no
depth of field. Saturated but not neon. Crisp, clean linework.

CANVAS
Square 1:1 aspect ratio. The highest resolution you can produce, 2048 x 2048 or
larger. The illustration fills the entire square edge to edge: no border, no
frame, no vignette, no margin, no white edge.

CROWD
About [CROWD] small cartoon people, each drawn full body, each roughly one
[FRACTION] of the image height. Wide variety of skin tones, hair colours,
hairstyles and clothing colours. Spread evenly across the entire image with
small gaps between them: never overlapping, never clustered into one half,
never leaving a large empty area. Fill the frame right to the edges.

POSES - every figure is doing something
No two people share the same pose. Each is doing something that belongs to this
particular place. Vary which way they face: some towards the viewer, some away,
some in profile. Vary build, age and height. Put small interactions between
pairs and groups, so the crowd reads as a real moment rather than a field of
figures.

Keep about a third of them simply standing or walking normally, mixed evenly in
among the rest, so that a person standing still is an ordinary sight in the
scene and not the one thing that catches the eye.

NEAR-MISSES - this is what makes the level hard
The girl the player hunts for has three signatures together: brown hair in two
braids, a bright yellow sleeveless top, and a violet skirt. She is NOT in these
images. What the crowd needs instead is people who are almost her.

Include about [ONE_TRAIT] figures who have EXACTLY ONE of those three
signatures and nothing else in common with her. For example: a woman with brown
braids in a green dress. A man in a yellow sleeveless top. A child in a violet
skirt and a grey jumper. Spread them across the whole image, not in a group.

Include about [TWO_TRAIT] figures who have EXACTLY TWO of the three, and
clearly not the third. For example: brown braids and a yellow top, but blue
trousers. A yellow top and a violet skirt, but short blonde hair.

NEVER draw a figure with all three together. That figure is added by the game,
not by you, and a second one in the artwork breaks the level.

Every purple in this image must be a visibly different purple from hers: plum,
magenta, lilac, indigo, mauve. Never the exact mid violet of her skirt. Two
shades of purple that read as the same colour will be corrected away
automatically and the near-miss will be wasted.

SCENE
[SCENE]

DO NOT INCLUDE
No text, letters, numbers, written signs, logos, signatures or watermarks
anywhere in the image. No figure carrying all three of her signatures.
```

### For bands 7 and 8, add this

Band 7 (yellow-dominant) — append to SCENE:

```
The scene's dominant colour is yellow: the ground, the produce, the awnings and
the vehicles are yellows and golds, so that a single yellow garment is an
ordinary sight here rather than something that catches the eye.
```

Band 8 (violet-dominant) — append to SCENE:

```
The scene's dominant colour is purple: the flowers, the fabric, the light and
the painted surfaces are purples and mauves, so that a single purple garment is
an ordinary sight here rather than something that catches the eye. Keep every
one of those purples visibly different from a mid violet.
```

### For bands 9 and 10, add this

```
LIGHT
Evening. The whole scene sits under a low warm or cool ambient light, with
lamps, lanterns, screens or fires as the light sources. Still flat colour, no
glow and no blur: darkness is painted as darker flat fills, not as shading. The
crowd stays fully readable.
```

Register those levels with `--tint 0.5` so Findo is lit like the scene she
stands in. A daylit figure dropped into a night scene is the brightest thing on
the map, which would make the hardest level the easiest.

---

## The hundred scenes

Levels 1 to 19 are built. Eighty-one to generate, starting with the Fishing
Docks that level 20 has been waiting on.

Each row becomes the `[SCENE]` block. Write it as two or three sentences of
specific things a person could be doing there, the way the Fishing Docks
example in `GEMINI_LEVELS_11_20.md` does — that specificity is what makes the
poses vary, and a scene described in one flat noun phrase comes back as a field
of identical figures.

The per-level numbers are in `tool/levels.csv`; these tables are the names and
the ids, so you know what you are asking for and what to call the file.

### Band 3 — levels 21 to 30 · 440–520 people · 1/20 · 90→82 px · 4 decoys · 115→105 s

| # | Level | id | name key |
| --- | --- | --- | --- |
| 21 | Rooftop Pool | `level_21` | `level.rooftop` |
| 22 | Botanical Glasshouse | `level_22` | `level.glasshouse` |
| 23 | Ski Resort Base | `level_23` | `level.skibase` |
| 24 | Public Library | `level_24` | `level.library` |
| 25 | Farmers Market | `level_25` | `level.farmers` |
| 26 | Skate Park | `level_26` | `level.skatepark` |
| 27 | The Aquarium | `level_27` | `level.aquarium` |
| 28 | Cathedral Square | `level_28` | `level.cathedral` |
| 29 | Bus Depot | `level_29` | `level.busdepot` |
| 30 | Water Park | `level_30` | `level.waterpark` |

### Band 4 — levels 31 to 40 · 540–600 people · 1/22 · 80→74 px · 6+1 decoys · 105→100 s

| # | Level | id | name key |
| --- | --- | --- | --- |
| 31 | Amusement Arcade | `level_31` | `level.arcade` |
| 32 | Garden Nursery | `level_32` | `level.nursery` |
| 33 | Container Port | `level_33` | `level.port` |
| 34 | Textile Bazaar | `level_34` | `level.bazaar` |
| 35 | Bowling Alley | `level_35` | `level.bowling` |
| 36 | Fire Station Open Day | `level_36` | `level.firestation` |
| 37 | Cattle Auction | `level_37` | `level.auction` |
| 38 | Flower Auction Hall | `level_38` | `level.floralhall` |
| 39 | Recycling Depot | `level_39` | `level.recycling` |
| 40 | Baggage Hall | `level_40` | `level.baggage` |

### Band 5 — levels 41 to 50 · 620–680 people · 1/26 · 72→68 px · 8+1 decoys · 100→95 s

| # | Level | id | name key |
| --- | --- | --- | --- |
| 41 | Marching Band Parade | `level_41` | `level.parade` |
| 42 | Open-Air Cinema | `level_42` | `level.opencinema` |
| 43 | Cycling Criterium | `level_43` | `level.criterium` |
| 44 | Balloon Meet | `level_44` | `level.balloons` |
| 45 | The Dog Show | `level_45` | `level.dogshow` |
| 46 | Kite Festival | `level_46` | `level.kites` |
| 47 | Regatta Quayside | `level_47` | `level.regatta` |
| 48 | Ice Rink Gala | `level_48` | `level.icerink` |
| 49 | Motor Show | `level_49` | `level.motorshow` |
| 50 | Street Food Alley | `level_50` | `level.streetfood` |

### Band 6 — levels 51 to 60 · 700–760 people · 1/30 · 68 px · 10+2 decoys · 95→90 s

| # | Level | id | name key |
| --- | --- | --- | --- |
| 51 | Store Atrium | `level_51` | `level.atrium` |
| 52 | The Casino Floor | `level_52` | `level.casino` |
| 53 | Convention Centre | `level_53` | `level.convention` |
| 54 | Climbing Gym | `level_54` | `level.climbing` |
| 55 | Engine Roundhouse | `level_55` | `level.roundhouse` |
| 56 | Cruise Ship Deck | `level_56` | `level.cruise` |
| 57 | Theatre Auditorium | `level_57` | `level.theatre` |
| 58 | Trampoline Park | `level_58` | `level.trampoline` |
| 59 | Lecture Hall | `level_59` | `level.lecture` |
| 60 | Wholesale Fish Hall | `level_60` | `level.fishhall` |

### Band 7 — levels 61 to 70 · 780–840 people · 1/30 · 68 px · 12+2 decoys · **yellow-dominant** · 90→85 s

| # | Level | id | name key |
| --- | --- | --- | --- |
| 61 | Sunflower Festival | `level_61` | `level.sunflower` |
| 62 | Harvest Fair | `level_62` | `level.harvest` |
| 63 | Corn Maze | `level_63` | `level.cornmaze` |
| 64 | Taxi Rank | `level_64` | `level.taxirank` |
| 65 | Roadworks Junction | `level_65` | `level.roadworks` |
| 66 | Beekeepers Fair | `level_66` | `level.bees` |
| 67 | Lemon Grove Market | `level_67` | `level.lemongrove` |
| 68 | School Bus Depot | `level_68` | `level.schoolbus` |
| 69 | Marigold Temple Fair | `level_69` | `level.marigold` |
| 70 | Desert Rally Camp | `level_70` | `level.rally` |

### Band 8 — levels 71 to 80 · 860–900 people · 1/30 · 68 px · 14+3 decoys · **violet-dominant** · 85→75 s

| # | Level | id | name key |
| --- | --- | --- | --- |
| 71 | Lavender Festival | `level_71` | `level.lavender` |
| 72 | Jacaranda Boulevard | `level_72` | `level.jacaranda` |
| 73 | Neon Arcade Alley | `level_73` | `level.neonalley` |
| 74 | Grape Harvest | `level_74` | `level.grapes` |
| 75 | Amethyst Mine Tour | `level_75` | `level.amethyst` |
| 76 | Twilight Beach Concert | `level_76` | `level.beachgig` |
| 77 | The Orchid Show | `level_77` | `level.orchid` |
| 78 | Purple Carnival | `level_78` | `level.purplecarnival` |
| 79 | Blackberry Market | `level_79` | `level.blackberry` |
| 80 | Violet Hour Promenade | `level_80` | `level.promenade` |

### Band 9 — levels 81 to 90 · 900 people · 1/30 · 68 px · 16+3 decoys · **dusk and night** · 75→65 s

| # | Level | id | name key |
| --- | --- | --- | --- |
| 81 | Lantern River Festival | `level_81` | `level.lanterns` |
| 82 | Fireworks Embankment | `level_82` | `level.fireworks` |
| 83 | The Night Zoo | `level_83` | `level.nightzoo` |
| 84 | Midnight Bazaar | `level_84` | `level.midnightbazaar` |
| 85 | Winter Light Trail | `level_85` | `level.lighttrail` |
| 86 | Harbour at Dusk | `level_86` | `level.duskharbour` |
| 87 | Drive-in Cinema | `level_87` | `level.drivein` |
| 88 | Floodlit Ski Slope | `level_88` | `level.nightski` |
| 89 | Torchlit Procession | `level_89` | `level.procession` |
| 90 | Airport at Night | `level_90` | `level.nightairport` |

### Band 10 — levels 91 to 100 · 900 people · 1/30 · 68 px · 18+4 decoys · **night, both accents** · 65→45 s

| # | Level | id | name key |
| --- | --- | --- | --- |
| 91 | New Year Countdown | `level_91` | `level.countdown` |
| 92 | Carnival Finale | `level_92` | `level.carnivalfinale` |
| 93 | Rush Hour Concourse | `level_93` | `level.rushhour` |
| 94 | Cup Final, Night | `level_94` | `level.cupfinal` |
| 95 | The Midnight Sale | `level_95` | `level.midnightsale` |
| 96 | Pilgrimage Bridge | `level_96` | `level.pilgrimage` |
| 97 | Rooftop Festival | `level_97` | `level.rooftopfest` |
| 98 | Floating Market | `level_98` | `level.floatingmarket` |
| 99 | Ice Palace Gala | `level_99` | `level.icepalace` |
| 100 | The Great Crowd | `level_100` | `level.greatcrowd` |

---

## Registering them

The whole ladder lives in **`tool/levels.csv`** — one row per level, all one
hundred, with the height, time limit and tint each one wants alongside the
crowd size and decoy counts the prompt needs. It was generated rather than
typed, because a hundred rows of interpolated numbers is exactly the table
where one transposed digit hides for weeks.

Save each scene into one folder, named after its level id — `level_21.png`,
`level_22.jpg` — and then it is one command:

```powershell
python tool/build_all_levels.py --scenes C:\temp\findo\scenes
```

It builds every level whose artwork has arrived, skips the ones already
registered, and lists the ones still waiting. Re-run it as images trickle in.

```powershell
# just one band
python tool/build_all_levels.py --scenes C:\temp\findo\scenes --only 21-30

# see what it would do, build nothing
python tool/build_all_levels.py --scenes C:\temp\findo\scenes --dry-run

# rebuild levels that are already registered
python tool/build_all_levels.py --scenes C:\temp\findo\scenes --rebuild
```

**Build the levels in order.** The unlock chain runs on consecutive indexes, so
a level with a hole before it cannot be reached. If you build 21 before 20
exists, the map and its metadata are written and kept, but the level is held
out of `index.json` and the runner says so; it joins the game the moment the
gap is filled. Nothing is lost either way — it just will not appear yet.

The eighty new level names are already in `assets/locales/`, in English and
Hebrew. The localisation test fails the build if a registered level has no
name, which is the behaviour you want.

Afterwards, look at `store/previews/level_NN_spot*.png` — one crop per hiding
place. That is how you catch a scene where the tool found somewhere a person
would not stand, or where the crowd around her happens to include a near-twin
that reads as a genuine second Findo.

---

## What else a hundred levels needs

Generating the art is the visible half. These are the rest, and none of them
are large on their own:

- ~~**160 level names.**~~ Done — the eighty new names are in
  `assets/locales/en.json` and `he.json`.
- **The level list becomes a scroll of a hundred rows.** It wants grouping by
  band, with a header per band and a completion count, or it becomes unusable
  around level thirty.
- **Star totals and progression.** With a hundred levels, a total-stars figure
  and a per-band summary are worth more to a player than a single unlock chain.
- **Play Asset Delivery**, per the size section at the top.

---

## Honest expectations

Eighty images at one per reply is eight sessions of ten. Expect roughly one in
six to come back unusable — the wrong aspect ratio, a crowd bunched into one
half, text baked into a sign, or a figure wearing all three signatures. The
first twenty levels needed exactly that kind of triage: two scenes were never
produced at all, one came back twice, and one arrived as a hospital with a
classroom wing in it.

Budget for a hundred and ten generations to land a hundred maps, and check the
previews for every one.

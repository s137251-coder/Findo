# Findo — art brief

Everything needed to draw the twenty level maps and the character hidden in them,
without opening the code. Numbers here are not preferences: they are what the
game measures, and `tool/level_data.py` rejects work that misses them.

---

## 0. How the game uses what you deliver

One map per level. **Findo is part of the map artwork before the game ever sees
it** — the game never composites her at runtime. It is handed a rectangle saying
where she ended up and puts an invisible hit area there.

There are two ways she gets into the artwork, and the game cannot tell them
apart:

- **An illustrator draws her in.** Preferred. You can tuck her behind a
  lamppost, light her like the rest of the scene, and draw her in the same hand
  as everyone else. Then hand over her bounding box.
- **The tool pastes her in.** What happens with generated scenes, where the
  model is asked to leave her out entirely: `tool/build_level.py` places the
  master at the size the level calls for and records the box itself. She is
  then pixel-identical everywhere, at the cost of no occlusion and no
  scene-specific lighting.

The player sees the whole map shrunk to fit the phone, then pinches in up to
**3.2x**. So the map has to read at both extremes: a legible crowd when zoomed
out, clean linework when zoomed in.

The character sheet `findo.png` is used for two things only: her portrait in
the game's objective bar, and the shape of the tap area over her. It is never
drawn on the map.

---

## 1. The character

### Canonical description

A girl of about eleven. Standing, facing the viewer, arms relaxed at her sides,
feet together. Cheerful, neutral expression. She is never running, waving, or
doing anything that draws the eye.

### Palette — exact, and not negotiable

| Part | Hex | Notes |
| --- | --- | --- |
| Hair and braids | `#784A28` | Mid brown |
| Skin | `#F6CEB0` | |
| Top | `#FACE3E` | Warm yellow, sleeveless |
| Top's yoke / neckline | `#201C22` | Near-black V across the chest |
| Skirt | `#923EA8` | Violet, A-line, knee length |
| Shoes | `#201C22` | Flat, near-black |
| Outline | `#1A161E` | Same weight as every other figure |

`#923EA8` is **hers alone**. No other figure, object, sign, balloon or awning on
any map may use it or anything within a noticeable distance of it. It is the
one colour the eye can be trained on, and it is also how automated checks find
her. If a scene calls for purple elsewhere, use `#6C52B0` or `#C658A0`.

### The three signature traits

1. Two long brown braids, one either side of the head, hanging to chest height
2. Yellow sleeveless top with the black V yoke
3. Violet A-line skirt

All three must be present on every map. **Her head and at least two of the three
traits must be fully unobstructed** in every scene, however much of the rest of
her is hidden.

### Proportions

Drawn at the map's scale, she is a figure among figures. Her height per level is
in the table in section 3. Head is roughly 1/7 of her total height; the braids
reach about halfway down the torso.

### Deliverable

`findo.png` — the character alone, transparent background, **at least 800 px
tall**, PNG-32, trimmed so the image bounds touch her silhouette on all four
sides.

This is the master, and it is also what the game uses for her portrait in the
objective bar and for the shape of her tap area. When an illustrator draws her
into a scene, they redraw this figure at the map's scale rather than pasting a
resized copy; when the tool composites her, it scales this file directly.

---

## 2. Map technical specification

| Property | Requirement |
| --- | --- |
| Dimensions | **exactly 2048 x 2048 px** |
| Delivery format | PNG-24 or high-quality JPEG, **no alpha channel** |
| Colour space | sRGB |
| Shipping format | WebP, written by `tool/build_level.py` -- do not hand-convert |
| Shipped size | **at most 1.5 MB** per map |
| File name | `level_01` … `level_10`, extension as delivered |
| Location | `assets/images/maps/` |

Square, because the camera has to cover both a tall phone held upright and the
same phone on its side.

Hand over the master in whatever lossless or near-lossless format you work in.
The build tool re-encodes it to WebP, which is what the app ships: these are
dense illustrations, and one of them measured 5.9 MB as a PNG against 0.8 MB as
WebP at quality 92, with no visible difference at any zoom the game allows. Ten
maps as PNG would have been a 60 MB download; as WebP the whole set is about
9 MB. Flutter decodes WebP on both Android and iOS.

### Style

Flat vector illustration with a consistent dark outline, in the tradition of a
printed seek-and-find book: high-angle three-quarter view, saturated but not
neon, no gradients, no photographic texture, no drop shadows beyond a simple
contact shadow. Every figure carries the same outline weight, Findo included —
a heavier or lighter line on her is a giveaway.

### Crowd

- Every crowd figure stands **90–130 px** tall.
- Counts per level are in section 3. They are minimums.
- Spread evenly. A map with one dense half and one empty half is a map where
  half the search is wasted.
- No figure may be within 40 px of another figure's outline, or the crowd reads
  as a smear when zoomed out.

### Poses

The crowd has to look alive, or the map reads as wallpaper rather than a place.

- **No two figures share a pose.** Each is doing something the scene explains:
  pointing, carrying, crouching, leaning on a railing, reaching up, turning to
  talk, kneeling to a child, shielding their eyes.
- **Vary who they are**, not just what they wear: children, teenagers, adults,
  older people. Vary height and build.
- **Vary which way they face** — towards the viewer, away, in profile.
- **Put pairs and groups in small interactions**, so the eye finds relationships
  rather than a field of separate figures.

One counterweight, and it matters more than it looks. **Keep about a third of
the crowd simply standing or walking normally, mixed evenly through the rest.**
Findo stands still with her arms at her sides. If every other figure is
mid-gesture, the one calm person is the first thing the eye lands on, and the
level solves itself. A still figure has to be an ordinary sight.

### Where Findo may stand

- Her feet at least **140 px** from any edge of the map.
- At least **six** other figures within a 400 px radius of her. She is never
  alone in a clearing.
- At least **250 px** from the scene's focal point — the fountain, the big
  wheel, the stage. That is the first place anyone looks.
- Not centred. Vary which part of the map she is in across the ten levels; the
  table in section 3 assigns each level a region.

### Decoys

A decoy is a crowd figure that shares **exactly one** of her three signature
traits. Never two. A figure with braids and a yellow top is not a decoy, it is a
bug — it makes the level feel unfair rather than hard.

Decoys must be at least **500 px** from Findo, so the player cannot compare them
side by side.

---

## 3. The twenty levels

Difficulty is carried by five dials: how many people are on the map, how large
each of them is drawn, how tall Findo is, how much of her is hidden behind
scenery, and how many decoys compete for attention. Time comes down as those go
up.

Levels 1 to 10 are the first half; every figure there is 90-130 px tall. From
level 11 the crowds outgrow that: the individual figures are drawn smaller so
they still fit the frame, and Findo shrinks with them. The **figure size**
column gives each scene's crowd height as a fraction of the map's height.

| # | Level | Scene | Crowd | Findo height | Occluded | Decoys | Region | Time |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Fountain Square | A town square around a fountain, shopfronts and balconies on three sides, a zebra crossing | 180 | 130 px | 0% | 0 | lower left | 150 s |
| 2 | Hollow Farm | Working farm: barns, silo, haystacks, sheep, pig pen, tractor | 210 | 125 px | up to 10% | 1 | upper right | 150 s |
| 3 | The Funfair | Striped stalls, a big wheel, balloon sellers, a clown | 240 | 120 px | up to 10% | 2 | lower centre | 140 s |
| 4 | Harbour Beach | Beach and jetty: parasols, deckchairs, boats, ice-cream cart | 260 | 115 px | up to 15% | 3 | upper left | 140 s |
| 5 | Central Station | Concourse: platforms, departure board, benches, luggage, a café | 290 | 110 px | up to 20% | 4 | right edge | 130 s |
| 6 | Night Market | Lantern-lit stalls after dark, food carts, string lights | 310 | 105 px | up to 25% | 6 | lower right | 130 s |
| 7 | Snow Village | Ski slopes, chalets, a chairlift, snowmen, sledges | 280 | 100 px | up to 25% | 7 | upper centre | 120 s |
| 8 | The Museum | Galleries: dinosaur skeleton, framed paintings, school groups | 320 | 95 px | up to 30% | 8 | left edge | 120 s |
| 9 | Cup Final | Packed stadium stand, banners, stewards, the pitch along one edge | 380 | 90 px | up to 30% | 10 | lower left | 110 s |
| 10 | Terminal Two | Airport: check-in queues, gates, trolleys, planes through the glass | 420 | 85 px | up to 35% | 12 | upper right | 100 s |
| 11 | City Zoo | Enclosures, keepers, aviary dome, penguin pool, winding paths | 440 | 82 px | up to 35% | 12 | lower centre | 95 s |
| 12 | Splash Park | Water slides, wave pool, lazy river, loungers, lifeguards | 460 | 80 px | up to 35% | 13 | upper left | 95 s |
| 13 | Grand Mall | Two-floor atrium, escalators, shopfronts, food court | 480 | 78 px | up to 40% | 14 | right edge | 90 s |
| 14 | Fishing Docks | Quaysides, boats, fish market, crane, warehouses | 500 | 75 px | up to 40% | 15 | lower left | 90 s |
| 15 | Castle Fair | Courtyard, jousting run, craft stalls, blacksmith, banners | 520 | 73 px | up to 40% | 16 | upper centre | 85 s |
| 16 | County Hospital | Cutaway wings, wards, theatre, ambulance bay, helipad | 540 | 70 px | up to 45% | 17 | left edge | 85 s |
| 17 | Riverside School | Cutaway classrooms, hall, playground, running track | 560 | 68 px | up to 45% | 18 | lower right | 80 s |
| 18 | Building Site | Half-built tower, tower cranes, diggers, site cabins | 580 | 66 px | up to 45% | 19 | upper right | 80 s |
| 19 | City Marathon | A river of runners, packed barriers, water station | 620 | 63 px | up to 50% | 20 | lower centre | 75 s |
| 20 | Festival Field | Main stage, an enormous crowd, tents, food trucks | 660 | 60 px | up to 50% | 22 | upper left | 75 s |

### Notes on the harder levels

**Night Market** is the one dark scene. Keep Findo lit like everyone near her —
do not put her in shadow. A hidden character the player physically cannot see is
not difficulty, it is a broken level.

**Snow Village** has a pale, low-contrast palette. Her yellow and violet will
pop harder here than anywhere else, so this is the level to lean on occlusion
and on decoys rather than on colour noise.

**Cup Final** is the densest. Rows of seated spectators give a strong repeating
rhythm; break it with standing figures so the eye has somewhere to catch.

**Terminal Two** closes the first half: smallest figure of those ten, most
decoys, least time. Genuinely hard, still fair — head clear, two traits visible.

**City Marathon** is a river of near-identical runners. Vary their vests and
give the pavement crowd ordinary clothes, so the two groups read differently.

**Festival Field** is the last level and the hardest thing in the game: the
biggest crowd, the smallest figure, and 75 seconds. At 60 px on a 2048 px map
she is about 23 logical pixels tall when the whole map is on screen, so the
level cannot be solved without pinching in. That is the point of the 3.2x zoom
and the 2048 px masters; by level 20 the player is expected to work the map
rather than scan it.

### Star cuts

Do not set these by hand. Score is `100 + 10 x seconds left`, and the tool
derives the cuts from the time limit: one star at roughly 90% of the clock used,
two at 55%, three at 28%. For reference:

| Time | 1 star | 2 stars | 3 stars | Ceiling |
| --- | --- | --- | --- | --- |
| 150 s | 250 | 775 | 1180 | 1600 |
| 140 s | 240 | 730 | 1108 | 1500 |
| 130 s | 230 | 685 | 1036 | 1400 |
| 120 s | 220 | 640 | 964 | 1300 |
| 110 s | 210 | 595 | 892 | 1200 |
| 100 s | 200 | 550 | 820 | 1100 |

---

## 4. Delivering a map

For each finished map, supply the image plus **Findo's bounding box in map
pixels**: the x and y of the top-left corner of a rectangle drawn tightly around
her, and its width and height. Any image editor's selection readout gives these.

Then one command registers it. The level names are already translated, so
nothing else needs editing:

```powershell
python tool/level_data.py register --map assets/images/maps/level_01.png `
    --id level_01 --index 1 --name-key level.town    --target X Y W H --time 150
python tool/level_data.py register --map assets/images/maps/level_02.png `
    --id level_02 --index 2 --name-key level.farm    --target X Y W H --time 150
python tool/level_data.py register --map assets/images/maps/level_03.png `
    --id level_03 --index 3 --name-key level.fair    --target X Y W H --time 140
python tool/level_data.py register --map assets/images/maps/level_04.png `
    --id level_04 --index 4 --name-key level.beach   --target X Y W H --time 140
python tool/level_data.py register --map assets/images/maps/level_05.png `
    --id level_05 --index 5 --name-key level.station --target X Y W H --time 130
python tool/level_data.py register --map assets/images/maps/level_06.png `
    --id level_06 --index 6 --name-key level.market  --target X Y W H --time 130
python tool/level_data.py register --map assets/images/maps/level_07.png `
    --id level_07 --index 7 --name-key level.snow    --target X Y W H --time 120
python tool/level_data.py register --map assets/images/maps/level_08.png `
    --id level_08 --index 8 --name-key level.museum  --target X Y W H --time 120
python tool/level_data.py register --map assets/images/maps/level_09.png `
    --id level_09 --index 9 --name-key level.stadium --target X Y W H --time 110
python tool/level_data.py register --map assets/images/maps/level_10.png `
    --id level_10 --index 10 --name-key level.airport --target X Y W H --time 100
```

Then check the set:

```powershell
python tool/level_data.py verify
flutter test
```

`verify` fails on a missing image, a map under 2048 px, a box outside the map,
or a box too small to tap. `flutter test` additionally fails if a level has no
translated name or the level numbering has a gap.

---

## 5. Checklist before a map is called done

- [ ] Exactly 2048 x 2048, PNG-24, no alpha, sRGB, under 1.5 MB
- [ ] Crowd count at or above the level's number, figures 90–130 px, none closer
      than 40 px to another
- [ ] Findo drawn in the scene's own style, outline weight identical to the crowd
- [ ] Her height matches the level's row in section 3
- [ ] Head fully visible, at least two of the three signature traits unobstructed
- [ ] Feet 140 px or more from every edge
- [ ] Six or more figures within 400 px of her
- [ ] 250 px or more from the scene's focal point
- [ ] She is in the region the table assigns to that level
- [ ] `#923EA8` appears nowhere else on the map
- [ ] Decoy count matches the table; no decoy carries two of her traits; every
      decoy at least 500 px away
- [ ] Zoom the map to 30% and confirm the crowd still reads as people
- [ ] Zoom to 100% and confirm the linework is clean, not resampled

---

## 6. What is in the repo now

All ten maps are illustrated and in place, generated from the prompts in
`docs/GEMINI_PROMPTS.md` and composited with `tool/build_level.py`.

`tool/generate_maps.py` still builds the original geometric placeholders. It is
kept as a working reference for what these rules mean in practice: the same
routine draws Findo and the crowd, and it refuses to give any crowd member two
of her signature traits.

### The rule the tool enforces for you

This brief says `#923EA8` is Findo's alone. Generators do not obey that. The
supplied Fountain Square artwork contained a woman in a yellow top *and* a
violet skirt -- two of the three signature traits, which reads as a second Findo
the game cannot register, and a player who taps her is penalised for finding
the right-looking person.

So `tool/build_level.py` shifts every pixel near her skirt colour to `#6C52B0`
before compositing her in, and reports how many it moved. After that the colour
really is hers, on every map, whoever drew it.

Replacing a map is dropping in the new file and re-running its build command.
Nothing in the Dart code names a particular map.

# Generating Findo's artwork with Gemini

Eleven prompts: one for the character, ten for the scenes. Plus the two
commands that turn what comes back into playable levels.

---

## Why the character is generated separately

An image model will not draw the same character twice. Ask for "a crowded
square with Findo hidden in it" ten times and you get ten different girls, in
ten different palettes, in ten places you would then have to hunt for yourself.

So: **the model draws the crowd, and never Findo.** She is generated once, on
her own, and composited into each scene afterwards from that single master. She
comes out identical on every map, and her coordinates are exact because the
tool placed her.

That is also why every scene prompt below ends with an instruction to include
no girl in a violet skirt. If the model paints one anyway, the map has a second
Findo who cannot be tapped — the most confusing bug this game could ship.

---

## Step 1 — the character

Paste this into Gemini. Ask for the highest resolution it offers.

```
A single cartoon character, full body, front view, standing straight and still,
arms relaxed at her sides, feet together, facing the viewer.

WHO SHE IS
A cheerful girl of about eleven with a calm, neutral expression. She is not
posing, waving, running or gesturing.

EXACT APPEARANCE — follow every colour precisely
- Hair: medium brown (#784A28), parted in the middle, worn in TWO long braids,
  one hanging on each side of her head, reaching down to chest height
- Skin: light warm tone (#F6CEB0)
- Top: a bright warm yellow (#FACE3E) sleeveless top, with a solid near-black
  (#201C22) V-shaped yoke across the chest and shoulders
- Skirt: a violet purple (#923EA8) A-line skirt, knee length, flaring outward
- Legs: bare, same skin tone as her face
- Shoes: flat, solid near-black (#201C22)

STYLE
Flat vector illustration for a children's seek-and-find puzzle book. A uniform
thick black outline (#1A161E) around every shape, the same weight everywhere.
Solid flat colour fills only. Absolutely no gradients, no airbrushing, no soft
shading, no cel shading, no highlights, no drop shadow, no glow, no texture.
Simple, bold, readable at small size.

BACKGROUND
A completely solid, flat, uniform pure green background, RGB 0 255 0, filling
the whole canvas. No ground line, no floor, no shadow beneath her, no scenery,
no pattern, no gradient in the background whatsoever. The green must be one
single flat colour.

FRAMING
The entire figure is visible from the top of her head to the soles of her
shoes, centred, with a comfortable margin of green on all four sides. Nothing
is cropped.

DO NOT INCLUDE
No text, letters, numbers, logos, signatures or watermarks. No border or frame.
No other characters. No props, no bag, no hat.

Square 1:1 aspect ratio, highest resolution available.
```

Save what comes back, then:

```powershell
python tool/build_level.py character --image C:\Users\Vashdi\Downloads\findo_raw.png
```

That keys the green away, trims to her silhouette, writes
`assets/images/targets/findo.png`, and saves a checkerboard preview at
`store/previews/character.png`. Open it: if there is green left anywhere, or a
green fringe around her, re-run with `--tolerance 100`.

**Check before moving on.** Every map inherits this figure, so a mistake here is
a mistake ten times over. She should be at least 800 px tall after trimming;
the tool warns if she is not.

---

## Step 2 — the ten scenes

Each prompt below is complete and standalone. The first four blocks are
identical in all ten on purpose: that is what makes the set look like one book
rather than ten unrelated pictures. Change only the SCENE block.

### Generating tips

- Ask for the largest size Gemini offers. The tool upscales anything smaller
  than 2048 px and warns you, but upscaled linework looks soft at full zoom.
- Generate three or four variants per level and keep the busiest one. Models
  under-populate crowds by default.
- If text appears on signs, regenerate. Text in the artwork will not be
  translated and looks wrong in Hebrew.
- If the result has a white border or a vignette, regenerate. The map is panned
  around, so a framed illustration reads as a mistake.

---

### Level 1 — Fountain Square

```
A densely crowded scene for a children's seek-and-find puzzle book.

STYLE
Flat vector illustration. High-angle three-quarter aerial view, looking down at
roughly 55 degrees, so both the ground and the fronts of buildings are visible.
Every object and every person drawn with a uniform thick black outline of the
same weight. Solid flat colour fills only: no gradients, no airbrushing, no soft
shading, no photographic texture, no drop shadows, no glow, no blur, no depth of
field. Saturated but not neon. Crisp, clean linework.

CROWD
Approximately 180 small cartoon people, each drawn full body, standing or
walking, all seen from the same high angle, each roughly one sixteenth of the
image height. Wide variety of skin tones, hair colours, hairstyles and clothing
colours. Spread evenly across the entire image with small gaps between them:
never overlapping, never clustered into one half, never leaving a large empty
area.

POSES - every figure is doing something
No two people share the same pose. Each is doing something that belongs to this
place: pointing at something, carrying a bag or a tray, crouching, leaning on a
railing, reaching up, turning to talk to the person beside them, kneeling down
to a child, lifting a toddler onto their shoulders, checking a pocket, shielding
their eyes, waving across the frame. Vary which way they face - some towards the
viewer, some away, some in profile. Vary build, age and height: small children,
teenagers, adults, older people with walking sticks. Put small interactions
between pairs and groups, so the crowd reads as a moment in a real place rather
than a field of figures.

Keep about a third of them simply standing or walking normally, mixed evenly in
among the rest, so that a person standing still is an ordinary sight in the
scene and not the one thing that catches the eye.

SCENE
A town square. A round stone fountain with arching jets of water in the middle.
Three and four storey shopfronts and apartment buildings with balconies, awnings
and window boxes along the top edge. A zebra crossing, a couple of parked cars,
a delivery van, a cyclist. Wooden benches, trimmed hedges, leafy trees, paved
paths crossing the grass, a dog on a lead.

DO NOT INCLUDE
No girl or woman wearing a violet or purple skirt or a purple dress. No figure
in a bright yellow sleeveless top. No text, letters, numbers, written signs,
logos, signatures or watermarks. No border, frame, vignette, margin or white
edge: the illustration fills the entire square canvas edge to edge.

Square 1:1 aspect ratio, highest resolution available.
```

### Level 2 — Hollow Farm

Same STYLE, CROWD (**210 people**), POSES and DO NOT INCLUDE blocks. SCENE:

```
SCENE
A working farm on a summer day. A large barn with a red pitched roof, a second
wooden barn with stables and horses looking out, a tall grey silo with a ladder.
Cone-shaped haystacks, a red tractor, wooden post-and-rail fences dividing the
yard into paddocks. A flock of white sheep, a pen of pink pigs, a brown horse in
a round paddock, chickens and yellow chicks scattered around, geese by a small
pond, a dog running.
```

### Level 3 — The Funfair

Same blocks, **240 people**. SCENE:

```
SCENE
A funfair. A row of striped canvas stalls with scalloped awnings along the top,
hoopla and coconut shy games, a big wheel with coloured gondolas on the right, a
carousel with horses, bumper cars, a helter skelter. A balloon seller holding a
huge bunch of balloons, a clown, a popcorn cart, a candy floss stand, bunting
strung between poles, picnic tables, litter bins.
```

### Level 4 — Harbour Beach

Same blocks, **260 people**. SCENE:

```
SCENE
A busy seaside beach. Golden sand across the lower two thirds, blue sea along
the top with small sailing boats, a rowing boat, and a wooden jetty running out
into the water. Rows of brightly coloured parasols, striped deckchairs, beach
towels laid out, an ice-cream cart with a queue, beach balls, sandcastles with
little flags, a red and white lifeguard tower, seagulls, a line of rocks at one
edge.
```

### Level 5 — Central Station

Same blocks, **290 people**. SCENE:

```
SCENE
A railway station concourse under an arched glass and steel roof, seen from
above with the roof shown as transparent so the interior is fully visible. Two
platforms with a train waiting at each. A large blank departure board, ticket
machines, wooden benches, luggage trolleys piled with suitcases, a café with
small round tables, a flower stall, a newsstand, a big round clock hanging from
the roof structure, pigeons on the girders.
```

### Level 6 — Night Market

Same blocks, **310 people**. SCENE:

```
SCENE
A street food night market after dark. The ground is a deep blue-purple. Rows of
food stalls under canopies, each lit by warm orange hanging lanterns, with
strings of small round fairy lights criss-crossing overhead between the stalls.
Steam rising from woks and pots, crates of fruit and vegetables, hanging paper
lanterns, low plastic stools around small tables, a noodle cart, a fish stall on
ice.

IMPORTANT: although the scene is at night, every person is clearly and warmly
lit by the stall lights and fully readable. Nobody is in silhouette or hidden in
darkness.
```

### Level 7 — Snow Village

Same blocks, **280 people**. SCENE:

```
SCENE
An alpine village in deep snow. Wooden chalets with steep snow-covered roofs and
shuttered windows, smoke curling from chimneys. A chairlift climbing the right
side with occupied chairs, ski slopes with skiers carving turns, dark green pine
trees heavy with snow, snowmen, wooden sledges, a frozen pond with skaters, log
piles, a hot drinks hut.
```

### Level 8 — The Museum

Same blocks, **320 people**. SCENE:

```
SCENE
The inside of a grand museum, seen from above with the roof removed so all the
galleries are visible at once, like a cutaway. A large dinosaur skeleton
mounted in the central hall. Framed paintings hung along the walls, glass
display cases with pottery and jewels, marble columns, a wide grand staircase
with a red carpet, velvet rope barriers on brass posts, a suit of armour, a
mounted whale skeleton in one wing, school groups sitting cross-legged on the
floor with a guide.
```

### Level 9 — Cup Final

Same blocks, **380 people**. SCENE:

```
SCENE
A packed football stadium stand, seen from a high angle. Tiered rows of coloured
seats filled with supporters in team colours, waving flags and long banners.
Stewards in high-visibility jackets standing in the aisles. The green pitch runs
along the bottom edge with players on it and a referee. Floodlight pylons at the
corners, a scoreboard with no writing on it, food kiosks at the back of the
stand.

IMPORTANT: leave a clear standing concourse or wide aisle running across the
stand where people are standing rather than seated, so the crowd is not entirely
made of seated figures.
```

### Level 10 — Terminal Two

Same blocks, **420 people**. SCENE:

```
SCENE
An airport departures hall, seen from a high angle. A long row of check-in desks
with queues snaking between belt barriers, security lanes with trays, seating
areas at the gates, luggage trolleys and stacks of suitcases, blank information
screens on stands, a café with tables, escalators going up and down, potted
plants. Along the top edge, a huge glass wall with aeroplanes parked at their
stands and a fuel truck outside.
```

---

## Step 3 — placing her and registering the level

Open the scene you kept in any image viewer that shows pixel coordinates, and
find the spot where Findo should stand. Use the region assigned to that level in
`docs/ART_BRIEF.md` — she should be among people, at least 140 px from any edge,
and not next to the scene's centrepiece.

You do not pick where she stands. The tool does that.

```powershell
python tool/build_level.py level `
    --scene C:\Users\Vashdi\Downloads\fountain_square.png `
    --id level_01 --index 1 --name-key level.town `
    --height 130 --time 150 --tint 0.45
```

One command per level. The values for each are:

| Level | id | name key | height | time |
| --- | --- | --- | --- | --- |
| 1 | `level_01` | `level.town` | 130 | 150 |
| 2 | `level_02` | `level.farm` | 125 | 150 |
| 3 | `level_03` | `level.fair` | 120 | 140 |
| 4 | `level_04` | `level.beach` | 115 | 140 |
| 5 | `level_05` | `level.station` | 110 | 130 |
| 6 | `level_06` | `level.market` | 105 | 130 |
| 7 | `level_07` | `level.snow` | 100 | 120 |
| 8 | `level_08` | `level.museum` | 95 | 120 |
| 9 | `level_09` | `level.stadium` | 90 | 110 |
| 10 | `level_10` | `level.airport` | 85 | 100 |

The tool fits the scene to exactly 2048x2048, writes the map **without her on
it**, finds several places she could hide in it, derives the star cuts from the
time limit, and registers the level. It warns if the source was too small, if
the file is over the 1.5 MB budget, or if the height asked for leaves her too
narrow to tap.

It also writes two previews per level:

- `store/previews/level_0N_spot0.png`, `_spot1.png` and so on — one close crop
  per hiding place it found. **Look at these.** They are how you check she is
  among people rather than stranded in an empty patch, and that the crowd
  around her does not happen to include a near-twin.
- `store/previews/level_0N_map.png` — the whole map small, to confirm the scene
  reads at the zoomed-out size the player first sees.

If a spot looks wrong, run the same command again with a different `--spots`
count. It overwrites cleanly.

---

## Step 4 — check the set

```powershell
python tool/level_data.py verify
flutter test
flutter run
```

`verify` fails on a missing image, a map under 2048 px, a box outside the map,
or a box too small to tap. `flutter test` additionally fails if a level has no
translated name or the numbering has a gap. Then play it.

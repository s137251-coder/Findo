# One prompt for levels 11 to 20

The ten maps already in the repo stay as they are. This adds the second half of
a twenty-level game: ten new scenes, carrying the difficulty ramp on past where
the first ten leave off.

Paste the block below into Gemini once, then ask for the images one at a time
by replying with a number. Image models return one picture per turn; what a
single prompt can do is hold the style, crowd and exclusion rules across the
whole conversation, which is what keeps twenty maps looking like one book.

The character sheet is not regenerated. `assets/images/targets/findo.png` is
already in place and every new map gets the same figure composited in.

---

## How the ramp continues

Levels 1 to 10 run from 180 people at 130 px tall with 150 seconds, down to 420
people at 85 px with 100 seconds. The second half keeps going: the crowd grows,
the individual figures get smaller so they still fit, Findo shrinks with them,
and the clock tightens.

| # | Level | Crowd | Figure size | Findo | Time |
| --- | --- | --- | --- | --- | --- |
| 11 | City Zoo | 440 | 1/18 of height | 82 px | 95 s |
| 12 | Splash Park | 460 | 1/18 | 80 px | 95 s |
| 13 | Grand Mall | 480 | 1/19 | 78 px | 90 s |
| 14 | Fishing Docks | 500 | 1/19 | 75 px | 90 s |
| 15 | Castle Fair | 520 | 1/20 | 73 px | 85 s |
| 16 | County Hospital | 540 | 1/20 | 70 px | 85 s |
| 17 | Riverside School | 560 | 1/21 | 68 px | 80 s |
| 18 | Building Site | 580 | 1/21 | 66 px | 80 s |
| 19 | City Marathon | 620 | 1/22 | 63 px | 75 s |
| 20 | Festival Field | 660 | 1/22 | 60 px | 75 s |

At 60 px on a 2048 px map she is about 23 logical pixels tall on a phone at the
zoomed-out view. That is deliberate: by level 20 the player has to pinch in and
work the map, which is what the 3.2x zoom and the 2048 px masters are for.

---

## What arrived, and what is still missing

Nine of the ten scenes came back and are registered as levels 11 to 19. Two
were never produced — Fishing Docks and Riverside School — and one came back
twice, as a daytime festival and a dusk one. Both festivals were kept: they
look different enough to be separate levels, and the dusk one makes a better
finale.

| Level | Scene | Findo | Time | Notes |
| --- | --- | --- | --- | --- |
| 11 | City Zoo | 82 px | 95 s | |
| 12 | Splash Park | 80 px | 95 s | |
| 13 | Grand Mall | 78 px | 90 s | |
| 14 | Castle Fair | 75 px | 90 s | |
| 15 | County Hospital | 73 px | 85 s | Came back with a classroom wing; the operating theatre settles what it is |
| 16 | Building Site | 70 px | 85 s | |
| 17 | City Marathon | 74 px | 80 s | |
| 18 | Festival Field, day | 71 px | 80 s | |
| 19 | Night Festival | 68 px | 75 s | Tinted 0.55 towards the scene's own light |

### Two limits the real artwork exposed

**She cannot be made smaller than 68 px.** A standing figure is about a third as
wide as she is tall, so at 66 px her tap box is 23 px wide and the verifier
rejects it. Shrinking her runs out of tap target before it runs out of map. Past
level 17 the difficulty has to come from the scene and the clock instead, which
is why 17 to 19 barely shrink at all.

**A daylit character in a dusk scene gives itself away.** Composited unchanged
into the night festival she was the brightest thing on the map, which would have
made the hardest level the easiest. `build_level.py --tint` blends her towards
the ambient colour sampled around where she lands, capped at 0.55 so she stays
recognisable as the girl on the objective panel.

### The one scene still to generate

Level 20 is missing. Ask Gemini for this, save it, and register it:

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
About 700 small cartoon people, each drawn full body, each roughly one
twenty-second of the image height. Wide variety of skin tones, hair colours,
hairstyles and clothing colours. Spread evenly across the entire image with
small gaps between them: never overlapping, never clustered into one half,
never leaving a large empty area. This is the busiest scene in the game, so
fill the frame right to the edges.

POSES - every figure is doing something
No two people share the same pose. Each is doing something that belongs to this
place: hauling a crate, coiling rope, pointing out to sea, crouching by a net,
leaning on a railing, carrying a fish box on a shoulder, turning to talk,
kneeling to a child, shielding their eyes. Vary which way they face - some
towards the viewer, some away, some in profile. Vary build, age and height.
Put small interactions between pairs and groups, so the crowd reads as a
working morning rather than a field of figures.

Keep about a third of them simply standing or walking normally, mixed evenly in
among the rest, so that a person standing still is an ordinary sight in the
scene and not the one thing that catches the eye.

SCENE
A working fishing harbour at full tilt. Wooden quaysides with fishing boats
moored two deep along them, stacks of crab pots and coiled rope, a long fish
market under an open awning with crates of ice and buyers pressing in, gulls
everywhere, a tall crane lifting a container, a row of warehouses with big
sliding doors, forklifts weaving between pallets, a lighthouse at one edge, nets
hung to dry on frames, a chandlery, a slipway with a boat being winched out.

DO NOT INCLUDE
No girl or woman wearing a violet or purple skirt or a purple dress. No figure
in a bright yellow sleeveless top. No text, letters, numbers, written signs,
logos, signatures or watermarks. No border, frame, vignette, margin or white
edge: the illustration fills the entire square canvas edge to edge.

Square 1:1 aspect ratio, highest resolution available.
```

Then:

```powershell
python tool/build_level.py level `
    --scene C:\temp\findo\docks.png `
    --id level_20 --index 20 --name-key level.docks `
    --height 68 --time 70 --tint 0.45
```

Then add `"level_20"` to `assets/images/maps/meta/index.json`.

Nothing here says where she stands. The tool finds the hiding places itself --
in crowds, and away from open sky, where a figure would be silhouetted -- and
writes all of them into the level, because the game picks one per attempt so
that replaying a level is a fresh search. Afterwards look at
`store/previews/level_20_spot*.png`, one crop per hiding place, and re-run with
a different `--spots` count if any of them sit somewhere a person would not.

`level.docks` is already translated in both languages. 68 px is the floor, so
the finale takes its extra difficulty from the crowd and from having only 70
seconds.

---

## The prompt

```
You are producing the second half of the artwork for a mobile hidden-object
game called Findo. It works like a printed "Where's Wally" book: each level is
one big crowded scene, and one specific girl is hidden somewhere in it. The
player pans and pinch-zooms to find her.

The first ten scenes are already done. This is levels 11 to 20, and they are
the hard half: bigger crowds, smaller figures, less time. Ten images in total.

HOW WE WILL WORK
Generate exactly ONE image per reply, in order, and nothing else. Do not
combine images, do not make a grid or a contact sheet of several, do not
summarise the brief back to me. Wait for me to reply with the next number. I
will say "1" through "10". If I say "again", produce a different take on the
same number.

=========================================================================
RULES THAT APPLY TO ALL TEN IMAGES
=========================================================================

STYLE - identical in all ten, this is what makes them a set
Flat vector illustration for a children's seek-and-find puzzle book. High-angle
three-quarter aerial view, looking down at roughly 55 degrees, so both the
ground and the fronts of buildings are visible. Every object and every person
drawn with a uniform thick black outline of the same weight. Solid flat colour
fills only: no gradients, no airbrushing, no soft shading, no photographic
texture, no drop shadows, no glow, no blur, no depth of field. Saturated but
not neon. Crisp, clean linework.

CROWD - the count and the figure size both change per scene
Small cartoon people, each drawn full body, standing, walking or seated, all
seen from the same high angle. Wide variety of skin tones, hair colours,
hairstyles and clothing colours. Spread evenly across the entire image with
small gaps between them: never overlapping, never clustered into one half,
never leaving a large empty area. These are the busiest scenes in the game, so
fill the frame right to the edges.

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

THE MOST IMPORTANT RULE
There must be NO girl matching this description anywhere in any scene: brown
hair in two braids, a bright yellow sleeveless top, and a violet purple skirt.
She is the character the player hunts for, and she is added afterwards by
software so that she is identical on every map and her position is known
exactly. Concretely, in every scene: no figure wearing a violet or purple skirt
or a purple dress, and no figure in a bright yellow sleeveless top. If either
appears, the scene contains a second version of her that the game cannot
register, and a player who spots her is penalised for finding the right-looking
person.

NEVER INCLUDE IN A SCENE
No text, letters, numbers, written signs, logos, signatures or watermarks -
artwork text is never translated and reads wrong in Hebrew. No border, frame,
vignette, margin or white edge: the illustration fills the entire square canvas
edge to edge.

OUTPUT FOR EVERY IMAGE
Square 1:1 aspect ratio. The highest resolution you can produce, 2048 x 2048 or
larger.

=========================================================================
THE TEN SCENES
=========================================================================

IMAGE 1 - CITY ZOO - about 440 people, each roughly one eighteenth of the image height
A city zoo on a busy afternoon, seen from above. Curved paths winding between
enclosures with low walls and glass panels: elephants in a sandy paddock, a
giraffe house, penguins on rocks around a pool, a big cat enclosure with a
climbing frame, an aviary dome, a reptile house. Keepers in uniform, feeding
buckets, information posts with blank panels, ice-cream kiosks, pushchairs,
benches, litter bins, tall trees between the enclosures.

IMAGE 2 - SPLASH PARK - about 460 people, each roughly one eighteenth of the image height
An outdoor water park. Tall spiralling water slides in bright colours feeding
into splash pools, a large wave pool with bathers, a lazy river winding through,
a children's shallow area with fountains and a tipping bucket, rows of sun
loungers and parasols, changing cabins, a snack bar with a queue, lifeguards on
high chairs, wet footprint paths between everything.

IMAGE 3 - GRAND MALL - about 480 people, each roughly one nineteenth of the image height
The inside of a shopping mall seen from above with the roof removed, showing two
floors at once. A central atrium with a fountain and planters, criss-crossing
escalators, glass-fronted shops along both levels with blank window displays,
a food court with tables, a balcony railing around the upper floor, benches,
pushchairs, shopping bags everywhere, a lift in a glass shaft.

IMAGE 4 - FISHING DOCKS - about 500 people, each roughly one nineteenth of the image height
A working fishing harbour. Wooden quaysides with fishing boats moored along
them, stacks of crab pots and coiled rope, a fish market under a long awning
with crates of ice, gulls everywhere, a tall crane lifting a container, a row of
warehouses with big sliding doors, forklifts, a lighthouse at one edge, nets
hung to dry.

IMAGE 5 - CASTLE FAIR - about 520 people, each roughly one twentieth of the image height
A medieval fair in a castle courtyard. Stone curtain walls with round towers on
two sides, a jousting run with a fence down the middle and two knights on
horseback, striped tents and craft stalls, a blacksmith at an anvil, archery
butts, a maypole, jugglers and a fire-eater, banners and pennants on poles,
haybales, oxen pulling a cart.

IMAGE 6 - COUNTY HOSPITAL - about 540 people, each roughly one twentieth of the image height
A hospital seen from above with the roof removed, showing several wings at once.
A busy reception with a queue, a waiting room full of chairs, wards with rows of
beds and curtain rails, an operating theatre with a team around the table, a
physiotherapy room, a canteen. Outside, an ambulance bay with two ambulances,
a helipad, a car park, and a small garden with benches.

IMAGE 7 - RIVERSIDE SCHOOL - about 560 people, each roughly one twenty-first of the image height
A large school seen from above with the roof removed. Classrooms with rows of
desks and blank whiteboards, a science lab with benches, an art room, a library
with shelves, a big hall with a stage. Outside: a playground with painted court
markings, football goals, a running track, a bicycle rack, a school bus at the
gate, trees along a river running past one edge.

IMAGE 8 - BUILDING SITE - about 580 people, each roughly one twenty-first of the image height
A large construction site. A half-built tower with exposed floors and
scaffolding, two tall tower cranes, a concrete mixer truck pouring, diggers and
dumpers, stacks of timber and steel beams, portable site cabins, a fenced
perimeter with mesh panels, workers in hard hats and high-visibility jackets
everywhere, a queue at a food van outside the gate.

IMAGE 9 - CITY MARATHON - about 620 people, each roughly one twenty-second of the image height
A city marathon in full flow. A dense river of runners in numbered-free running
vests filling a wide street that curves through the image, spectators packed
behind barriers on both sides waving and clapping, a water station with
volunteers holding out cups, first-aid tents, a gantry over the road, balloons
tied to the barriers, city buildings along both sides, a marching band on one
corner.

IMAGE 10 - FESTIVAL FIELD - about 660 people, each roughly one twenty-second of the image height
An outdoor music festival at dusk in a large field. A main stage with a band
playing under a rigging tower, an enormous crowd facing it with arms raised, a
sea of small camping tents behind, food trucks along one side with queues,
a small second stage, portable toilets, flags and banners on tall poles,
strings of lights, people sitting on blankets at the back.

=========================================================================

Confirm you have understood by replying with one short line only, then wait.
I will send "1".
```

---

## What to save each image as

| You send | You get | Save as | Level |
| --- | --- | --- | --- |
| `1` | City Zoo | `level_11.png` | 11 |
| `2` | Splash Park | `level_12.png` | 12 |
| `3` | Grand Mall | `level_13.png` | 13 |
| `4` | Fishing Docks | `level_14.png` | 14 |
| `5` | Castle Fair | `level_15.png` | 15 |
| `6` | County Hospital | `level_16.png` | 16 |
| `7` | Riverside School | `level_17.png` | 17 |
| `8` | Building Site | `level_18.png` | 18 |
| `9` | City Marathon | `level_19.png` | 19 |
| `10` | Festival Field | `level_20.png` | 20 |

Unlike the first batch there is no offset here: image 1 is level 11, and the
numbers run in step from there.

## Registering them

One command each. The level names are already translated, so nothing else needs
editing:

```powershell
python tool/build_level.py level `
    --scene C:\temp\findo2\level_11.png `
    --id level_11 --index 11 --name-key level.zoo `
    --height 82 --time 95 --tint 0.45
```

| Level | id | name key | height | time |
| --- | --- | --- | --- | --- |
| 11 | `level_11` | `level.zoo` | 82 | 95 |
| 12 | `level_12` | `level.water` | 80 | 95 |
| 13 | `level_13` | `level.mall` | 78 | 90 |
| 14 | `level_14` | `level.docks` | 75 | 90 |
| 15 | `level_15` | `level.castle` | 73 | 85 |
| 16 | `level_16` | `level.hospital` | 70 | 85 |
| 17 | `level_17` | `level.school` | 68 | 80 |
| 18 | `level_18` | `level.site` | 66 | 80 |
| 19 | `level_19` | `level.marathon` | 63 | 75 |
| 20 | `level_20` | `level.festival` | 60 | 75 |

You do not place her. The tool finds the hiding places itself -- in crowds, and
away from open sky where a figure would be silhouetted -- keeps them at least
140 px from any edge and well apart from each other, and writes all of them
into the level. The game picks one per attempt, so replaying a level is a fresh
search. Check the crops at `store/previews/level_NN_spot*.png`, one per place.

Then:

```powershell
python tool/level_data.py verify
flutter test
```

## Reject and re-roll

Reply `again` rather than accepting any of these:

- Any figure in a purple or violet skirt, or a bright yellow sleeveless top
- Any text, lettering or numbers on signs, boards, banners or race bibs
- A white border, frame or vignette
- A crowd that is thin for the number asked, or bunched into one half
- Soft shading or a painterly look instead of flat colour with uniform outlines

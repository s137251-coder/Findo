# One prompt for the whole set

Paste the block below into Gemini once. It sets up every rule, then you ask for
the eleven images one at a time by replying with a number.

Image models produce one image per turn, so a single prompt cannot return
eleven pictures. What it *can* do is hold the whole contract across the
conversation, which is what makes the ten maps read as one book instead of ten
unrelated illustrations.

When all eleven are in, follow `docs/GEMINI_PROMPTS.md` from Step 1 for the two
commands that turn them into playable levels.

---

```
You are producing the complete artwork set for a mobile hidden-object game
called Findo. It works like a printed "Where's Wally" book: each level is one
big crowded scene, and one specific girl is hidden somewhere in it. The player
pans and pinch-zooms to find her.

There are ELEVEN images in total: one character sheet, then ten crowd scenes.

HOW WE WILL WORK
Generate exactly ONE image per reply, in order, and nothing else. Do not
combine images, do not make a grid or a contact sheet of several, do not
summarise the brief back to me. Wait for me to reply with the next number. I
will say "1" for the character, then "2" through "11" for the scenes. If I say
"again", produce a different take on the same number.

=========================================================================
IMAGE 1 - THE CHARACTER SHEET
=========================================================================

A single cartoon character, full body, front view, standing straight and still,
arms relaxed at her sides, feet together, facing the viewer.

WHO SHE IS
A cheerful girl of about eleven with a calm, neutral expression. She is not
posing, waving, running or gesturing.

EXACT APPEARANCE - follow every colour precisely
- Hair: medium brown (#784A28), parted in the middle, worn in TWO long braids,
  one hanging on each side of her head, reaching down to chest height
- Skin: light warm tone (#F6CEB0)
- Top: a bright warm yellow (#FACE3E) sleeveless top, with a solid near-black
  (#201C22) V-shaped yoke across the chest and shoulders
- Skirt: a violet purple (#923EA8) A-line skirt, knee length, flaring outward
- Legs: bare, same skin tone as her face
- Shoes: flat, solid near-black (#201C22)

BACKGROUND FOR THIS IMAGE ONLY
A completely solid, flat, uniform pure green background, RGB 0 255 0, filling
the whole canvas. No ground line, no floor, no shadow beneath her, no scenery,
no pattern, no gradient of any kind. One single flat green.

FRAMING
The whole figure visible from the top of her head to the soles of her shoes,
centred, with a comfortable margin of green on all four sides. Nothing cropped.

Also for this image: no other characters, no props, no bag, no hat.

=========================================================================
RULES THAT APPLY TO ALL TEN SCENES (IMAGES 2 TO 11)
=========================================================================

STYLE - identical in all ten, this is what makes them a set
Flat vector illustration for a children's seek-and-find puzzle book. High-angle
three-quarter aerial view, looking down at roughly 55 degrees, so both the
ground and the fronts of buildings are visible. Every object and every person
drawn with a uniform thick black outline of the same weight. Solid flat colour
fills only: no gradients, no airbrushing, no soft shading, no photographic
texture, no drop shadows, no glow, no blur, no depth of field. Saturated but
not neon. Crisp, clean linework.

CROWD - the count changes per scene, everything else does not
Small cartoon people, each drawn full body, standing or walking, all seen from
the same high angle, each roughly one sixteenth of the image height. Wide
variety of skin tones, hair colours, hairstyles and clothing colours. Spread
evenly across the entire image with small gaps between them: never overlapping,
never clustered into one half, never leaving a large empty area.

THE MOST IMPORTANT RULE
The girl from image 1 must NOT appear in any of the ten scenes. She is added
afterwards by software, so that she is identical everywhere and her position is
known exactly. Specifically, in every scene: no girl or woman wearing a violet
or purple skirt or a purple dress, and no figure in a bright yellow sleeveless
top. If either appears, the scene contains a second version of her that the
game cannot register, which is the worst bug this game could ship.

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

IMAGE 2 - FOUNTAIN SQUARE - approximately 180 people
A town square. A round stone fountain with arching jets of water in the middle.
Three and four storey shopfronts and apartment buildings with balconies, awnings
and window boxes along the top edge. A zebra crossing, a couple of parked cars,
a delivery van, a cyclist. Wooden benches, trimmed hedges, leafy trees, paved
paths crossing the grass, a dog on a lead.

IMAGE 3 - HOLLOW FARM - approximately 210 people
A working farm on a summer day. A large barn with a red pitched roof, a second
wooden barn with stables and horses looking out, a tall grey silo with a ladder.
Cone-shaped haystacks, a red tractor, wooden post-and-rail fences dividing the
yard into paddocks. A flock of white sheep, a pen of pink pigs, a brown horse in
a round paddock, chickens and yellow chicks scattered around, geese by a small
pond, a dog running.

IMAGE 4 - THE FUNFAIR - approximately 240 people
A funfair. A row of striped canvas stalls with scalloped awnings along the top,
hoopla and coconut shy games, a big wheel with coloured gondolas on the right, a
carousel with horses, bumper cars, a helter skelter. A balloon seller holding a
huge bunch of balloons, a clown, a popcorn cart, a candy floss stand, bunting
strung between poles, picnic tables, litter bins.

IMAGE 5 - HARBOUR BEACH - approximately 260 people
A busy seaside beach. Golden sand across the lower two thirds, blue sea along
the top with small sailing boats, a rowing boat, and a wooden jetty running out
into the water. Rows of brightly coloured parasols, striped deckchairs, beach
towels laid out, an ice-cream cart with a queue, beach balls, sandcastles with
little flags, a red and white lifeguard tower, seagulls, a line of rocks at one
edge.

IMAGE 6 - CENTRAL STATION - approximately 290 people
A railway station concourse under an arched glass and steel roof, seen from
above with the roof shown as transparent so the interior is fully visible. Two
platforms with a train waiting at each. A large blank departure board, ticket
machines, wooden benches, luggage trolleys piled with suitcases, a cafe with
small round tables, a flower stall, a newsstand, a big round clock hanging from
the roof structure, pigeons on the girders.

IMAGE 7 - NIGHT MARKET - approximately 310 people
A street food night market after dark. The ground is a deep blue-purple. Rows of
food stalls under canopies, each lit by warm orange hanging lanterns, with
strings of small round fairy lights criss-crossing overhead between the stalls.
Steam rising from woks and pots, crates of fruit and vegetables, hanging paper
lanterns, low plastic stools around small tables, a noodle cart, a fish stall on
ice.
IMPORTANT: although the scene is at night, every person is clearly and warmly
lit by the stall lights and fully readable. Nobody is in silhouette or hidden in
darkness.

IMAGE 8 - SNOW VILLAGE - approximately 280 people
An alpine village in deep snow. Wooden chalets with steep snow-covered roofs and
shuttered windows, smoke curling from chimneys. A chairlift climbing the right
side with occupied chairs, ski slopes with skiers carving turns, dark green pine
trees heavy with snow, snowmen, wooden sledges, a frozen pond with skaters, log
piles, a hot drinks hut.

IMAGE 9 - THE MUSEUM - approximately 320 people
The inside of a grand museum, seen from above with the roof removed so all the
galleries are visible at once, like a cutaway. A large dinosaur skeleton mounted
in the central hall. Framed paintings hung along the walls, glass display cases
with pottery and jewels, marble columns, a wide grand staircase with a red
carpet, velvet rope barriers on brass posts, a suit of armour, a mounted whale
skeleton in one wing, school groups sitting cross-legged on the floor with a
guide.

IMAGE 10 - CUP FINAL - approximately 380 people
A packed football stadium stand, seen from a high angle. Tiered rows of coloured
seats filled with supporters in team colours, waving flags and long banners.
Stewards in high-visibility jackets standing in the aisles. The green pitch runs
along the bottom edge with players on it and a referee. Floodlight pylons at the
corners, a scoreboard with no writing on it, food kiosks at the back of the
stand.
IMPORTANT: leave a clear standing concourse or wide aisle running across the
stand where people are standing rather than seated, so the crowd is not entirely
made of seated figures.

IMAGE 11 - TERMINAL TWO - approximately 420 people
An airport departures hall, seen from a high angle. A long row of check-in desks
with queues snaking between belt barriers, security lanes with trays, seating
areas at the gates, luggage trolleys and stacks of suitcases, blank information
screens on stands, a cafe with tables, escalators going up and down, potted
plants. Along the top edge, a huge glass wall with aeroplanes parked at their
stands and a fuel truck outside.

=========================================================================

Confirm you have understood by replying with one short line only, then wait.
I will send "1".
```

---

## What to save each image as

| You send | You get | Save as |
| --- | --- | --- |
| `1` | The character on green | `findo_raw.png` |
| `2` | Fountain Square | `level_01.png` |
| `3` | Hollow Farm | `level_02.png` |
| `4` | The Funfair | `level_03.png` |
| `5` | Harbour Beach | `level_04.png` |
| `6` | Central Station | `level_05.png` |
| `7` | Night Market | `level_06.png` |
| `8` | Snow Village | `level_07.png` |
| `9` | The Museum | `level_08.png` |
| `10` | Cup Final | `level_09.png` |
| `11` | Terminal Two | `level_10.png` |

The image number and the level number differ by one: image 2 is level 1,
because image 1 is the character.

## Reject and re-roll

Reply `again` rather than accepting any of these:

- A girl in a purple or violet skirt anywhere in the crowd
- Any text, lettering or numbers on signs, boards or banners
- A white border, frame or vignette around the illustration
- A crowd that is thin, or bunched into one half with an empty area elsewhere
- Soft shading, gradients or a painterly look instead of flat colour with
  uniform outlines
- On image 1: anything other than one flat pure green field behind her

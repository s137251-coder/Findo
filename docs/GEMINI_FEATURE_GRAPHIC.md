# The Play feature graphic, drawn by Gemini

The banner that sits at the top of the store listing is `1024x500`. The one in
`store/` is built from a crop of level 3, the funfair. This is the alternative:
a scene drawn for the banner specifically, wider and composed for it.

```powershell
# save Gemini's image here, then:
python tool/generate_brand.py
```

`store/feature-art.png` is picked up automatically, centre-cropped to
`1024x500`, and everything else is composited on top. Delete the file and the
generator goes back to the level-3 crop.

### What the model draws, and what it does not

**It draws the crowd and nothing else.** Findo herself, the magnifier, and the
wordmark are composited by `tool/generate_brand.py` afterwards. That split is
deliberate, and it is worth understanding before you decide to fight it:

- **Findo has to be exactly right.** She is the one thing a player memorises —
  brown braids, yellow top with a black yoke, purple skirt. An image model
  redraws her a little differently every time, and a girl on the banner who is
  not quite the girl in the game is worse than no girl at all. The code pastes
  the actual sprite the game ships.
- **Image models cannot set type.** Text generated inside an image comes out
  with mangled letterforms, wrong spacing, and no way to match Roboto. The
  wordmark is drawn with the bundled font at the real size.
- **The lens has to sit where she is.** The generator finds a clear gap with
  people pressed up against it, stands her there, and centres the magnifier on
  her. It cannot do that if she is already painted into the picture.

So: ask for a crowd, get a crowd.

### One thing to tell the model, and one to check

The prompt asks for a **calm right-hand third** — sky, grass, a single large
silhouette — because the wordmark sits there over a dark scrim. Busy art under
the type is the single most common way a feature graphic ends up unreadable.

When the image comes back, check the **left third**: it needs real crowd, at a
consistent scale, with small gaps between people. That is where the magnifier
lands. A left third full of tents and empty ground produces a lens over nothing.

### Then check where she landed

The generator picks her spot by looking for a smooth patch with detail pressed
up against it. That is a decent proxy for "a gap in a crowd", and it is wrong
often enough that you must look at the result. Tested against a festival scene
it stood her **on the flat side panel of a food truck** — smooth area, busy
surroundings, exactly what the heuristic rewards.

Override it when that happens:

```powershell
python tool/generate_brand.py --findo 300,368
```

Two numbers in banner pixels, `1024x500`, origin top-left: the first is her
centre, the second is the ground under her shoes. It warns if the magnifier
would run off the edge and tells you the range that fits.

---

```
Draw one wide banner illustration for a mobile hidden-object game called Findo.
It plays like a printed "Where's Wally" book: one big crowded scene, one girl
hidden in it, the player pans and pinch-zooms to find her.

This image is the store banner, not a level. Draw the crowd only. Do not draw
any text, letters, numbers, logos or watermarks anywhere in the image. Do not
single out or highlight any one person.

CANVAS
Wide landscape banner, aspect ratio 2:1 - twice as wide as it is tall. The
highest resolution you can produce at that shape, 2048 x 1024 or larger. Fill
the entire frame with illustration, edge to edge, with no border, no frame, no
margin and no rounded corners.

STYLE
Flat vector illustration. High-angle three-quarter aerial view, looking down at
roughly 55 degrees, so both the ground and the fronts of structures are visible.
Every object and every person drawn with a uniform thick black outline of the
same weight. Solid flat colour fills only: no gradients, no soft shading, no
airbrushing, no photographic texture, no drop shadows, no glow, no blur, no
depth of field. Saturated but not neon. Crisp, clean linework. Bright daylight.

SUBJECT
A fairground in full swing. A ferris wheel, a carousel with painted horses,
bunting strung on poles, a bunch of helium balloons, food stalls with striped
awnings, bumper cars, picnic benches, a litter bin, a few dogs and chickens
underfoot.

THE CROWD - this is the part that matters
Hundreds of people, all drawn at the same scale, standing and walking on the
ground. Each person roughly one twenty-fifth of the image height. Wide variety
of skin tones, hair colours, ages and body shapes. Every person in a different
colour combination of top and trousers or skirt. People in ones, twos and small
groups, facing different directions, some walking, some standing talking, some
sitting. Leave small gaps of open ground between individuals - they must not
merge into a single mass, and no person may overlap another person's head.

COMPOSITION - follow this exactly
Think of the banner in vertical thirds.

LEFT THIRD: the densest crowd in the picture, people packed close on open
ground, with small clear gaps between them. No large structures here. This is
the part of the image the viewer looks at first.

MIDDLE THIRD: the carousel and the bumper cars, with crowd continuing around
their edges.

RIGHT THIRD: deliberately calm and simple. The ferris wheel as a large clean
silhouette against open sky and flat grass. Very few people. No stalls, no
bunting, no small detail, no busy pattern. This area gets covered by a dark
panel later, so anything intricate there is wasted.

Return exactly one image and nothing else - no commentary, no description, no
alternatives.
```

---

### If the shape comes back wrong

Image models often ignore aspect ratio and hand back a square. That is fine —
`scene_band()` centre-crops whatever you give it to `1024x500`. But a square
crops to its middle band, so the composition rules above land on the wrong
thirds. If it returns a square, either ask again for 2:1, or crop it yourself to
a wide strip that keeps a dense crowd on the left before saving it as
`store/feature-art.png`.

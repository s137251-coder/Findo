# The one prompt — all 81 remaining scenes

Paste the block below into Gemini **once**. Then reply with a level number and
nothing else — `20`, then `21`, then `22` — and it returns that scene. Save each
image as `level_NN.png` and register the lot with one command:

```powershell
python tool/build_all_levels.py --scenes C:\temp\findo\scenes
```

### What "all at once" actually means

Image models return **one picture per turn**. There is no way to ask for
eighty-one images in one reply, from Gemini or from anything else. What a
single prompt *can* do is hold the style, the crowd rules and the near-miss
rules across a whole conversation, so that every image comes back looking like
a page from the same book. That is what this is, and it is the thing that
matters — the twenty maps already in the game only look like one game because
the rules were pinned once and never restated.

**If quality drifts after a dozen or so images**, start a fresh chat and paste
the prompt again. Model adherence decays over a long session, and drift shows
up as thinner crowds and a wandering camera angle before it shows up as
anything obvious. The bands below are the natural place to break: their
parameters do not change within a band.

Levels 1 to 19 are already built. This covers 20 to 100.

---

```
You are producing the artwork for a mobile hidden-object game called Findo. It
works like a printed "Where's Wally" book: each level is one big crowded scene,
and one specific girl is hidden somewhere in it. The player pans and
pinch-zooms to find her.

I need 81 scenes, numbered 20 to 100. They are listed at the end of this
message.

HOW WE WILL WORK
I will reply with a single number. Return exactly ONE image for that number and
nothing else - no commentary, no description, no alternatives, no text in the
reply. Then wait for the next number. Every rule in this message applies to
every image, so that all of them read as pages from one book.

STYLE - identical in every image, never varying
Flat vector illustration. High-angle three-quarter aerial view, looking down at
roughly 55 degrees, so that both the ground and the fronts of buildings are
visible. Every object and every person drawn with a uniform thick black outline
of the same weight. Solid flat colour fills only: no gradients, no airbrushing,
no soft shading, no photographic texture, no drop shadows, no glow, no blur, no
depth of field. Saturated but not neon. Crisp, clean linework.

CANVAS
Square 1:1 aspect ratio. The highest resolution you can produce, 2048 x 2048 or
larger. The illustration fills the entire square edge to edge: no border, no
frame, no vignette, no margin, no white edge, no rounded corners.

CROWD
Each scene names how many people it wants and how tall they are as a fraction
of the image height. Draw every one of them full body. Wide variety of skin
tones, hair colours, hairstyles and clothing colours.

Spread them evenly across the entire image with small gaps between them: never
overlapping, never clustered into one half, never leaving a large empty area.
Fill the frame right to the edges. A scene with an empty quarter is unusable.

POSES - every figure is doing something
No two people share the same pose. Each is doing something that belongs to that
particular place. Vary which way they face: some towards the viewer, some away,
some in profile. Vary build, age and height. Put small interactions between
pairs and groups - two people talking, an adult bending to a child, someone
handing something over - so the crowd reads as a real moment rather than a
field of figures.

Keep about a third of them simply standing or walking normally, mixed evenly in
among the rest, so that a person standing still is an ordinary sight in the
scene and not the one thing that catches the eye.

NEAR-MISSES - this is what makes the game hard
The girl the player hunts has three signatures together: brown hair in two
braids, a bright yellow sleeveless top, and a violet skirt. SHE IS NOT IN THESE
IMAGES. She is added by the game afterwards. What the crowd needs instead is
people who are almost her.

Each scene below says how many of each to include.

A ONE-TRAIT near-miss has exactly one of those three signatures and nothing
else in common with her. A woman with brown braids in a green dress. A man in a
yellow sleeveless top and jeans. A child in a violet skirt and a grey jumper.

A TWO-TRAIT near-miss has exactly two, and clearly not the third. Brown braids
and a yellow top, but blue trousers. A yellow top and a violet skirt, but short
blonde hair.

Spread the near-misses across the whole image, never grouped together.

NEVER draw a figure carrying all three signatures at once. One such figure in
the artwork breaks the level completely, because the player would find a second
girl who looks exactly like the one they are hunting.

Every purple in every image must be a visibly different purple from hers: plum,
magenta, lilac, indigo, mauve, wine. Never a plain mid violet. Two purples that
read as the same colour will be corrected away automatically and the near-miss
will be wasted.

NIGHT SCENES
Scenes marked NIGHT sit under a low ambient light, with lamps, lanterns,
screens, fires or floodlights as the light sources. Still flat colour: darkness
is painted as darker flat fills, never as shading, glow or blur. The crowd must
stay completely readable - a night scene the player cannot search is a broken
level, not a hard one.

DO NOT INCLUDE, IN ANY IMAGE
No text, letters, numbers, written signs, shop names, logos, signatures or
watermarks anywhere. No figure with all three of her signatures. No borders or
margins. No close-up: the camera is always high and wide.

=================== THE SCENES ===================

--- BAND 2 - about 700 people, each 1/22 of image height,
    2 one-trait near-misses, 0 two-trait, daylight ---

20 FISHING DOCKS. A working fishing harbour at full tilt. Wooden quaysides with
boats moored two deep, stacks of crab pots and coiled rope, a fish market under
an open awning with crates of ice and buyers pressing in, a crane lifting a
container, warehouses with sliding doors, forklifts between pallets, a
lighthouse at one edge, nets drying on frames, a slipway with a boat winched
out.

--- BAND 3 - 440 to 520 people, growing through the band, each 1/20 of image
    height, 4 one-trait near-misses, 0 two-trait, daylight ---

21 ROOFTOP POOL. A hotel rooftop pool deck at capacity. Swimmers pushing off
the wall, a lifeguard on a high chair, waiters threading between loungers with
trays, someone rubbing on sunscreen, a child on a float, towels being shaken
out, a bar along one edge with every stool taken, city skyline beyond the
parapet.

22 BOTANICAL GLASSHOUSE. A Victorian palm house packed with visitors. Gardeners
on step ladders misting leaves, a school group crouched round a pond, someone
photographing an orchid, a man carrying a potted fern, benches full, a spiral
staircase up to a walkway with people on it, watering cans and hoses.

23 SKI RESORT BASE. The bottom of a ski area at mid-morning. Queues zigzagging
at the lift gates, chairs loading, people clipping into bindings, an instructor
demonstrating a snowplough to children, a first-aid sled being pulled, racks of
hire skis, a terrace of picnic tables, snow cannons.

24 PUBLIC LIBRARY. A grand reading room over two floors. Readers hunched at
long tables under lamps, a librarian pushing a trolley, someone up a ladder at
a high shelf, a queue at the desk, children cross-legged at a story circle, a
study group arguing quietly, computer terminals along one wall.

25 FARMERS MARKET. A market square of trestle stalls on a Saturday. Traders
calling over stacked crates, someone weighing apples, a cheese wheel being cut,
shoppers with canvas bags, a queue at a bread van, a knife sharpener at work,
dogs tied to table legs, bunting strung between poles.

26 SKATE PARK. A concrete skate park mid-session. A rider dropping into a bowl,
someone sitting on the coping, a BMX in the air off a ramp, spectators along a
fence, a first attempt with arms out, boards being repaired on a bench, a
drinks van, painted walls.

27 THE AQUARIUM. A dim aquarium hall with lit tanks. A curved tunnel with
people looking up at rays, a child with both palms on the glass, a keeper on a
gantry above an open tank feeding by hand, a touch pool with a queue, a talk in
progress with a semicircle of listeners, pushchairs parked.

28 CATHEDRAL SQUARE. A cathedral forecourt on a feast day. A procession forming
with banners, tourists photographing the west front, a woman feeding pigeons, a
queue for the tower stairs, market stalls round the edge, scaffolding on one
tower with masons on it, cafe tables spilling out.

29 BUS DEPOT. A city bus depot at shift change. Buses nose-in over inspection
pits, drivers walking between them with clipboards, a wash bay with a bus half
through it, mechanics under a raised vehicle, a crowd at the duty board, a
canteen door, fuel pumps.

30 WATER PARK. A water park of flumes and pools. Riders shooting out of tube
ends into splash pools, queues up the tower stairs, a wave pool full of bobbing
heads, lifeguards on stands, a lazy river of rings, sun loungers, a snack bar.

--- BAND 4 - 540 to 600 people, each 1/22 of image height,
    6 one-trait near-misses, 1 two-trait, daylight ---

31 AMUSEMENT ARCADE. A packed arcade floor. Players at racing cabinets, an air
hockey match, someone feeding coins into a claw machine, a queue at the token
booth, a dance machine with a ring of watchers, an attendant with a key ring at
an open cabinet, prize shelves.

32 GARDEN NURSERY. A plant nursery under polytunnels. Customers pushing flat
trolleys of trays, staff loading bags of compost, someone bending to smell a
rose, a potting bench with people working, coiled hoses, a checkout queue,
wheelbarrows, long rows of shrubs.

33 CONTAINER PORT. A container terminal working. Straddle carriers moving
between stacks, lashers on a ship's deck, a gang round an open container,
high-vis crews with radios, trucks queueing at a gate, a gantry crane over the
quay, coils of cable.

34 TEXTILE BAZAAR. A covered cloth market. Bolts of fabric unrolled across
counters, a tailor measuring a customer, porters with bales on their shoulders,
haggling at a till, sewing machines running at the back, fabric hung overhead
as a canopy.

35 BOWLING ALLEY. A twenty-lane bowling alley on league night. Bowlers
mid-delivery, groups on the benches, someone choosing a ball from a rack, a
shoe hire counter with a queue, a birthday party at one lane, a bar down one
side.

36 FIRE STATION OPEN DAY. A fire station with the doors up. Children in helmets
on an engine step, a hose demonstration with a crowd, a ladder extended with a
firefighter on it, a cutting demonstration round a wrecked car, a barbecue, a
queue for a bouncy castle.

37 CATTLE AUCTION. A livestock auction mart. Bidders banked on tiered benches
round a ring, an auctioneer at a rostrum, a beast being walked through,
handlers at the gates, pens behind full of animals with farmers leaning on the
rails, a tea counter.

38 FLOWER AUCTION HALL. A wholesale flower hall before dawn. Trolleys of
buckets wheeled in lines, buyers walking the rows with notebooks, a clock
auction with banked seats, forklifts with pallets, someone sleeving bouquets,
loading bays with vans.

39 RECYCLING DEPOT. A recycling centre on a Saturday. Cars queued at the ramp,
people carrying boxes to skips, a staff member directing traffic, a crane grab
over a scrap pile, a reuse shop with browsers, bays of sorted material, a
weighbridge.

40 BAGGAGE HALL. An airport baggage reclaim. Passengers three deep at
carousels, bags going round, trolleys being pulled free, a family reuniting,
staff at an oversize counter, a customs channel with officers, a queue at a
lost luggage desk.

--- BAND 5 - 620 to 680 people, each 1/26 of image height,
    8 one-trait near-misses, 1 two-trait, daylight ---

41 MARCHING BAND PARADE. A street parade of marching bands. Drum lines in
formation, brass players mid-step, majorettes with batons, a crowd four deep
behind barriers, marshals in tabards, children on shoulders, a float following,
flags.

42 OPEN-AIR CINEMA. A park screening filling up in the late afternoon. People
spreading rugs, deckchairs being unfolded, a queue at a popcorn van,
technicians on a ladder at the screen frame, friends waving across the grass,
dogs, picnic baskets.

43 CYCLING CRITERIUM. A city-centre bike race. The bunch sweeping through a
corner, spectators leaning over barriers, mechanics in a pit with spare wheels,
a commissaire's motorbike, a crowd at the finish arch, team tents.

44 BALLOON MEET. A hot air balloon meet on a field. Envelopes being inflated
flat on the grass with fans, crews holding crown lines, a basket being righted,
spectators walking between them, one balloon already lifting, burners,
trailers.

45 THE DOG SHOW. A dog show under marquees. Handlers running dogs round a ring,
a judge going over a dog on a table, grooming benches with dryers, spectators
on folding chairs, a queue at a trade stand, dogs in crates.

46 KITE FESTIVAL. A kite festival on a headland. Fliers with lines out, a huge
inflatable kite anchored by a team, children running with small kites,
spectators sitting on the grass looking up, stalls along one edge, windsocks.

47 REGATTA QUAYSIDE. A rowing regatta on a river bank. Crews carrying a shell
overhead, boats pushing off a pontoon, coaches on bikes along the towpath,
spectators with programmes, a start tower, tents, an umpire's launch.

48 ICE RINK GALA. An indoor ice rink during a gala. Skaters warming up in a
circuit, a pair lifting mid-ice, coaches at the barrier, a full seating bank, a
queue at skate hire, ice technicians at the gate, kit bags.

49 MOTOR SHOW. A motor show hall. Cars on turntables and plinths, crowds
pressing round an open bonnet, presenters with headsets, someone sitting in a
driver's seat, a stand with a queue, banners overhead, lighting gantries.

50 STREET FOOD ALLEY. A narrow street of food stalls at lunchtime. Cooks over
griddles and woks, queues coiling between tables, people eating standing up, a
juice stall pressing fruit, plastic stools, awnings, a scooter squeezing
through.

--- BAND 6 - 700 to 760 people, each 1/30 of image height,
    10 one-trait near-misses, 2 two-trait, daylight ---

51 STORE ATRIUM. A department store atrium over several floors. Escalators
criss-crossing with people on every step, shoppers leaning over balcony rails,
a perfume counter with a queue, a piano being played, bags everywhere, a glass
roof above.

52 THE CASINO FLOOR. A casino floor at full tilt. Players banked round roulette
and blackjack tables, dealers mid-deal, rows of slot machines with someone at
nearly every one, waiters with trays, a cashier queue, a pit boss watching.

53 CONVENTION CENTRE. A convention hall of exhibitor booths. Aisles jammed,
demonstrations with small crowds round them, people scanning badges, a stage
with a talk in progress, freebies being handed out, a coffee queue.

54 CLIMBING GYM. An indoor climbing centre. Climbers spread over the walls at
every height, belayers below, boulderers on mats, someone chalking up, an
instructor pointing out a route, a queue at the desk, kit on benches.

55 ENGINE ROUNDHOUSE. A locomotive roundhouse on an open day. Engines radiating
from a turntable, visitors walking between them, a footplate with a queue up
the steps, fitters under a loco, the turntable turning with people watching, a
shop in one corner.

56 CRUISE SHIP DECK. A cruise ship's top decks at sea. Loungers full round a
pool, a band on a small stage, a buffet queue, deck games, people at the rail
looking out, a waterslide, a jogging track with runners, funnels.

57 THEATRE AUDITORIUM. A theatre seen from above during the interval. Stalls
and two balconies with people standing and moving along rows, an usher with a
torch, a crush at the bar at the back, musicians returning to the orchestra
pit.

58 TRAMPOLINE PARK. A trampoline park mid-session. Jumpers across a grid of
beds, a foam pit with someone in mid-air, a dodgeball court, staff in bibs on
the edges, a queue for the airbag, benches of waiting parents, lockers.

59 LECTURE HALL. A raked university lecture theatre, full. Students writing, a
lecturer at a screen, latecomers on the steps, someone asleep, hands up, a row
of laptops, a demonstrator handing out sheets, a crowd in the doorway.

60 WHOLESALE FISH HALL. A wholesale fish market at dawn. Boxes of ice down long
aisles, buyers with hooks and notebooks, filleting at a bench, porters with
barrows, an auctioneer with a crowd, hosing down, gulls at the open doors.

--- BAND 7 - 780 to 840 people, each 1/30 of image height,
    12 one-trait near-misses, 2 two-trait, daylight.
    YELLOW-DOMINANT: the ground, produce, awnings and vehicles are yellows and
    golds, so that a single yellow garment is an ordinary sight here rather
    than something that catches the eye ---

61 SUNFLOWER FESTIVAL. A sunflower farm open to visitors. Head-high rows with
paths cut through, people photographing among the stems, a cutting field with
buckets, a tractor trailer ride, a queue at a farm shop, straw bales.

62 HARVEST FAIR. A wheat harvest fair on stubble. Combines and vintage tractors
on display, a threshing demonstration with a crowd, stacked sheaves, a tug of
war, a beer tent, a produce marquee, golden fields to every edge.

63 CORN MAZE. An autumn corn maze and pumpkin field. Families at the maze
entrance with maps, heads visible above the corn along the paths, a pumpkin
field with wheelbarrows, a hay bale climb, a cider stall, scarecrows.

64 TAXI RANK. A yellow taxi rank at a station front. Cabs nose to tail down the
kerb, drivers leaning on doors, a marshal with a whistle, passengers with
cases, a queue behind railings, luggage being lifted into boots.

65 ROADWORKS JUNCTION. A city junction dug up for works. Yellow diggers and
dumpers, workers in yellow high-vis everywhere, a jackhammer crew, barriers and
cones, a traffic controller, pedestrians squeezing along a boarded walkway, a
site cabin.

66 BEEKEEPERS FAIR. A beekeeping fair in a meadow. Rows of hives with
beekeepers in suits, a glass observation hive with a crowd, honey stalls with
jars catching the light, an extraction demonstration, candle making, straw
skeps.

67 LEMON GROVE MARKET. A citrus market in a grove. Crates of lemons stacked
shoulder high, pickers coming out of the trees with bags, a juicing stall,
buyers inspecting fruit, a weighing station, ladders against trunks.

68 SCHOOL BUS DEPOT. A school bus depot at pick-up. Yellow buses in ranks,
children boarding in lines, drivers doing walk-round checks, staff with
clipboards, a queue at a doorway, mechanics at an open engine bay, a wash lane.

69 MARIGOLD TEMPLE FAIR. A temple fair heaped with marigolds. Garland sellers
threading flowers, mounds of orange and yellow blooms, pilgrims queueing at the
steps, a priest at a shrine, drummers, offerings on trays, brass and saffron
cloth.

70 DESERT RALLY CAMP. A desert rally bivouac. Cars and bikes on stands with
mechanics under them, a sand-coloured tent city, a briefing crowd, refuelling
drums, a start ramp with spectators, dust hanging in the air.

--- BAND 8 - 860 to 900 people, each 1/30 of image height,
    14 one-trait near-misses, 3 two-trait, daylight.
    VIOLET-DOMINANT: the flowers, fabric, light and painted surfaces are purples
    and mauves, so that a single purple garment is an ordinary sight here.
    Keep every one of those purples visibly different from a plain mid violet ---

71 LAVENDER FESTIVAL. A lavender farm in full flower. Rows of purple lavender
to the horizon, visitors walking between them, cutters with sickles and
baskets, a distillery tent, a stall of tied bunches, picnic blankets.

72 JACARANDA BOULEVARD. A boulevard under jacaranda in bloom. Purple canopies
overhead and fallen blossom carpeting the road, cafe tables under the trees,
people photographing, a market along the pavement, cyclists, benches.

73 NEON ARCADE ALLEY. A covered arcade lit violet and magenta. Sign boards and
tube lighting in purples, gaming booths, a photo booth queue, vending machines,
crowds shoulder to shoulder, a stairwell up to more floors.

74 GRAPE HARVEST. A vineyard at harvest. Pickers bent to the vines with purple
grapes in crates, a tractor with a bin, a crushing floor with a crowd round it,
tasting tables, stacked barrels, purple-stained hands and cloth.

75 AMETHYST MINE TOUR. A show mine and gem market. Visitors in helmets on a
walkway through violet-lit rock, a guide with a group, stalls of amethyst
geodes, a polishing bench, a queue at a cage lift, lamps.

76 TWILIGHT BEACH CONCERT. A beach concert under a violet sky. A stage with a
band, the crowd dense on the sand with arms up, a bar queue, deck chairs at the
back, food stalls, flags, a purple sea.

77 THE ORCHID SHOW. An orchid show under glass. Tiered displays of purple
orchids, judges with clipboards, growers tending exhibits, visitors leaning in
with cameras, a sales area with a queue, watering cans, staging.

78 PURPLE CARNIVAL. A carnival parade in purple costume. Dancers in violet
feathers and sequins, a drum section, floats draped in purple, a crowd behind
barriers, stilt walkers, confetti, banners.

79 BLACKBERRY MARKET. A berry market. Punnets of blackberries and plums in
purple heaps, sellers weighing fruit, a jam stall with a queue, a juice press,
crates being carried, awnings dyed mauve.

80 VIOLET HOUR PROMENADE. A seafront promenade at the violet hour. Strollers
along the rail, an ice cream queue, a bandstand with a small crowd, benches
full, cyclists, a pier, everything under a mauve light.

--- BAND 9 - about 900 people, each 1/30 of image height,
    16 one-trait near-misses, 3 two-trait. NIGHT ---

81 LANTERN RIVER FESTIVAL. A river lantern festival at night. Crowds on both
banks setting paper lanterns on the water, boats hung with lamps, a bridge
packed with watchers, stalls with strings of bulbs, reflections on the river.

82 FIREWORKS EMBANKMENT. A city embankment during fireworks. Crowds massed
along the railings looking up, phones raised, marshals in high-vis, food vans
with lit hatches, a bridge closed to traffic and solid with people.

83 THE NIGHT ZOO. A zoo open after dark. Lit enclosures with visitors at the
glass, keepers with torches, a queue at the nocturnal house, a lit path with
families on it, a feeding talk with a small crowd, lanterns in the trees.

84 MIDNIGHT BAZAAR. A night bazaar of lit stalls. Bulbs strung overhead,
traders under awnings, a food row with steam rising, crowds squeezing between
tables, a generator, carpets and lamps for sale.

85 WINTER LIGHT TRAIL. A winter light trail through a park. Illuminated arches
and tunnels with people walking through them, a lit lake with reflections, a
mulled wine hut with a queue, children with light-up toys, bare trees strung
with bulbs.

86 HARBOUR AT DUSK. A working harbour at dusk. Boats lit at their moorings, a
quayside market packing up under lamps, nets under floodlights, a fish
restaurant terrace full, a lighthouse beam, crews on deck.

87 DRIVE-IN CINEMA. A drive-in cinema at night. Cars in ranks facing a lit
screen, people on bonnets and sitting in open tailgates, a concession hut with
a queue, someone directing cars in with a torch, speaker posts.

88 FLOODLIT SKI SLOPE. A ski slope under floodlights. Skiers coming down a lit
piste, a lift running with loaded chairs, a lit terrace bar with a crowd, a
piste basher, snow bright under the lamps, dark trees at the edges.

89 TORCHLIT PROCESSION. A torchlit procession through a town. A long column
carrying torches, crowds lining the street, a band, banners, children on
shoulders, sparks in the air, watchers at upper windows.

90 AIRPORT AT NIGHT. An airport apron at night. Aircraft at lit stands with
ground crews working, baggage trains, a fuel bowser, marshallers with wands, a
terminal wall of windows with silhouetted passengers, floodlight masts.

--- BAND 10 - about 900 people, each 1/30 of image height,
    18 one-trait near-misses, 4 two-trait. NIGHT.
    These are the hardest levels in the game: the busiest crowds, and both
    yellow and purple appearing naturally throughout the scene ---

91 NEW YEAR COUNTDOWN. A city square at the countdown. A dense crowd filling
the square, a lit stage with a screen, streamers and confetti in the air,
people on shoulders, police lines, bars spilling out, a clock tower.

92 CARNIVAL FINALE. The last night of a carnival. Floats lit from within,
dancers in feathers, sound trucks, a crowd packed to the barriers and dancing,
sparklers, a judges' stand, streets solid with people.

93 RUSH HOUR CONCOURSE. A vast station concourse at night. Commuters streaming
in every direction, a departure board with a crowd beneath it, ticket gates
flowing, buskers, a queue at a coffee stand, lit platforms beyond.

94 CUP FINAL, NIGHT. A floodlit stadium at a cup final. Stands packed and
banked steeply, flags and scarves held up, a pitch with small figures of
players, stewards facing the crowd, a big screen.

95 THE MIDNIGHT SALE. A shopping street on a midnight sale night. Lit
shopfronts with queues outside them, crowds moving between doors, security on
the doors, bags everywhere, a street performer with a ring of watchers.

96 PILGRIMAGE BRIDGE. A great bridge crossed by a night pilgrimage. A slow
river of people with candles and lamps, vendors along the parapet, a lit shrine
at one end, boats below with lights, a dense mass on both approaches.

97 ROOFTOP FESTIVAL. A rooftop festival at night. Several connected roof
terraces with crowds, a DJ booth, strings of bulbs, a bar queue, people at the
parapet looking over a lit city, heaters, tented corners.

98 FLOATING MARKET. A floating market by lamplight. Boats packed gunwale to
gunwale loaded with produce, traders standing and passing goods across, buyers
on a lit jetty, lanterns on poles, cooking on board, reflections.

99 ICE PALACE GALA. An ice palace gala at night. Carved ice halls lit violet
and gold, a skating floor with couples on it, an ice bar with a queue,
sculptors finishing a piece, a band, spectators in heavy coats.

100 THE GREAT CROWD. The finale, and the busiest image of all: a colossal city
plaza at night with every kind of gathering happening at once. A stage at one
end, a market along one side, a fountain ringed with people, a procession
entering, food stalls, a big screen, the whole square solid with people right
to every edge.
```

---

## After the images arrive

Save each one as `level_NN.png` in a single folder, then:

```powershell
python tool/build_all_levels.py --scenes C:\temp\findo\scenes
```

Build them **in order** — a level with a hole before it is held out of the
manifest until the gap is filled, because the unlock chain runs on consecutive
indexes.

Then look at `store/previews/level_NN_spot*.png`. One crop per hiding place, and
they are how you catch the two failures that matter: a spot the tool found
somewhere nobody would stand, and a crowd that happens to contain a genuine
second Findo. Budget for roughly one image in six coming back unusable — that
was the hit rate on the first twenty.

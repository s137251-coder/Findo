# Audio

`ok/`, `notok/` and `music/` are pools. The game reads them from the asset
manifest at startup and picks one at random per event, so adding a file is a
copy, not a code change. The `.wav` files at the top level are the synthesised
fallback for a build that ships empty pools -- `tool/generate_audio.py` makes
those.

## Only ship audio whose licence you can point at

This is not a style rule. Google Play removes apps on a copyright complaint,
and the complaint does not have to be right to cost you the listing while it
is sorted out. Two sources are in use here:

| Source | Filename shape | Terms |
| --- | --- | --- |
| Mixkit | `mixkit-*` | Free licence, commercial use, no attribution required |
| Freesound | `<6+ digit id>-<author>-*` | Per upload -- check the id's page |

**Freesound licences differ per upload.** CC0 needs nothing; CC-BY needs a
credit somewhere the player can see it. The two in `music/` are ids 753499
(AudioCoffee) and 854591 (SergeQuadrado) -- confirm both before production and
add credits to the store listing if either is CC-BY.

## What was removed, and why

Fifteen files were deleted in the commit that added this README. Seven were
recognisable third-party property: SpongeBob clips (Nickelodeon), the
Final Fantasy V victory fanfare (Square Enix), a Mario level-up (Nintendo), a
Ragnarok Online sting (Gravity), and the Jixaw metal-pipe clip.

The other eight had no identifiable source -- names like `wrong-1.mp3` and
`money-soundfx.mp3`. Unknown provenance is its own licensing problem: you
cannot show you hold the right to ship it, and "it was in a sound pack" is not
a defence. They are in git history if a licence turns up.

**The source folders outside this repo still hold the deleted files.** Clear
them too, or the next sync brings every one of them back.

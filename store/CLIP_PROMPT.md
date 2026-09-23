# קליפ ההיכרות — פרומפט לייצור וידאו

קליפ אחד שמסביר את המשחק בלי מילה, ובונה חיבור לדמות: ילדה אמיתית הופכת
לדמות מצוירת, נכנסת לעולם של המשחק, ומתחבאת בתוך הקהל.

נכתב עבור: מי שמפעיל את מודל הווידאו ומרכיב את הקליפ.

---

## איך זה בנוי — ולמה לא הכול במודל אחד

מודל וידאו יודע לעשות דמות אחת בתנועה מצוין. הוא **לא** יודע לייצר מאות דמויות
זעירות, עקביות, בסגנון קבוע — וזה בדיוק השוט האחרון, שהוא כל העניין.

לכן הקליפ מורכב משני חלקים:

| חלק | כמה | מי מייצר |
| --- | --- | --- |
| א. ילדה אמיתית → מונפשת → נכנסת לעולם | 6 שניות | מודל הווידאו |
| ב. היא מתקטנת לתוך הקהל, המצלמה נסוגה | 4 שניות | `tool/make_clips.py`, מהמפה האמיתית |

החלק השני נבנה מהמפה שבמשחק, כך שמה שהצופה מתבקש לחפש הוא **בדיוק** מה שיקבל
כשיוריד. זה גם מה שמונע את הפער שבין פרסומת למשחק.

---

## מה לצרף למודל

| קובץ | בשביל מה |
| --- | --- |
| `real.mp4` | הדמות האמיתית — פנים, שיער, תלבושת |
| `anime.mp4` (או `assets/images/targets/findo.png`) | **עיצוב היעד המדויק** של הדמות המצוירת |
| `assets/images/maps/level_03.webp` | סגנון העולם שהיא נכנסת אליו |

---

## הפרומפט

העתק הכל, באנגלית:

```
A ten-second vertical video, 1080x1920, no text of any kind, no logos, no user
interface, no captions, no watermark. Silent.

THE CHARACTER
Use the girl in the attached live-action video exactly as she is: a young girl
with brown hair in two long braids, a bright yellow sleeveless top with a black
V-shaped neckline, and a mid-violet skirt that falls to just below the knee,
with plain black shoes. Her face, her hair and her clothing must stay
recognisably the same person from the first frame to the last. These three
things -- the two brown braids, the yellow sleeveless top, the violet skirt --
are the whole point of the character and may never change colour or shape.

THE SECOND ATTACHMENT is the exact cartoon design she must become: flat vector
illustration, uniform thick black outline of even weight, solid flat colour
fills, no gradients, no soft shading, no airbrushing, no drop shadows, no glow,
no blur, simple friendly face with small dot eyes. Match that design precisely
rather than inventing a cartoon of your own.

SHOT 1 - 0 to 2 seconds
The real girl stands on a plain soft white background, framed from the knees
up, lit evenly and brightly. She looks straight into the camera, smiles, and
gives one small friendly wave. Natural, warm, unhurried. The camera is still.

SHOT 2 - 2 to 3.5 seconds
She turns into the cartoon. The change sweeps across her once, from her feet up
to her head, in under a second: as it passes, the photograph becomes the flat
vector drawing, the black outline draws itself around her, and the colours
flatten into solid yellow, violet and brown. Her pose and her expression do not
change while it happens -- it is the same girl, drawn. No sparkles, no magic
dust, no particle effects, no light beams. Clean and instant.

SHOT 3 - 3.5 to 6 seconds
The white background falls away and an illustrated world builds around her in
the same flat vector style as the third attachment: a bright, busy outdoor
funfair seen from a high three-quarter aerial angle, roughly 55 degrees looking
down, with stalls, bunting, a carousel and a big wheel, drawn in solid flat
colour with the same uniform thick black outlines. As the world arrives, the
camera begins to rise and pull back, and she starts to walk away from the
camera into the scene. Cartoon people appear around her, all drawn in the same
style and the same weight of outline.

SHOT 4 - 6 to 10 seconds
The camera keeps rising and pulling back, faster now. She walks deeper into the
growing crowd, glances back over her shoulder at the viewer once, and then
turns away and stands still among the other people, facing away. The crowd
thickens around her until there are hundreds of small figures filling the whole
frame, and she is simply one of them -- still visible, still wearing the yellow
top and the violet skirt, but no larger and no brighter than anyone else. The
final second holds completely still on the crowded scene.

STYLE RULES, IN EVERY FRAME AFTER THE CHANGE
Flat vector illustration only. Uniform thick black outlines of the same weight
on every person and every object. Solid flat colour fills. No gradients, no
photographic texture, no soft shading, no drop shadows, no glow, no blur, no
depth of field, no lens flare, no film grain. Saturated but not neon.

THE ONE RULE THAT MATTERS MOST
Nobody else in the crowd may have all three of her signatures together. Other
people may have brown braids, or a yellow top, or a violet skirt -- never two
of them on the same person, and never all three. A second girl who looks like
her ruins the whole idea.

Also: no other character looks at the camera, and nothing in the scene points
at her, circles her, highlights her or marks her in any way. The viewer has to
find her.

DO NOT INCLUDE
No text, letters, numbers, signs, logos or watermarks. No arrows, circles,
sparkles or highlights on the girl. No camera shake, no zoom punches, no speed
ramps. No music or sound.
```

---

## מה לבדוק בסרטון שיחזור

| | אם לא — מה לעשות |
| --- | --- |
| התלבושת זהה מההתחלה לסוף | להריץ שוב; זה הכישלון הנפוץ ביותר |
| אין אף דמות עם שלושת הסימנים | להריץ שוב. זה שובר את הרעיון |
| הסגנון שטוח — בלי הצללות וזוהר | לחזק את סעיף STYLE RULES |
| היא נראית בשוט האחרון, קטנה | אם נעלמה לגמרי — לבקש שתעמוד קרוב יותר למרכז |
| אין טקסט בשום מקום | להריץ שוב |

**אם השוט האחרון יוצא חלש** — וסביר שכן — קח רק את 6 השניות הראשונות. אני
מחבר להן זנב מהמפה האמיתית, וזו ממילא האפשרות הטובה יותר.

---

## איפה הקליפ הזה נכנס בקמפיין

**הוא לא מחליף את עשרים קליפי החידה — הוא מקדים אותם.**

- **הפוסט הראשון בחשבון**, שמסביר מי היא ומה המשחק
- **הפוסט המוצמד** בפרופיל, שכל מבקר חדש רואה קודם
- **הקריאייטיב הראשון בתשלום**, כי הוא היחיד שמסביר את המשחק למי שלא מכיר

עשרים קליפי החידה מניחים שהצופה כבר מבין את המשחק. הקליפ הזה הוא מה שגורם לו
להבין — ולהתחבר לדמות שהוא מחפש.

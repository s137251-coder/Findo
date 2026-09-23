# קליפ ההיכרות — פרומפט לייצור וידאו

קליפ אחד שמסביר את המשחק בלי מילה, ובונה חיבור לדמות: ילדה אמיתית הופכת
לדמות מצוירת, נכנסת לעולם של המשחק, ומתחבאת בתוך הקהל.

נכתב עבור: מי שמפעיל את מודל הווידאו ומרכיב את הקליפ.

---

## מה לצרף — ארבע תמונות, לא סרטונים

מחולל הווידאו של Gemini מקבל **עד ארבע תמונות ייחוס** לשמירת עקביות של דמות,
אובייקט וסגנון. הוא **לא** מקבל סרטון כייחוס, אז הכנתי מתוך הסרטונים שלך את
הפריימים הנכונים. הכל ב-`store/clip_refs/`:

| # | קובץ | בשביל מה |
| --- | --- | --- |
| 1 | `1_girl_real.png` | הילדה האמיתית — פנים, צמות, תלבושת. המסך הירוק הוסר |
| 2 | `2_findo_cartoon.png` | עיצוב היעד המדויק של הדמות המצוירת |
| 3 | `3_world_style.png` | סגנון העולם שהיא נכנסת אליו |
| 4 | `4_crowd_scale.png` | **כמה קטן אדם בעולם הזה** — בלי זה המודל מצייר קהל של ענקים |

**הגדרות בממשק:** יחס **9:16 אנכי**, האיכות הגבוהה ביותר. אם יש שדה נפרד
ל-negative prompt, הדבק בו: `text, letters, logos, watermark, arrows, circles,
highlights, sparkles, glow, gradients, drop shadows, camera shake, music`.

**למה שמונה שניות:** זה האורך שהמודל מייצר בבת אחת. אם יש בממשק שלך אפשרות
הארכה (extend), אפשר להוסיף שניות בסוף — אבל שמונה מספיקות לקליפ הזה.

---

## הפרומפט

הטקסט המלא שמור גם ב-`store/clip_refs/PROMPT.txt`, להעתקה נוחה.

```
An eight-second vertical 9:16 video of a girl who turns into a cartoon and
hides inside an illustrated crowd. Silent, with no text anywhere in the frame.

THE GIRL, FROM THE FIRST REFERENCE IMAGE
A young girl with brown hair in two long braids, a bright yellow sleeveless top
with a black V-shaped neckline, and a mid-violet knee-length skirt. Keep her
face, her hair and her clothes the same person in every frame. Those three
things -- two brown braids, yellow sleeveless top, violet skirt -- are the
whole point of her and must never change colour or shape.

THE CARTOON SHE BECOMES, FROM THE SECOND REFERENCE IMAGE
Flat vector illustration: one uniform thick black outline of even weight around
her, solid flat colour fills, a simple friendly face with small dot eyes. No
gradients, no soft shading, no airbrushing, no drop shadows, no glow, no blur.
Match that drawing rather than inventing a cartoon of your own.

THE WORLD, FROM THE THIRD AND FOURTH REFERENCE IMAGES
A bright outdoor funfair drawn in the same flat vector style, seen from a high
three-quarter aerial angle looking down at about 55 degrees, with stalls,
bunting, a carousel and a big wheel. Every person and every object carries the
same uniform thick black outline. The fourth image shows how small a person is
in that world: at the end of the clip the people are that size.

0.0 to 1.5 SECONDS
The real girl stands on a plain white background, framed from the knees up,
evenly lit. She looks straight into the camera, smiles, and gives one small
friendly wave. The camera is still. Warm, natural, unhurried.

1.5 to 2.5 SECONDS
She turns into the cartoon. The change sweeps up her body once, from her feet
to her head, in under a second: as it passes, the photograph becomes the flat
vector drawing, the black outline draws itself around her, and the colours
flatten into solid yellow, violet and brown. Her pose and her expression do not
change while it happens. It is the same girl, drawn. No sparkles, no magic
dust, no particles, no light beams.

2.5 to 4.5 SECONDS
The white background falls away and the illustrated funfair builds around her
in every direction. The camera begins to rise and pull back into the high
aerial angle while she walks away from it, deeper into the scene. Cartoon
people appear around her as the fair fills in, all in the same style and the
same weight of outline.

4.5 to 8.0 SECONDS
The camera keeps rising and pulling back, faster. She walks into the thickening
crowd, glances back over her shoulder at the viewer once, then turns away and
stands still among the other people. The crowd grows until hundreds of small
figures fill the frame edge to edge and she is simply one of them: still there,
still in the yellow top and violet skirt, but no bigger and no brighter than
anybody else. The last second holds completely still on the crowded fair.

THE RULE THAT MATTERS MOST
Nobody else in the crowd may carry all three of her signatures. Other people
may have brown braids, or a yellow top, or a violet skirt, but never two of
them on one person and never all three. A second girl who looks like her ruins
the whole idea. Nothing in the scene may point at her, circle her, spotlight
her or mark her, and no other character looks at the camera. The viewer has to
find her.

DO NOT INCLUDE
No text, letters, numbers, signs, logos or watermarks. No arrows, circles,
sparkles or highlights. No camera shake, no zoom punches, no speed ramps. No
music, no speech, no sound effects.
```

---

## מה לבדוק בסרטון שיחזור

| | אם לא — מה לעשות |
| --- | --- |
| התלבושת זהה מההתחלה לסוף | להריץ שוב; זה הכישלון הנפוץ ביותר |
| אין אף דמות עם שלושת הסימנים | להריץ שוב. זה שובר את הרעיון |
| הסגנון שטוח — בלי הצללות וזוהר | להריץ שוב, ולחזור על סעיף THE CARTOON SHE BECOMES |
| היא נראית בשוט האחרון, קטנה | אם נעלמה לגמרי — לבקש שתעמוד קרוב יותר למרכז |
| אין טקסט בשום מקום | להריץ שוב |

**אם השוט האחרון יוצא חלש** — וזה החלק שהכי סביר שיכשל, כי מודל וידאו מתקשה
במאות דמויות זעירות ועקביות — קח רק את 4.5 השניות הראשונות, עד שהיא מתחילה
ללכת פנימה. אני מחבר להן זנב שנבנה מהמפה **האמיתית** של המשחק, וכך מה שהצופה
מתבקש לחפש הוא בדיוק מה שיקבל כשיוריד.

---

## איפה הקליפ הזה נכנס בקמפיין

**הוא לא מחליף את עשרים קליפי החידה — הוא מקדים אותם.**

- **הפוסט הראשון בחשבון**, שמסביר מי היא ומה המשחק
- **הפוסט המוצמד** בפרופיל, שכל מבקר חדש רואה קודם
- **הקריאייטיב הראשון בתשלום**, כי הוא היחיד שמסביר את המשחק למי שלא מכיר

עשרים קליפי החידה מניחים שהצופה כבר מבין את המשחק. הקליפ הזה הוא מה שגורם לו
להבין — ולהתחבר לדמות שהוא מחפש.

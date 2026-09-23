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

**ההיפוך לדמות המצוירת נמצא בסוף, לא בהתחלה.** היא אמיתית לאורך כל הסרטון —
הדבר האמיתי היחיד בתוך ציור — ורק בשנייה השביעית היא הופכת לפינדו המצוירת
ונבלעת בקהל. זה גם מה שפותר את בעיית הגודל: **רגע ההיפוך הוא רגע ההתכווצות**,
כך שאין שלב שבו היא מצוירת אבל עדיין ענקית.

```
An eight-second vertical 9:16 video: a real girl walks into a drawn world, and
at the end she becomes a drawing herself and vanishes into the crowd. Silent,
no text anywhere in the frame.

THE GIRL, FROM THE FIRST REFERENCE IMAGE
Brown hair in two long braids, a bright yellow sleeveless top with a black
V-shaped neckline, a mid-violet knee-length skirt, black shoes. The same real
girl, filmed, in every frame until the very end.

0.0 to 1.5 SECONDS - THE REAL GIRL
She stands on a plain white background, framed from the knees up, evenly lit.
She looks into the camera, smiles, and gives one small friendly wave. Camera
still.

1.5 to 3.0 SECONDS - A DRAWN WORLD BUILDS AROUND HER
The white background is replaced by the illustrated funfair from the THIRD
reference image: stalls, bunting, a carousel, a big wheel, all flat vector
illustration with uniform thick black outlines, seen from a high
three-quarter aerial angle about 55 degrees looking down. Cartoon people are
walking about.

She stays exactly as she is: a real, filmed girl, with real skin, real hair and
real fabric, standing inside a drawing. She is deliberately the only real thing
in the frame, and she should look it. She turns and begins to walk away from
the camera into the fair.

3.0 to 6.0 SECONDS - SHE WALKS IN, STILL REAL
She walks deeper into the fair, seen from behind. The camera rises and pulls
back steadily into the high aerial view. More and more cartoon people fill in
around her as the fair opens out. She is still filmed and still real, and she
is getting smaller only because the camera is getting further away.

6.0 to 7.0 SECONDS - THE CHANGE, AND THIS IS THE MOMENT THE CLIP IS FOR
She becomes a drawing. The change sweeps up her body once, feet to head, in
under a second, and as it passes she turns into the flat cartoon girl in the
SECOND reference image: one uniform black outline of even weight, solid flat
colour fills, a simple face, no skin shading, no separate strands of hair, no
folds in the fabric, no highlights.

At the same instant she also settles to exactly the size of the cartoon people
around her. She does not shrink oddly or squash: the drawing of her that
appears is simply the same height as everybody else in the crowd, about one
thirtieth of the image height, as in the FOURTH reference image.

7.0 to 8.0 SECONDS - SHE IS ONE OF THEM
The camera holds completely still on the whole fair, hundreds of small people
filling the frame. She is among them and nothing marks her out:

- HER SIZE: the same height as everyone else. If she is taller than the people
  beside her, the shot is wrong.
- AROUND HER: other people standing close on every side, within one body width.
  No clearing, no gap, no empty ground around her.
- WHERE SHE IS: not in the middle of the frame. About a third of the way in
  from one edge, among stalls and people.
- HOW SHE IS DRAWN: exactly like everyone else - same outline weight, same flat
  fills, same proportions. Her yellow and her violet are ordinary colours here,
  no brighter than anyone else's.
- FACING: away from the camera, standing still, doing nothing that draws the
  eye.

A viewer should have to search for several seconds to find her. If she is
obvious the moment the change finishes, the clip has failed.

THE OTHER RULE
Nobody else may wear all three of her signatures together. Other people may
have brown braids, or a yellow top, or a violet skirt, but never two on one
person and never all three. Plenty of the crowd wear yellow of other shades and
purple of other shades, so those colours are ordinary here.

Nothing points at her, circles her, lights her or marks her. No other character
looks at the camera.

DO NOT INCLUDE
No text, letters, numbers, signs, logos or watermarks. No arrows, circles,
sparkles, magic dust or highlights. No camera shake, no speed ramps. No music
or speech.
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

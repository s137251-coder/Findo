# Google Play listing copy

Paste-ready text for Play Console. Character counts are checked against Play's
limits: **short description ≤ 80**, **full description ≤ 4000**, **app name ≤ 30**.

Add both languages in Play Console under **Store listing → Manage translations**.

---

## English (en-US)

### App name (5 / 30)

```
Findo
```

### Short description (67 / 80)

```
Find one girl hidden in a crowded scene. Before the clock runs out.
```

### Full description (1407 / 4000)

```
Findo is hidden somewhere in this crowd. You have two minutes to find her.

Nineteen levels, each one big hand-drawn scene packed with hundreds of people going about their day: a town square around a fountain, a working farm, a funfair, a night market. Somewhere in there, one girl with brown braids, a yellow top and a purple skirt is standing perfectly still, waiting to be spotted.

HOW IT PLAYS
• Drag to move around the scene, pinch to zoom right in
• Study the crowd. She looks like everyone else until she doesn't
• Tap her and the level is yours
• Tap the wrong person and it costs you points and precious seconds
• The faster you find her, the bigger the time bonus
• Every level is rated one to three stars, so there is always a better run to chase
• Play a level again and she is hiding somewhere else, so chasing a better time is a real search and not a memory test

CAN'T SEE HER?
A hint sweeps the map towards Findo and makes her glow. Start with three, earn more by watching a video, or buy a pack.

PLAYS YOUR WAY
• Full English and Hebrew, with proper right-to-left layout
• Switch language any time, mid-level, without restarting
• Everything is stored on your device. No account, no login, no sign-up
• Works on phones and tablets, in portrait and landscape

Findo is free to play. It contains ads and optional in-app purchases, including a one-time purchase that removes ads permanently.
```

### What's new — release 1.0.0 (91 / 500)

```
First release. Three crowded scenes to search, English and Hebrew, hints, and star ratings.
```

---

## Hebrew (he-IL)

### App name (5 / 30)

```
Findo
```

### Short description (48 / 80)

```
מצאו ילדה אחת שמסתתרת בתוך קהל. לפני שהזמן נגמר.
```

### Full description (1141 / 4000)

```
פינדו מסתתרת אי שם בתוך הקהל הזה. יש לכם שתי דקות למצוא אותה.

תשעה עשר שלבים, כל אחד סצנה מצוירת אחת גדולה, עמוסה במאות אנשים באמצע היום שלהם: כיכר עיר סביב מזרקה, חווה פעילה, לונה פארק, שוק לילה. אי שם שם, ילדה אחת עם צמות חומות, חולצה צהובה וחצאית סגולה עומדת בלי לזוז ומחכה שתשימו לב אליה.

איך משחקים
• גררו כדי לנוע בסצנה, צבטו כדי להתקרב
• סרקו את הקהל. היא נראית כמו כולם, עד שלא
• לחצו עליה והשלב שלכם
• לחיצה על האדם הלא נכון עולה לכם בנקודות ובשניות יקרות
• ככל שתמצאו אותה מהר יותר, בונוס הזמן גדול יותר
• כל שלב מדורג בין כוכב אחד לשלושה, אז תמיד יש ריצה טובה יותר לרדוף אחריה
• שחקו שוב באותו שלב והיא תתחבא במקום אחר, כך שמרדף אחרי זמן טוב יותר הוא חיפוש אמיתי ולא מבחן זיכרון

לא מוצאים אותה?
רמז מזיז את המפה לכיוון פינדו וגורם לה לזהור. מתחילים עם שלושה, מרוויחים עוד בצפייה בסרטון, או קונים חבילה.

מותאם לכם
• עברית ואנגלית מלאות, כולל פריסה מימין לשמאל כמו שצריך
• החלפת שפה בכל רגע, גם באמצע שלב, בלי להפעיל מחדש
• הכל נשמר על המכשיר שלכם. בלי חשבון, בלי התחברות, בלי הרשמה
• עובד על טלפונים וטאבלטים, לאורך ולרוחב

Findo חינמי לשחק. הוא כולל פרסומות ורכישות אופציונליות, ובהן רכישה חד-פעמית שמסירה את הפרסומות לצמיתות.
```

### What's new — release 1.0.0 (75 / 500)

```
גרסה ראשונה. שלוש סצנות עמוסות לחיפוש, עברית ואנגלית, רמזים, ודירוג כוכבים.
```

---

## Graphics checklist

| Asset | Requirement | File |
| --- | --- | --- |
| App icon | 512×512 PNG, 32-bit, no transparency | `store/icon-512.png` ✅ |
| Feature graphic | 1024×500 PNG/JPEG, no transparency | `store/feature-graphic-1024x500.png` ✅ |
| Phone screenshots | 2–8, each side 320–3840 px | `store/screenshots/phone-*.png` ✅ |
| 7" tablet screenshots | Only if you declare tablet support | not generated |
| 10" tablet screenshots | Only if you declare tablet support | not generated |

The six phone screenshots are 1080×2400 captures from a real run of the signed
1.0.0+2 release build: the title, the rules screen, the level list with
progress, a hunt on Hollow Farm, a three-star completion, and the Hebrew level
list. Play accepts them as-is; adding captions on top is optional polish.

Upload the Hebrew one under the he-IL listing rather than the default, so an
English-speaking browser is not shown a screen they cannot read.

To list tablet support, capture the same screens from a tablet emulator
(for example a Pixel Tablet AVD) and upload those too. Skipping tablet
screenshots is fine — Play then simply markets the app to phones.

---

## Data safety form

Answers matching what the shipped code actually does.

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **Yes** |
| Device or other IDs → Collected | **Yes** — advertising ID, by the Google Mobile Ads SDK |
| Device or other IDs → Shared | **Yes** — with Google for advertising |
| Device or other IDs → Purpose | Advertising or marketing |
| Device or other IDs → Optional? | Required |
| Purchase history → Collected | **Yes** — via Google Play Billing |
| Purchase history → Purpose | App functionality |
| App activity / App info and performance | **Not collected** by us |
| Location | **Not collected** by us (AdMob infers coarse location from IP; declare under Device IDs, not Location) |
| Personal info, Financial info, Photos, Files, Contacts, Messages | **Not collected** |
| Is all collected data encrypted in transit? | **Yes** |
| Can users request data deletion? | **Yes** — uninstalling removes all local data; advertising ID is reset in device settings |

Game progress, language and audio settings live in `shared_preferences` on the
device. On-device storage is **not** "collection" under Play's definition, so it
is not declared.

---

## Content rating questionnaire

| Question | Answer |
| --- | --- |
| Category | Game |
| Violence, blood, or realistic violence | No |
| Sexual content or nudity | No |
| Profanity or crude humour | No |
| Drugs, alcohol, tobacco | No |
| Gambling, or simulated gambling | No |
| User-generated content or user interaction | No |
| Shares user location with other users | No |
| Digital purchases | **Yes** |
| Contains ads | **Yes** |

Expected outcome: **Everyone / PEGI 3** in most territories.

---

## Ads and target audience

- **Ads declaration:** yes, the app contains ads. Getting this wrong is a common
  rejection cause.
- **Target audience:** declare **13 and over**. Declaring an audience that
  includes under-13s triggers Google Play Families Policy, and the AdMob
  configuration in this app is not set up for child-directed treatment.

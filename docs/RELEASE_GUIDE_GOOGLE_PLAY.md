# Releasing Findo to Google Play

Everything below is done once per app, then repeated only for the parts that
change between releases. Work through it in order -- several steps depend on
values created in an earlier one.

The build produced by these steps is an **Android App Bundle** (`.aab`). Google
Play no longer accepts APKs for new apps; the APK build stays useful only for
testing on a device you hold.

---

## 0. Before you start

| What you need | Why |
| --- | --- |
| A Google Play developer account (one-off 25 USD) | Required to publish at all |
| An AdMob account | Real ad unit ids; the repo ships Google's test ids |
| A keystore you can keep for the life of the app | Play rejects an update signed with a different key |
| A privacy policy hosted at a public URL | Mandatory for any app that shows ads. The policy itself is written: `docs/privacy-policy.html`. See section 10 for hosting it free. |

Check the toolchain first:

```powershell
flutter doctor -v
```

Every line under "Android toolchain" must be green. `cmdline-tools` missing is
the usual failure; install it from Android Studio's SDK Manager.

---

## 1. Replace the placeholder identifiers

The repository ships with Google's public test values so a fresh clone runs.
None of them may reach production.

**AdMob app id** -- `android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"/>
```

**Ad unit ids** -- `lib/managers/monetization_manager.dart`, class `AdUnitIds`.
Four constants: interstitial and rewarded, Android and iOS. Nothing else in the
codebase refers to an ad unit, so these four lines are the whole change.

**In-app product ids** -- `lib/managers/monetization_manager.dart`, class
`StoreProducts`. The ids there (`findo_remove_ads`, `findo_hint_pack_10`) must
match the products you create in step 6 exactly, character for character.

> The `~` in an app id and the `/` in an ad unit id are not interchangeable.
> Mixing them up produces ads that silently never load.

### Test devices, once the ids are real

The moment `AdUnitIds` carries real units, every ad request is a real
impression. A dozen testers replaying the same build is the pattern AdMob reads
as invalid traffic, and it suspends the ad account rather than the app -- after
you have already spent the fourteen days.

Register the devices instead. Ids are passed at build time, so none is ever
committed:

```powershell
flutter build appbundle --dart-define=FINDO_AD_TEST_DEVICES=ID1,ID2
```

The real unit ids, load callbacks and reward callbacks all still run; the
impressions simply are not counted.

**Finding a device's id:** run a debug build on it and trigger an ad -- ask for
a hint. The SDK logs a line naming the id to add. It is per-device and stable
across installs.

**For the closed test, this is usually the wrong tool.** Collecting an id from
twelve people you cannot reach through a terminal does not work. Leave Google's
test units in the build the testers get: the ad code path is identical and no
ad account is at risk. Use `FINDO_AD_TEST_DEVICES` for your own devices, on the
builds that carry real ids -- which is exactly the window between production
access and going live.

---

## 2. Application id and version

`android/app/build.gradle.kts` already sets:

```kotlin
applicationId = "com.findo.game"
```

This string is permanent once the app is published -- it is the app's identity
on Play forever. Change it now if you want something else.

The version comes from `pubspec.yaml`:

```yaml
version: 1.0.0+1
```

`1.0.0` is the version name players see. `+1` is the version code. **Play
rejects an upload whose version code is not higher than every previous
upload**, so raise the number after the `+` for every single upload, including
ones you only send to internal testing.

---

## 3. The upload keystore

> **Already done.** A 2048-bit RSA keystore valid for 10,000 days was generated
> at `C:\Users\Vashdi\findo-upload.jks`, and `android/key.properties` points at
> it. Release builds are signed with it. **Back that .jks file up now** — if it
> is lost, this app can never be updated on Play again, only republished under a
> new application id with zero installs and zero reviews.
>
> The steps below are the reference for recreating it, or for doing the same on
> another machine.

Run this once, and back up the resulting file somewhere you will still have it
in five years. If it is lost, the app cannot be updated -- only republished
under a new application id, losing every install and review.

```powershell
keytool -genkey -v -keystore $env:USERPROFILE\findo-upload.jks `
        -keyalg RSA -keysize 2048 -validity 10000 -alias findo
```

Then copy `android/key.properties.template` to `android/key.properties` and
fill it in:

```properties
storePassword=...
keyPassword=...
keyAlias=findo
storeFile=C:/Users/you/findo-upload.jks
```

Use forward slashes in `storeFile` even on Windows.

`android/key.properties` and `*.jks` are both git-ignored. Keep them that way:
a keystore in a public repository is a compromised keystore.

The Gradle configuration reads that file automatically. When it is absent the
release build falls back to the debug keys so the project still builds on a
fresh clone -- such a build runs on a device but **cannot be uploaded to Play**.

---

## 4. Build the bundle

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

Confirm it is signed with your key and not the debug key:

```powershell
flutter build appbundle --release -v | Select-String "Signing"
```

Test the exact artifact you are about to upload, rather than a debug build,
using `bundletool`:

```powershell
java -jar bundletool.jar build-apks --bundle=app-release.aab --output=findo.apks `
     --ks=$env:USERPROFILE\findo-upload.jks --ks-key-alias=findo
java -jar bundletool.jar install-apks --apks=findo.apks
```

---

## 5. Store listing assets

Play will not let you submit until all of these exist. Sizes are hard
requirements, not suggestions.

| Asset | Requirement |
| --- | --- |
| App icon | 512 x 512 PNG, 32-bit, no transparency |
| Feature graphic | 1024 x 500 PNG or JPEG, no transparency |
| Phone screenshots | 2 to 8, 16:9 or 9:16, each side 320-3840 px |
| 7-inch tablet screenshots | Required if you list tablet support |
| 10-inch tablet screenshots | Required if you list tablet support |
| Short description | Max 80 characters |
| Full description | Max 4000 characters |

> **Already done.** The launcher icon (all five densities plus an Android 13
> adaptive and monochrome layer), the iOS app icon set, the 512x512 store icon
> and the 1024x500 feature graphic are generated by `tool/generate_brand.py` and
> committed. Phone screenshots from a real run of the release build are in
> `store/screenshots/`. Paste-ready listing text in English and Hebrew, plus the
> Data safety and content rating answers, are in `store/LISTING.md`.

Because Findo ships English and Hebrew, add both languages to the listing.
Play localizes per language, so a Hebrew listing needs its own title,
descriptions and screenshots.

---

## 6. In-app products

**Monetise -> Products -> In-app products**, then create:

| Product id | Type | What it does |
| --- | --- | --- |
| `findo_remove_ads` | Non-consumable (one-time) | Turns off interstitials permanently |
| `findo_hint_pack_10` | Consumable | Grants 10 hints |

Products must be **Active**, and the app must have been uploaded to a track at
least once, before `queryProductDetails` returns anything. Until then the store
buttons in Settings correctly report that the store is unavailable -- that is
the code working, not a bug.

Add licence testers under **Setup -> License testing** so you can run through a
purchase without being charged.

---

## 7. Data safety and content rating

Both are questionnaires in Play Console, and both are checked against what the
app actually does.

Findo, as shipped:

- **Collects** an advertising id, through the Google Mobile Ads SDK, for
  advertising. Declare it.
- **Collects** purchase history through Play Billing, for app functionality.
- **Stores** progress, language and audio settings **on the device only**
  (`shared_preferences`). On-device storage is not "collection" and is not
  declared.
- Sends no data to any server operated by you.

Content rating: a hidden-object game with no violence, no user-generated
content and no communication features. Answering the questionnaire honestly
yields "Everyone" / PEGI 3 in most territories.

**Ads declaration**: answer *yes*, the app contains ads. Getting this wrong is
a common cause of rejection.

**Target audience**: if you declare an audience that includes children under
13, Families Policy applies and the ad configuration in this app is not
compliant as-is. Declare 13+ unless you are prepared to do that work.

---

## 8. Upload and roll out

1. **Testing -> Internal testing -> Create new release**
2. Upload the `.aab`. The first upload asks about Play App Signing -- accept
   it; Google then holds the app signing key and yours becomes the upload key.
3. Write release notes (they are per-language).
4. Add testers by email list, save, then share the opt-in link.
5. Install from that link on a real device and play through a level, a
   purchase and a rewarded ad.
6. When it holds up: **Production -> Create new release**, promote the same
   bundle, and submit for review.

First review typically takes a few days. Later updates are usually faster.

---

## 9. Repeat checklist for every later release

- [ ] Raise the version code (`+N` in `pubspec.yaml`)
- [ ] `flutter analyze` clean
- [ ] `flutter test` green
- [ ] `flutter build appbundle --release`
- [ ] Install the built bundle on a device and play one level end to end
- [ ] Release notes written in both English and Hebrew
- [ ] Upload to internal testing before production

---

## 10. Hosting the privacy policy

Play needs a public URL, not a file. `docs/privacy-policy.html` is written in
English and Hebrew and is ready to publish. The cheapest route is GitHub Pages,
straight out of this repository:

1. On GitHub, open **Settings -> Pages**.
2. Under *Build and deployment*, set **Source** to *Deploy from a branch*.
3. Choose branch `main` and folder **`/docs`**, then **Save**.
4. Wait a minute or two, then confirm the page loads at:

   `https://s137251-coder.github.io/Findo/privacy-policy.html`

5. Paste that URL into Play Console under **Policy -> App content -> Privacy
   policy**, and into the *Privacy Policy* field of the store listing.

Read the page once it is live before submitting. The contact address in it is
`s137251@gmail.com`; change it in `docs/privacy-policy.html` if you would rather
publish a different one.

---

## Appendix: two iOS steps that need a Mac

Findo's iOS target is configured, but two things must be done once in Xcode on
a Mac, because they change the Xcode project file rather than any source file:

1. **Add `ios/Runner/PrivacyInfo.xcprivacy` to the Runner target.** The file is
   written and correct, but a resource is only bundled once it is a member of
   the target. In Xcode: select the file, then tick *Runner* under Target
   Membership. App Store submissions are rejected without a privacy manifest.
2. **Optional: localize the tracking prompt.** `NSUserTrackingUsageDescription`
   in `Info.plist` is English only. To show Hebrew on a Hebrew device, add
   `InfoPlist.strings` localized to `he` in Xcode and translate that one key.

Everything else on iOS -- bundle id `com.findo.game`, the AdMob app id,
SKAdNetwork entries, supported orientations and locales -- is already set in
`ios/Runner/Info.plist`.

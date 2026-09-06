# Fonts

`Findo-Regular.ttf`, `Findo-Medium.ttf` and `Findo-Bold.ttf` are Roboto,
renamed so the family name matches the app. Roboto is licensed under the
Apache License 2.0 by Google, which permits redistribution inside an
application; the licence text is at
<https://www.apache.org/licenses/LICENSE-2.0>.

The family is bundled rather than relying on the platform default so that
typography is identical on Android and iOS. Hebrew glyphs that Roboto does not
cover fall back to the system font automatically.

To swap in a different typeface, replace these three files and keep the file
names -- `pubspec.yaml` refers to them by name and nothing else changes.

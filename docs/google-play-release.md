# Google Play Release

## Assets already prepared

- `play_store/assets/google-play-icon-512.png`
- `play_store/assets/google-play-feature-graphic.png`
- `play_store/metadata/en-US/title.txt`
- `play_store/metadata/en-US/short-description.txt`
- `play_store/metadata/en-US/full-description.txt`

## Android release signing

1. Copy `android/key.properties.example` to `android/key.properties`.
2. Replace the placeholder values with your real upload keystore values.
3. Put your keystore file at the path referenced by `storeFile`.

## Before upload

1. Review `pubspec.yaml` version and build number.
2. Confirm the package id is correct:
   `com.opplexify.quranpakdualpagereader`
3. Build a release artifact locally:
   `flutter build appbundle`
4. Upload the generated `.aab` file to Google Play Console.

## Store listing

Use the files in `play_store/metadata/en-US` for the listing text and the files in `play_store/assets` for visual assets.

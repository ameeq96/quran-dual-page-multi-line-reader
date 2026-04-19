# Quran Pak Dual Page Reader

A polished Flutter Quran reader built around a landscape dual-page Mushaf spread with switchable 10-line, 13-line, 14-line, 15-line, 16-line, 17-line, and Kanzul Iman scan editions.

## Project structure

```text
lib/
  app/
  core/
    constants/
    services/
    storage/
  features/quran_reader/
    data/
    domain/
    presentation/
```

## What is implemented

- Direct launch into the Quran reader
- Portrait single-page reading and landscape dual-page spread reading
- Switchable Mushaf editions:
  - 10-line Pak Company scans
  - 13-line Qudrat Ullah Company scans
  - 14-line Pak Company scans
  - 15-line Qudrat Ullah Company scans
  - 16-line Taj Company scans
  - 17-line Taj Company scans
  - Kanzul Iman Urdu translation + tafsir scans
- Real Mushaf image mode with automatic edition-aware asset detection
- Bundled offline IndoPak 16-line Quran text for all 604 standard pages
- Placeholder Mushaf page mode only if both scans and text are unavailable
- Page swipe navigation by page or spread
- Search by Surah
- Search by Sipara / Juz
- Index search for Ruku, Hizb, Manzil, and Rub
- Ayah and page text search
- Resume last reading position with local storage
- Reader settings, audio panel, insights, and dashboard sheets

## How page pairing works

- Each spread contains two pages.
- The right page is the lower-numbered page.
- The left page is the higher-numbered page.
- Spread 1 shows pages `1` and `2`.
- Spread 2 shows pages `3` and `4`.
- When Taj Company scan assets are present, the final spread ends at page `550`.
- When the fallback text profile is used, the reader expands back to the bundled 604-page text set.

## Real page image assets

The app now keeps each Mushaf edition in its own folder:

```text
assets/quran_pages/
  10_line/
  13_line/
  14_line/
  15_line/
  16_line/
  17_line/
  kanzul_iman/
```

Current extracted scan sets:

- `assets/quran_pages/10_line/001.jpg` ... `1439.jpg`
- `assets/quran_pages/13_line/001.jpg` ... `850.jpg`
- `assets/quran_pages/14_line/001.jpg` ... `732.jpg`
- `assets/quran_pages/15_line/001.jpg` ... `611.jpg`
- `assets/quran_pages/16_line/001.jpg` ... `550.jpg`
- `assets/quran_pages/17_line/001.jpg` ... `487.jpg`
- `assets/quran_pages/kanzul_iman/001.jpg` ... `1087.jpg`

Source PDFs currently stored with the extracted editions:

```text
assets/quran_pages/10_line/11 Al-Quran 10 Lines [Pak Company] - www.Momeen.blogspot.com.pdf
assets/quran_pages/13_line/14 Al-Quran 13 Lines [Qudrat Ullah Company] - www.Momeen.blogspot.com.pdf
assets/quran_pages/14_line/09A-lquran14LinespakCompany-Www.momeen.blogspot.com.pdf
assets/quran_pages/15_line/42 QuranMajeed-15 Lines Pakistani Print (Qudrat Ullah Company)-- www.Momeen.blogspot.in -- www.Quranpdf.blogspot.in.pdf
assets/quran_pages/16_line/AL QURAN 16 Lines Taj Company Arabic Side Binding.pdf
assets/quran_pages/17_line/49 Al Quran Al Kareem 17 Lines - Taj Company - www.Momeen.blogspot.com - www.Quranpdf.blogspot.in.pdf
assets/quran_pages/kanzul_iman/کنزالایمان - خزائن العرفان فی تفسیر القرآن - ترجمہ امام احمد رضا خان بریلوی - تفسیر علامہ نعیم الدین مراد آبادی.pdf
```

When a page image exists for the selected edition, the reader renders it automatically. If not, the app falls back to the bundled Quran text data. The placeholder layout is only used as a last-resort fallback if neither images nor text data are available.

Edition switching is available from `Reader settings > Mushaf edition`.

## Bundled Quran text

The app ships with offline page text here:

```text
assets/quran_pages/quran_text_by_page.json
```

This file was generated from the Quran.com API page endpoint using `text_indopak` and page line metadata:

- `https://api.quran.com/api/v4/verses/by_page/{page}`

To regenerate it:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tool\generate_quran_text_asset.ps1
```

This gives the reader an IndoPak 16-line-compatible text layout. The app uses the selected edition's scan set first, then falls back to this bundled text profile when needed.

## Placeholder mode

The fallback placeholder renderer intentionally avoids fake Quran text. Each page instead shows:

- a respectful framed page presentation
- a header treatment
- 16 line placeholders
- realistic spacing and page margins
- page number chips

## Run the app

```bash
flutter pub get
flutter run -d chrome
```

## Useful commands

```bash
dart format .
flutter analyze
flutter test
```

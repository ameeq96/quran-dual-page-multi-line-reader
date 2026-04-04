This folder contains the scan-based Mushaf editions used by the app.

Current structure:

- `10_line/`
- `13_line/`
- `14_line/`
- `15_line/`
- `16_line/`
- `17_line/`
- `kanzul_iman/`

Current extracted scan sets:

- `10_line/001.jpg` ... `1439.jpg`
- `13_line/001.jpg` ... `850.jpg`
- `14_line/001.jpg` ... `732.jpg`
- `15_line/001.jpg` ... `611.jpg`
- `16_line/001.jpg` ... `550.jpg`
- `17_line/001.jpg` ... `487.jpg`
- `kanzul_iman/001.jpg` ... `1087.jpg`

Source PDFs currently bundled with the extracted assets:

- `10_line/11 Al-Quran 10 Lines [Pak Company] - www.Momeen.blogspot.com.pdf`
- `13_line/14 Al-Quran 13 Lines [Qudrat Ullah Company] - www.Momeen.blogspot.com.pdf`
- `14_line/09A-lquran14LinespakCompany-Www.momeen.blogspot.com.pdf`
- `15_line/42 QuranMajeed-15 Lines Pakistani Print (Qudrat Ullah Company)-- www.Momeen.blogspot.in -- www.Quranpdf.blogspot.in.pdf`
- `16_line/AL QURAN 16 Lines Taj Company Arabic Side Binding.pdf`
- `17_line/49 Al Quran Al Kareem 17 Lines - Taj Company - www.Momeen.blogspot.com - www.Quranpdf.blogspot.in.pdf`
- `kanzul_iman/کنزالایمان - خزائن العرفان فی تفسیر القرآن - ترجمہ امام احمد رضا خان بریلوی - تفسیر علامہ نعیم الدین مراد آبادی.pdf`

The app automatically uses page images from the selected edition when they exist.
If an image is missing, the reader falls back to the bundled `quran_text_by_page.json` IndoPak text asset.
The placeholder page is only used when neither page images nor the bundled text asset are available.

Optional exact Taj navigation overrides can be added in:

- `taj_navigation_overrides.json`

Structure:

```json
{
  "surahStartPages": {
    "1": 2,
    "2": 3
  },
  "siparaStartPages": {
    "1": 2,
    "2": 22
  }
}
```

These override the default Taj start-page anchors used by Surah and Sipara search/jump for the 16-line edition.

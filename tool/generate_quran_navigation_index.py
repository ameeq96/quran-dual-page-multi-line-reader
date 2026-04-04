from __future__ import annotations

import json
from pathlib import Path
from urllib.request import Request, urlopen


OUTPUT_PATH = Path(
    r"c:\Users\AMEEQ EMAAD PC\Documents\GitHub\opplexiptv\my_flutter_app\assets\quran_pages\quran_navigation_index.json"
)
HEADERS = {
    "Accept": "application/json",
    "User-Agent": "my_flutter_app/1.0 (local setup script)",
}
STANDARD_TOTAL_PAGES = 604
TAJ_SCAN_TOTAL_PAGES = 550
TAJ_QURAN_START_PAGE = 2
TAJ_QURAN_END_PAGE = 549
JUZ_NAMES = [
    ("Alif Lam Meem", "الم"),
    ("Sayaqool", "سَيَقُولُ"),
    ("Tilka Rusul", "تِلْكَ الرُّسُلُ"),
    ("Lan Tana Loo", "لَن تَنَالُوا"),
    ("Wal Mohsanat", "وَالْمُحْصَنَاتُ"),
    ("La Yuhibbullah", "لَا يُحِبُّ ٱللَّهُ"),
    ("Wa Iza Samiu", "وَإِذَا سَمِعُوا"),
    ("Wa Lau Annana", "وَلَوْ أَنَّنَا"),
    ("Qalal Malao", "قَالَ ٱلْمَلَأُ"),
    ("Wa A'lamu", "وَٱعْلَمُوا"),
    ("Yatazeroon", "يَعْتَذِرُونَ"),
    ("Wa Mamin Da'abat", "وَمَا مِن دَآبَّةٍ"),
    ("Wa Ma Ubrioo", "وَمَا أُبَرِّئُ"),
    ("Rubama", "رُبَمَا"),
    ("Subhanallazi", "سُبْحَانَ ٱلَّذِى"),
    ("Qal Alam", "قَالَ أَلَمْ"),
    ("اقترب", "ٱقْتَرَبَ"),
    ("Qad Aflaha", "قَدْ أَفْلَحَ"),
    ("Wa Qalallazina", "وَقَالَ ٱلَّذِينَ"),
    ("Aman Khalaq", "أَمَّنْ خَلَقَ"),
    ("Utlu Ma Oohi", "ٱتْلُ مَآ أُوحِىَ"),
    ("Wa Manyaqnut", "وَمَن يَقْنُتْ"),
    ("Wa Mali", "وَمَا لِىَ"),
    ("Faman Azlam", "فَمَنْ أَظْلَمُ"),
    ("Elahe Yuruddu", "إِلَيْهِ يُرَدُّ"),
    ("Ha Meem", "حم"),
    ("Qala فما خطبكم", "قَالَ فَمَا خَطْبُكُم"),
    ("Qad Sami Allah", "قَدْ سَمِعَ ٱللَّهُ"),
    ("Tabarakallazi", "تَبَارَكَ ٱلَّذِى"),
    ("Amma", "عَمَّ"),
]


def fetch_json(url: str) -> dict:
    request = Request(url, headers=HEADERS)
    with urlopen(request) as response:
        return json.load(response)


def map_standard_page_to_taj_scan(standard_page: int) -> int:
    if standard_page <= 1:
        return TAJ_QURAN_START_PAGE
    ratio = (standard_page - 1) / (STANDARD_TOTAL_PAGES - 1)
    mapped = TAJ_QURAN_START_PAGE + round(
        ratio * (TAJ_QURAN_END_PAGE - TAJ_QURAN_START_PAGE)
    )
    return max(TAJ_QURAN_START_PAGE, min(TAJ_QURAN_END_PAGE, mapped))


def main() -> None:
    chapters = fetch_json("https://api.quran.com/api/v4/chapters")["chapters"]
    juzs = fetch_json("https://api.quran.com/api/v4/juzs")["juzs"]

    unique_juzs: dict[int, dict] = {}
    for juz in juzs:
        unique_juzs.setdefault(juz["juz_number"], juz)

    surah_entries = []
    for chapter in chapters:
        standard_start_page = int(chapter["pages"][0])
        surah_entries.append(
            {
                "id": int(chapter["id"]),
                "nameSimple": chapter["name_simple"],
                "nameComplex": chapter["name_complex"],
                "nameArabic": chapter["name_arabic"],
                "translatedName": chapter["translated_name"]["name"],
                "standardStartPage": standard_start_page,
                "tajScanStartPage": map_standard_page_to_taj_scan(
                    standard_start_page
                ),
            }
        )

    juz_entries = []
    for juz_number in range(1, 31):
        juz = unique_juzs[juz_number]
        first_mapping = next(iter(juz["verse_mapping"].items()))
        surah_id = int(first_mapping[0])
        first_verse = int(str(first_mapping[1]).split("-")[0])
        verse = fetch_json(
            f"https://api.quran.com/api/v4/verses/by_key/{surah_id}:{first_verse}?words=false&fields=page_number"
        )["verse"]
        standard_start_page = int(verse["page_number"])
        juz_name, juz_name_arabic = JUZ_NAMES[juz_number - 1]
        juz_entries.append(
            {
                "number": juz_number,
                "name": juz_name,
                "nameArabic": juz_name_arabic,
                "standardStartPage": standard_start_page,
                "tajScanStartPage": map_standard_page_to_taj_scan(
                    standard_start_page
                ),
            }
        )

    payload = {
        "profile": {
            "standardTotalPages": STANDARD_TOTAL_PAGES,
            "tajScanTotalPages": TAJ_SCAN_TOTAL_PAGES,
            "tajQuranStartPage": TAJ_QURAN_START_PAGE,
            "tajQuranEndPage": TAJ_QURAN_END_PAGE,
            "notes": "Official Quran.com surah and juz anchors mapped onto the Taj Company scan profile bundled in this app.",
        },
        "surahs": surah_entries,
        "siparas": juz_entries,
    }

    OUTPUT_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Saved navigation index to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()

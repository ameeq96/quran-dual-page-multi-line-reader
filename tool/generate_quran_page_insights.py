from __future__ import annotations

import json
import re
import time
from html import unescape
from pathlib import Path
from typing import Any
from urllib.request import Request, urlopen


OUTPUT_PATH = Path(
    r"c:\Users\AMEEQ EMAAD PC\Documents\GitHub\opplexiptv\my_flutter_app\assets\quran_pages\quran_page_insights.json"
)
HEADERS = {
    "Accept": "application/json",
    "User-Agent": "my_flutter_app/1.0 (metadata generator)",
}
ENGLISH_TRANSLATION_ID = 84
URDU_TRANSLATION_ID = 97
TOTAL_PAGES = 604


def fetch_json(url: str) -> dict[str, Any]:
    request = Request(url, headers=HEADERS)
    with urlopen(request, timeout=30) as response:
        return json.load(response)


def compact_text(value: str) -> str:
    text = unescape(value)
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"\[[^\]]+\]", " ", text)
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def page_payload(page_number: int) -> dict[str, Any]:
    url = (
        "https://api.quran.com/api/v4/verses/by_page/"
        f"{page_number}?words=false&translations={ENGLISH_TRANSLATION_ID},{URDU_TRANSLATION_ID}"
        "&fields=verse_key&per_page=50"
    )
    response = fetch_json(url)
    verses = response.get("verses", [])

    verse_entries: list[dict[str, Any]] = []
    chapter_ids: set[int] = set()
    juz_numbers: set[int] = set()
    hizb_numbers: set[int] = set()
    rub_el_hizb_numbers: set[int] = set()
    ruku_numbers: set[int] = set()
    manzil_numbers: set[int] = set()
    sajdah_verse_keys: list[str] = []
    english_segments: list[str] = []
    urdu_segments: list[str] = []

    for verse in verses:
        chapter_id = int(str(verse["verse_key"]).split(":")[0])
        verse_number = int(verse["verse_number"])
        chapter_ids.add(chapter_id)
        juz_numbers.add(int(verse["juz_number"]))
        hizb_numbers.add(int(verse["hizb_number"]))
        rub_el_hizb_numbers.add(int(verse["rub_el_hizb_number"]))
        ruku_numbers.add(int(verse["ruku_number"]))
        manzil_numbers.add(int(verse["manzil_number"]))

        if verse.get("sajdah_number") is not None:
            sajdah_verse_keys.append(str(verse["verse_key"]))

        translations = verse.get("translations", [])
        english_translation = ""
        urdu_translation = ""

        for translation in translations:
            resource_id = int(translation["resource_id"])
            cleaned = compact_text(str(translation.get("text", "")))
            if not cleaned:
                continue
            if resource_id == ENGLISH_TRANSLATION_ID:
                english_translation = cleaned
            elif resource_id == URDU_TRANSLATION_ID:
                urdu_translation = cleaned

        if english_translation:
            english_segments.append(english_translation)
        if urdu_translation:
            urdu_segments.append(urdu_translation)

        verse_entries.append(
            {
                "verseKey": verse["verse_key"],
                "chapterId": chapter_id,
                "verseNumber": verse_number,
                "juzNumber": int(verse["juz_number"]),
                "hizbNumber": int(verse["hizb_number"]),
                "rubElHizbNumber": int(verse["rub_el_hizb_number"]),
                "rukuNumber": int(verse["ruku_number"]),
                "manzilNumber": int(verse["manzil_number"]),
                "sajdahNumber": verse.get("sajdah_number"),
                "translationEn": english_translation,
                "translationUr": urdu_translation,
            }
        )

    return {
        "pageNumber": page_number,
        "chapterIds": sorted(chapter_ids),
        "juzNumbers": sorted(juz_numbers),
        "hizbNumbers": sorted(hizb_numbers),
        "rubElHizbNumbers": sorted(rub_el_hizb_numbers),
        "rukuNumbers": sorted(ruku_numbers),
        "manzilNumbers": sorted(manzil_numbers),
        "sajdahVerseKeys": sajdah_verse_keys,
        "translationEn": " ".join(english_segments).strip(),
        "translationUr": " ".join(urdu_segments).strip(),
        "verses": verse_entries,
    }


def main() -> None:
    chapters_response = fetch_json("https://api.quran.com/api/v4/chapters")
    chapters = chapters_response.get("chapters", [])
    chapter_entries = [
        {
            "id": int(chapter["id"]),
            "nameSimple": chapter["name_simple"],
            "nameArabic": chapter["name_arabic"],
            "translatedName": chapter["translated_name"]["name"],
            "revelationPlace": chapter["revelation_place"],
            "versesCount": int(chapter["verses_count"]),
            "pages": chapter["pages"],
        }
        for chapter in chapters
    ]

    page_entries: list[dict[str, Any]] = []
    started = time.time()
    for page_number in range(1, TOTAL_PAGES + 1):
        page_entries.append(page_payload(page_number))
        if page_number % 20 == 0:
            elapsed = time.time() - started
            print(f"Fetched {page_number}/{TOTAL_PAGES} pages in {elapsed:.1f}s")

    payload = {
        "source": {
            "name": "Quran.com API v4",
            "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "notes": (
                "Bundled page insights for fast local search and reading helpers. "
                "Arabic page text remains in quran_text_by_page.json."
            ),
            "englishTranslationId": ENGLISH_TRANSLATION_ID,
            "urduTranslationId": URDU_TRANSLATION_ID,
        },
        "chapters": chapter_entries,
        "pages": page_entries,
    }
    OUTPUT_PATH.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Saved page insights to {OUTPUT_PATH}")


if __name__ == "__main__":
    main()

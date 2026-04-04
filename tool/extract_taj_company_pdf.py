from __future__ import annotations

import shutil
from pathlib import Path

import fitz
from PIL import Image


SOURCE_PDF = Path(
    r"c:\Users\AMEEQ EMAAD PC\Downloads\AL QURAN 16 Lines Taj Company Arabic Side Binding.pdf"
)
OUTPUT_DIR = Path(
    r"c:\Users\AMEEQ EMAAD PC\Documents\GitHub\opplexiptv\my_flutter_app\assets\quran_pages"
)

# This PDF contains:
# - 1 cover page
# - inner Taj Company opening page at PDF page 2
# - Quran scans
# - closing dua page at PDF page 551
# - appendix/index pages after that
FIRST_BOOK_PAGE = 2
LAST_BOOK_PAGE = 551
RENDER_SCALE = 2.0
JPEG_QUALITY = 88


def main() -> None:
    if not SOURCE_PDF.exists():
        raise SystemExit(f"Source PDF not found: {SOURCE_PDF}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    for stale in OUTPUT_DIR.glob("*.jpg"):
        if stale.name.lower() != "readme.jpg":
            stale.unlink()
    for stale in OUTPUT_DIR.glob("*.png"):
        stale.unlink()

    document = fitz.open(SOURCE_PDF)
    if LAST_BOOK_PAGE > document.page_count:
        raise SystemExit(
            f"Configured end page {LAST_BOOK_PAGE} exceeds PDF page count {document.page_count}."
        )

    exported = 0
    matrix = fitz.Matrix(RENDER_SCALE, RENDER_SCALE)

    for pdf_page_number in range(FIRST_BOOK_PAGE, LAST_BOOK_PAGE + 1):
        page_index = pdf_page_number - 1
        page = document[page_index]
        pixmap = page.get_pixmap(matrix=matrix, colorspace=fitz.csGRAY, alpha=False)
        image = Image.frombytes("L", [pixmap.width, pixmap.height], pixmap.samples)
        logical_page_number = exported + 1
        output_path = OUTPUT_DIR / f"{logical_page_number:03}.jpg"
        image.save(output_path, quality=JPEG_QUALITY, optimize=True)
        exported += 1
        if logical_page_number % 25 == 0:
            print(f"Exported {logical_page_number} pages...")

    source_copy = OUTPUT_DIR / SOURCE_PDF.name
    shutil.copy2(SOURCE_PDF, source_copy)

    print(
        f"Done. Exported {exported} page images from PDF pages "
        f"{FIRST_BOOK_PAGE}-{LAST_BOOK_PAGE} into {OUTPUT_DIR}."
    )


if __name__ == "__main__":
    main()

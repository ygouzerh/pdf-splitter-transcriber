# PDF Splitter

Split a PDF into sections based on pages matching a start pattern, using pdfgrep and qpdf. Ranges are half-open: start inclusive, end exclusive. The last section ends at the first page after the last start that matches an end pattern (enabled by default; default value: "HSK Model Test"); if not found after the last start, it ends at the document's end.

## Features
- Start pattern detection via pdfgrep (on an OCR'd temp PDF for reliable search)
- End pattern enabled by default (default: `HSK Model Test`) to cap the last range
- OCR toggle (enabled by default; `--no-ocr` disables)
- Outputs numbered PDFs: `output/<input-basename>/1.pdf`, `2.pdf`, ...
- Uses qpdf for splitting, preserving original PDF quality

## Requirements
- `qpdf`
- `pdfgrep`
- `ocrmypdf` (optional but recommended; disabled with `--no-ocr`)

On macOS (Homebrew):
- `brew install qpdf pdfgrep ocrmypdf`

## Usage
```
./pdf-splitter.sh [options] <input.pdf>
```
Options:
- `-p, --pattern <string>`: Start pattern to search for. Default:
  `Choose the right picture for each dialogue you hear`
- `-e, --end-pattern <string>`: End pattern (default: `HSK Model Test`); used as exclusive
  upper bound for the last section if found after the last start match.
- `--no-ocr`: Disable OCR; search directly in the original PDF.
- `-h, --help`: Show help.

Behavior:
- Ranges: `[start, nextStart)` for every match of the start pattern.
- Last range: `[lastStart, endMatch)` (with default end pattern `HSK Model Test`) if found after the last start; otherwise `[lastStart, lastPage+1)` (i.e., up to the document end).
- Splitting with qpdf uses inclusive page ranges; the script converts half-open intervals accordingly.

## Examples
- Default split:
```
./pdf-splitter.sh input.pdf
```
- Custom patterns, no OCR:
```
./pdf-splitter.sh -p "Unit" -e "Appendix" --no-ocr book.pdf
```

## Notes
- If OCR fails, the script falls back to searching in the original PDF.
- If the start pattern isn't found, the script exits with an error.
- If the end pattern (default or custom) is not found after the last start, the script warns and uses the document end.

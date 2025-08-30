# PDF Splitter + Transcriber

This project helps you split a PDF into logical sections and transcribe each section into structured text. It pairs a splitter (page-range extraction driven by text patterns) with a transcriber (Claude CLI + Read tool) for fast batch processing.

## Reason of creation

I created this repo in order to translate my chinese workbook which contains exercices for each lessons into pinyin texts and translation for each exercice, per lesson, in order to auto-correct myself. 

It's mostly for my personal usage and not updated. If you want to use it, feel free to modify the prompt in the transcribe script and the patterns when calling pdf-splitter.

## What’s inside
- PDF Splitter — see `pdf-splitter/README.md`
- PDF Transcriber — see `pdf-transcriber/README.md`

## Main tools

- ocrmypdf (OCR, chi_sim+eng) — to make PDFs searchable for reliable pattern matching
- pdfgrep — to find start/end patterns by page number
- qpdf — to split PDFs into page ranges
- Claude CLI — to open local PDFs and produce structured transcriptions

## One-command workflow
A `justfile` is provided to run both steps in sequence:

```
just split-transcribe <path/to/file.pdf> [concurrency]
```

See the individual READMEs for details:
- pdf-splitter: `pdf-splitter/README.md`
- pdf-transcriber: `pdf-transcriber/README.md`

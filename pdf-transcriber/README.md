# PDF Transcriber

Utilities to transcribe one or many PDFs into structured text using the Claude CLI and its Read tool.

- `transcribe.sh`: Transcribes a single PDF and prints the result to stdout.
- `transcribe-all-folder.sh`: Runs `transcribe.sh` over all PDFs in a folder, concurrently, and writes one `.txt` per PDF.

## Requirements

- macOS or Linux with Bash
- `find` and `xargs` (present by default on macOS)
- Claude CLI installed and authenticated
  - You must have access to the `Read` tool so Claude can open local PDFs
  - Ensure your Claude CLI is logged in or `ANTHROPIC_API_KEY` is set

## How it works

- `transcribe.sh` sends the PDF path to Claude with a system prompt that asks for structured outputs (Chinese, pinyin, translation, short grammar point, and special handling for multiple choice). The prompt is embedded in the script.
- `transcribe-all-folder.sh` discovers all `*.pdf` files in a directory and calls `transcribe.sh` for each file in parallel. Results are saved to `output/<folder-name>/<basename>.txt`.

## Usage

Make the scripts executable once:

```bash
chmod +x transcribe.sh transcribe-all-folder.sh
```

### Single PDF

```bash
./transcribe.sh /absolute/or/relative/path/to/file.pdf > output.txt
```

- Prints the transcription to stdout. Redirect to a file if desired.

### Entire Folder

```bash
./transcribe-all-folder.sh <folder-with-pdfs> [concurrency]
```

- Writes results to: `pdf-transcriber/output/<folder-name>/<file-basename>.txt`
- Skips files whose output already exists and is non-empty
- Concurrency defaults to `4`; can be provided as an optional arg or via `CONCURRENCY` env var

Examples for this repo layout:

```bash
# Transcribe all split PDFs from pdf-splitter
./transcribe-all-folder.sh ../pdf-splitter/output/hsk-3-workbook 6

# Single file
./transcribe.sh ../pdf-splitter/output/hsk-3-workbook/1.pdf > output/hsk-3-workbook/1.txt
```

## Configuration

Environment variables:

- `CONCURRENCY`: Max parallel transcriptions for the folder script (default: 4)
- `OUTPUT_BASE_DIR`: Base directory for batch outputs (default: `pdf-transcriber/output`)

To change the output format or instructions, edit the `SYSTEM_PROMPT` inside `transcribe.sh`.

## Troubleshooting

- Permission denied: `chmod +x transcribe.sh transcribe-all-folder.sh`
- Claude auth errors: run `claude --version` to check install; ensure you are logged in or `ANTHROPIC_API_KEY` is exported
- Read tool missing: make sure your Claude CLI supports `--allowed-tools "Read"`
- Batch run failure for a file: check the corresponding `*.stderr` sibling file referenced in the error message
- File not found: verify the PDF path exists and is readable

## Notes

- Robust to spaces/newlines in file names (uses `find -print0` and `xargs -0`)
- Atomic writes: writes to a temp file then moves to final path
- Idempotent for existing outputs: non-empty `.txt` files are skipped to save time

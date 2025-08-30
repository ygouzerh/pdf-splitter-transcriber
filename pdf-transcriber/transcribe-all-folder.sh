#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

# Usage and args
if [[ $# -lt 1 ]]; then
	echo "Usage: $(basename "$0") <folder-with-pdfs> [concurrency]" >&2
	exit 1
fi

INPUT_DIR="$1"
CONCURRENCY="${2:-${CONCURRENCY:-4}}" # optional arg or env var; default 4

# Resolve absolute paths
if [[ ! -d "$INPUT_DIR" ]]; then
	echo "Error: directory not found: $INPUT_DIR" >&2
	exit 1
fi

# Absolute input dir
ABS_INPUT_DIR="$(cd "$INPUT_DIR" && pwd)"
FOLDER_NAME="$(basename "$ABS_INPUT_DIR")"

# Script dir and output base dir (within pdf-transcriber by default)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_BASE_DIR="${OUTPUT_BASE_DIR:-"$SCRIPT_DIR/output"}"
OUT_DIR="$OUTPUT_BASE_DIR/$FOLDER_NAME"

mkdir -p "$OUT_DIR"

echo "Input folder: $ABS_INPUT_DIR" >&2
echo "Output folder: $OUT_DIR" >&2
echo "Concurrency: $CONCURRENCY" >&2

# Find all PDFs and process in parallel with xargs
# - robust against spaces/newlines with -print0 and -0
# - safe write using temp files then atomic mv
export LC_ALL=C

find "$ABS_INPUT_DIR" -type f \( -iname '*.pdf' \) -print0 | \
	xargs -0 -n 1 -P "$CONCURRENCY" -I {} \
	bash -c '
		set -euo pipefail
		FILE="$1"
		SCRIPT_DIR="$2"
		OUT_DIR="$3"
		base_name="$(basename "${FILE%.*}")"
		out_file="$OUT_DIR/$base_name.txt"
		tmp_file="$out_file.__tmp__"

		mkdir -p "$OUT_DIR"
		echo "Transcribing -> $out_file" >&2

		# If output already exists and is non-empty, skip to save time
		if [[ -s "$out_file" ]]; then
			echo "Skip existing: $out_file" >&2
			exit 0
		fi

		# Run the transcriber and write to a temp file first
		if "$SCRIPT_DIR/transcribe.sh" "$FILE" >"$tmp_file" 2>"$tmp_file.stderr"; then
			mv -f "$tmp_file" "$out_file"
			rm -f "$tmp_file.stderr" || true
		else
			echo "Failed: $FILE (see $tmp_file.stderr)" >&2
			rm -f "$tmp_file" || true
			exit 1
		fi
	' _ {} "$SCRIPT_DIR" "$OUT_DIR"

echo "Done." >&2
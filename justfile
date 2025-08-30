# Run PDF splitter then transcribe all split PDFs in one go.
# Usage:
#   just split-transcribe <path/to/file.pdf> [concurrency]
# Example:
#   just split-transcribe pdf-splitter/hsk-3-workbook.pdf 6

set shell := ["bash", "-o", "pipefail", "-eu", "-c"]

default:
	@just --list

# Main task: split the input PDF and transcribe all resulting pages
split-transcribe pdf concurrency='' :
	#!/usr/bin/env bash
	pdf="{{pdf}}"
	if [[ ! -f "$pdf" ]]; then
		echo "Error: PDF not found: $pdf" >&2
		exit 1
	fi

	# Resolve absolute path to the input PDF (robust to later cd)
	abs_pdf="$(cd "$(dirname "$pdf")" && pwd)/$(basename "$pdf")"

	# Ensure helper scripts are executable
	chmod +x ./pdf-splitter/pdf-splitter.sh ./pdf-transcriber/transcribe-all-folder.sh ./pdf-transcriber/transcribe.sh || true

	# 1) Split the PDF into per-section files under pdf-splitter/output/<basename>
	pushd ./pdf-splitter > /dev/null
	./pdf-splitter.sh "$abs_pdf"
	popd > /dev/null

	# 2) Compute split output directory from input basename
	base="$(basename "$abs_pdf")"
	name="${base%.*}"
	split_dir_rel="pdf-splitter/output/$name"
	if [[ ! -d "$split_dir_rel" ]]; then
		echo "Error: Expected split output directory not found: $split_dir_rel" >&2
		exit 1
	fi
	split_dir_abs="$(cd "$split_dir_rel" && pwd)"

	# 3) Transcribe all PDFs in the split folder (optionally with concurrency)
	pushd ./pdf-transcriber > /dev/null
	if [[ -n "{{concurrency}}" ]]; then
		./transcribe-all-folder.sh "$split_dir_abs" "{{concurrency}}"
	else
		./transcribe-all-folder.sh "$split_dir_abs"
	fi
	popd > /dev/null

#!/usr/bin/env bash

set -euo pipefail

# pdf-splitter
#
# Split a PDF into sections based on page matches for a start pattern.
# Ranges are computed as half-open intervals: [start, nextStart) for each match.
# For the last section, if an end pattern is provided, it uses [lastStart, endMatch),
# otherwise [lastStart, lastPage+1).
#
# Searches happen on an OCR'd temporary PDF (unless --no-ocr), but splitting is done
# from the original input to preserve quality.

DEFAULT_START_PATTERN='Choose the right picture for each dialogue you hear'
DEFAULT_END_PATTERN='HSK Model Test'

usage() {
	cat <<EOF
Usage: $(basename "$0") [options] <input.pdf>

Options:
	-p, --pattern <string>       Start pattern to search for (default: exact string match)
									 Default: ${DEFAULT_START_PATTERN}
	-e, --end-pattern <string>   End pattern; used as exclusive upper bound for the last section
									 Default: ${DEFAULT_END_PATTERN}
	--no-ocr                     Disable OCR; search directly in the original PDF
	-h, --help                   Show this help

Behavior:
	- Ranges are half-open: start inclusive, end exclusive.
	- Output PDFs are 1.pdf, 2.pdf, ... under output/<input-basename>/
	- Uses qpdf to split and pdfgrep to locate pages.

Examples:
	$(basename "$0") input.pdf
	$(basename "$0") -p "Unit" -e "Appendix" --no-ocr book.pdf
EOF
}

start_pattern=${DEFAULT_START_PATTERN}
end_pattern=${DEFAULT_END_PATTERN}
use_ocr=1

if [[ $# -eq 0 ]]; then
	usage; exit 1
fi

ARGS=()
while [[ $# -gt 0 ]]; do
	case "$1" in
		-p|--pattern)
			[[ $# -ge 2 ]] || { echo "Error: --pattern requires a value" >&2; exit 2; }
			start_pattern="$2"; shift 2;;
		-e|--end-pattern)
			[[ $# -ge 2 ]] || { echo "Error: --end-pattern requires a value" >&2; exit 2; }
			end_pattern="$2"; shift 2;;
		--no-ocr)
			use_ocr=0; shift;;
		-h|--help)
			usage; exit 0;;
		--)
			shift; while [[ $# -gt 0 ]]; do ARGS+=("$1"); shift; done; break;;
		-*)
			echo "Unknown option: $1" >&2; usage; exit 2;;
		*)
			ARGS+=("$1"); shift;;
	esac
done

if [[ ${#ARGS[@]} -ne 1 ]]; then
	echo "Error: exactly one input PDF must be provided" >&2
	usage
	exit 2
fi

INPUT=${ARGS[0]}
if [[ ! -f "$INPUT" ]]; then
	echo "Error: input file not found: $INPUT" >&2
	exit 1
fi

base_name=$(basename -- "$INPUT")
name_no_ext=${base_name%.*}
out_dir="output/$name_no_ext"
mkdir -p "$out_dir"

# Prepare searchable PDF
search_pdf="$INPUT"
tmp_ocr=""
cleanup() {
	if [[ -n "$tmp_ocr" && -f "$tmp_ocr" ]]; then rm -f "$tmp_ocr"; fi
}
trap cleanup EXIT

if [[ $use_ocr -eq 1 ]]; then
	# Create a temporary OCR'd PDF for reliable text search
	tmp_ocr=$(mktemp "${TMPDIR:-/tmp}/pdf-splitter-ocr-XXXXXX.pdf")
	echo "[info] OCR'ing for search: $INPUT -> $tmp_ocr" >&2
	# Use default ocrmypdf settings; rely on auto-detection
	ocrmypdf "$INPUT" "$tmp_ocr" >/dev/null 2>&1 || {
		echo "[warn] ocrmypdf failed; falling back to original PDF for search" >&2
		rm -f "$tmp_ocr"; tmp_ocr=""; search_pdf="$INPUT"
	}
	if [[ -n "$tmp_ocr" && -f "$tmp_ocr" ]]; then
		search_pdf="$tmp_ocr"
	fi
else
	echo "[info] OCR disabled; searching in original PDF" >&2
fi

# Find start pages (unique, ascending)
mapfile -t start_pages < <(pdfgrep -n -F -- "$start_pattern" "$search_pdf" | awk -F: '{print $1}' | sort -n | uniq)

if [[ ${#start_pages[@]} -eq 0 ]]; then
	echo "Error: start pattern not found: $start_pattern" >&2
	exit 3
fi

# Determine total pages via qpdf; needed if no end-pattern or not found after last start
total_pages=$(qpdf --show-npages "$INPUT" 2>/dev/null || true)
if ! [[ "$total_pages" =~ ^[0-9]+$ ]]; then
	echo "Error: could not determine total pages via qpdf" >&2
	exit 4
fi

# Determine end bound for the last section
last_start=${start_pages[-1]}
last_end_exclusive=$((total_pages + 1))

if [[ -n "$end_pattern" ]]; then
	# Collect all end pattern hits and pick the first strictly after last_start
	mapfile -t end_pages_all < <(pdfgrep -n -F -- "$end_pattern" "$search_pdf" | awk -F: '{print $1}' | sort -n | uniq)
	for ep in "${end_pages_all[@]:-}"; do
		if [[ -n "$ep" && "$ep" =~ ^[0-9]+$ ]] && (( ep > last_start )); then
			last_end_exclusive=$ep
			break
		fi
	done
	if (( last_end_exclusive == total_pages + 1 )); then
		echo "[warn] end pattern not found after last start; defaulting to end of document" >&2
	fi
fi

# Compute ranges as half-open intervals and split with qpdf
section_index=1
for (( i=0; i<${#start_pages[@]}; i++ )); do
	start=${start_pages[$i]}
	if (( i+1 < ${#start_pages[@]} )); then
		end_excl=${start_pages[$((i+1))]}
	else
		end_excl=$last_end_exclusive
	fi

	# Convert half-open [start, end_excl) to qpdf inclusive range [start, end_incl]
	end_incl=$((end_excl - 1))
	if (( end_incl < start )); then
		echo "[warn] Skipping empty range ${section_index}:${start}-${end_excl}" >&2
		((section_index++))
		continue
	fi

	out_file="$out_dir/${section_index}.pdf"
	echo "[info] Creating ${out_file} from pages ${start}-${end_incl}" >&2
	# qpdf syntax: qpdf in.pdf --pages in.pdf start-end -- out.pdf
	qpdf "$INPUT" --pages "$INPUT" ${start}-${end_incl} -- "$out_file"

	((section_index++))
done

echo "[done] Created $((section_index-1)) sections in $out_dir" >&2
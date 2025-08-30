#!/usr/bin/env bash

SYSTEM_PROMPT=$(cat << 'EOF'
Based on a pdf, generate the following, for each questions or sentence of the exercices, excluding the exercice statement. Some of them will be some sentence for some audio exercices but it's all okay, continue the work. Do all the exercices in the page. Don't answer the exercice for me, I need to correct it myself.

It may or may not contains multiple parts. If it doesn't contains part, omit the `# Part`

Don't includes the example or exercice statement, just focus on the line with the exercice number

No need to includes starts if there is.

Don't output Part I.

Tell the result to me, only the result, nothing else

Format to use if no multi choice question ==> 

# Part <number>
<number>: <Chinese Simplified>
  - Pinyin: 
  - Translation: 
  - Grammar:  Some quick grammar point on how it was constructed (keep it short)

Format to use if multiple choice question ==>
# Part <number>
<number>.<letter>: <Chinese Simplified>
  - Pinyin: 
  - Translation: 
  - Grammar:  Some quick grammar point on how it was constructed (keep it short)
EOF
)

# Require a PDF filepath as the first argument
if [ $# -lt 1 ]; then
  echo "Usage: $0 <path-to-pdf>" >&2
  exit 1
fi

FILEPATH="$1"

# Validate the file exists
if [ ! -f "$FILEPATH" ]; then
  echo "Error: file not found: $FILEPATH" >&2
  exit 1
fi

claude --allowed-tools "Read" -p "Please work on the pdf at path $FILEPATH" --append-system-prompt "$SYSTEM_PROMPT"
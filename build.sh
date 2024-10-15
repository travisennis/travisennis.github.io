#!/bin/bash

md_to_html() {
  if [ -z "$1" ]; then
    echo "Usage: md_to_html <input_markdown_file.md> [optional_css_file.css]"
    return 1
  fi

  local input_file="$1"
  local output_file="${input_file%.md}.html"
  local css_file="$2"

  if [ -n "$css_file" ]; then
    # If a CSS file is provided, include it in the Pandoc command

  pandoc "$input_file" -o "$output_file" --standalone --css="$css_file" --no-highlight --include-in-header=<(echo '
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.3.1/styles/monokai.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.3.1/highlight.min.js"></script>
    <script>hljs.highlightAll();</script>')
  else
    # If no CSS file is provided, run the command without the --css option
  pandoc "$input_file" -o "$output_file" --standalone  --no-highlight --include-in-header=<(echo '
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.3.1/styles/monokai.min.css">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.3.1/highlight.min.js"></script>
    <script>hljs.highlightAll();</script>')
  fi

  echo "Converted $input_file to $output_file"
}

# Directory to process (first argument)
directory="$1"

# Optional CSS file (second argument)
css_file="$2"

# Check if the directory exists
if [ ! -d "$directory" ]; then
  echo "Directory $directory does not exist."
  exit 1
fi

# Loop through all .md files in the directory
for md_file in "$directory"/*.md; do
  # Check if the file exists (in case there are no .md files)
  if [ -f "$md_file" ]; then
    md_to_html "$md_file" "$css_file"
  fi
done
#!/usr/bin/env bash
#
# Build the search-index JSON from the TEI XML source, locally.
#
# Converts every TEI article to json/<id>.json using siteGenerator/xsl/json.xsl,
# then concatenates them into json/combined.json (the file search.js loads).
#
# Requirements:
#   - Java (java on PATH)
#   - Saxon-HE 10.6 jar (auto-downloaded to /tmp/saxon.jar if missing)
#
# Usage:
#   siteGenerator/build-json.sh [TEI_DIR]
#
# TEI_DIR defaults to the sibling checkout of the data repo:
#   ../e-gedsh/data/tei/articles/tei
#
set -euo pipefail

# Resolve the app root (parent of this script's directory).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

TEI_DIR="${1:-$APP_ROOT/../e-gedsh/data/tei/articles/tei}"
XSL="$APP_ROOT/siteGenerator/xsl/json.xsl"
OUT_DIR="$APP_ROOT/json"
SAXON_JAR="${SAXON_JAR:-/tmp/saxon.jar}"
SAXON_URL="https://repo1.maven.org/maven2/net/sf/saxon/Saxon-HE/10.6/Saxon-HE-10.6.jar"

if [ ! -d "$TEI_DIR" ]; then
  echo "ERROR: TEI directory not found: $TEI_DIR" >&2
  echo "Pass the path as the first argument, e.g.:" >&2
  echo "  $0 /path/to/e-gedsh/data/tei/articles/tei" >&2
  exit 1
fi

if [ ! -f "$SAXON_JAR" ]; then
  echo "Saxon jar not found at $SAXON_JAR; downloading Saxon-HE 10.6 ..."
  curl -sSL "$SAXON_URL" -o "$SAXON_JAR"
fi

mkdir -p "$OUT_DIR"

echo "Converting TEI -> JSON"
echo "  TEI dir : $TEI_DIR"
echo "  XSL     : $XSL"
echo "  Out dir : $OUT_DIR"

count=0
skipped=0
failed=0
while IFS= read -r file; do
  id="$(basename "$file" .xml)"
  out="$OUT_DIR/${id}.json"
  # Config is resolved relative to the stylesheet, so no staticSitePath needed.
  if ! java -jar "$SAXON_JAR" \
      -s:"$file" \
      -xsl:"$XSL" \
      -o:"$out"; then
    echo "  WARNING: conversion failed for $file" >&2
    failed=$((failed + 1))
    continue
  fi
  # Keep only article entries: the produced JSON must carry a top-level "idno".
  # This drops front/back matter and other non-article XML.
  if grep -q '"idno"' "$out"; then
    count=$((count + 1))
  else
    echo "  Skipping non-article file: $file"
    rm -f "$out"
    skipped=$((skipped + 1))
  fi
done < <(find "$TEI_DIR" -type f -name '*.xml' | sort)

echo "Converted $count files ($skipped skipped, $failed failed)"

echo "Building combined.json"
combined="$OUT_DIR/combined.json"
echo '[' > "$combined"
first=true
for f in "$OUT_DIR"/*.json; do
  [ "$f" = "$combined" ] && continue
  # Only include article records (those carrying an idno).
  grep -q '"idno"' "$f" || continue
  if [ "$first" = true ]; then first=false; else echo ',' >> "$combined"; fi
  cat "$f" >> "$combined"
done
echo ']' >> "$combined"

echo "Wrote $combined with $(grep -c '"idno"' "$combined") entries"

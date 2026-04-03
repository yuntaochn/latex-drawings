#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${ROOT_DIR}/src"
OUTPUT_DIR="${ROOT_DIR}/output"

require_command() {
  local cmd="$1"

  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}" >&2
    exit 1
  fi
}

require_command latexmk
require_command pdf2svg

mkdir -p "${OUTPUT_DIR}"

tex_files=("${SRC_DIR}"/*.tex)

if [ ${#tex_files[@]} -eq 0 ]; then
  echo "No TeX files found in ${SRC_DIR}" >&2
  exit 1
fi

export CTEX_FONTSET="${CTEX_FONTSET:-fandol}"

for tex_file in "${tex_files[@]}"; do
  base_name="$(basename "${tex_file%.tex}")"
  pdf_file="${OUTPUT_DIR}/${base_name}.pdf"
  svg_file="${OUTPUT_DIR}/${base_name}.svg"

  echo "Compiling ${base_name}.tex"

  latexmk \
    -xelatex \
    -interaction=nonstopmode \
    -halt-on-error \
    -file-line-error \
    -outdir="${OUTPUT_DIR}" \
    "${tex_file}"

  if [ ! -f "${pdf_file}" ]; then
    echo "Expected PDF not found: ${pdf_file}" >&2
    exit 1
  fi

  echo "Converting ${base_name}.pdf -> ${base_name}.svg"
  pdf2svg "${pdf_file}" "${svg_file}"
done

echo
echo "Generated files in ${OUTPUT_DIR}:"
ls -lh "${OUTPUT_DIR}"/*.pdf "${OUTPUT_DIR}"/*.svg

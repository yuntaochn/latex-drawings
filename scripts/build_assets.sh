#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${ROOT_DIR}/src"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/.local/output}"

if [[ "${OUTPUT_DIR}" != /* ]]; then
  OUTPUT_DIR="${ROOT_DIR}/${OUTPUT_DIR}"
fi

require_command() {
  local cmd="$1"

  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Missing required command: ${cmd}" >&2
    exit 1
  fi
}

require_command latexmk
require_command xelatex

if command -v dvisvgm >/dev/null 2>&1; then
  SVG_CONVERTER="dvisvgm"
elif command -v pdf2svg >/dev/null 2>&1; then
  SVG_CONVERTER="pdf2svg"
else
  echo "Missing required SVG converter: dvisvgm or pdf2svg" >&2
  exit 1
fi

mkdir -p "${OUTPUT_DIR}"

tex_files=("${SRC_DIR}"/*.tex)

if [ ${#tex_files[@]} -eq 0 ]; then
  echo "No TeX files found in ${SRC_DIR}" >&2
  exit 1
fi

export CTEX_FONTSET="${CTEX_FONTSET:-fandol}"

LOCAL_OUTPUT_DIR="${ROOT_DIR}/.local/output"
KEEP_INTERMEDIATES=1
if [ "${OUTPUT_DIR}" = "${LOCAL_OUTPUT_DIR}" ]; then
  KEEP_INTERMEDIATES=0
fi

for tex_file in "${tex_files[@]}"; do
  base_name="$(basename "${tex_file%.tex}")"
  pdf_file="${OUTPUT_DIR}/${base_name}.pdf"
  svg_file="${OUTPUT_DIR}/${base_name}.svg"
  xdv_file="${OUTPUT_DIR}/${base_name}.xdv"

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
  if [ "${SVG_CONVERTER}" = "dvisvgm" ]; then
    if [ ! -f "${xdv_file}" ]; then
      echo "Expected XDV not found for dvisvgm: ${xdv_file}" >&2
      exit 1
    fi

    dvisvgm --output="${svg_file}" "${xdv_file}"
  else
    pdf2svg "${pdf_file}" "${svg_file}"
  fi
done

if [ "${KEEP_INTERMEDIATES}" -eq 0 ]; then
  rm -f "${OUTPUT_DIR}"/*.aux \
        "${OUTPUT_DIR}"/*.fdb_latexmk \
        "${OUTPUT_DIR}"/*.fls \
        "${OUTPUT_DIR}"/*.log \
        "${OUTPUT_DIR}"/*.out \
        "${OUTPUT_DIR}"/*.xdv \
        "${OUTPUT_DIR}"/xelatex*.fls
fi

echo
echo "Generated files in ${OUTPUT_DIR}:"
ls -lh "${OUTPUT_DIR}"/*.pdf "${OUTPUT_DIR}"/*.svg

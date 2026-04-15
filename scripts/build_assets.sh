#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="${OUTPUT_DIR:-${ROOT_DIR}/.local/output}"
SOURCE_NAMES_RAW="${SOURCE_NAMES:-src,drafts}"
SOURCE_ENTRIES=()

if [[ "${OUTPUT_DIR}" != /* ]]; then
  OUTPUT_DIR="${ROOT_DIR}/${OUTPUT_DIR}"
fi

SOURCE_NAMES_NORMALIZED="$(echo "${SOURCE_NAMES_RAW}" | tr ',' ' ')"
for source_name in ${SOURCE_NAMES_NORMALIZED}; do
  source_dir="${ROOT_DIR}/${source_name}"
  SOURCE_ENTRIES+=("${source_name}:${source_dir}")
done

if [ ${#SOURCE_ENTRIES[@]} -eq 0 ]; then
  echo "No source directories configured. Set SOURCE_NAMES (e.g. src,drafts)." >&2
  exit 1
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

tex_jobs=()
for source_entry in "${SOURCE_ENTRIES[@]}"; do
  source_name="${source_entry%%:*}"
  source_dir="${source_entry#*:}"
  if [ -d "${source_dir}" ]; then
    for tex_file in "${source_dir}"/*.tex; do
      tex_jobs+=("${source_name}|${tex_file}")
    done
  fi
done

if [ ${#tex_jobs[@]} -eq 0 ]; then
  echo "No TeX files found in source directories." >&2
  exit 1
fi

export CTEX_FONTSET="${CTEX_FONTSET:-fandol}"

LOCAL_OUTPUT_DIR="${ROOT_DIR}/.local/output"
KEEP_INTERMEDIATES=1
if [ "${OUTPUT_DIR}" = "${LOCAL_OUTPUT_DIR}" ]; then
  KEEP_INTERMEDIATES=0
fi

if [ -n "${KEEP_INTERMEDIATES:-}" ]; then
  case "${KEEP_INTERMEDIATES}" in
    0|false|FALSE|no|NO)
      KEEP_INTERMEDIATES=0
      ;;
    1|true|TRUE|yes|YES)
      KEEP_INTERMEDIATES=1
      ;;
    *)
      echo "Invalid KEEP_INTERMEDIATES value: ${KEEP_INTERMEDIATES}. Use 0/1/true/false." >&2
      exit 1
      ;;
  esac
fi

for tex_job in "${tex_jobs[@]}"; do
  source_name="${tex_job%%|*}"
  tex_file="${tex_job#*|}"
  target_dir="${OUTPUT_DIR}/${source_name}"
  base_name="$(basename "${tex_file%.tex}")"
  pdf_file="${target_dir}/${base_name}.pdf"
  svg_file="${target_dir}/${base_name}.svg"
  xdv_file="${target_dir}/${base_name}.xdv"

  mkdir -p "${target_dir}"

  echo "Compiling ${base_name}.tex -> ${source_name}/"

  latexmk \
    -xelatex \
    -interaction=nonstopmode \
    -halt-on-error \
    -file-line-error \
    -outdir="${target_dir}" \
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
  find "${OUTPUT_DIR}" -type f \( \
    -name "*.aux" -o \
    -name "*.fdb_latexmk" -o \
    -name "*.fls" -o \
    -name "*.log" -o \
    -name "*.out" -o \
    -name "*.xdv" -o \
    -name "xelatex*.fls" \
  \) -delete
fi

echo
echo "Generated files in ${OUTPUT_DIR}:"
find "${OUTPUT_DIR}" -type f \( -name "*.pdf" -o -name "*.svg" \) -print

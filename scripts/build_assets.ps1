$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
$SrcDir = Join-Path $RootDir "src"

if ($env:OUTPUT_DIR) {
    $OutputDir = if ([System.IO.Path]::IsPathRooted($env:OUTPUT_DIR)) {
        $env:OUTPUT_DIR
    } else {
        Join-Path $RootDir $env:OUTPUT_DIR
    }
} else {
    $OutputDir = Join-Path $RootDir ".local/output"
}

function Require-Command {
    param([string]$Name)

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Missing required command: $Name"
    }
}

function Get-SvgConverter {
    if (Get-Command dvisvgm -ErrorAction SilentlyContinue) {
        return "dvisvgm"
    }

    if (Get-Command pdf2svg -ErrorAction SilentlyContinue) {
        return "pdf2svg"
    }

    throw "Missing required SVG converter: dvisvgm or pdf2svg"
}

Require-Command latexmk
Require-Command xelatex
$SvgConverter = Get-SvgConverter

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$TexFiles = Get-ChildItem -LiteralPath $SrcDir -Filter *.tex | Sort-Object Name
if ($TexFiles.Count -eq 0) {
    throw "No TeX files found in $SrcDir"
}

if (-not $env:CTEX_FONTSET) {
    $env:CTEX_FONTSET = "fandol"
}

$KeepIntermediates = [System.IO.Path]::GetFullPath($OutputDir).TrimEnd('\', '/') -ne (Join-Path $RootDir ".local/output")

foreach ($TexFile in $TexFiles) {
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($TexFile.Name)
    $PdfFile = Join-Path $OutputDir "$BaseName.pdf"
    $SvgFile = Join-Path $OutputDir "$BaseName.svg"
    $XdvFile = Join-Path $OutputDir "$BaseName.xdv"

    Write-Host "Compiling $($TexFile.Name)"
    & latexmk `
        -xelatex `
        -interaction=nonstopmode `
        -halt-on-error `
        -file-line-error `
        -outdir="$OutputDir" `
        "$($TexFile.FullName)"

    if (-not (Test-Path -LiteralPath $PdfFile)) {
        throw "Expected PDF not found: $PdfFile"
    }

    Write-Host "Converting $BaseName.pdf -> $BaseName.svg"
    if ($SvgConverter -eq "dvisvgm") {
        if (-not (Test-Path -LiteralPath $XdvFile)) {
            throw "Expected XDV not found for dvisvgm: $XdvFile"
        }

        & dvisvgm --output="$SvgFile" "$XdvFile"
    } else {
        & pdf2svg "$PdfFile" "$SvgFile"
    }
}

if (-not $KeepIntermediates) {
    Get-ChildItem -LiteralPath $OutputDir -File |
        Where-Object {
            $_.Extension -in ".aux", ".fdb_latexmk", ".fls", ".log", ".out", ".xdv" -or
            $_.BaseName -like "xelatex*"
        } |
        Remove-Item -Force
}

Write-Host ""
Write-Host "Generated files in ${OutputDir}:"
Get-ChildItem -LiteralPath $OutputDir -File | Where-Object { $_.Extension -in ".pdf", ".svg" } | Sort-Object Name | Select-Object Name, Length

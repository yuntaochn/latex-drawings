$ErrorActionPreference = "Stop"

$RootDir = Split-Path -Parent $PSScriptRoot
$SourceNamesRaw = if ($env:SOURCE_NAMES) { $env:SOURCE_NAMES } else { "src,drafts" }
$SourceNames = $SourceNamesRaw -split '[,\s]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

if ($SourceNames.Count -eq 0) {
    throw "No source directories configured. Set SOURCE_NAMES (e.g. src,drafts)."
}

$FlattenOutput = $SourceNames.Count -eq 1

$SourceDirs = $SourceNames | ForEach-Object {
    @{ Name = $_; Path = Join-Path $RootDir $_ }
}

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

function Get-PngConverter {
    if (Get-Command pdftoppm -ErrorAction SilentlyContinue) {
        return "pdftoppm"
    }

    if (Get-Command pdftocairo -ErrorAction SilentlyContinue) {
        return "pdftocairo"
    }

    throw "Missing required PNG converter: pdftocairo or pdftoppm"
}

Require-Command latexmk
Require-Command xelatex
$SvgConverter = Get-SvgConverter
$PngConverter = Get-PngConverter

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$TexJobs = foreach ($Source in $SourceDirs) {
    if (Test-Path -LiteralPath $Source.Path) {
        Get-ChildItem -LiteralPath $Source.Path -Filter *.tex -File |
            Sort-Object FullName |
            ForEach-Object {
                [PSCustomObject]@{
                    SourceName = $Source.Name
                    TexFile    = $_
                }
            }
    }
}

if ($TexJobs.Count -eq 0) {
    $SourcePaths = $SourceDirs | ForEach-Object { $_.Path }
    throw "No TeX files found in source directories: $($SourcePaths -join ', ')"
}

if (-not $env:CTEX_FONTSET) {
    $env:CTEX_FONTSET = "fandol"
}

$KeepIntermediates = [System.IO.Path]::GetFullPath($OutputDir).TrimEnd('\', '/') -ne (Join-Path $RootDir ".local/output")

if ($env:KEEP_INTERMEDIATES) {
    switch -Regex ($env:KEEP_INTERMEDIATES) {
        '^(0|false|no)$' { $KeepIntermediates = $false; break }
        '^(1|true|yes)$' { $KeepIntermediates = $true; break }
        default { throw "Invalid KEEP_INTERMEDIATES value: $($env:KEEP_INTERMEDIATES). Use 0/1/true/false." }
    }
}

foreach ($TexJob in $TexJobs) {
    $TexFile = $TexJob.TexFile
    if ($FlattenOutput) {
        $TargetDir = $OutputDir
        $TargetLabel = "./"
    } else {
        $TargetDir = Join-Path $OutputDir $TexJob.SourceName
        $TargetLabel = "$($TexJob.SourceName)/"
    }
    $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($TexFile.Name)
    $PdfFile = Join-Path $TargetDir "$BaseName.pdf"
    $PngFile = Join-Path $TargetDir "$BaseName.png"
    $PngOutputBase = Join-Path $TargetDir $BaseName
    $SvgFile = Join-Path $TargetDir "$BaseName.svg"
    $XdvFile = Join-Path $TargetDir "$BaseName.xdv"

    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

    Write-Host "Compiling $($TexFile.Name) -> $TargetLabel"
    & latexmk `
        -xelatex `
        -interaction=nonstopmode `
        -halt-on-error `
        -file-line-error `
        -outdir="$TargetDir" `
        "$($TexFile.FullName)"

    if (-not (Test-Path -LiteralPath $PdfFile)) {
        throw "Expected PDF not found: $PdfFile"
    }

    Write-Host "Converting $BaseName.pdf -> $BaseName.png"
    if ($PngConverter -eq "pdftoppm") {
        & pdftoppm -png -singlefile "$PdfFile" "$PngOutputBase"
    } else {
        & pdftocairo -png -singlefile "$PdfFile" "$PngOutputBase"
    }

    if (-not (Test-Path -LiteralPath $PngFile)) {
        throw "Expected PNG not found: $PngFile"
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
    Get-ChildItem -LiteralPath $OutputDir -Recurse -File |
        Where-Object {
            $_.Extension -in ".aux", ".fdb_latexmk", ".fls", ".log", ".out", ".xdv" -or
            $_.BaseName -like "xelatex*"
        } |
        Remove-Item -Force
}

Write-Host ""
Write-Host "Generated files in ${OutputDir}:"
Get-ChildItem -LiteralPath $OutputDir -Recurse -File |
    Where-Object { $_.Extension -in ".pdf", ".png", ".svg" } |
    Sort-Object FullName |
    Select-Object FullName, Length

.PHONY: all assets clean

all: assets

ifeq ($(OS),Windows_NT)
BUILD_ASSETS = powershell -ExecutionPolicy Bypass -File scripts/build_assets.ps1
CLEAN_OUTPUT = powershell -ExecutionPolicy Bypass -Command "if (Test-Path .local/output) { Get-ChildItem .local/output -Include *.aux,*.fdb_latexmk,*.fls,*.log,*.out,*.xdv,*.svg,*.pdf -File | Remove-Item -Force }"
else
BUILD_ASSETS = ./scripts/build_assets.sh
CLEAN_OUTPUT = rm -f .local/output/*.aux .local/output/*.fdb_latexmk .local/output/*.fls .local/output/*.log .local/output/*.out .local/output/*.xdv .local/output/*.svg .local/output/*.pdf
endif

assets:
	$(BUILD_ASSETS)

clean:
	$(CLEAN_OUTPUT)

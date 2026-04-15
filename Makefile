.PHONY: all assets clean

all: assets

ifeq ($(OS),Windows_NT)
BUILD_ASSETS = powershell -ExecutionPolicy Bypass -File scripts/build_assets.ps1
CLEAN_OUTPUT = powershell -ExecutionPolicy Bypass -Command "if (Test-Path .local/output) { Get-ChildItem .local/output -Recurse -Include *.aux,*.fdb_latexmk,*.fls,*.log,*.out,*.xdv,*.svg,*.png,*.pdf -File | Remove-Item -Force }"
else
BUILD_ASSETS = ./scripts/build_assets.sh
CLEAN_OUTPUT = find .local/output -type f \( -name "*.aux" -o -name "*.fdb_latexmk" -o -name "*.fls" -o -name "*.log" -o -name "*.out" -o -name "*.xdv" -o -name "*.svg" -o -name "*.png" -o -name "*.pdf" \) -delete
endif

assets:
	$(BUILD_ASSETS)

clean:
	$(CLEAN_OUTPUT)

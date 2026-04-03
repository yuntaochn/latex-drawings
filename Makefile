.PHONY: all assets clean

all: assets

assets:
	./scripts/build_assets.sh

clean:
	rm -f output/*.aux output/*.fdb_latexmk output/*.fls output/*.log output/*.out output/*.xdv

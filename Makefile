.PHONY: inspect test build serve fixtures validate-dist

PDF ?= notes.pdf
DIST ?= dist

inspect:
	cargo run --manifest-path generator/Cargo.toml -- inspect $(PDF)

test:
	cargo test --manifest-path generator/Cargo.toml
	npm --prefix viewer test
	npm --prefix viewer run build

build:
	cargo run --manifest-path generator/Cargo.toml -- build $(PDF) $(DIST)
	npm --prefix viewer run build -- --base ./
	cp -R viewer/dist/. $(DIST)/
	$(MAKE) validate-dist

validate-dist:
	test -f $(DIST)/index.html
	test -f $(DIST)/manifest.json
	test -f $(DIST)/board.dzi
	test -d $(DIST)/board_files
	! grep -R 'src="/' $(DIST)/index.html
	! grep -R 'href="/' $(DIST)/index.html
	! grep -R 'notes.pdf' $(DIST)
	! grep -R 'cdnjs.cloudflare.com' $(DIST)

serve: build
	python3 -m http.server 8000 --directory $(DIST)

fixtures:
	./scripts/make-fixtures.sh

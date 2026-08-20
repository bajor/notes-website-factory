.PHONY: build evaluate inspect serve test validate-dist

CABAL ?= cabal
DIST ?= $(CURDIR)/dist

inspect:
	$(CABAL) run freeform-site -- inspect "$(CURDIR)"

test:
	$(CABAL) build all
	$(CABAL) test all --test-show-details=direct
	$(MAKE) inspect
	$(MAKE) build

build:
	$(CABAL) run freeform-site -- build "$(CURDIR)" "$(DIST)"
	$(MAKE) validate-dist

evaluate:
	$(CABAL) run freeform-site -- evaluate "$(CURDIR)" "$(DIST)"
	$(MAKE) validate-dist

validate-dist:
	test -f "$(DIST)/index.html"
	test -f "$(DIST)/runtime.js"
	test -f "$(DIST)/styles.css"
	test -f "$(DIST)/scene.generated.js"
	test -f "$(DIST)/scene-summary.json"
	test -d "$(DIST)/assets"
	test "$$(find "$(DIST)/assets" -type f | wc -l)" -eq 9
	test -z "$$(find "$(DIST)" -type f -name '*.pdf' -print -quit)"
	! grep -R -E '(src|href)="/' "$(DIST)"
	grep -q '"assets":9' "$(DIST)/scene-summary.json"
	grep -q '"images":9' "$(DIST)/scene-summary.json"
	grep -q '"vectorArtworks":35' "$(DIST)/scene-summary.json"
	grep -q '"kind":"vector-artwork"' "$(DIST)/scene.generated.js"
	! grep -q 'canvas' "$(DIST)/runtime.js"

serve: build
	python3 -m http.server 8000 --directory "$(DIST)"

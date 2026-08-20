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
	test -n "$$(find "$(DIST)/assets" -type f -print -quit)"
	test -z "$$(find "$(DIST)" -type f -name '*.pdf' -print -quit)"
	! grep -R -E '(src|href)="/' "$(DIST)"

serve: build
	python3 -m http.server 8000 --directory "$(DIST)"

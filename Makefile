.PHONY: build evaluate inspect serve test validate-dist

CABAL ?= cabal
SOURCE ?= $(CURDIR)/generator/test/fixtures/minimal
TEMPLATES ?= $(CURDIR)/site
WORK ?= $(CURDIR)/build
DIST ?= $(CURDIR)/dist
REPORT ?= $(WORK)/evaluation
SITE_TITLE ?= Notes Website Factory Fixture
export SITE_TITLE

inspect:
	$(CABAL) run freeform-site -- inspect "$(SOURCE)" "$(WORK)"

test:
	$(CABAL) build all
	$(CABAL) test all --test-show-details=direct
	$(MAKE) inspect
	$(MAKE) build

build:
	$(CABAL) run freeform-site -- build "$(SOURCE)" "$(TEMPLATES)" "$(DIST)" "$${SITE_TITLE}"
	$(MAKE) validate-dist

evaluate:
	$(CABAL) run freeform-site -- evaluate "$(SOURCE)" "$(TEMPLATES)" "$(DIST)" "$(REPORT)" "$${SITE_TITLE}"
	$(MAKE) validate-dist

validate-dist:
	test -f "$(DIST)/index.html"
	test -f "$(DIST)/runtime.js"
	test -f "$(DIST)/styles.css"
	test -f "$(DIST)/scene.generated.js"
	test -f "$(DIST)/scene-summary.json"
	test -z "$$(find "$(DIST)" -type f -iname '*.pdf' -print -quit)"
	! grep -R -E '(src|href)="/' "$(DIST)"
	! grep -qi 'canvas' "$(DIST)/runtime.js"

serve: build
	python3 -m http.server 8000 --directory "$(DIST)"

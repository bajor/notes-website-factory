.PHONY: build evaluate inspect serve test test-runtime validate-dist

CABAL ?= cabal
SOURCE ?= $(CURDIR)/generator/test/fixtures/minimal
TEMPLATES ?= $(CURDIR)/site
WORK ?= $(CURDIR)/build
DIST ?= $(CURDIR)/dist
REPORT ?= $(WORK)/evaluation
SITE_TITLE ?= Notes Website Factory Fixture
CHROMIUM ?= chromium
override RUNTIME_TEST := $(CURDIR)/build/runtime-test
BROWSER_FLAGS = --headless --no-sandbox --disable-gpu --allow-file-access-from-files --virtual-time-budget=15000 --log-level=3
RUNTIME_TEST_URL = file://$(abspath $(RUNTIME_TEST))/index.html
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
	$(MAKE) test-runtime
	$(MAKE) validate-dist

test-runtime:
	test ! -L "$(CURDIR)/build"
	test ! -L "$(RUNTIME_TEST)"
	scratch="$$(realpath -m "$(RUNTIME_TEST)")" && for candidate in "$(SOURCE)" "$(TEMPLATES)" "$(DIST)" "$(REPORT)"; do protected="$$(realpath -m "$$candidate")" || exit 1; case "$$scratch/" in "$$protected/"*) printf 'runtime scratch overlaps protected path: %s\n' "$$candidate"; exit 1;; esac; case "$$protected/" in "$$scratch/"*) printf 'runtime scratch overlaps protected path: %s\n' "$$candidate"; exit 1;; esac; done
	mkdir -p "$(RUNTIME_TEST)"
	rm -f "$(RUNTIME_TEST)/index.html" "$(RUNTIME_TEST)/runtime.js" "$(RUNTIME_TEST)/styles.css" "$(RUNTIME_TEST)/scene.generated.js"
	cp "$(TEMPLATES)/index.html" "$(TEMPLATES)/runtime.js" "$(TEMPLATES)/styles.css" generator/test/fixtures/runtime/scene.generated.js "$(RUNTIME_TEST)"
	normal_dom="$$("$(CHROMIUM)" $(BROWSER_FLAGS) --dump-dom "$(RUNTIME_TEST_URL)")" && printf '%s' "$$normal_dom" | grep -Fq 'class="scene-link scene-game-link"' && printf '%s' "$$normal_dom" | grep -Fq 'aria-label="Play example game in Algo Arcade"' && printf '%s' "$$normal_dom" | grep -Fq 'aria-label="Play %FF in Algo Arcade"' && printf '%s' "$$normal_dom" | grep -Fq 'target="_blank" rel="noopener noreferrer"' && printf '%s' "$$normal_dom" | grep -Fq 'class="scene-game-icon"' && printf '%s' "$$normal_dom" | grep -Fq 'aria-label="Play YouTube video"' && printf '%s' "$$normal_dom" | grep -Fq 'stroke-miterlimit="4"' && printf '%s' "$$normal_dom" | grep -Fq 'stroke-dasharray="6 3"' && printf '%s' "$$normal_dom" | grep -Fq 'stroke-dashoffset="1"' && printf '%s' "$$normal_dom" | grep -Fq 'transform="matrix(0, 20, 30, 0, 50, 90)"' && printf '%s' "$$normal_dom" | grep -Fq 'class="scene-image"' && printf '%s' "$$normal_dom" | grep -Fq 'transform="matrix(40, 10, 5, -20, 10, 45)"'
	evaluation_dom="$$("$(CHROMIUM)" $(BROWSER_FLAGS) --dump-dom "$(RUNTIME_TEST_URL)?evaluation=18")" && printf '%s' "$$evaluation_dom" | grep -Fq 'aria-label="Play example game in Algo Arcade"' && ! printf '%s' "$$evaluation_dom" | grep -Fq 'scene-game-icon'

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

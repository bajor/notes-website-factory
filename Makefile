.PHONY: install inspect test build serve validate-dist

install:
	npm --prefix generator ci
	npm --prefix viewer ci

inspect:
	npm --prefix generator run inspect

test:
	npm --prefix generator run typecheck
	npm --prefix generator test
	npm --prefix viewer run typecheck
	npm --prefix viewer test
	npm --prefix viewer run build

build:
	npm --prefix generator run generate
	npm --prefix viewer run build -- --base ./
	cp -R viewer/dist/. dist/
	$(MAKE) validate-dist

validate-dist:
	test -f dist/index.html
	test -f dist/manifest.json
	test -f dist/board.dzi
	test -d dist/board_files
	! grep -R 'src="/' dist/index.html
	! grep -R 'href="/' dist/index.html
	! grep -R 'notes.pdf' dist
	! grep -R 'cdnjs.cloudflare.com' dist

serve: build
	python3 -m http.server 8000 --directory dist

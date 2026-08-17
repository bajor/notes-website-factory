# Freeform PDF Notes Site

This repository turns one Apple Freeform PDF export into a high-fidelity, zoomable static website published by GitHub Pages.

Normal workflow:

1. Export the Apple Freeform board as PDF.
2. Ensure the export consists of exactly one PDF page.
3. Replace `./notes.pdf`.
4. Commit and open a PR.
5. CI validates and builds the site.
6. Merge to `main`.
7. GitHub Pages updates automatically.

Local commands:

```bash
make inspect
make test
make build
make serve
```

The browser never parses or downloads `notes.pdf`. The Rust generator uses Poppler CLI tools to inspect and render the PDF, generates a Deep Zoom tile pyramid, writes `manifest.json`, and copies a small OpenSeadragon viewer into `dist/`.

## Requirements

Install these tools locally:

```bash
sudo apt-get install -y poppler-utils qpdf
```

Required commands are `pdfinfo`, `pdftoppm`, `qpdf`, `cargo`, `node`, and `npm`.

## Output

`make build` creates:

```text
dist/
├── index.html
├── assets/
├── manifest.json
├── board.dzi
└── board_files/
```

## Hard Invariant

`notes.pdf` must exist and must contain exactly one page. Missing, invalid, empty, or multi-page PDFs fail inspection, tests, CI, and builds.

## GitHub Pages Deployment

Deploy this repository as an independent GitHub Pages project site, not as the root `bajor.github.io` user site.

Expected default URL shape:

```text
https://bajor.github.io/algos-for-slow-learners/
```

This does not replace or modify another repository such as `bajor/bajor-dev-blog`. GitHub Pages treats each repository project site as a separate deployment under `https://<user>.github.io/<repository>/`.

Repository settings required on GitHub:

1. Open this repository on GitHub.
2. Go to `Settings` -> `Pages`.
3. Set `Source` to `GitHub Actions`.
4. Merge changes to `main`.
5. The workflow in `.github/workflows/pages.yml` builds `dist/` and deploys it.

The repository can stay private while the implementation is developed. Before publishing the GitHub Pages site publicly, do the following on GitHub:

1. Decide whether the generated notes should be public, because GitHub Pages serves the deployed `dist/` files publicly for public project sites.
2. If public publishing is acceptable, change the repository visibility to public or confirm that the GitHub account plan supports Pages for private repositories.
3. Open `Settings` -> `Pages`.
4. Set `Source` to `GitHub Actions`.
5. Merge a PR to `main` and wait for the `Deploy Pages` workflow to complete.
6. Open `https://bajor.github.io/algos-for-slow-learners/`.

The generated site is project-path-safe. `make build` uses `vite build --base ./`, and runtime files are referenced relatively, for example `manifest.json`, `board.dzi`, and `board_files/...`. The generated website does not require `notes.pdf`, a backend, Poppler, QPDF, Rust, Node, or npm at runtime.

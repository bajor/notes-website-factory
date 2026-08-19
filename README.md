# Freeform Notes Site

This repository publishes one Apple Freeform board as a faithful, zoomable static website. The PDF rendering is the visible board; the generator does not approximate drawings, handwriting, text, images, or shapes with HTML.

## Workflow

1. Export the Apple Freeform board as a single-page PDF.
2. Keep exactly one PDF in the repository. Its filename and directory are arbitrary.
3. Commit the replacement PDF and open a pull request.
4. CI validates the PDF and builds the complete static site.
5. Merge the pull request to `main`.
6. GitHub Actions publishes the updated site to GitHub Pages.

The build fails when it finds zero PDFs, more than one PDF, an invalid PDF, or a PDF whose page count is not exactly one. Generated and dependency directories `.git`, `dist`, and `node_modules` are not source inputs.

## YouTube Links

YouTube videos are created only from real URI link annotations in the PDF. The generator does not use optical character recognition, computer vision, an external API, or image-based URL guessing. A YouTube screenshot without a PDF link annotation remains part of the rendered board but is not interactive.

HTTP and HTTPS link annotations become clickable regions. A YouTube annotation opens an embedded `youtube-nocookie.com` player in its original board region; another web annotation opens in a new tab.

## Local Development

Prerequisites:

- Node.js 22 or newer
- Poppler command-line tools: `pdfinfo` and `pdftoppm`
- QPDF command-line tool: `qpdf`

Install the native tools on Ubuntu:

```bash
sudo apt-get install -y poppler-utils qpdf
```

Install dependencies and run the project:

```bash
make install
make inspect
make test
make build
make serve
```

`make serve` publishes the generated site at `http://localhost:8000` until the command is stopped.

## Generated Site

`make build` creates:

```text
dist/
├── index.html
├── assets/
├── manifest.json
├── board-render.json
├── board.dzi
└── board_files/
```

The TypeScript generator delegates PDF inspection and rasterization to Poppler and QPDF, then uses Sharp/libvips to create a standard Deep Zoom image pyramid. The browser downloads only the generated static site. It does not download or parse the source PDF, and no server-side runtime is required.

## GitHub Pages

Configure `Settings` -> `Pages` -> `Source` as `GitHub Actions`. A push to `main` runs `.github/workflows/pages.yml` and deploys `dist/` as a project site:

```text
https://bajor.github.io/algos-for-slow-learners/
```

The generated paths are relative, so deployment under the repository project path does not interfere with another site at `https://bajor.github.io/`.

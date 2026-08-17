use notes_site::domain::PdfSize;
use notes_site::pdf_adapter::render_pdf_to_png;
use notes_site::render::{generate_dzi_tiles, RenderConfig};
use std::path::Path;
use tempfile::tempdir;

#[test]
fn renders_fixture_into_dzi_tiles() {
    let temp = tempdir().unwrap();
    let png = temp.path().join("board.png");
    render_pdf_to_png(Path::new("tests/fixtures/one-page-links.pdf"), &png, 72).unwrap();
    let stats = generate_dzi_tiles(
        &png,
        temp.path(),
        PdfSize {
            width: 420.0,
            height: 320.0,
        },
        RenderConfig {
            max_render_dpi: 72,
            tile_size: 128,
        },
    )
    .unwrap();
    assert!(stats.tiles > 0);
    assert!(temp.path().join("board.dzi").exists());
}

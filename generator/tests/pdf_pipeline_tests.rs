use assert_cmd::Command;
use notes_site::domain::LinkKind;
use notes_site::pdf_adapter::{board_links, inspect_pdf};
use predicates::str::contains;
use std::path::Path;

#[test]
fn extracts_links_from_one_page_fixture() {
    let doc = inspect_pdf(Path::new("tests/fixtures/one-page-links.pdf")).unwrap();
    let links = board_links(&doc).unwrap();
    assert_eq!(links.len(), 2);
    assert!(links.iter().any(
        |link| matches!(link.kind, LinkKind::YouTube { ref video_id } if video_id == "dQw4w9WgXcQ")
    ));
}

#[test]
fn rejects_multi_page_fixture() {
    let mut command = Command::cargo_bin("notes-site").unwrap();
    command.arg("inspect").arg("tests/fixtures/two-pages.pdf");
    command
        .assert()
        .failure()
        .stderr(contains("expected exactly one page"));
}

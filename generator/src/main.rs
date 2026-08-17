use notes_site::domain::{LinkKind, NotesError};
use notes_site::manifest::build_manifest;
use notes_site::pdf_adapter::{board_links, inspect_pdf, render_pdf_to_png};
use notes_site::render::{generate_dzi_tiles, RenderConfig};
use std::env;
use std::fs;
use std::path::Path;

fn main() {
    if let Err(err) = run_cli() {
        eprintln!("ERROR: {err}");
        std::process::exit(1);
    }
}

fn run_cli() -> Result<(), NotesError> {
    let args: Vec<String> = env::args().collect();
    match args.get(1).map(String::as_str) {
        Some("inspect") => inspect_command(args.get(2).map(String::as_str).unwrap_or("notes.pdf")),
        Some("build") => build_command(
            args.get(2).map(String::as_str).unwrap_or("notes.pdf"),
            args.get(3).map(String::as_str).unwrap_or("dist"),
        ),
        _ => {
            eprintln!("Usage: notes-site inspect <pdf> | notes-site build <pdf> <dist>");
            Err(NotesError::InvalidPdf("missing command".to_string()))
        }
    }
}

fn inspect_command(pdf: &str) -> Result<(), NotesError> {
    let doc = inspect_pdf(Path::new(pdf))?;
    let links = board_links(&doc)?;
    let youtube = links
        .iter()
        .filter(|l| matches!(l.kind, LinkKind::YouTube { .. }))
        .count();
    let external = links.len() - youtube;
    let board = doc.geometry.board_size();
    println!("File: {}", doc.path.display());
    println!("Pages: {}", doc.page_count);
    println!();
    println!("Page:");
    println!(
        "  MediaBox: {} {} {} {}",
        doc.geometry.media_box.x1,
        doc.geometry.media_box.y1,
        doc.geometry.media_box.x2,
        doc.geometry.media_box.y2
    );
    println!(
        "  CropBox: {} {} {} {}",
        doc.geometry.crop_box.x1,
        doc.geometry.crop_box.y1,
        doc.geometry.crop_box.x2,
        doc.geometry.crop_box.y2
    );
    println!("  Rotation: {:?}", doc.geometry.rotation);
    println!(
        "  Effective size: {:.0} x {:.0} pt",
        board.width, board.height
    );
    println!();
    println!("URI annotations: {}", links.len());
    println!("YouTube annotations: {youtube}");
    println!("External links: {external}");
    println!();
    println!("Links:");
    for link in links {
        match link.kind {
            LinkKind::YouTube { video_id } => println!(
                "  [youtube] rect=({:.1},{:.1},{:.1},{:.1}) videoId={video_id}",
                link.x, link.y, link.width, link.height
            ),
            LinkKind::ExternalUrl { url } => println!(
                "  [url] rect=({:.1},{:.1},{:.1},{:.1}) url={url}",
                link.x, link.y, link.width, link.height
            ),
        }
    }
    Ok(())
}

fn build_command(pdf: &str, dist: &str) -> Result<(), NotesError> {
    let dist_path = Path::new(dist);
    if dist_path.exists() {
        fs::remove_dir_all(dist_path)
            .map_err(|e| NotesError::TileGenerationFailure(e.to_string()))?;
    }
    fs::create_dir_all(dist_path).map_err(|e| NotesError::TileGenerationFailure(e.to_string()))?;
    let doc = inspect_pdf(Path::new(pdf))?;
    let links = board_links(&doc)?;
    let board = doc.geometry.board_size();
    let manifest = build_manifest(board, links.clone(), doc.build_id.clone())?;
    fs::write(
        dist_path.join("manifest.json"),
        serde_json::to_string_pretty(&manifest).unwrap(),
    )
    .map_err(|e| NotesError::ManifestValidationFailure(e.to_string()))?;
    let config = RenderConfig::default();
    let render_png = dist_path.join("board.png");
    render_pdf_to_png(Path::new(pdf), &render_png, config.max_render_dpi)?;
    let stats = generate_dzi_tiles(&render_png, dist_path, board, config)?;
    fs::remove_file(&render_png).ok();
    let pdf_size = fs::metadata(pdf).map(|m| m.len()).unwrap_or(0);
    let output_size = dir_size(dist_path);
    let youtube = links
        .iter()
        .filter(|l| matches!(l.kind, LinkKind::YouTube { .. }))
        .count();
    println!(
        "Input PDF:              {:.1} MiB",
        pdf_size as f64 / 1024.0 / 1024.0
    );
    println!("Pages:                  {}", doc.page_count);
    println!(
        "Board size:             {:.0} x {:.0} pt",
        board.width, board.height
    );
    println!("URI annotations:        {}", links.len());
    println!("YouTube annotations:    {youtube}");
    println!("Tile levels:            {}", stats.levels);
    println!("Generated tiles:        {}", stats.tiles);
    println!(
        "Output size:            {:.1} MiB",
        output_size as f64 / 1024.0 / 1024.0
    );
    Ok(())
}

fn dir_size(path: &Path) -> u64 {
    let Ok(entries) = fs::read_dir(path) else {
        return 0;
    };
    entries
        .flatten()
        .map(|e| {
            let path = e.path();
            if path.is_dir() {
                dir_size(&path)
            } else {
                e.metadata().map(|m| m.len()).unwrap_or(0)
            }
        })
        .sum()
}

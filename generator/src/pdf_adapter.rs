use crate::domain::{
    BoardLink, NotesError, PageGeometry, PageRotation, PdfBox, RawLinkAnnotation, Rect,
};
use crate::geometry::pdf_to_board_coordinates;
use crate::links::classify_url;
use regex::Regex;
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Debug, Clone)]
pub struct PdfDocument {
    pub path: PathBuf,
    pub page_count: usize,
    pub geometry: PageGeometry,
    pub raw_links: Vec<RawLinkAnnotation>,
    pub build_id: String,
}

pub fn inspect_pdf(path: &Path) -> Result<PdfDocument, NotesError> {
    if !path.exists() {
        return Err(NotesError::MissingNotesPdf(path.display().to_string()));
    }
    require_command("pdfinfo")?;
    require_command("qpdf")?;
    let info = run(Command::new("pdfinfo").arg("-box").arg(path))?;
    let page_count = parse_page_count(&info)?;
    if page_count != 1 {
        return Err(NotesError::UnexpectedPageCount { found: page_count });
    }
    let geometry = parse_geometry(&info)?;
    let raw_links = extract_links(path)?;
    let build_id = sha256(path)?;
    Ok(PdfDocument {
        path: path.to_path_buf(),
        page_count,
        geometry,
        raw_links,
        build_id,
    })
}

pub fn board_links(doc: &PdfDocument) -> Result<Vec<BoardLink>, NotesError> {
    doc.raw_links
        .iter()
        .map(|raw| {
            let rect = pdf_to_board_coordinates(raw.rect, doc.geometry)
                .ok_or(NotesError::InvalidAnnotationRectangle)?;
            let kind =
                classify_url(&raw.uri).ok_or_else(|| NotesError::UnsafeUrl(raw.uri.clone()))?;
            Ok(BoardLink {
                x: round(rect.x),
                y: round(rect.y),
                width: round(rect.width),
                height: round(rect.height),
                kind,
            })
        })
        .collect()
}

pub fn render_pdf_to_png(path: &Path, output_png: &Path, dpi: u32) -> Result<(), NotesError> {
    require_command("pdftoppm")?;
    let stem = output_png.with_extension("");
    run(Command::new("pdftoppm")
        .arg("-singlefile")
        .arg("-png")
        .arg("-r")
        .arg(dpi.to_string())
        .arg(path)
        .arg(&stem))?;
    Ok(())
}

fn extract_links(path: &Path) -> Result<Vec<RawLinkAnnotation>, NotesError> {
    let json = run(Command::new("qpdf").arg("--json").arg(path))?;
    let root: Value =
        serde_json::from_str(&json).map_err(|e| NotesError::InvalidPdf(e.to_string()))?;
    let objects = qpdf_objects(&root)?;
    let page_object = root["pages"]
        .as_array()
        .and_then(|pages| pages.first())
        .and_then(|page| page["object"].as_str())
        .ok_or_else(|| NotesError::InvalidPdf("missing qpdf page object".to_string()))?;
    let page = objects
        .get(page_object)
        .ok_or_else(|| NotesError::InvalidPdf("missing qpdf page dictionary".to_string()))?;
    let annot_refs = page["/Annots"].as_array().cloned().unwrap_or_default();
    let mut links = Vec::new();
    for annot_ref in annot_refs {
        let Some(name) = annot_ref.as_str() else {
            continue;
        };
        let Some(annot) = objects.get(name) else {
            continue;
        };
        if annot["/Subtype"].as_str() != Some("/Link") || annot["/A"]["/S"].as_str() != Some("/URI")
        {
            continue;
        }
        let Some(uri) = annot["/A"]["/URI"].as_str() else {
            continue;
        };
        let Some(rect) = annot["/Rect"].as_array() else {
            continue;
        };
        if rect.len() != 4 {
            return Err(NotesError::InvalidAnnotationRectangle);
        }
        let x1 = json_f64(&rect[0])?;
        let y1 = json_f64(&rect[1])?;
        let x2 = json_f64(&rect[2])?;
        let y2 = json_f64(&rect[3])?;
        links.push(RawLinkAnnotation {
            rect: Rect {
                x: x1,
                y: y1,
                width: x2 - x1,
                height: y2 - y1,
            },
            uri: uri.strip_prefix("u:").unwrap_or(uri).to_string(),
        });
    }
    links.sort_by(|a, b| {
        a.uri
            .cmp(&b.uri)
            .then(a.rect.y.total_cmp(&b.rect.y))
            .then(a.rect.x.total_cmp(&b.rect.x))
    });
    Ok(links)
}

fn qpdf_objects(root: &Value) -> Result<BTreeMap<String, Value>, NotesError> {
    let object_map = root["qpdf"]
        .as_array()
        .and_then(|sections| sections.get(1))
        .and_then(|section| section.as_object())
        .ok_or_else(|| NotesError::InvalidPdf("missing qpdf object table".to_string()))?;
    let mut objects = BTreeMap::new();
    for (key, object) in object_map {
        if let Some(name) = key.strip_prefix("obj:") {
            objects.insert(name.to_string(), object["value"].clone());
        }
    }
    Ok(objects)
}

fn parse_page_count(info: &str) -> Result<usize, NotesError> {
    let re = Regex::new(r"(?m)^Pages:\s+(\d+)\s*$").unwrap();
    let pages = re
        .captures(info)
        .and_then(|c| c.get(1))
        .ok_or_else(|| NotesError::InvalidPdf("missing page count".to_string()))?;
    pages
        .as_str()
        .parse()
        .map_err(|_| NotesError::InvalidPdf("invalid page count".to_string()))
}

fn parse_geometry(info: &str) -> Result<PageGeometry, NotesError> {
    let media_box = parse_box(info, "MediaBox")?;
    let crop_box = parse_box(info, "CropBox").unwrap_or(media_box);
    let rotation = parse_rotation(info)?;
    if crop_box.width() <= 0.0 || crop_box.height() <= 0.0 {
        return Err(NotesError::InvalidPageGeometry);
    }
    Ok(PageGeometry {
        media_box,
        crop_box,
        rotation,
    })
}

fn parse_box(info: &str, name: &str) -> Result<PdfBox, NotesError> {
    let re = Regex::new(&format!(
        r"(?m)^\s*(?:Page\s+1\s+)?{}:\s+([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)\s+([-0-9.]+)",
        regex::escape(name)
    ))
    .unwrap();
    let captures = re
        .captures(info)
        .ok_or_else(|| NotesError::InvalidPdf(format!("missing {name}")))?;
    let number = |i| {
        captures
            .get(i)
            .unwrap()
            .as_str()
            .parse::<f64>()
            .map_err(|_| NotesError::InvalidPageGeometry)
    };
    Ok(PdfBox {
        x1: number(1)?,
        y1: number(2)?,
        x2: number(3)?,
        y2: number(4)?,
    })
}

fn parse_rotation(info: &str) -> Result<PageRotation, NotesError> {
    let re = Regex::new(r"(?m)^Page rot:\s+(\d+)\s*$").unwrap();
    let rotation = re
        .captures(info)
        .and_then(|c| c.get(1))
        .map(|m| m.as_str())
        .unwrap_or("0");
    match rotation {
        "0" => Ok(PageRotation::Deg0),
        "90" => Ok(PageRotation::Deg90),
        "180" => Ok(PageRotation::Deg180),
        "270" => Ok(PageRotation::Deg270),
        _ => Err(NotesError::InvalidPageGeometry),
    }
}

fn json_f64(value: &Value) -> Result<f64, NotesError> {
    value.as_f64().ok_or(NotesError::InvalidAnnotationRectangle)
}

fn run(command: &mut Command) -> Result<String, NotesError> {
    let output = command
        .output()
        .map_err(|e| NotesError::PdfRendererFailure(e.to_string()))?;
    if !output.status.success() {
        return Err(NotesError::PdfRendererFailure(
            String::from_utf8_lossy(&output.stderr).to_string(),
        ));
    }
    Ok(String::from_utf8_lossy(&output.stdout).to_string())
}

fn require_command(name: &str) -> Result<(), NotesError> {
    let ok = Command::new("sh")
        .arg("-c")
        .arg(format!("command -v {name}"))
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false);
    if ok {
        Ok(())
    } else {
        Err(NotesError::PdfRendererFailure(format!(
            "required command `{name}` is not installed"
        )))
    }
}

fn sha256(path: &Path) -> Result<String, NotesError> {
    let bytes = fs::read(path).map_err(|e| NotesError::InvalidPdf(e.to_string()))?;
    let digest = Sha256::digest(bytes);
    Ok(format!("{digest:x}"))
}

fn round(value: f64) -> f64 {
    (value * 1000.0).round() / 1000.0
}

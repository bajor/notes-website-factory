use serde::Serialize;
use thiserror::Error;

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct PdfSize {
    pub width: f64,
    pub height: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Serialize)]
pub struct Rect {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

impl Rect {
    pub fn right(self) -> f64 {
        self.x + self.width
    }
    pub fn bottom(self) -> f64 {
        self.y + self.height
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PdfBox {
    pub x1: f64,
    pub y1: f64,
    pub x2: f64,
    pub y2: f64,
}

impl PdfBox {
    pub fn width(self) -> f64 {
        self.x2 - self.x1
    }
    pub fn height(self) -> f64 {
        self.y2 - self.y1
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum PageRotation {
    Deg0,
    Deg90,
    Deg180,
    Deg270,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub struct PageGeometry {
    pub media_box: PdfBox,
    pub crop_box: PdfBox,
    pub rotation: PageRotation,
}

impl PageGeometry {
    pub fn board_size(self) -> PdfSize {
        match self.rotation {
            PageRotation::Deg0 | PageRotation::Deg180 => PdfSize {
                width: self.crop_box.width(),
                height: self.crop_box.height(),
            },
            PageRotation::Deg90 | PageRotation::Deg270 => PdfSize {
                width: self.crop_box.height(),
                height: self.crop_box.width(),
            },
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct RawLinkAnnotation {
    pub rect: Rect,
    pub uri: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(tag = "kind", rename_all = "camelCase")]
pub enum LinkKind {
    #[serde(rename = "youtube")]
    #[serde(rename_all = "camelCase")]
    YouTube { video_id: String },
    #[serde(rename = "externalUrl")]
    #[serde(rename_all = "camelCase")]
    ExternalUrl { url: String },
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct BoardLink {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
    #[serde(flatten)]
    pub kind: LinkKind,
}

#[derive(Debug, Error)]
pub enum NotesError {
    #[error("notes.pdf is missing: {0}")]
    MissingNotesPdf(String),
    #[error("invalid PDF: {0}")]
    InvalidPdf(String),
    #[error("expected exactly one page, found {found}")]
    UnexpectedPageCount { found: usize },
    #[error("invalid page geometry")]
    InvalidPageGeometry,
    #[error("invalid annotation rectangle")]
    InvalidAnnotationRectangle,
    #[error("PDF engine command failed: {0}")]
    PdfRendererFailure(String),
    #[error("unsafe or unsupported URL: {0}")]
    UnsafeUrl(String),
    #[error("tile generation failed: {0}")]
    TileGenerationFailure(String),
    #[error("manifest validation failed: {0}")]
    ManifestValidationFailure(String),
}

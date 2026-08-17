use crate::domain::{BoardLink, LinkKind, NotesError, PdfSize};
use serde::Serialize;

#[derive(Debug, Clone, Serialize)]
pub struct BoardManifest {
    pub width: f64,
    pub height: f64,
}

#[derive(Debug, Clone, Serialize)]
pub struct SiteManifest {
    pub version: u8,
    #[serde(rename = "buildId")]
    pub build_id: String,
    pub board: BoardManifest,
    pub links: Vec<BoardLink>,
}

pub fn build_manifest(
    board: PdfSize,
    mut links: Vec<BoardLink>,
    build_id: String,
) -> Result<SiteManifest, NotesError> {
    links.sort_by(|a, b| {
        a.y.total_cmp(&b.y)
            .then(a.x.total_cmp(&b.x))
            .then(a.width.total_cmp(&b.width))
            .then(a.height.total_cmp(&b.height))
            .then(link_key(&a.kind).cmp(&link_key(&b.kind)))
    });
    let manifest = SiteManifest {
        version: 1,
        build_id,
        board: BoardManifest {
            width: board.width,
            height: board.height,
        },
        links,
    };
    validate_manifest(&manifest)?;
    Ok(manifest)
}

pub fn validate_manifest(manifest: &SiteManifest) -> Result<(), NotesError> {
    if manifest.board.width <= 0.0 || manifest.board.height <= 0.0 {
        return Err(NotesError::ManifestValidationFailure(
            "board dimensions must be positive".to_string(),
        ));
    }
    for link in &manifest.links {
        if link.width <= 0.0 || link.height <= 0.0 {
            return Err(NotesError::ManifestValidationFailure(
                "link rectangles must be positive".to_string(),
            ));
        }
        if link.x < 0.0
            || link.y < 0.0
            || link.x + link.width > manifest.board.width + 0.5
            || link.y + link.height > manifest.board.height + 0.5
        {
            return Err(NotesError::ManifestValidationFailure(
                "link rectangle is outside board bounds".to_string(),
            ));
        }
    }
    Ok(())
}

fn link_key(kind: &LinkKind) -> String {
    match kind {
        LinkKind::YouTube { video_id } => format!("youtube:{video_id}"),
        LinkKind::ExternalUrl { url } => format!("url:{url}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn serializes_manifest_stably() {
        let links = vec![
            BoardLink {
                x: 20.0,
                y: 20.0,
                width: 5.0,
                height: 5.0,
                kind: LinkKind::ExternalUrl {
                    url: "https://b.example/".to_string(),
                },
            },
            BoardLink {
                x: 10.0,
                y: 10.0,
                width: 5.0,
                height: 5.0,
                kind: LinkKind::ExternalUrl {
                    url: "https://a.example/".to_string(),
                },
            },
        ];
        let manifest = build_manifest(
            PdfSize {
                width: 100.0,
                height: 100.0,
            },
            links,
            "abc".to_string(),
        )
        .unwrap();
        let json = serde_json::to_string_pretty(&manifest).unwrap();
        assert!(json.find("a.example").unwrap() < json.find("b.example").unwrap());
    }
}

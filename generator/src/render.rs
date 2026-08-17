use crate::domain::{NotesError, PdfSize};
use image::{GenericImageView, ImageFormat};
use std::fs;
use std::path::Path;

#[derive(Debug, Clone, Copy)]
pub struct RenderConfig {
    pub max_render_dpi: u32,
    pub tile_size: u32,
}

impl Default for RenderConfig {
    fn default() -> Self {
        Self {
            max_render_dpi: 180,
            tile_size: 256,
        }
    }
}

#[derive(Debug, Clone)]
pub struct TileStats {
    pub levels: usize,
    pub tiles: usize,
}

pub fn build_render_plan(width: u32, height: u32, tile_size: u32) -> Vec<(u32, u32)> {
    let mut levels = vec![(width.max(1), height.max(1))];
    while levels.last().unwrap().0 > tile_size || levels.last().unwrap().1 > tile_size {
        let (w, h) = *levels.last().unwrap();
        levels.push(((w + 1) / 2, (h + 1) / 2));
    }
    levels.reverse();
    levels
}

pub fn generate_dzi_tiles(
    source_png: &Path,
    out_dir: &Path,
    board: PdfSize,
    config: RenderConfig,
) -> Result<TileStats, NotesError> {
    let img =
        image::open(source_png).map_err(|e| NotesError::TileGenerationFailure(e.to_string()))?;
    let (full_w, full_h) = img.dimensions();
    let levels = build_render_plan(full_w, full_h, config.tile_size);
    let files_dir = out_dir.join("board_files");
    fs::create_dir_all(&files_dir).map_err(|e| NotesError::TileGenerationFailure(e.to_string()))?;
    let mut tile_count = 0;

    for (level_index, (level_w, level_h)) in levels.iter().enumerate() {
        let level_dir = files_dir.join(level_index.to_string());
        fs::create_dir_all(&level_dir)
            .map_err(|e| NotesError::TileGenerationFailure(e.to_string()))?;
        let level_img = if *level_w == full_w && *level_h == full_h {
            img.clone()
        } else {
            img.resize_exact(*level_w, *level_h, image::imageops::FilterType::Lanczos3)
        };
        let cols = level_w.div_ceil(config.tile_size);
        let rows = level_h.div_ceil(config.tile_size);
        for col in 0..cols {
            for row in 0..rows {
                let x = col * config.tile_size;
                let y = row * config.tile_size;
                let w = config.tile_size.min(level_w - x);
                let h = config.tile_size.min(level_h - y);
                let tile = level_img.crop_imm(x, y, w, h);
                tile.save_with_format(level_dir.join(format!("{col}_{row}.png")), ImageFormat::Png)
                    .map_err(|e| NotesError::TileGenerationFailure(e.to_string()))?;
                tile_count += 1;
            }
        }
    }

    let dzi = format!(
        r#"<?xml version="1.0" encoding="UTF-8"?>
<Image TileSize="{}" Overlap="0" Format="png" xmlns="http://schemas.microsoft.com/deepzoom/2008">
  <Size Width="{}" Height="{}" />
</Image>
"#,
        config.tile_size, full_w, full_h
    );
    fs::write(out_dir.join("board.dzi"), dzi)
        .map_err(|e| NotesError::TileGenerationFailure(e.to_string()))?;
    let board_info = serde_json::json!({ "pdfWidth": board.width, "pdfHeight": board.height, "renderedWidth": full_w, "renderedHeight": full_h });
    fs::write(
        out_dir.join("board-render.json"),
        serde_json::to_string_pretty(&board_info).unwrap(),
    )
    .map_err(|e| NotesError::TileGenerationFailure(e.to_string()))?;
    Ok(TileStats {
        levels: levels.len(),
        tiles: tile_count,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn render_plan_has_edge_tiles() {
        let levels = build_render_plan(1000, 600, 256);
        assert_eq!(*levels.last().unwrap(), (1000, 600));
        assert!(levels.first().unwrap().0 <= 256);
    }
}

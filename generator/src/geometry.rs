use crate::domain::{PageGeometry, PageRotation, Rect};

pub fn normalize_rect(rect: Rect) -> Option<Rect> {
    if !rect.x.is_finite()
        || !rect.y.is_finite()
        || !rect.width.is_finite()
        || !rect.height.is_finite()
    {
        return None;
    }
    let (x, width) = if rect.width < 0.0 {
        (rect.x + rect.width, -rect.width)
    } else {
        (rect.x, rect.width)
    };
    let (y, height) = if rect.height < 0.0 {
        (rect.y + rect.height, -rect.height)
    } else {
        (rect.y, rect.height)
    };
    Some(Rect {
        x,
        y,
        width,
        height,
    })
}

pub fn pdf_to_board_coordinates(rect: Rect, page: PageGeometry) -> Option<Rect> {
    let rect = normalize_rect(rect)?;
    let crop = page.crop_box;
    let x1 = rect.x - crop.x1;
    let x2 = rect.right() - crop.x1;
    let y1 = rect.y - crop.y1;
    let y2 = rect.bottom() - crop.y1;
    let w = crop.width();
    let h = crop.height();

    let points = match page.rotation {
        PageRotation::Deg0 => [(x1, h - y2), (x2, h - y1)],
        PageRotation::Deg90 => [(y1, x1), (y2, x2)],
        PageRotation::Deg180 => [(w - x2, y1), (w - x1, y2)],
        PageRotation::Deg270 => [(h - y2, w - x2), (h - y1, w - x1)],
    };

    let min_x = points[0].0.min(points[1].0);
    let max_x = points[0].0.max(points[1].0);
    let min_y = points[0].1.min(points[1].1);
    let max_y = points[0].1.max(points[1].1);
    normalize_rect(Rect {
        x: min_x,
        y: min_y,
        width: max_x - min_x,
        height: max_y - min_y,
    })
}

pub fn board_to_pdf_coordinates(rect: Rect, page: PageGeometry) -> Option<Rect> {
    let rect = normalize_rect(rect)?;
    let crop = page.crop_box;
    let w = crop.width();
    let h = crop.height();
    let x1 = rect.x;
    let x2 = rect.right();
    let y1 = rect.y;
    let y2 = rect.bottom();

    let converted = match page.rotation {
        PageRotation::Deg0 => Rect {
            x: x1 + crop.x1,
            y: h - y2 + crop.y1,
            width: x2 - x1,
            height: y2 - y1,
        },
        PageRotation::Deg90 => Rect {
            x: y1 + crop.x1,
            y: x1 + crop.y1,
            width: y2 - y1,
            height: x2 - x1,
        },
        PageRotation::Deg180 => Rect {
            x: w - x2 + crop.x1,
            y: y1 + crop.y1,
            width: x2 - x1,
            height: y2 - y1,
        },
        PageRotation::Deg270 => Rect {
            x: w - y2 + crop.x1,
            y: h - x2 + crop.y1,
            width: y2 - y1,
            height: x2 - x1,
        },
    };
    normalize_rect(converted)
}

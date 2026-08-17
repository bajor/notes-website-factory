use notes_site::domain::{PageGeometry, PageRotation, PdfBox, Rect};
use notes_site::geometry::{board_to_pdf_coordinates, normalize_rect, pdf_to_board_coordinates};
use proptest::prelude::*;

fn page() -> PageGeometry {
    PageGeometry {
        media_box: PdfBox {
            x1: 0.0,
            y1: 0.0,
            x2: 100.0,
            y2: 100.0,
        },
        crop_box: PdfBox {
            x1: 0.0,
            y1: 0.0,
            x2: 100.0,
            y2: 100.0,
        },
        rotation: PageRotation::Deg0,
    }
}

#[test]
fn maps_pdf_bottom_left_to_board_top_left() {
    let rect = pdf_to_board_coordinates(
        Rect {
            x: 0.0,
            y: 90.0,
            width: 10.0,
            height: 10.0,
        },
        page(),
    )
    .unwrap();
    assert_eq!(
        rect,
        Rect {
            x: 0.0,
            y: 0.0,
            width: 10.0,
            height: 10.0
        }
    );
}

#[test]
fn normalizes_negative_dimensions() {
    assert_eq!(
        normalize_rect(Rect {
            x: 10.0,
            y: 10.0,
            width: -5.0,
            height: -4.0
        })
        .unwrap(),
        Rect {
            x: 5.0,
            y: 6.0,
            width: 5.0,
            height: 4.0
        }
    );
}

proptest! {
    #[test]
    fn round_trips_unrotated_rects(x in 0.0f64..80.0, y in 0.0f64..80.0, w in 1.0f64..20.0, h in 1.0f64..20.0) {
        let pdf = Rect { x, y, width: w.min(100.0 - x), height: h.min(100.0 - y) };
        let board = pdf_to_board_coordinates(pdf, page()).unwrap();
        let again = board_to_pdf_coordinates(board, page()).unwrap();
        prop_assert!((pdf.x - again.x).abs() < 0.0001);
        prop_assert!((pdf.y - again.y).abs() < 0.0001);
        prop_assert!((pdf.width - again.width).abs() < 0.0001);
        prop_assert!((pdf.height - again.height).abs() < 0.0001);
    }
}

use crate::domain::LinkKind;
use url::Url;

pub fn classify_url(raw: &str) -> Option<LinkKind> {
    if let Some(video_id) = parse_youtube_url(raw) {
        return Some(LinkKind::YouTube { video_id });
    }
    let url = Url::parse(raw).ok()?;
    match url.scheme() {
        "http" | "https" => Some(LinkKind::ExternalUrl {
            url: url.to_string(),
        }),
        _ => None,
    }
}

pub fn parse_youtube_url(raw: &str) -> Option<String> {
    let url = Url::parse(raw).ok()?;
    if url.scheme() != "http" && url.scheme() != "https" {
        return None;
    }
    let host = url.host_str()?.to_ascii_lowercase();
    let segments: Vec<_> = url.path_segments().map(|s| s.collect()).unwrap_or_default();

    let candidate = match host.as_str() {
        "youtube.com" | "www.youtube.com" | "m.youtube.com" => {
            if url.path() == "/watch" {
                url.query_pairs()
                    .find(|(k, _)| k == "v")
                    .map(|(_, v)| v.into_owned())
            } else if segments.len() >= 2 && (segments[0] == "shorts" || segments[0] == "embed") {
                Some(segments[1].to_string())
            } else {
                None
            }
        }
        "youtu.be" => segments.first().map(|id| id.to_string()),
        _ => None,
    }?;

    is_valid_youtube_id(&candidate).then_some(candidate)
}

fn is_valid_youtube_id(id: &str) -> bool {
    id.len() == 11
        && id
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_supported_youtube_urls() {
        let id = "dQw4w9WgXcQ";
        for url in [
            format!("https://youtube.com/watch?v={id}"),
            format!("https://www.youtube.com/watch?v={id}&t=10"),
            format!("https://m.youtube.com/watch?v={id}"),
            format!("https://youtu.be/{id}?t=10"),
            format!("https://youtube.com/shorts/{id}"),
            format!("https://www.youtube.com/embed/{id}"),
        ] {
            assert_eq!(parse_youtube_url(&url), Some(id.to_string()));
        }
    }

    #[test]
    fn rejects_deceptive_or_malformed_youtube_urls() {
        for url in [
            "https://youtube.com.evil.example/watch?v=dQw4w9WgXcQ",
            "javascript:alert(1)",
            "https://youtube.com/watch?v=short",
            "https://example.com/embed/dQw4w9WgXcQ",
        ] {
            assert_eq!(parse_youtube_url(url), None);
        }
    }
}

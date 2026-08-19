import { describe, expect, it } from "vitest";
import { parseYoutubeUrl } from "../src/links.js";

const VIDEO_ID = "dQw4w9WgXcQ";

describe("parseYoutubeUrl", () => {
  it.each([
    `https://youtube.com/watch?v=${VIDEO_ID}`,
    `https://www.youtube.com/watch?v=${VIDEO_ID}&t=10`,
    `https://m.youtube.com/watch?v=${VIDEO_ID}`,
    `https://youtu.be/${VIDEO_ID}?t=10`,
    `https://youtube.com/shorts/${VIDEO_ID}`,
    `https://www.youtube.com/embed/${VIDEO_ID}`,
  ])("extracts the ID from %s", (url) => {
    expect(parseYoutubeUrl(url)).toBe(VIDEO_ID);
  });

  it.each([
    "https://youtube.com.evil.example/watch?v=dQw4w9WgXcQ",
    "javascript:alert(1)",
    "https://youtube.com/watch?v=short",
  ])("rejects unsupported URL %s", (url) => {
    expect(parseYoutubeUrl(url)).toBeNull();
  });
});

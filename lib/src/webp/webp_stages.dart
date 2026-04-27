/// Default WebP compression budget for sticker / cover-style assets.
///
/// iMessage's hard ceiling on stickers is 500KB, but the iMessage
/// extension renders 4:3 covers and grid tiles at 32-200pt, so 40KB
/// is more than enough visually and keeps the in-extension grid
/// scrolling smooth. Both lingo_cosmos and kinjin standardised on
/// 40KB; keeping the constant here is the canonical source.
const int kStickerMaxWebpFileBytes = 40 * 1024;

/// Lossy-WebP compression ladder, identical to lingo_cosmos's
/// historical `StickerImageService._webpStages` and
/// `StickerMediaPickerService._webpStages`. Tried top-down; the
/// first stage whose output ≤ [kStickerMaxWebpFileBytes] is the
/// chosen result. If every stage overshoots, the last (most
/// aggressive) stage's output is kept.
///
/// Tiers are tuned for "sticker-style" assets (small, simple,
/// transparent-bg cut-outs):
///  - 512px @ Q90/80 — covers most direct-camera / cropped-photo
///    inputs in one shot
///  - 480/384px @ Q70/55 — busy backgrounds / detailed art
///  - 320/256px @ Q40/30 — extreme fallback for huge inputs
const List<({int maxSide, int quality})> kStickerWebpStages = [
  (maxSide: 512, quality: 90),
  (maxSide: 512, quality: 80),
  (maxSide: 480, quality: 70),
  (maxSide: 384, quality: 55),
  (maxSide: 320, quality: 40),
  (maxSide: 256, quality: 30),
];

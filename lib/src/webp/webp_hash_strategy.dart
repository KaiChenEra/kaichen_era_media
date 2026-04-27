/// Which sha256 to use as the "file key" for an output [MediaWebpResult].
///
/// The result of [normalizeBytesToWebp] always exposes both the
/// **input** sha256 (the bytes the caller handed in) and the
/// **output** sha256 (the actual WebP that will be written to disk).
/// Callers usually persist one of the two as a content-addressed file
/// key (Drift `media.sha256` column, R2 file_key, …); this enum
/// picks which.
///
/// - [WebpHashStrategy.output] (default) — the file key reflects the
///   actual on-disk bytes. Two re-compressions of the same source at
///   different quality settings yield different keys (they're
///   genuinely different files). This is the **correct** behaviour
///   for sticker storage and matches kinjin's existing
///   `addStickerFromBytes` flow.
///
/// - [WebpHashStrategy.input] — the file key reflects the **source**
///   bytes. Two passes over the same source produce the same key
///   even if a different compression ladder fired, which is useful
///   for source-level dedup (e.g. uploading the same logo across
///   sections only stores one R2 object). Beware: two callers using
///   `input` strategy on the **same** source but writing files at
///   different qualities will collide on the file key but disagree
///   on the actual bytes — only enable this when content-by-source
///   identity is what you want.
enum WebpHashStrategy { input, output }

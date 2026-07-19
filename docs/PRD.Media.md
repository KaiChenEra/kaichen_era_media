# PRD: kaichen_era_media

## Scope

This package owns image picking, optional native cropping, canonical WebP
normalization, and SHA-256 helpers. It does not persist media rows or know about
stickers, accounts, sections, or R2 APIs.

## Canonical output

`normalizeBytesToWebp` accepts decodable image bytes and always returns a real
lossless WebP file. The longest edge is capped at 512px and output at 500,000
bytes; aspect ratio and alpha are preserved. Sticker canvas trimming happens
before this package encodes the
already-finalized render.

```dart
Future<MediaWebpResult> normalizeBytesToWebp(
  Uint8List input, {
  int maxSide = kStickerWebpMaxSide,
});
```

`MediaWebpResult` has one identity:

```dart
class MediaWebpResult {
  final Uint8List bytes; // WebP
  final Sha256Pair sha256; // digest of bytes
}
```

The stored file name, Drift `media.sha256`, and R2 checksum must all derive from
this output digest. There is no source-hash mode and no alternate output format.

## Picking

- `pickSingleImageBytes` returns the selected/cropped source bytes for ML flows.
- `pickSingleImageToWebp` returns one canonical WebP or `null` on cancellation.
- `pickMultiImagesToWebp` returns successful WebP results up to `maxCount`.
- Native pickers are serialized; a concurrent request returns the method's empty
  result instead of replacing the active platform view.

## Errors

User cancellation is represented by `null` or an empty list. Decode, crop,
encode, and filesystem failures are thrown to the caller. Temporary files are
removed best-effort.

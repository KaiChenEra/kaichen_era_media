# ARCH: kaichen_era_media

## Modules

| File | Responsibility |
|---|---|
| `webp_normalizer.dart` | Longest-edge / byte-bound resize and lossless WebP encode |
| `webp_result.dart` | Canonical bytes plus their output digest |
| `sha256_helper.dart` | One digest exposed as hex and base64 |
| `image_picker_service.dart` | Serialized native picker/cropper flow |

## Normalization

Every platform decodes once, caps the longest edge at 512px, and returns a
lossless VP8L WebP no larger than 500,000 bytes. Oversized output is resized
directly to the estimated fitting dimensions; there is no lossy quality
fallback. Aspect ratio and alpha are preserved.

The SHA-256 digest is computed after encoding. This is the only content identity
because it exactly matches the file on disk and the bytes uploaded to R2.

## Data flow

```text
picker -> optional native crop -> source bytes -> lossless WebP
       -> MediaWebpResult(bytes, sha256) -> caller persistence
```

The package deliberately stops before persistence so host and sticker packages
cannot acquire a second media repository or account context through it.

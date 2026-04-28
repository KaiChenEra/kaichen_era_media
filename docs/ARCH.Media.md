# ARCH: kaichen_era_media — internal pipeline

> Public API surface see [PRD.Media](PRD.Media.md).

## 1. Module map

| Path | Role |
|---|---|
| `lib/src/webp/webp_normalizer.dart` | Top-level `normalizeBytesToWebp` — temp file → 6-stage `flutter_image_compress` ladder → `MediaWebpResult` |
| `lib/src/webp/webp_stages.dart` | `kStickerWebpStages` constant + `kStickerMaxWebpFileBytes` |
| `lib/src/webp/webp_result.dart` | `MediaWebpResult` data class + `MediaWebpResult.from(...)` resolves `fileKey` from `WebpHashStrategy` |
| `lib/src/webp/webp_hash_strategy.dart` | `WebpHashStrategy { input, output }` enum + design-decision doc |
| `lib/src/hash/sha256_helper.dart` | `Sha256Pair` (single-pass hex+base64) + `computeSha256Hex` / `computeSha256Base64` shorthands |
| `lib/src/picker/image_picker_service.dart` | `ImagePickerService` singleton — `pickSingleImageToWebp` / `pickMultiImagesToWebp` |
| `lib/src/picker/image_picker_options.dart` | `ImagePickToWebpOptions` + `MediaCropperOptions` |
| `lib/src/cache/media_cache_service.dart` | `MediaCacheService` — URL → file cache, concurrent-safe |
| `lib/src/cache/image_with_cache.dart` | `ImageWithCache` — Flutter `ImageProvider` for `AppContentMediaInterface` |

## 2. WebP ladder

### 2.1 Algorithm

```
normalizeBytesToWebp(input):
    inputSha = Sha256Pair.from(input)
    write input → temp PNG file
    for stage in kStickerWebpStages (top-down):
        FlutterImageCompress.compressAndGetFile(
            tmpIn, tmpOut,
            format: WebP,
            quality: stage.quality,
            minWidth: stage.maxSide,
            minHeight: stage.maxSide,
        )
        bytes = read tmpOut
        if bytes.length ≤ maxFileBytes:
            return MediaWebpResult(
                bytes,
                input: inputSha,
                output: Sha256Pair.fromBytes(bytes),
                strategy: hashStrategy,
                fileKey: hashStrategy == output ? output : input,
            )
    # all stages overshot — keep the most aggressive stage's output
    return MediaWebpResult(lastBytes, ...)
```

### 2.2 Why a ladder, not a binary search

A binary search over `(maxSide, quality)` would technically be tighter but:
- Each stage runs the full image decode + WebP encode (~30–80 ms for sticker-sized inputs); 6 stages cap the wall-clock at ~360 ms even worst-case.
- Empirically (during kinjin / lingo iteration), **stage 1 hits budget for ~85 % of phone photos**. The ladder short-circuits on first success, so the typical path is one decode-encode.
- Constants are visually predictable (callers can reason about the maximum side a sticker will end up at) — important for sticker-tab-bar pixel quality.

### 2.3 Why these specific tiers

Tuned during kinjin's first device run (Apr 2026). Constraints:
- iMessage hard ceiling = 500 KB; we target **40 KB** for grid-scrolling smoothness.
- Sticker assets are typically transparent-bg cut-outs (200 KB–4 MB raw PNG).
- `(512, 90)` and `(512, 80)` cover ~85 % of inputs without size reduction (just quality drop).
- `(480, 70)` and `(384, 55)` handle photographic backgrounds.
- `(320, 40)` and `(256, 30)` are extreme fallback — the cap on pixel quality starts being noticeable at this point but grid-tile rendering doesn't suffer (tiles are ≤ 256 px display-side).

### 2.4 Why temp files instead of in-memory

`flutter_image_compress` v2 supports `compressWithList` (in-memory) on iOS/Android. We chose `compressAndGetFile` because:
- The plugin's in-memory path internally writes to a temp file anyway on most platforms; in-memory at the call site doesn't save IO, just adds wrapping.
- File-based output makes the "all stages overshoot, keep last" path trivial (each iteration overwrites the same `tmpOut`).
- Stack traces from temp-file paths are easier to debug than `<Uint8List len=N>`.

The temp files are removed in a `finally` block before returning.

## 3. sha256 timing

### 3.1 The legacy bug

lingo's pre-extraction `StickerMediaPickerService._processAndSaveImage`:

```dart
// LEGACY — DON'T DO THIS
final bytes = await image.readAsBytes();
final sha = sha256.convert(bytes).toString();    // ← sha256 of SOURCE bytes
// ... later ...
await _convertAndSaveAsWebp(image, media);       // ← write WebP file (different bytes)
final media = StickerContentInstance.media(
  sha256: sha,                                   // ← stored SOURCE sha
  extension: 'webp',                             // ← but file is WebP
);
```

Result: Drift `media.sha256` did not match `sha256(<file at media path>)`. Server-side dedup checks comparing client sha against R2 object hash would silently fail; cache invalidation by content-address broke; retransmits computed a fresh sha and disagreed with the row.

### 3.2 The fix

`normalizeBytesToWebp` always computes **both** sha256s in one pass:
- `MediaWebpResult.input` — captured **before** WebP encoding from the input bytes.
- `MediaWebpResult.output` — captured **after** WebP encoding from the bytes that will be written to disk.

`fileKey` is one of the two by explicit `WebpHashStrategy`:
- `output` (default) — what every existing sticker / cover row uses; sha matches on-disk file.
- `input` — opt-in for source-level dedup scenarios.

Callers cannot accidentally mix them: there is no "compute sha and then encode" path in the API. The bug class is structurally eliminated.

### 3.3 Why expose both formats (`Sha256Pair`)

| Consumer | Format | Reason |
|---|---|---|
| Drift `StickerContentMedia.sha256` / `AppContentInstance.sha256` | hex (lowercase, 64 chars) | Historical schema, matches `crypto.sha256.convert(b).toString()` directly |
| R2 presigned-URL request body (`sha256_base64`) | base64 (raw 32-byte digest) | AWS S3 presign API + `x-amz-checksum-sha256` HTTP header convention |
| iMessage extension cache key | hex | Same store as Drift |
| Server-side echo (`/api/media/missing-batch/`) | hex (in `file_keys` field) | Server treats keys as opaque strings, but they originated as hex |

Forcing every call site to compute hex from base64 (or vice versa) was where lingo's pre-extraction code had subtle bugs. The single-pass `Sha256Pair.from(bytes)` factory does both formats from the same digest in one allocation.

## 4. Picker → ladder data flow

```
ImagePickerService.pickSingleImageToWebp(options):
    picked  = image_picker.pickImage(source: options.source)
    if cancel: return null
    workingFile = picked
    if options.cropper != null:
        cropped = image_cropper.cropImage(workingFile.path, ...)
        if cancel: return null
        delete picked tmp file
        workingFile = cropped
    bytes  = workingFile.readAsBytes()
    result = normalizeBytesToWebp(bytes, ...options forwarded)
    return result
```

**Why no DB / repo wiring** — by design. The legacy `StickerMediaPickerService` was sticker-coupled (took `StickerContentMediaRepo`, returned `StickerContentMediaImpl`, had `sectionId` parameters). Moving the picker into a generic media package required severing those ties. Sticker-domain orchestration (constructing the row, dedup, file write) is now in `kaichen_era_sticker_sdk`'s `sticker_add_flow.dart`.

## 5. Cache flow

```
MediaCacheService.setCachedFile(remotePath, localPath, uuid):
    cacheKey = "$uuid-md5(remotePath)"
    if _ongoingCacheTasks[cacheKey] exists:
        return that task's future  ← coalesce concurrent callers
    if existing file at localPath, size > 0:
        return it
    completer = Completer<File>()
    _ongoingCacheTasks[cacheKey] = completer
    download to side path → rename to localPath → complete
```

The keying by `uuid + md5(url)` rather than `url` alone lets two distinct media rows that *happen* to point at the same URL stay separate (e.g. two users uploaded identical sticker bytes; their App-Group paths differ).

`ImageWithCache.getProvider(media)` is the synchronous fast path: `FileImage` if local exists, else `NetworkImage` + fire-and-forget `setCachedFile` so subsequent renders hit the disk path.

## 6. Design decisions (in-line because no ADRs)

### 6.1 Singleton instances

Both `ImagePickerService` and `MediaCacheService` are singletons. `image_picker` + `image_cropper` carry native resources (camera permission caches, plugin channel subscriptions) that prefer being long-lived; one process-wide instance avoids re-initialization overhead and ensures only one camera session can be active at a time.

### 6.2 Image package not a transitive concern

The package depends on `flutter_image_compress` (native re-encoder) but not the `image` Dart package. We don't decode pixels in Dart — every transform is a single round trip through the platform encoder. This:
- Keeps the package lean (no Dart-side image library transitive deps).
- Avoids matching color profile / orientation / metadata between Dart-side decode and native-side encode.
- Loses the ability to do pixel-level effects (which we don't want here — sticker border / mask post-processing live in `kaichen_era_sticker_sdk` / `kaichen_era_sticker_ai`).

### 6.3 No platform-conditional asset support

The package itself is pure Dart-on-Flutter; no Android-only or iOS-only code. ONNX / VisionKit / native bridges are someone else's problem (sticker_ai). This means consumer hosts pay for nothing they don't use — the package is < 200 KB after tree-shaking.

## 7. Performance notes

| Operation | Target | Typical |
|---|---|---|
| `normalizeBytesToWebp(4MP source)` stage 1 | < 500 ms | 200–350 ms iPhone 16 Pro |
| `normalizeBytesToWebp` worst case (all 6 stages) | < 2.5 s | 1.2–1.8 s iPhone 16 Pro |
| `pickSingleImageToWebp` (no cropper) | gallery + decode + ladder | ~600 ms after user taps a photo |
| `pickSingleImageToWebp` (with cropper) | + cropper UX | ~3 s including user crop time |
| `MediaCacheService.setCachedFile` 200 KB WebP | network-bound | 50–300 ms on Wi-Fi |

All `normalizeBytesToWebp` callers should run via `compute(...)` to keep the UI isolate responsive on phone-photo-sized inputs.

## 8. Change history

| Date | Change |
|---|---|
| 2026-04-28 | Initial ARCH covering 0.1.0 release; sha256 timing fix vs legacy `_processAndSaveImage` documented |

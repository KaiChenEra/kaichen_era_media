import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../webp/webp_normalizer.dart';
import '../webp/webp_result.dart';
import 'image_picker_options.dart';

/// Generic image-picker → optional cropper → canonical WebP-ladder
/// pipeline. Returns the WebP bytes plus both source/output sha256 in
/// a [MediaWebpResult] — call sites decide what to do with the bytes
/// (write to App Group, push to a repo, mint a media row, etc).
///
/// Replaces the legacy sticker-coupled `StickerMediaPickerService`,
/// which mixed in Drift / repo / sectionId concerns. This service is
/// **pure**: no DB, no path, no host knowledge. Sticker-specific
/// orchestration moves into the SDK's `sticker_add_flow`.
///
/// Singleton because [ImagePicker] / [ImageCropper] hold native
/// resources that prefer being long-lived.
class ImagePickerService {
  ImagePickerService._internal();

  static final ImagePickerService _instance = ImagePickerService._internal();

  factory ImagePickerService() => _instance;

  final ImagePicker _picker = ImagePicker();
  final ImageCropper _cropper = ImageCropper();
  bool _operationInFlight = false;

  /// Native pickers and croppers are modal platform views. A second request
  /// while one is presented is rejected instead of cancelling the first one.
  bool get isBusy => _operationInFlight;

  Future<T> _runExclusive<T>(T busyResult, Future<T> Function() action) async {
    if (_operationInFlight) {
      debugPrint('[ImagePicker] ignored concurrent native picker request');
      return busyResult;
    }
    _operationInFlight = true;
    try {
      return await action();
    } finally {
      _operationInFlight = false;
    }
  }

  /// Pick one image and optionally run the existing native cropper, but keep
  /// the selected bytes lossless for callers that still need to run ML.
  Future<Uint8List?> pickSingleImageBytes({
    ImageSource source = ImageSource.gallery,
    MediaCropperOptions? cropper,
  }) =>
      _runExclusive<Uint8List?>(null, () async {
        final picked = await _picker.pickImage(source: source);
        if (picked == null) return null;

        final pickedFile = File(picked.path);
        File workingFile = pickedFile;
        try {
          if (cropper != null) {
            final cropped = await _runCropper(workingFile, cropper);
            if (cropped == null) return null;
            workingFile = File(cropped.path);
          }
          return await workingFile.readAsBytes();
        } finally {
          await _bestEffortDelete(pickedFile);
          if (workingFile.path != pickedFile.path) {
            await _bestEffortDelete(workingFile);
          }
        }
      });

  /// Crop already-picked bytes with the same native cropper used by the
  /// picker flow. This keeps source selection and ratio confirmation as two
  /// separate UI steps without decoding/re-encoding the image in Dart.
  Future<Uint8List?> cropImageBytes(
    Uint8List bytes, {
    required MediaCropperOptions cropper,
  }) =>
      _runExclusive<Uint8List?>(null, () async {
        final tempDir =
            await Directory.systemTemp.createTemp('kce_media_crop_');
        final isPng = bytes.length >= 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4E &&
            bytes[3] == 0x47;
        final source = File('${tempDir.path}/source.${isPng ? 'png' : 'jpg'}');
        File? croppedFile;
        try {
          await source.writeAsBytes(bytes, flush: true);
          final cropped = await _runCropper(source, cropper);
          if (cropped == null) return null;
          croppedFile = File(cropped.path);
          return await croppedFile.readAsBytes();
        } finally {
          if (croppedFile != null &&
              !croppedFile.path.startsWith(tempDir.path)) {
            await _bestEffortDelete(croppedFile);
          }
          try {
            if (await tempDir.exists()) await tempDir.delete(recursive: true);
          } catch (_) {/* best effort */}
        }
      });

  /// Pick a single image from gallery/camera, optionally crop, then
  /// run through the WebP ladder.
  ///
  /// Returns null when the user cancels the picker; throws on any
  /// other failure. The intermediate file (after crop, before WebP)
  /// is best-effort cleaned up.
  Future<MediaWebpResult?> pickSingleImageToWebp({
    ImagePickToWebpOptions options = const ImagePickToWebpOptions(),
  }) =>
      _runExclusive<MediaWebpResult?>(null, () async {
        final picked = await _picker.pickImage(source: options.source);
        if (picked == null) return null;

        XFile workingFile = picked;
        try {
          if (options.cropper != null) {
            final cropped =
                await _runCropper(File(workingFile.path), options.cropper!);
            if (cropped == null) {
              // user cancelled cropper — treat as cancel of whole pick
              return null;
            }
            workingFile = XFile(cropped.path);
          }

          final bytes = await File(workingFile.path).readAsBytes();
          final result = await normalizeBytesToWebp(
            bytes,
            maxFileBytes: options.maxFileBytes,
            stages: options.stages,
            hashStrategy: options.hashStrategy,
          );
          return result;
        } finally {
          await _bestEffortDelete(File(picked.path));
          if (workingFile.path != picked.path) {
            await _bestEffortDelete(File(workingFile.path));
          }
        }
      });

  /// Pick multiple images from the gallery and run each through the
  /// WebP ladder. Falls back to [pickSingleImageToWebp] when the
  /// remaining slot count is exactly 1 so users get the
  /// camera-fallback hint.
  ///
  /// Returns an empty list on cancel or when [maxCount] is already
  /// reached.
  Future<List<MediaWebpResult>> pickMultiImagesToWebp({
    required int maxCount,
    int currentCount = 0,
    ImagePickToWebpOptions options = const ImagePickToWebpOptions(),
  }) async {
    if (currentCount >= maxCount) {
      debugPrint('[ImagePicker] already at max ($maxCount)');
      return const [];
    }

    final remaining = maxCount - currentCount;
    if (remaining == 1) {
      final one = await pickSingleImageToWebp(options: options);
      return one == null ? const [] : [one];
    }

    return _runExclusive<List<MediaWebpResult>>(const [], () async {
      final picked = await _picker.pickMultiImage(limit: remaining);
      if (picked.isEmpty) return const [];

      final results = <MediaWebpResult>[];
      for (final image in picked) {
        try {
          final bytes = await File(image.path).readAsBytes();
          final result = await normalizeBytesToWebp(
            bytes,
            maxFileBytes: options.maxFileBytes,
            stages: options.stages,
            hashStrategy: options.hashStrategy,
          );
          results.add(result);
        } catch (e, st) {
          debugPrint('[ImagePicker] failed on $image: $e\n$st');
          // skip this one, continue with the rest
        } finally {
          await _bestEffortDelete(File(image.path));
        }
      }
      return results;
    });
  }

  Future<CroppedFile?> _runCropper(
      File source, MediaCropperOptions opts) async {
    final aspectRatio = opts.aspectRatio;
    final initialPreset = opts.initialPreset ??
        (aspectRatio != null &&
                aspectRatio.ratioX == 4 &&
                aspectRatio.ratioY == 3
            ? CropAspectRatioPreset.ratio4x3
            : CropAspectRatioPreset.original);
    return _cropper.cropImage(
      sourcePath: source.path,
      compressFormat: ImageCompressFormat.jpg,
      aspectRatio: aspectRatio,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: opts.title,
          toolbarColor: opts.toolbarColor,
          toolbarWidgetColor: opts.toolbarTextColor,
          initAspectRatio: initialPreset,
          lockAspectRatio: opts.lockAspectRatio,
          showCropGrid: false,
          activeControlsWidgetColor: opts.activeControlsColor,
          cropStyle: CropStyle.rectangle,
        ),
        IOSUiSettings(
          title: opts.title,
          aspectRatioLockEnabled: opts.lockAspectRatio,
          resetAspectRatioEnabled: !opts.lockAspectRatio,
          rotateButtonsHidden: true,
          rotateClockwiseButtonHidden: true,
          cropStyle: CropStyle.rectangle,
        ),
      ],
    );
  }

  Future<void> _bestEffortDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {/* swallow */}
  }
}

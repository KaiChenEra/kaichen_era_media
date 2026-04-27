import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kaichen_era_app_core/kaichen_era_app_core.dart';

import 'media_cache_service.dart';

/// `ImageProvider` for an [AppContentMediaInterface] entity that
/// prefers the local file (App Group / pack DB / etc.) and falls
/// back to a `NetworkImage` when the local copy is missing — kicking
/// off an async download in the background so the next render can
/// hit the disk path.
class ImageWithCache {
  ImageWithCache._internal();

  static final ImageWithCache _instance = ImageWithCache._internal();

  factory ImageWithCache() => _instance;

  final MediaCacheService _cacheService = MediaCacheService();

  ImageProvider getProvider(AppContentMediaInterface media) {
    final localPath = media.getLocalPathFull();
    final remotePath = media.getRemotePathFull();
    final localFile = File(localPath);

    if (localFile.existsSync()) {
      return FileImage(localFile);
    }

    // ignore: discarded_futures
    _cacheService.setCachedFile(
      remotePath: remotePath,
      localPath: localPath,
      uuid: media.id,
    );

    return NetworkImage(remotePath);
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

/// Generic remote-file → local-disk cache. Used by the SDK to back
/// `ImageProvider`s that fall back to a network URL when the local
/// App-Group copy is missing.
///
/// Concurrent calls for the same `(uuid, remotePath)` coalesce onto
/// one in-flight task so multiple widgets reading the same media
/// don't kick off duplicate downloads.
class MediaCacheService {
  static final MediaCacheService _instance = MediaCacheService._internal();
  factory MediaCacheService() => _instance;
  MediaCacheService._internal();

  final Map<String, Completer<File>> _ongoingCacheTasks = {};

  String _generateCacheFileName(String url) {
    final hash = md5.convert(utf8.encode(url)).toString();
    final extension = path.extension(url).isNotEmpty ? path.extension(url) : '.bin';
    return '$hash$extension';
  }

  /// Returns the local file if it exists and is non-empty; otherwise
  /// null. Empty files are treated as failed-cache leftovers and
  /// removed.
  Future<File?> getCachedFile({required String localPath}) async {
    try {
      final tempFilePath = File(localPath);
      if (await tempFilePath.exists()) {
        final fileSize = await tempFilePath.length();
        if (fileSize > 0) {
          return tempFilePath;
        }
        await tempFilePath.delete();
        debugPrint('[MediaCache] removed empty cache file: $localPath');
      }
      return null;
    } catch (e) {
      debugPrint('[MediaCache] getCachedFile error: $e');
      return null;
    }
  }

  /// Download `remotePath` to `localPath` (atomic rename via tmp
  /// file). Concurrent calls for the same `uuid+url` await the same
  /// in-flight download.
  Future<File?> setCachedFile({
    required String remotePath,
    required String localPath,
    required String uuid,
  }) async {
    if (remotePath.isEmpty) {
      debugPrint('[MediaCache] empty remotePath');
      return null;
    }

    final cacheKey = '$uuid-${_generateCacheFileName(remotePath)}';
    if (_ongoingCacheTasks.containsKey(cacheKey)) {
      return _ongoingCacheTasks[cacheKey]!.future;
    }

    final existingFile = await getCachedFile(localPath: localPath);
    if (existingFile != null) return existingFile;

    final completer = Completer<File>();
    _ongoingCacheTasks[cacheKey] = completer;

    try {
      final cacheFileDir = File(localPath).parent;
      final cacheFilename = _generateCacheFileName(remotePath);
      final cacheFilePath = path.join(cacheFileDir.path, cacheFilename);
      final cacheFile = File(cacheFilePath);

      if (await cacheFile.exists()) {
        await cacheFile.delete();
      }

      final response = await http.get(Uri.parse(remotePath));
      if (response.statusCode == 200) {
        await cacheFile.writeAsBytes(response.bodyBytes);
        final fileSize = await cacheFile.length();
        if (fileSize > 0 && fileSize == response.bodyBytes.length) {
          final fileFile = await cacheFile.rename(localPath);
          completer.complete(fileFile);
          _ongoingCacheTasks.remove(cacheKey);
          return fileFile;
        }
        if (await cacheFile.exists()) {
          await cacheFile.delete();
        }
        throw Exception('Cache file size mismatch or zero');
      }
      throw Exception('HTTP ${response.statusCode}');
    } catch (e) {
      debugPrint('[MediaCache] setCachedFile failed: $remotePath, $e');
      _ongoingCacheTasks.remove(cacheKey);
      return null;
    }
  }
}

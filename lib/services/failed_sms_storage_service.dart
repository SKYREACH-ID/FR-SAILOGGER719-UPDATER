import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sailogger719/screens/diagnostic_commands.dart';

class FailedSmsStorageException implements Exception {
  const FailedSmsStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FailedSmsSavedFile {
  const FailedSmsSavedFile({
    required this.displayName,
    required this.uri,
    required this.mimeType,
    required this.relativePath,
  });

  final String displayName;
  final String uri;
  final String mimeType;
  final String relativePath;
}

class FailedSmsDownloadSession {
  FailedSmsDownloadSession.android({
    required this.sessionId,
    required this.displayName,
    required this.mimeType,
    required this.relativePath,
  })  : sink = null,
        file = null,
        uri = null;

  FailedSmsDownloadSession.io({
    required this.displayName,
    required this.mimeType,
    required this.relativePath,
    required this.sink,
    required this.file,
  })  : sessionId = null,
        uri = null;

  final int? sessionId;
  final IOSink? sink;
  final File? file;
  final String? uri;
  final String displayName;
  final String mimeType;
  final String relativePath;
}

class FailedSmsStorageService {
  static const MethodChannel _channel = MethodChannel(
    'id.skyreach.sailogger.updater/failed_sms_storage',
  );

  Future<int?> getAndroidSdkInt() async {
    if (!Platform.isAndroid) return null;
    return _channel.invokeMethod<int>('getAndroidSdkInt');
  }

  Future<FailedSmsDownloadSession> startDownload({
    required String fileName,
    required String appFolderName,
  }) async {
    final sanitizedFileName = sanitizeFailedSmsDownloadFileName(fileName);
    final relativePath = buildFailedSmsDownloadRelativePath(appFolderName);
    if (Platform.isAndroid) {
      final result = await _invokeMap('startDownload', {
        'fileName': sanitizedFileName,
        'appFolderName': appFolderName,
      });
      return FailedSmsDownloadSession.android(
        sessionId: (result['sessionId'] as num).toInt(),
        displayName: result['displayName'] as String,
        mimeType: result['mimeType'] as String,
        relativePath: result['relativePath'] as String,
      );
    }

    final baseDirectory = await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final targetDirectory = Directory('${baseDirectory.path}/$appFolderName');
    await targetDirectory.create(recursive: true);
    final targetFile = await _createUniqueFile(
      targetDirectory,
      sanitizedFileName,
    );
    return FailedSmsDownloadSession.io(
      displayName: targetFile.uri.pathSegments.isEmpty
          ? sanitizedFileName
          : targetFile.uri.pathSegments.last,
      mimeType: 'application/octet-stream',
      relativePath: relativePath,
      sink: targetFile.openWrite(),
      file: targetFile,
    );
  }

  Future<void> writeChunk(
    FailedSmsDownloadSession session,
    Uint8List chunk,
  ) async {
    if (chunk.isEmpty) return;
    if (session.sessionId != null) {
      await _channel.invokeMethod<void>('writeChunk', {
        'sessionId': session.sessionId,
        'bytes': chunk,
      });
      return;
    }
    session.sink?.add(chunk);
  }

  Future<FailedSmsSavedFile> finishDownload(
    FailedSmsDownloadSession session,
  ) async {
    if (session.sessionId != null) {
      final result = await _invokeMap('finishDownload', {
        'sessionId': session.sessionId,
      });
      return FailedSmsSavedFile(
        displayName: result['displayName'] as String,
        uri: result['uri'] as String,
        mimeType: result['mimeType'] as String,
        relativePath: result['relativePath'] as String,
      );
    }

    await session.sink?.flush();
    await session.sink?.close();
    final file = session.file;
    if (file == null || !await file.exists()) {
      throw const FailedSmsStorageException('Failed to finalize local file.');
    }
    if (await file.length() == 0) {
      await file.delete();
      throw const FailedSmsStorageException('Downloaded file is empty.');
    }
    return FailedSmsSavedFile(
      displayName: session.displayName,
      uri: file.uri.toString(),
      mimeType: session.mimeType,
      relativePath: session.relativePath,
    );
  }

  Future<void> abortDownload(
    FailedSmsDownloadSession session, {
    String reason = 'cancelled',
  }) async {
    if (session.sessionId != null) {
      try {
        await _channel.invokeMethod<void>('abortDownload', {
          'sessionId': session.sessionId,
          'reason': reason,
        });
      } on PlatformException {
        return;
      }
      return;
    }
    try {
      await session.sink?.close();
    } finally {
      final file = session.file;
      if (file != null && await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> openFile(FailedSmsSavedFile file) async {
    if (!Platform.isAndroid) {
      throw const FailedSmsStorageException(
        'Open file is only implemented on Android.',
      );
    }
    await _channel.invokeMethod<void>('openFile', {
      'uri': file.uri,
      'mimeType': file.mimeType,
    });
  }

  Future<Map<dynamic, dynamic>> _invokeMap(
    String method,
    Map<String, Object?> arguments,
  ) async {
    try {
      final result = await _channel.invokeMapMethod<dynamic, dynamic>(
        method,
        arguments,
      );
      if (result == null) {
        throw const FailedSmsStorageException('Storage response is empty.');
      }
      return result;
    } on PlatformException catch (error) {
      throw FailedSmsStorageException(_mapPlatformError(error));
    }
  }

  String _mapPlatformError(PlatformException error) {
    switch (error.code) {
      case 'invalid_file_name':
        return 'Invalid file name from terminal.';
      case 'insert_failed':
        return 'Failed to create MediaStore entry.';
      case 'write_failed':
        return 'Failed while writing file to storage.';
      case 'insufficient_storage':
        return 'Not enough storage space to save the file.';
      case 'finish_failed':
        return 'Failed to finalize downloaded file.';
      case 'close_failed':
        return 'Failed to close the storage stream.';
      case 'open_failed':
        return 'Failed to open the downloaded file.';
      case 'download_cancelled':
        return 'Download cancelled.';
      default:
        return error.message ?? 'Storage operation failed.';
    }
  }

  Future<File> _createUniqueFile(Directory directory, String fileName) async {
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final extension = dotIndex > 0 ? fileName.substring(dotIndex) : '';
    var candidate = fileName;
    var counter = 1;
    while (await File('${directory.path}/$candidate').exists()) {
      candidate = '$baseName ($counter)$extension';
      counter++;
    }
    return File('${directory.path}/$candidate');
  }
}

import 'package:flutter/material.dart';
import '../models/file_item.dart';

/// Maps file extensions to a [FileCategory] and picks a representative icon.
class FileTypeHelper {
  FileTypeHelper._();

  static const Set<String> _imageExtensions = {
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', 'bmp', 'svg', 'tiff',
  };

  static const Set<String> _videoExtensions = {
    'mp4', 'mov', 'mkv', 'avi', '3gp', 'webm', 'm4v', 'flv', 'wmv',
  };

  // Includes lossless formats (flac, wav, alac/m4a, aiff, ape, wv, dsf, dff)
  // alongside common lossy ones, since this app is used to sync a lossless
  // music library.
  static const Set<String> _audioExtensions = {
    'flac', 'wav', 'aiff', 'aif', 'ape', 'wv', 'dsf', 'dff',
    'mp3', 'aac', 'm4a', 'ogg', 'opus', 'wma', 'alac',
  };

  static String extensionOf(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) return '';
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  static FileCategory categoryForFileName(String fileName) {
    final ext = extensionOf(fileName);
    if (_imageExtensions.contains(ext)) return FileCategory.photo;
    if (_videoExtensions.contains(ext)) return FileCategory.video;
    if (_audioExtensions.contains(ext)) return FileCategory.audio;
    return FileCategory.document;
  }

  static String mimeTypeForFileName(String fileName) {
    final ext = extensionOf(fileName);
    const map = {
      'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png',
      'gif': 'image/gif', 'webp': 'image/webp', 'heic': 'image/heic',
      'bmp': 'image/bmp',
      'mp4': 'video/mp4', 'mov': 'video/quicktime', 'mkv': 'video/x-matroska',
      'avi': 'video/x-msvideo', 'webm': 'video/webm', '3gp': 'video/3gpp',
      'flac': 'audio/flac', 'wav': 'audio/wav', 'aiff': 'audio/aiff',
      'ape': 'audio/x-ape', 'wv': 'audio/x-wavpack', 'dsf': 'audio/x-dsf',
      'mp3': 'audio/mpeg', 'aac': 'audio/aac', 'm4a': 'audio/mp4',
      'ogg': 'audio/ogg', 'opus': 'audio/opus', 'wma': 'audio/x-ms-wma',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt': 'text/plain',
      'zip': 'application/zip',
      'rar': 'application/vnd.rar',
      'apk': 'application/vnd.android.package-archive',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  static IconData iconForFile(String fileName, FileCategory category) {
    final ext = extensionOf(fileName);
    switch (category) {
      case FileCategory.photo:
        return Icons.image_rounded;
      case FileCategory.video:
        return Icons.movie_rounded;
      case FileCategory.audio:
        return Icons.music_note_rounded;
      case FileCategory.document:
        switch (ext) {
          case 'pdf':
            return Icons.picture_as_pdf_rounded;
          case 'doc':
          case 'docx':
            return Icons.description_rounded;
          case 'xls':
          case 'xlsx':
            return Icons.table_chart_rounded;
          case 'ppt':
          case 'pptx':
            return Icons.slideshow_rounded;
          case 'zip':
          case 'rar':
          case '7z':
            return Icons.folder_zip_rounded;
          default:
            return Icons.insert_drive_file_rounded;
        }
    }
  }
}

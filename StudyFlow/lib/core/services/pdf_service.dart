import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  Future<String?> extractTextFromPlatformFile(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    return extractTextFromBytes(bytes, extension: _extensionFor(file));
  }

  Future<String?> extractTextFromBytes(
    List<int> bytes, {
    required String extension,
  }) async {
    try {
      final normalizedExtension = extension.toLowerCase();
      if (normalizedExtension == 'pdf') {
        return extractPdfText(Uint8List.fromList(bytes));
      }
      if (normalizedExtension == 'txt' ||
          normalizedExtension == 'md' ||
          normalizedExtension == 'csv') {
        return normalizeText(utf8.decode(bytes, allowMalformed: true));
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String? extractPdfText(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      return normalizeText(PdfTextExtractor(document).extractText());
    } finally {
      document.dispose();
    }
  }

  String? normalizeText(String raw) {
    final clean = raw
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    return clean.isEmpty ? null : clean;
  }

  String _extensionFor(PlatformFile file) {
    final extension = file.extension?.toLowerCase();
    if (extension != null && extension.isNotEmpty) return extension;
    final parts = file.name.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : 'file';
  }
}

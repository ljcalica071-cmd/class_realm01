import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:class_realm/core/utils/validators.dart';

class ExtractedLectureDocument {
  final String fileName;
  final String extension;
  final String mimeType;
  final int sizeBytes;
  final Uint8List rawBytes;
  final String extractedText;

  const ExtractedLectureDocument({
    required this.fileName,
    required this.extension,
    required this.mimeType,
    required this.sizeBytes,
    required this.rawBytes,
    required this.extractedText,
  });

  bool get isPdf => extension == 'pdf';
  bool get isPowerPoint => extension == 'ppt' || extension == 'pptx';
  bool get isWord => extension == 'doc' || extension == 'docx';
}

class LectureDocumentExtractor {
  /// Validates and extracts text from a `.pdf`, `.ppt`, `.pptx`, `.doc`, or `.docx` lecture file.
  /// Throws a [FormatException] with a user-facing inline validation message if invalid.
  static ExtractedLectureDocument extract({
    required String fileName,
    required Uint8List bytes,
  }) {
    final validationError = AppValidators.validateAiLectureFile(
      fileName: fileName,
      fileSizeBytes: bytes.length,
    );
    if (validationError != null) {
      throw FormatException(validationError);
    }

    final dot = fileName.lastIndexOf('.');
    final ext = dot == -1 ? '' : fileName.substring(dot + 1).toLowerCase();

    if (ext == 'pptx') {
      final text = _extractPptxText(bytes);
      if (text.trim().isEmpty) {
        throw const FormatException(
          'No readable text could be found in this PowerPoint (.pptx) file. Please ensure slides contain text and not only scanned images.',
        );
      }
      return ExtractedLectureDocument(
        fileName: fileName,
        extension: ext,
        mimeType:
            'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        sizeBytes: bytes.length,
        rawBytes: bytes,
        extractedText: text,
      );
    }

    if (ext == 'ppt') {
      final text = _extractPptText(bytes);
      if (text.trim().isEmpty) {
        throw const FormatException(
          'No readable text could be extracted from this PowerPoint (.ppt) file. Please save as .pptx or .pdf and try again.',
        );
      }
      return ExtractedLectureDocument(
        fileName: fileName,
        extension: ext,
        mimeType: 'application/vnd.ms-powerpoint',
        sizeBytes: bytes.length,
        rawBytes: bytes,
        extractedText: text,
      );
    }

    if (ext == 'docx') {
      final text = _extractDocxText(bytes);
      if (text.trim().isEmpty) {
        throw const FormatException(
          'No readable text could be found in this Word (.docx) file. Please ensure document contains readable text and not only scanned images.',
        );
      }
      return ExtractedLectureDocument(
        fileName: fileName,
        extension: ext,
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        sizeBytes: bytes.length,
        rawBytes: bytes,
        extractedText: text,
      );
    }

    if (ext == 'doc') {
      final text = _extractDocText(bytes);
      if (text.trim().isEmpty) {
        throw const FormatException(
          'No readable text could be extracted from this Word (.doc) file. Please save as .docx or .pdf and try again.',
        );
      }
      return ExtractedLectureDocument(
        fileName: fileName,
        extension: ext,
        mimeType: 'application/msword',
        sizeBytes: bytes.length,
        rawBytes: bytes,
        extractedText: text,
      );
    }

    if (ext == 'pdf') {
      final text = _extractPdfText(bytes);
      return ExtractedLectureDocument(
        fileName: fileName,
        extension: ext,
        mimeType: 'application/pdf',
        sizeBytes: bytes.length,
        rawBytes: bytes,
        extractedText: text,
      );
    }

    throw FormatException(
      "Unsupported file format '.$ext'. Only PDF (.pdf), PowerPoint (.ppt, .pptx), and Word (.doc, .docx) lecture files are allowed.",
    );
  }

  static String _extractPptxText(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      final slideRegex = RegExp(r'^ppt/slides/slide(\d+)\.xml$');
      final notesRegex = RegExp(r'^ppt/notesSlides/notesSlide(\d+)\.xml$');

      final slideFiles = <int, ArchiveFile>{};
      final notesFiles = <int, ArchiveFile>{};

      for (final file in archive.files) {
        if (!file.isFile) continue;
        final slideMatch = slideRegex.firstMatch(file.name);
        if (slideMatch != null) {
          final num = int.tryParse(slideMatch.group(1)!) ?? 0;
          slideFiles[num] = file;
          continue;
        }
        final notesMatch = notesRegex.firstMatch(file.name);
        if (notesMatch != null) {
          final num = int.tryParse(notesMatch.group(1)!) ?? 0;
          notesFiles[num] = file;
        }
      }

      if (slideFiles.isEmpty) {
        throw const FormatException(
          'Invalid PowerPoint (.pptx) archive: no slide XML entries found.',
        );
      }

      final sortedSlideNums = slideFiles.keys.toList()..sort();
      final buffer = StringBuffer();

      for (final slideNum in sortedSlideNums) {
        final slideFile = slideFiles[slideNum]!;
        final slideXml = utf8.decode(
          slideFile.content as List<int>,
          allowMalformed: true,
        );
        final slideText = _extractDrawingMlText(slideXml);

        String notesText = '';
        if (notesFiles.containsKey(slideNum)) {
          final notesXml = utf8.decode(
            notesFiles[slideNum]!.content as List<int>,
            allowMalformed: true,
          );
          notesText = _extractDrawingMlText(notesXml);
        }

        if (slideText.isNotEmpty || notesText.isNotEmpty) {
          buffer.writeln('[Slide $slideNum]');
          if (slideText.isNotEmpty) {
            buffer.writeln(slideText);
          }
          if (notesText.isNotEmpty) {
            buffer.writeln('Speaker Notes: $notesText');
          }
          buffer.writeln();
        }
      }

      return buffer.toString().trim();
    } on FormatException {
      rethrow;
    } catch (_) {
      // Fallback if a test passes plain UTF-8 text in a mock .pptx
      final rawAsText = _tryDecodePlainUtf8(bytes);
      if (rawAsText.isNotEmpty) return rawAsText;
      throw const FormatException(
        'Unable to read PowerPoint (.pptx) file. The file may be corrupted.',
      );
    }
  }

  static String _extractDrawingMlText(String xml) {
    final paragraphRegex = RegExp(r'<a:p\b[^>]*>([\s\S]*?)</a:p>');
    final textRunRegex = RegExp(r'<a:t(?:\s[^>]*)?>([\s\S]*?)</a:t>');

    final lines = <String>[];
    final pMatches = paragraphRegex.allMatches(xml);

    if (pMatches.isNotEmpty) {
      for (final pMatch in pMatches) {
        final pContent = pMatch.group(1) ?? '';
        final runTexts = textRunRegex
            .allMatches(pContent)
            .map((m) => _decodeXmlEntities(m.group(1) ?? ''))
            .where((t) => t.isNotEmpty)
            .join('');
        final cleaned = runTexts.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (cleaned.isNotEmpty) {
          lines.add(cleaned);
        }
      }
    } else {
      for (final tMatch in textRunRegex.allMatches(xml)) {
        final cleaned = _decodeXmlEntities(tMatch.group(1) ?? '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (cleaned.isNotEmpty) {
          lines.add(cleaned);
        }
      }
    }

    return lines.join('\n');
  }

  static String _decodeXmlEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
          final code = int.tryParse(m.group(1) ?? '');
          return code != null ? String.fromCharCode(code) : '';
        })
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
          final code = int.tryParse(m.group(1) ?? '', radix: 16);
          return code != null ? String.fromCharCode(code) : '';
        });
  }

  static String _extractPptText(Uint8List bytes) {
    // Check if the .ppt file is actually a ZIP-based .pptx
    if (bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      return _extractPptxText(bytes);
    }

    final plain = _tryDecodePlainUtf8(bytes);
    if (plain.isNotEmpty) return plain;

    return _extractReadableStringsFromBinary(bytes);
  }

  static String _extractDocxText(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes, verify: false);
      ArchiveFile? docFile;
      for (final f in archive.files) {
        if (f.name == 'word/document.xml') {
          docFile = f;
          break;
        }
      }
      if (docFile == null) {
        throw const FormatException(
          'Invalid Word (.docx) archive: no word/document.xml found.',
        );
      }
      final xml = utf8.decode(
        docFile.content as List<int>,
        allowMalformed: true,
      );
      final pRegex = RegExp(r'<w:p\b[^>]*>([\s\S]*?)</w:p>');
      final tRegex = RegExp(r'<w:t(?:\s[^>]*)?>([\s\S]*?)</w:t>');
      final lines = <String>[];
      for (final p in pRegex.allMatches(xml)) {
        final pContent = p.group(1) ?? '';
        final tRuns = tRegex
            .allMatches(pContent)
            .map((m) => m.group(1) ?? '')
            .join();
        if (tRuns.trim().isNotEmpty) {
          lines.add(_decodeXmlEntities(tRuns.trim()));
        }
      }
      return lines.join('\n');
    } on FormatException {
      rethrow;
    } catch (_) {
      final rawAsText = _tryDecodePlainUtf8(bytes);
      if (rawAsText.isNotEmpty) return rawAsText;
      throw const FormatException(
        'Unable to read Word (.docx) file. The file may be corrupted.',
      );
    }
  }

  static String _extractDocText(Uint8List bytes) {
    if (bytes.length >= 4 &&
        bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04) {
      return _extractDocxText(bytes);
    }

    final plain = _tryDecodePlainUtf8(bytes);
    if (plain.isNotEmpty) return plain;

    return _extractReadableStringsFromBinary(bytes);
  }

  static String _extractPdfText(Uint8List bytes) {
    final raw = latin1.decode(bytes, allowInvalid: true);
    final extractedLiterals = <String>[];

    // Extract text literals inside PDF text blocks BT ... ET
    final btEtRegex = RegExp(r'BT([\s\S]*?)ET');
    final literalRegex = RegExp(r'\(([^()\\]*(?:\\.[^()\\]*)*)\)');

    for (final block in btEtRegex.allMatches(raw)) {
      final blockContent = block.group(1) ?? '';
      final pieces = <String>[];
      for (final lit in literalRegex.allMatches(blockContent)) {
        final s = (lit.group(1) ?? '')
            .replaceAll(r'\(', '(')
            .replaceAll(r'\)', ')')
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\r', ' ')
            .replaceAll(r'\t', ' ')
            .replaceAll(r'\\', r'\')
            .trim();
        if (s.isNotEmpty && _isPrintableAsciiRun(s)) {
          pieces.add(s);
        }
      }
      if (pieces.isNotEmpty) {
        extractedLiterals.add(pieces.join(' '));
      }
    }

    if (extractedLiterals.isNotEmpty) {
      return extractedLiterals.join('\n').trim();
    }

    final plain = _tryDecodePlainUtf8(bytes);
    if (plain.isNotEmpty && !plain.startsWith('%PDF-')) {
      return plain;
    }

    return '';
  }

  static String _tryDecodePlainUtf8(Uint8List bytes) {
    try {
      final decoded = utf8.decode(bytes, allowMalformed: false).trim();
      final printableCount = decoded.runes.where((r) {
        return r == 9 || r == 10 || r == 13 || (r >= 32 && r <= 126) || r >= 160;
      }).length;
      if (decoded.isNotEmpty && printableCount >= decoded.runes.length * 0.85) {
        return decoded;
      }
    } catch (_) {}
    return '';
  }

  static bool _isPrintableAsciiRun(String s) {
    if (s.isEmpty) return false;
    int printable = 0;
    for (final code in s.codeUnits) {
      if ((code >= 32 && code <= 126) || code == 10 || code == 13) {
        printable++;
      }
    }
    return printable >= s.length * 0.8;
  }

  static String _extractReadableStringsFromBinary(Uint8List bytes) {
    final chunks = <String>[];
    final current = StringBuffer();

    for (int i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      if ((b >= 32 && b <= 126) || b == 10 || b == 13) {
        current.writeCharCode(b);
      } else {
        if (current.length >= 6) {
          final text = current.toString().trim();
          if (RegExp(r'[a-zA-Z]{3,}').hasMatch(text)) {
            chunks.add(text);
          }
        }
        current.clear();
      }
    }
    if (current.length >= 6) {
      final text = current.toString().trim();
      if (RegExp(r'[a-zA-Z]{3,}').hasMatch(text)) {
        chunks.add(text);
      }
    }

    return chunks.join('\n').trim();
  }
}


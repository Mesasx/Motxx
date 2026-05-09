import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:studyflow/core/services/pdf_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

void main() {
  group('PdfService', () {
    test('normalizes plain text content', () {
      final text =
          PdfService.instance.normalizeText('Tema 1\r\n\r\n\r\n  Redes   ');

      expect(text, 'Tema 1\n\n Redes');
    });

    test('extracts text from a generated PDF', () {
      final document = PdfDocument();
      final page = document.pages.add();
      page.graphics.drawString(
        'Tema 4 - Routing dinamico',
        PdfStandardFont(PdfFontFamily.helvetica, 12),
      );
      final bytes = Uint8List.fromList(document.saveSync());
      document.dispose();

      final text = PdfService.instance.extractPdfText(bytes);

      expect(text, contains('Tema 4'));
      expect(text, contains('Routing'));
    });
  });
}

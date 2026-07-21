import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:rapporto_servizio/pdf/generatore_pdf2.dart';

void main() {
  test('PDF schedule normalization preserves daily break data', () {
    final result = normalizzaOrariGiornataPdf({
      '2026-07-19': {
        'oraDa': '08:00',
        'oraA': '17:30',
        'pausa': 'true',
        'pausaOre': '1',
        'pausaMinuti': '30',
      },
    });

    expect(result['2026-07-19'], {
      'oraDa': '08:00',
      'oraA': '17:30',
      'pausa': 'true',
      'pausaOre': '1',
      'pausaMinuti': '30',
    });
  });

  test('PDF attachments are resized and compressed before upload', () {
    final source = img.Image(width: 2000, height: 1000);
    img.fill(source, color: img.ColorRgb8(30, 100, 180));

    final optimized = ottimizzaAllegatoPdf(
      Uint8List.fromList(img.encodePng(source)),
    );
    final decoded = img.decodeImage(optimized);

    expect(decoded, isNotNull);
    expect(decoded!.width, 1280);
    expect(decoded.height, 640);
  });
}

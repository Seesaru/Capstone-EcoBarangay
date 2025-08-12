// ignore: avoid_web_libraries_in_flutter
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'pdf_service_web.dart' if (dart.library.io) 'pdf_service_mobile.dart';

class PdfService {
  static Future<void> downloadPdf(Uint8List pdfBytes, String fileName) async {
    await PdfServiceImpl.downloadPdfWeb(pdfBytes, fileName);
  }
}

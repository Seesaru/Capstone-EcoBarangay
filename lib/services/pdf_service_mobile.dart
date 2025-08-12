import 'dart:typed_data';

class PdfServiceImpl {
  static Future<void> downloadPdfWeb(
      Uint8List pdfBytes, String fileName) async {
    throw UnsupportedError('PDF download is not supported on mobile platforms');
  }
}

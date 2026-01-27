import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Helper para download de arquivos no navegador - VERSÃO WEB
class WebDownloadHelper {
  static void downloadFile(Uint8List bytes, String fileName) {
    _downloadFileWeb(bytes, fileName);
  }

  static void _downloadFileWeb(Uint8List bytes, String fileName) {
    try {
      // Criar Blob a partir dos bytes
      final blob = web.Blob(
        [bytes.toJS].toJS,
        web.BlobPropertyBag(type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      );

      // Criar URL temporária para o blob
      final url = web.URL.createObjectURL(blob);

      // Criar elemento <a> para download
      final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
      anchor.href = url;
      anchor.download = fileName;
      anchor.style.display = 'none';

      // Adicionar ao DOM, clicar e remover
      web.document.body!.appendChild(anchor);
      anchor.click();

      // Aguardar um pouco antes de limpar
      Future.delayed(const Duration(milliseconds: 100), () {
        web.document.body!.removeChild(anchor);
        web.URL.revokeObjectURL(url);
      });

      if (kDebugMode) {
        print('✅ Download iniciado: $fileName (${bytes.length} bytes)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Erro ao fazer download: $e');
      }
      rethrow;
    }
  }
}

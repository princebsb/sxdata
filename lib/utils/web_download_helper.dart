// Exportação condicional: usa web_download_helper_web.dart na web
// e web_download_helper_stub.dart em outras plataformas
export 'web_download_helper_stub.dart'
  if (dart.library.js_interop) 'web_download_helper_web.dart';

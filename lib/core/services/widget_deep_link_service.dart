import 'dart:async';

/// Meneruskan deep link dari widget Android ke dalam tree Flutter.
///
/// Diperlukan karena deep link dari cold start diterima sebelum runApp,
/// sehingga tidak bisa langsung navigasi. Service ini menampung URI sementara
/// dan meneruskannya via stream setelah Flutter siap.
class WidgetDeepLinkService {
  WidgetDeepLinkService._();

  static final instance = WidgetDeepLinkService._();

  final _controller = StreamController<Uri>.broadcast();

  Stream<Uri> get stream => _controller.stream;

  /// Kirim URI ke semua listener aktif.
  void handle(Uri uri) => _controller.add(uri);

  void dispose() => _controller.close();

  /// Cek apakah URI berasal dari widget (bukan deep link Supabase).
  static bool isWidgetUri(Uri uri) =>
      uri.scheme == 'com.rizz.kawainotes' &&
      (uri.host == 'widget-note' || uri.host == 'widget-config');
}

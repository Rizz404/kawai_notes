import 'package:equatable/equatable.dart';

class AppRouteState extends Equatable {
  final Uri uri;
  final Map<String, dynamic> extra;

  const AppRouteState({required this.uri, this.extra = const {}});

  factory AppRouteState.fromUri(Uri uri, {Map<String, dynamic>? extra}) {
    return AppRouteState(uri: uri, extra: extra ?? {});
  }

  factory AppRouteState.fromPath(String path, {Map<String, dynamic>? extra}) {
    return AppRouteState(uri: Uri.parse(path), extra: extra ?? {});
  }

  String get path => uri.path;
  Map<String, String> get queryParams => uri.queryParameters;

  @override
  List<Object?> get props => [uri, extra];
}

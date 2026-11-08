import 'package:flutter/widgets.dart';
import 'package:kawai_notes/core/router/app_route_state.dart';
import 'package:kawai_notes/core/services/widget_deep_link_service.dart';

/// Marks route information that belongs to a widget deep link.
const widgetLinkMarker = 'widgetLink';

class AppRouteParser extends RouteInformationParser<AppRouteState> {
  const AppRouteParser();

  @override
  Future<AppRouteState> parseRouteInformation(
    RouteInformation routeInformation,
  ) async {
    final uri = routeInformation.uri;
    // * home-screen widget intents are handled by app_links; the engine's
    // * copy of the same intent must not reset the stack
    if (WidgetDeepLinkService.isWidgetUri(uri) ||
        (uri.path.isEmpty && uri.queryParameters.containsKey('widgetId'))) {
      return AppRouteState(uri: uri, extra: const {widgetLinkMarker: true});
    }
    final location = uri.path;
    if (location.isEmpty) {
      return AppRouteState.fromPath('/');
    }
    return AppRouteState.fromUri(routeInformation.uri);
  }

  @override
  RouteInformation restoreRouteInformation(AppRouteState configuration) {
    return RouteInformation(uri: configuration.uri);
  }
}

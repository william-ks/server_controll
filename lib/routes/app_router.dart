import 'package:flutter/material.dart';

import 'routes_config.dart';

class AppRouter {
  AppRouter._();

  static Map<String, WidgetBuilder> get routes => {
    for (final definition in AppRoutes.definitions) definition.path: definition.builder,
  };
}

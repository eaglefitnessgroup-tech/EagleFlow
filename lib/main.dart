import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'app/app.dart';

import 'core/di/service_locator.dart';


Future<void> main() async {
  usePathUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  

  ServiceLocator().init();
  runApp(const EagleFlowApp());
}

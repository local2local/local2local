import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local2local/core/app.dart';

void main() {
  // Use debugPrint to satisfy avoid_print lint
  debugPrint("L2LAAF_DART_MAIN_START: Version v11.45.36");
  
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: L2LAAFApp(),
    ),
  );
}
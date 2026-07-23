import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'engine_manager.dart';

final engineManagerProvider = Provider<EngineManager>((ref) {
  return EngineManager();
});

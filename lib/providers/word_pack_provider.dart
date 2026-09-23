import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/word_pack_registry.dart';
import '../models/word_category.dart';

final wordPackProvider = Provider<List<WordCategory>>((ref) {
  return allWordCategories;
});

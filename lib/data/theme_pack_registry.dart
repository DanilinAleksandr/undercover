import '../models/theme_pair.dart';
import '../models/word_category.dart';
import 'theme_packs/theme_books.dart';
import 'theme_packs/theme_games.dart';
import 'theme_packs/theme_life.dart';
import 'theme_packs/theme_music.dart';
import 'theme_packs/theme_screen.dart';
import 'word_pack_registry.dart';

/// The bundled «Самозванец» base: topic pairs, not word pairs.
///
/// Kept apart from [allWordCategories] on purpose. The word base is vetted by
/// rules written for single words — length, stems, association tags — and a
/// theme like «Souls-игры FromSoftware» would fail every one of them for
/// reasons that have nothing to do with how well it plays. Themes have their
/// own checks in `test/theme_pack_quality_test.dart`.
///
/// To extend it, add a file under `theme_packs/` exporting a
/// `const ThemeCategory` and list it here.
const List<ThemeCategory> allThemeCategories = [
  themeGamesCategory,
  themeScreenCategory,
  themeBooksCategory,
  themeMusicCategory,
  themeLifeCategory,
];

/// Everything a round can be dealt from, in every mode.
///
/// The themes join here in the one shape the game plays —
/// [ThemeCategory.toWordCategory] — so the filters, the pool counter and the
/// played history treat them exactly like any other mode's content.
final List<WordCategory> allGameCategories = [
  ...allWordCategories,
  for (final category in allThemeCategories) category.toWordCategory(),
];

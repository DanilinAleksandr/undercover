import '../models/word_pair.dart';

/// The rework queue: pairs pulled out of the shipping base and parked here
/// until their wording could be turned into a playable pair.
///
/// **Currently empty — every parked pair has been reworked and returned to a
/// category in `word_packs/`.** The list stays, with its rules, because the
/// next editorial pass will fill it again.
///
/// **Never registered in `word_pack_registry.dart`, so nothing here is ever
/// dealt in game.**
///
/// ## What gets parked
///
/// Two passes feed this list, and an entry must say which one caught it.
///
/// 1. **The editorial quality pass** parks pairs scored 1-2: the two words are
///    synonyms, one is an obvious subtype of the other, or the pair leaves
///    nothing to reason about. The score alone says why, so those entries need
///    no annotation beyond a `// was: <category>` note.
///
/// 2. **The Spy-guessability pass** parks pairs that read fine on paper but
///    leave the spy without a direction: after several honest associations the
///    field is as wide as it started, or both sides of the pair occupy the same
///    answer. Those keep their original score — the defect is the spy side of
///    the round, not the wording — so they must carry the annotation instead:
///
/// ```dart
/// // spy_guessability: 1 (E)
/// // reason: "почему шпион не может сузить поле"
/// // rework: чем заменить
/// WordPair('Сила', 'Воля', _x, ['внутри человека', ...], 3), // was: abstract
/// ```
///
/// Only 1 and 2 are parking grades; 3-5 stays in the game. A grade needs a
/// `reason`, and a reason needs a `rework`. `test/spy_guessability_test.dart`
/// checks all of that against this file's source, so the format is load-bearing
/// rather than decorative.
///
/// ## Getting a pair back out
///
/// Rewrite one or both sides until the pair has a shared association field with
/// two separate answers, give it at least four tags (two immediate, two that
/// take a second), re-decide its difficulty from scratch, and move it to the
/// category where it actually belongs — the `// was:` note records where it
/// came from, not where it has to go. A pair that lands in `_h` or `_x` in a
/// words-mode category also needs its hints in `word_hints/`.
const List<WordPair> pairsNeedingRework = [];

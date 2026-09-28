import '../models/game_mode.dart';
import 'word_descriptions/persons.dart';
import 'word_descriptions/professions.dart';

/// Plain definitions of the secret word, keyed by the exact word.
///
/// ## What this is, and what it is not
///
/// A *hint* (`word_hints.dart`) helps a player guess **somebody else's** word:
/// it is deliberately oblique, it escalates in three steps, it is offered only
/// in the hard and expert tiers, and the host can switch it off.
///
/// A *description* is the opposite. It explains a player's **own** word to the
/// player holding it, because a round dies on the spot when someone reads
/// «Завхоз» or «Крановщик» and simply does not know what that is — there is
/// nothing to associate from. So it is always available, in every tier,
/// whatever the «Подсказки» switch says — but never printed on the card. A
/// player who recognised the word does not need it; it waits behind the same
/// link under the card as the hints, as the last and most direct level.
///
/// ## Writing one
///
/// 1. One short phrase saying what the person does for a living. Neutral and
///    dictionary-flat: a description must not be a riddle, a joke or a nudge.
/// 2. Using a cognate of the word is fine here — «Крановщик: управляет
///    подъёмным краном» is exactly right. Hints may not do that; definitions
///    may, because the reader is looking at the word already.
/// 3. Keep it under 70 characters: one line of the help sheet, read at a
///    glance.
/// 4. Every word in the pack gets one, including the obvious ones. If only the
///    rare words offered it, the link's presence would itself tell the player
///    how unusual the word is.
///
/// Coverage is enforced by `test/word_descriptions_test.dart`.
const Map<String, String> wordDescriptions = {
  ...professionDescriptions,
};

/// The line printed under [word] on a card dealt in [mode], if there is one.
///
/// Each mode keeps its own table, because the same text can mean different
/// things in two modes and a description written for one must never land on
/// the other. In «Слова» it is the job descriptions above; in «Личности» it
/// is who the person is and when they were famous
/// (`word_descriptions/persons.dart`). The places and impostor modes have
/// none: a city or a theme needs no explaining to the player holding it.
String? descriptionFor(String word, GameMode mode) => switch (mode) {
      GameMode.words => wordDescriptions[word],
      GameMode.people => personDescriptions[word],
      GameMode.places || GameMode.impostor => null,
    };

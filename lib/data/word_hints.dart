import '../models/word_hints.dart';
import 'word_hints/hints_expert_a.dart';
import 'word_hints/hints_expert_b.dart';
import 'word_hints/hints_expert_c.dart';
import 'word_hints/hints_expert_d.dart';
import 'word_hints/hints_expert_e.dart';
import 'word_hints/hints_hard_a.dart';
import 'word_hints/hints_hard_b.dart';
import 'word_hints/hints_hard_c.dart';
import 'word_hints/hints_hard_d.dart';

/// Authored clues, keyed by the exact secret word.
///
/// Kept out of the word packs so the base itself stays untouched, and keyed by
/// word rather than by pair because the same word appears in several pairs and
/// deserves the same clue every time.
///
/// Coverage is enforced by `test/word_hints_test.dart`: every word in a hard
/// pair needs a soft hint, every word in an expert pair needs all three.
///
/// ## Writing a new hint
///
/// 1. A hint exists for the player who does not know the word. It is not a
///    riddle to be solved — the player is looking at the word already.
/// 2. For a hard pair a plainly explanatory hint is fine when the word really
///    is rare. "Ремень, которым раскручивали и метали камень" is the help a
///    player needs; dressing it up would only make it useless.
/// 3. For an expert pair the three levels must narrow the field step by step:
///    context -> situation -> distinguishing feature. Three restatements of
///    one idea are worse than a single good clue.
/// 4. A hint must never effectively say the answer out loud.
/// 5. Always read the new hint against the other word of the pair. If both
///    sides start attracting the same association, the hint is bad even when
///    every formal rule passes — that is the failure that ruins a round.
/// 6. Do not force imagery. Being understood beats sounding literary.
/// 7. The tests cover the formal limits only (no word, no cognate, no paired
///    word, length, escalation, reuse). Whether a hint is actually worth
///    anything at the table still has to be judged by a person.
const List<Map<String, WordHints>> hintParts = [
  hintsExpertA,
  hintsExpertB,
  hintsExpertC,
  hintsExpertD,
  hintsExpertE,
  hintsHardA,
  hintsHardB,
  hintsHardC,
  hintsHardD,
];

final Map<String, WordHints> wordHints = {
  for (final part in hintParts) ...part,
};

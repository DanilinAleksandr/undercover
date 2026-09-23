import 'package:flutter_test/flutter_test.dart';
import 'package:undercover/logic/game_rules.dart';
import 'package:undercover/models/alco_penalty.dart';
import 'package:undercover/models/difficulty.dart';
import 'package:undercover/models/game_config.dart';
import 'package:undercover/models/game_result.dart';
import 'package:undercover/models/role.dart';
import 'package:undercover/models/vote.dart';
import 'package:undercover/models/vote_result.dart';
import 'package:undercover/models/word_pair.dart';

void main() {
  const wordPair = WordPair('Маяк', 'Прожектор', Difficulty.medium, ['свет', 'дальность'], 5);

  group('assignRoles', () {
    test('assigns exactly one spy among the players', () {
      final assignment = assignRoles(['A', 'B', 'C', 'D']);
      final spies = assignment.players.where((p) => p.role == Role.spy);
      expect(spies.length, 1);
      expect(spies.first.id, assignment.spyPlayerId);
    });

    test('preserves player names and order', () {
      final assignment = assignRoles(['Alice', 'Bob', 'Carol']);
      expect(assignment.players.map((p) => p.name).toList(), ['Alice', 'Bob', 'Carol']);
    });
  });

  group('createSession', () {
    test('builds a session in roleIntro phase with the given word pair', () {
      const config = GameConfig(playerNames: ['A', 'B', 'C']);
      final session = createSession(config, wordPair);
      expect(session.players.length, 3);
      expect(session.wordPair, wordPair);
      expect(session.players.where((p) => p.role == Role.spy).length, 1);
    });
  });

  group('tallyVotes', () {
    test('detects a clear majority and marks the spy caught', () {
      final players = assignRoles(['A', 'B', 'C']).players;
      final result = tallyVotes(
        players,
        const [
          Vote(voterId: 'player_0', targetId: 'player_1'),
          Vote(voterId: 'player_2', targetId: 'player_1'),
        ],
        'player_1',
      );
      expect(result.isTie, isFalse);
      expect(result.majorityTargetId, 'player_1');
      expect(result.spyWasCaught, isTrue);
    });

    test('treats an even split as a tie with no majority', () {
      final players = assignRoles(['A', 'B']).players;
      final result = tallyVotes(
        players,
        const [
          Vote(voterId: 'player_0', targetId: 'player_1'),
          Vote(voterId: 'player_1', targetId: 'player_0'),
        ],
        'player_1',
      );
      expect(result.isTie, isTrue);
      expect(result.majorityTargetId, isNull);
      expect(result.spyWasCaught, isFalse);
    });

    test('spy is not caught when the majority targets a civilian', () {
      final players = assignRoles(['A', 'B', 'C']).players;
      final result = tallyVotes(
        players,
        const [
          Vote(voterId: 'player_1', targetId: 'player_0'),
          Vote(voterId: 'player_2', targetId: 'player_0'),
        ],
        'player_1',
      );
      expect(result.spyWasCaught, isFalse);
      expect(result.majorityTargetId, 'player_0');
    });
  });

  group('deriveOutcome', () {
    const caughtResult = VoteResult(
      tally: {},
      majorityTargetId: 'spy',
      isTie: false,
      spyWasCaught: true,
    );
    const uncaughtResult = VoteResult(
      tally: {},
      majorityTargetId: 'civilian',
      isTie: false,
      spyWasCaught: false,
    );
    const tieResult = VoteResult(tally: {}, majorityTargetId: null, isTie: true, spyWasCaught: false);

    test('caught and guessed correctly -> spy wins by guess', () {
      expect(deriveOutcome(caughtResult, spyGuessedCorrectly: true), Outcome.spyWinsByGuess);
    });

    test('caught and guessed wrong -> civilians win', () {
      expect(deriveOutcome(caughtResult, spyGuessedCorrectly: false), Outcome.civiliansWin);
    });

    test('not caught -> spy wins uncaught', () {
      expect(deriveOutcome(uncaughtResult), Outcome.spyWinsUncaught);
    });

    test('a tie is treated the same as the spy not being caught', () {
      expect(deriveOutcome(tieResult), Outcome.spyWinsUncaught);
    });
  });

  group('derivePenalty', () {
    test('returns null when Alco Mode is disabled', () {
      expect(derivePenalty(Outcome.civiliansWin, false), isNull);
    });

    test('civilians win -> spy drinks a full penalty shot', () {
      final penalty = derivePenalty(Outcome.civiliansWin, true)!;
      expect(penalty.target, PenaltyTarget.spy);
      expect(penalty.isFullShot, isTrue);
    });

    test('spy wins by guess -> all civilians drink 2 sips', () {
      final penalty = derivePenalty(Outcome.spyWinsByGuess, true)!;
      expect(penalty.target, PenaltyTarget.allCivilians);
      expect(penalty.sips, 2);
    });

    test('spy wins uncaught -> all civilians drink 1 sip', () {
      final penalty = derivePenalty(Outcome.spyWinsUncaught, true)!;
      expect(penalty.target, PenaltyTarget.allCivilians);
      expect(penalty.sips, 1);
    });
  });
}

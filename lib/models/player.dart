import 'role.dart';

class Player {
  final String id;
  final String name;
  final Role role;
  final bool hasSeenWord;
  final bool hasVoted;

  const Player({
    required this.id,
    required this.name,
    required this.role,
    this.hasSeenWord = false,
    this.hasVoted = false,
  });

  Player copyWith({
    String? name,
    Role? role,
    bool? hasSeenWord,
    bool? hasVoted,
  }) {
    return Player(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      hasSeenWord: hasSeenWord ?? this.hasSeenWord,
      hasVoted: hasVoted ?? this.hasVoted,
    );
  }
}

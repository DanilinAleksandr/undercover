import 'package:flutter/material.dart';

import '../../models/difficulty.dart';
import '../../models/theme_pair.dart';

const _e = Difficulty.easy;
const _m = Difficulty.medium;
const _h = Difficulty.hard;
const _x = Difficulty.expert;

const themeGamesCategory = ThemeCategory(
  id: 'theme_games',
  name: 'Игры',
  icon: Icons.sports_esports_outlined,
  pairs: [
    ThemePair('Гоночные игры', 'Шутеры', _e, 4),
    ThemePair('GTA', 'The Sims', _e, 4),
    ThemePair('World of Tanks', 'World of Warcraft', _e, 4),
    ThemePair('Игра «Мафия»', 'Монополия', _e, 5),
    ThemePair('Покемоны', 'Майнкрафт', _e, 4),

    ThemePair('Марио', 'Соник', _m, 5),
    ThemePair('Майнкрафт', 'Роблокс', _m, 4),
    ThemePair('Покер', 'Игра в дурака', _m, 4),
    ThemePair('Angry Birds', 'Subway Surfers', _m, 4),
    ThemePair('Герои меча и магии', 'Цивилизация', _m, 4),

    ThemePair('Ведьмак', 'Skyrim', _h, 4),
    ThemePair('Warcraft', 'StarCraft', _h, 4),
    ThemePair('Игры на Денди', 'Игры на Sega', _h, 5),
    ThemePair('Mortal Kombat', 'Tekken', _h, 4),
    ThemePair('Resident Evil', 'Silent Hill', _h, 4),
    ThemePair('Assassin’s Creed', 'Prince of Persia', _h, 4),

    ThemePair('Counter-Strike', 'Call of Duty', _x, 4),
    ThemePair('Dota 2', 'League of Legends', _x, 4),
    ThemePair('Fortnite', 'PUBG', _x, 4),
    ThemePair('Fallout', 'S.T.A.L.K.E.R.', _x, 5),
  ],
);

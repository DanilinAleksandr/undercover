import 'package:flutter/material.dart';

import '../../models/difficulty.dart';
import '../../models/theme_pair.dart';

const _e = Difficulty.easy;
const _m = Difficulty.medium;
const _h = Difficulty.hard;
const _x = Difficulty.expert;

const themeScreenCategory = ThemeCategory(
  id: 'theme_screen',
  name: 'Кино и сериалы',
  icon: Icons.movie_outlined,
  pairs: [
    ThemePair('Советские комедии', 'Голливудские боевики', _e, 4),
    ThemePair('Смешарики', 'Симпсоны', _e, 4),
    ThemePair('Пираты Карибского моря', 'Форсаж', _e, 4),
    ThemePair('Сериал «Друзья»', 'Игра престолов', _e, 4),
    ThemePair('Фильмы ужасов', 'Мелодрамы', _e, 4),

    ThemePair('Гарри Поттер', 'Звёздные войны', _m, 5),
    ThemePair('Шрек', 'Ледниковый период', _m, 5),
    ThemePair('Ну, погоди!', 'Том и Джерри', _m, 5),
    ThemePair('Матрица', 'Терминатор', _m, 4),
    ThemePair('Трое из Простоквашино', 'Бременские музыканты', _m, 4),

    ThemePair('Джеймс Бонд', 'Миссия невыполнима', _h, 4),
    ThemePair('Властелин колец', 'Хроники Нарнии', _h, 4),
    ThemePair('Мстители', 'Люди Икс', _h, 4),
    ThemePair('Шерлок Холмс', 'Эркюль Пуаро', _h, 5),
    ThemePair('Во все тяжкие', 'Декстер', _h, 4),
    ThemePair('Король Лев', 'Книга джунглей', _h, 4),
    ThemePair('Бригада', 'Крёстный отец', _h, 4),

    ThemePair('Пила', 'Пункт назначения', _x, 4),
    ThemePair('Сумерки', 'Дневники вампира', _x, 4),
    ThemePair('Универ', 'Интерны', _x, 4),
    ThemePair('Холодное сердце', 'Рапунцель', _x, 4),
  ],
);

import 'package:flutter/material.dart';

import '../../models/difficulty.dart';
import '../../models/theme_pair.dart';

const _e = Difficulty.easy;
const _m = Difficulty.medium;
const _h = Difficulty.hard;
const _x = Difficulty.expert;

const themeMusicCategory = ThemeCategory(
  id: 'theme_music',
  name: 'Музыка',
  icon: Icons.music_note_outlined,
  pairs: [
    ThemePair('Рок', 'Рэп', _e, 5),
    ThemePair('Классическая музыка', 'Джаз', _e, 4),
    ThemePair('Советская эстрада', 'K-pop', _e, 4),
    ThemePair('Электронная музыка', 'Кантри', _e, 4),

    ThemePair('Новогодние песни', 'Песни из мультфильмов', _m, 4),
    ThemePair('Духовые инструменты', 'Струнные инструменты', _m, 4),
    ThemePair('The Beatles', 'Queen', _m, 5),
    ThemePair('Опера', 'Балет', _m, 5),
    ThemePair('Рок-н-ролл', 'Диско', _m, 4),
    ThemePair('Хэви-метал', 'Панк', _m, 4),

    ThemePair('Группа «Кино»', 'ДДТ', _h, 4),
    ThemePair('Король и Шут', 'Сектор Газа', _h, 4),
    ThemePair('Майкл Джексон', 'Мадонна', _h, 4),
    ThemePair('Земфира', 'Мумий Тролль', _h, 4),
    ThemePair('Шансон', 'Бардовская песня', _h, 4),
    ThemePair('Nirvana', 'Linkin Park', _h, 4),

    ThemePair('Алла Пугачёва', 'София Ротару', _x, 4),
    ThemePair('Metallica', 'AC/DC', _x, 4),
    ThemePair('Руки Вверх!', 'Иванушки International', _x, 4),
    ThemePair('Баста', 'Каста', _x, 4),
  ],
);

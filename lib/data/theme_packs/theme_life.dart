import 'package:flutter/material.dart';

import '../../models/difficulty.dart';
import '../../models/theme_pair.dart';

const _e = Difficulty.easy;
const _m = Difficulty.medium;
const _h = Difficulty.hard;
const _x = Difficulty.expert;

const themeLifeCategory = ThemeCategory(
  id: 'theme_life',
  name: 'Жизнь вокруг',
  icon: Icons.local_cafe_outlined,
  pairs: [
    ThemePair('Итальянская кухня', 'Японская кухня', _e, 5),
    ThemePair('Футбол', 'Шахматы', _e, 4),
    ThemePair('Пляжный отдых', 'Горнолыжный курорт', _e, 4),
    ThemePair('Кошки', 'Собаки', _e, 5),
    ThemePair('Школа', 'Армия', _e, 4),

    ThemePair('Свадьба', 'Выпускной', _m, 5),
    ThemePair('Футбол', 'Хоккей', _m, 5),
    ThemePair('Мексиканская кухня', 'Индийская кухня', _m, 4),
    ThemePair('Баня', 'Спа-салон', _m, 4),
    ThemePair('Рыбалка', 'Охота', _m, 5),
    ThemePair('Дача', 'Поход', _m, 4),
    ThemePair('Новый год', 'День рождения', _m, 5),
    ThemePair('Бег', 'Велоспорт', _m, 4),

    ThemePair('IKEA', 'Леруа Мерлен', _h, 4),
    ThemePair('Кавказская кухня', 'Среднеазиатская кухня', _h, 4),
    ThemePair('Китайская кухня', 'Японская кухня', _h, 4),
    ThemePair('Бокс', 'Борьба', _h, 4),

    ThemePair('Макдоналдс', 'KFC', _x, 4),
    ThemePair('Apple', 'Samsung', _x, 4),
    ThemePair('Теннис', 'Бадминтон', _x, 4),
    ThemePair('Coca-Cola', 'Pepsi', _x, 4),
    ThemePair('Горные лыжи', 'Сноуборд', _x, 4),
  ],
);

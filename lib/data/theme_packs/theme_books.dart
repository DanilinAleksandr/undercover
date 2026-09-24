import 'package:flutter/material.dart';

import '../../models/difficulty.dart';
import '../../models/theme_pair.dart';

const _e = Difficulty.easy;
const _m = Difficulty.medium;
const _h = Difficulty.hard;
const _x = Difficulty.expert;

const themeBooksCategory = ThemeCategory(
  id: 'theme_books',
  name: 'Книги',
  icon: Icons.menu_book_outlined,
  pairs: [
    ThemePair('Сказки Пушкина', 'Басни Крылова', _e, 5),
    ThemePair('Детективы', 'Фантастика', _e, 4),
    ThemePair('Три мушкетёра', 'Остров сокровищ', _e, 4),
    ThemePair('Приключения Тома Сойера', 'Робинзон Крузо', _e, 4),
    ThemePair('Русские народные сказки', 'Мифы Древней Греции', _e, 4),
    ThemePair('Любовные романы', 'Фэнтези', _e, 4),

    ThemePair('Война и мир', 'Мастер и Маргарита', _m, 5),
    ThemePair('Незнайка', 'Буратино', _m, 5),
    ThemePair('Преступление и наказание', 'Мёртвые души', _m, 4),
    ThemePair('Мифы Древней Греции', 'Скандинавские мифы', _m, 5),
    ThemePair('Алиса в Стране чудес', 'Волшебник Изумрудного города', _m, 4),

    ThemePair('Евгений Онегин', 'Горе от ума', _h, 4),
    ThemePair('Стивен Кинг', 'Эдгар По', _h, 4),
    ThemePair('Чехов', 'Гоголь', _h, 4),
    ThemePair('Сказки Андерсена', 'Сказки братьев Гримм', _h, 4),
    ThemePair('Маленький принц', 'Алхимик', _h, 4),

    ThemePair('Пушкин', 'Лермонтов', _x, 4),
    ThemePair('Есенин', 'Маяковский', _x, 4),
    ThemePair('Толстой', 'Достоевский', _x, 5),
    ThemePair('Жюль Верн', 'Герберт Уэллс', _x, 4),
  ],
);

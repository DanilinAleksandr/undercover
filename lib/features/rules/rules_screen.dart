import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_palette.dart';
import '../../widgets/gradient_background.dart';
import '../../widgets/surface_card.dart';

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Как играть')),
      body: GradientBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.page, Gap.sm, Gap.page, Gap.xxl),
          children: const [
            _RuleSection(
              icon: Icons.groups_rounded,
              title: 'Расстановка',
              body:
                  'Большинство игроков получают одно и то же слово. Один случайный игрок — Шпион — получает похожее, но другое слово.',
            ),
            _RuleSection(
              icon: Icons.phonelink_lock_rounded,
              title: 'Показ карт',
              body:
                  'Телефон передаётся по кругу. Каждый игрок приватно видит своё слово и подтверждает это.',
            ),
            _RuleSection(
              icon: Icons.record_voice_over_rounded,
              title: 'Ассоциации и обсуждение',
              body:
                  'Дальше говорите вслух, не показывая на телефоне. Сколько кругов сыграть, кто начинает и в каком порядке — решаете за столом; приложение очередь не ведёт.',
            ),
            _RuleSection(
              icon: Icons.how_to_vote_rounded,
              title: 'Голосование',
              body:
                  'Каждый игрок тайно голосует, передавая телефон по кругу. Голосовать за себя нельзя.',
            ),
            _RuleSection(
              icon: Icons.emoji_events_rounded,
              title: 'Победа',
              body:
                  'Если большинство поймало Шпиона — у него есть последний шанс угадать слово мирных. Угадал — побеждает Шпион, не угадал — мирные. Если большинство ошиблось (или голоса разделились) — побеждает Шпион.',
            ),
            _RuleSection(
              icon: Icons.local_bar_rounded,
              title: 'Алко-режим',
              body:
                  'Шпион пойман и не угадал — пьёт штрафной стакан. Шпион пойман и угадал — все мирные пьют по 2 глотка. Мирного выгнали по ошибке — все мирные пьют по 1 глотку.',
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _RuleSection({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: SurfaceCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(icon, color: AppColors.gold, size: 19),
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15.5,
                    ),
                  ),
                  const SizedBox(height: Gap.xs + 2),
                  Text(
                    body,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

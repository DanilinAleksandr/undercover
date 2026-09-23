import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimens.dart';
import '../theme/app_text.dart';
import 'app_button.dart';
import 'game_settings_button.dart';
import 'gradient_background.dart';
import 'player_avatar.dart';
import 'surface_card.dart';

/// The shared "pass the phone" ritual screen, reused for the reveal hand-off
/// and the voting hand-off so the most repeated moment of the game always
/// looks and behaves the same.
class PassDeviceScaffold extends StatefulWidget {
  final String eyebrow;
  final String playerName;
  final String message;
  final String buttonLabel;
  final VoidCallback onConfirm;
  final IconData icon;
  final Gradient accent;

  const PassDeviceScaffold({
    super.key,
    required this.eyebrow,
    required this.playerName,
    required this.message,
    required this.buttonLabel,
    required this.onConfirm,
    this.icon = Icons.phonelink_lock_rounded,
    this.accent = AppColors.spyGradient,
  });

  @override
  State<PassDeviceScaffold> createState() => _PassDeviceScaffoldState();
}

class _PassDeviceScaffoldState extends State<PassDeviceScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    // A single settling halo marks the arrival of a new player. Deliberately
    // one-shot: a looping animation here would never let the frame settle,
    // which costs battery through a long party.
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    )..forward();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accent.colors.first;

    return Scaffold(
      body: GradientBackground(
        accentGlow: widget.accent,
        intense: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, Gap.lg, Gap.page, Gap.lg),
            child: Column(
              children: [
                const GameSettingsButton(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: Gap.lg),
                          CountPill(text: widget.eyebrow, accent: accentColor),
                          const SizedBox(height: Gap.huge),
                          AnimatedBuilder(
                            animation: _pulse,
                            builder: (context, child) {
                              final t = Curves.easeOutBack.transform(_pulse.value);
                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accentColor.withValues(alpha: 0.14),
                                ),
                                child: Transform.scale(
                                  scale: 0.82 + 0.18 * t.clamp(0.0, 1.2),
                                  child: child,
                                ),
                              );
                            },
                            child: PlayerAvatar(name: widget.playerName, size: 96),
                          ),
                          const SizedBox(height: Gap.xl),
                          Text(
                            'Телефон переходит к',
                            style: AppText.caption(context),
                          ),
                          const SizedBox(height: Gap.xs),
                          Text(
                            widget.playerName,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.playerName(context, size: 32),
                          ),
                          const SizedBox(height: Gap.lg),
                          SurfaceCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: Gap.lg, vertical: Gap.md),
                            child: Row(
                              children: [
                                Icon(widget.icon, size: 20, color: accentColor),
                                const SizedBox(width: Gap.md),
                                Expanded(
                                  child: Text(
                                    widget.message,
                                    style: AppText.body(context)
                                        .copyWith(fontSize: 13.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: Gap.lg),
                        ],
                      ),
                    ),
                  ),
                ),
                AppButton(
                  label: widget.buttonLabel,
                  icon: Icons.touch_app_rounded,
                  onPressed: widget.onConfirm,
                  gradient: widget.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

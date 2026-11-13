import 'package:flutter/material.dart';

import '../../../../app/localization/generated/app_localizations.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/trade_square_discover_models.dart';
import 'discover_icons.dart';
import 'discover_network_image.dart';
import 'discover_voice_listener.dart';

class DiscoverHeroSearch extends StatefulWidget {
  const DiscoverHeroSearch({
    required this.controller,
    required this.focusNode,
    required this.locale,
    required this.onLocaleChanged,
    required this.onSubmit,
    required this.onExampleTap,
    this.enabled = true,
    this.voiceListener,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final VoidCallback onSubmit;
  final ValueChanged<String> onExampleTap;
  final bool enabled;
  final DiscoverVoiceListener? voiceListener;

  @override
  State<DiscoverHeroSearch> createState() => _DiscoverHeroSearchState();
}

class _DiscoverHeroSearchState extends State<DiscoverHeroSearch>
    with SingleTickerProviderStateMixin {
  late final DiscoverVoiceListener _voice =
      widget.voiceListener ?? DiscoverVoiceListener();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _ownsVoice = false;
  bool _listening = false;
  String? _voiceStatus;

  @override
  void initState() {
    super.initState();
    _ownsVoice = widget.voiceListener == null;
    widget.focusNode.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(covariant DiscoverHeroSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocus);
      widget.focusNode.addListener(_onFocus);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocus);
    _pulse.dispose();
    if (_ownsVoice) {
      _voice.dispose();
    }
    super.dispose();
  }

  void _onFocus() => setState(() {});

  String _speechLocaleId(Locale locale) {
    return switch (locale.languageCode) {
      'fr' => 'fr_FR',
      'sw' => 'sw_KE',
      'rw' => 'rw_RW',
      _ => 'en_US',
    };
  }

  Future<void> _toggleVoice() async {
    if (!widget.enabled) return;
    final localizations = AppLocalizations.of(context)!;

    if (_listening) {
      await _voice.stop();
      if (!mounted) return;
      setState(() {
        _listening = false;
        _voiceStatus = null;
      });
      _pulse.stop();
      _pulse.reset();
      return;
    }

    setState(() {
      _voiceStatus = localizations.discoverVoicePreparing;
    });

    try {
      final ready = await _voice.ensureReady();
      if (!mounted) return;
      if (!ready) {
        setState(() => _voiceStatus = localizations.discoverVoiceUnavailable);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.deepBlue,
            content: Text(localizations.discoverVoiceUnavailable),
          ),
        );
        return;
      }

      setState(() {
        _listening = true;
        _voiceStatus = localizations.discoverVoiceListening;
      });
      _pulse.repeat(reverse: true);

      await _voice.start(
        localeId: _speechLocaleId(widget.locale),
        onPartial: (text) {
          if (!mounted) return;
          widget.controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          setState(() => _voiceStatus = localizations.discoverVoiceListening);
        },
        onFinal: (text) async {
          if (!mounted) return;
          widget.controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
          setState(() {
            _listening = false;
            _voiceStatus = localizations.discoverVoiceCaptured;
          });
          _pulse.stop();
          _pulse.reset();
          await _voice.stop();
          if (text.trim().isNotEmpty) {
            widget.onSubmit();
          }
        },
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listening = false;
        _voiceStatus = localizations.discoverVoiceUnavailable;
      });
      _pulse.stop();
      _pulse.reset();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.deepBlue,
          content: Text(localizations.discoverVoiceUnavailable),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final focused = widget.focusNode.hasFocus;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 768;

    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 24 : 28),
        child: Stack(
          children: [
            Positioned.fill(
              child: DiscoverNetworkImage(
                url: tradeSquareDiscoverHeroImage,
                fallbackIcon: DiscoverIcons.spark,
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.deepBlue.withValues(alpha: 0.55),
                      AppColors.deepBlue.withValues(alpha: 0.82),
                      AppColors.primary.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 24,
                compact ? 16 : 20,
                compact ? 16 : 24,
                compact ? 14 : 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.white.withValues(alpha: 0.22),
                            ),
                          ),
                          child: const Icon(
                            DiscoverIcons.spark,
                            color: AppColors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                localizations.discoverAiBadge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.white.withValues(alpha: 0.88),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                localizations.discoverHeroTitle,
                                maxLines: compact ? 2 : 3,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: compact ? 24 : 30,
                                  height: 1.12,
                                  letterSpacing: -0.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _LanguageChip(
                          locale: widget.locale,
                          onLocaleChanged: widget.onLocaleChanged,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      compact
                          ? localizations.discoverHeroSubtitleMobile
                          : localizations.discoverHeroSubtitle,
                      maxLines: compact ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.92),
                        fontSize: compact ? 13.5 : 15,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: compact ? 14 : 18),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.fromLTRB(
                        compact ? 12 : 14,
                        compact ? 8 : 6,
                        6,
                        compact ? 8 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(compact ? 22 : 18),
                        border: Border.all(
                          color: _listening
                              ? AppColors.primary
                              : focused
                                  ? AppColors.lightBlue
                                  : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (_listening
                                    ? AppColors.primary
                                    : AppColors.deepBlue)
                                .withValues(alpha: _listening ? 0.28 : 0.12),
                            blurRadius: _listening ? 24 : 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  bottom: compact ? 10 : 12,
                                ),
                                child: Icon(
                                  _listening
                                      ? Icons.graphic_eq_rounded
                                      : DiscoverIcons.search,
                                  color: _listening
                                      ? AppColors.primary
                                      : AppColors.secondaryText,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  key: const ValueKey('discover-ai-search'),
                                  controller: widget.controller,
                                  focusNode: widget.focusNode,
                                  enabled: widget.enabled,
                                  minLines: 1,
                                  maxLines: compact ? 2 : 3,
                                  textInputAction: TextInputAction.search,
                                  onSubmitted: (_) => widget.onSubmit(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                    color: AppColors.text,
                                    height: 1.35,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _listening
                                        ? localizations.discoverVoiceHint
                                        : localizations.discoverSearchHint,
                                    hintStyle: const TextStyle(
                                      color: AppColors.secondaryText,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _VoiceButton(
                                listening: _listening,
                                pulse: _pulse,
                                onPressed: _toggleVoice,
                                tooltip: _listening
                                    ? localizations.discoverVoiceStop
                                    : localizations.topBarVoiceSearch,
                              ),
                              const SizedBox(width: 6),
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: widget.controller,
                                builder: (context, value, _) {
                                  final enabled = widget.enabled &&
                                      value.text.trim().isNotEmpty &&
                                      !_listening;
                                  return FilledButton(
                                    onPressed: enabled ? widget.onSubmit : null,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      disabledBackgroundColor: AppColors.primary
                                          .withValues(alpha: 0.35),
                                      foregroundColor: AppColors.white,
                                      minimumSize: Size(
                                        compact ? 44 : 0,
                                        44,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: compact ? 12 : 16,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: compact
                                        ? const Icon(DiscoverIcons.spark,
                                            size: 20)
                                        : Text(
                                            localizations.discoverSearchAction,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                  );
                                },
                              ),
                            ],
                          ),
                          if (_voiceStatus != null) ...[
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _voiceStatus!,
                                style: TextStyle(
                                  color: _listening
                                      ? AppColors.primary
                                      : AppColors.secondaryText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      localizations.discoverTryExamples,
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.84),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: tradeSquareDiscoverExamplePrompts.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final prompt =
                              tradeSquareDiscoverExamplePrompts[index];
                          return _ExampleChip(
                            label: prompt,
                            onTap: () => widget.onExampleTap(prompt),
                          );
                        },
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

class _VoiceButton extends StatelessWidget {
  const _VoiceButton({
    required this.listening,
    required this.pulse,
    required this.onPressed,
    required this.tooltip,
  });

  final bool listening;
  final AnimationController pulse;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final scale = listening ? 1 + (pulse.value * 0.08) : 1.0;
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Material(
          color: listening
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(
                listening ? Icons.stop_rounded : Icons.mic_none_rounded,
                color: listening ? AppColors.primary : AppColors.deepBlue,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({
    required this.locale,
    required this.onLocaleChanged,
  });

  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  Widget build(BuildContext context) {
    final locales = AppLocalizations.supportedLocales;
    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<Locale>(
        tooltip: AppLocalizations.of(context)!.topBarLanguage,
        onSelected: onLocaleChanged,
        itemBuilder: (context) => [
          for (final item in locales)
            PopupMenuItem(
              value: item,
              child: Text(item.languageCode.toUpperCase()),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.white.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                DiscoverIcons.language,
                size: 16,
                color: AppColors.white,
              ),
              const SizedBox(width: 6),
              Text(
                locale.languageCode.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

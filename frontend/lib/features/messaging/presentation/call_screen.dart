import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:livekit_client/livekit_client.dart';

import '../../../app/theme/app_colors.dart';
import '../data/livekit_call_connection.dart';
import '../domain/call_models.dart';
import 'widgets/call_controls.dart';
import 'widgets/local_webcam_preview.dart';
import 'widgets/messaging_avatar.dart';

class TradeSquareCallScreen extends StatefulWidget {
  const TradeSquareCallScreen({
    required this.initialSession,
    this.localIdentity,
    this.localDisplayName,
    super.key,
  });

  final TradeSquareCallSession initialSession;
  final String? localIdentity;
  final String? localDisplayName;

  @override
  State<TradeSquareCallScreen> createState() => _TradeSquareCallScreenState();
}

class _TradeSquareCallScreenState extends State<TradeSquareCallScreen>
    with TickerProviderStateMixin {
  late TradeSquareCallSession _session = widget.initialSession;
  late final TradeSquareLiveKitCallConnection _liveKit =
      TradeSquareLiveKitCallConnection();
  late final String _identity = widget.localIdentity?.trim().isNotEmpty == true
      ? widget.localIdentity!.trim()
      : 'guest-${DateTime.now().microsecondsSinceEpoch}';
  Timer? _phaseTimer;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    if (_session.isVideo && !_session.isCameraOn) {
      _session = _session.copyWith(isCameraOn: true);
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _liveKit.addListener(_onLiveKitChanged);
    _advancePhase();
    if (_session.phase != TradeSquareCallPhase.incoming) {
      _joinLiveKit();
    }
  }

  void _onLiveKitChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _joinLiveKit() {
    return _liveKit.connect(
      session: _session,
      identity: _identity,
      displayName: widget.localDisplayName?.trim().isNotEmpty == true
          ? widget.localDisplayName!.trim()
          : 'TradeSquare member',
    );
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    _ticker?.cancel();
    _liveKit.removeListener(_onLiveKitChanged);
    _liveKit.close();
    _pulseController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _advancePhase() {
    if (_session.phase == TradeSquareCallPhase.outgoing) {
      _phaseTimer = Timer(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        setState(() {
          _session = _session.copyWith(phase: TradeSquareCallPhase.connecting);
        });
        _advancePhase();
      });
      return;
    }

    if (_session.phase == TradeSquareCallPhase.connecting) {
      _phaseTimer = Timer(const Duration(milliseconds: 900), () {
        if (!mounted) return;
        setState(() {
          _session = _session.copyWith(
            phase: TradeSquareCallPhase.active,
            startedAt: DateTime.now(),
          );
        });
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted || _session.startedAt == null) return;
          setState(() {
            _elapsed = DateTime.now().difference(_session.startedAt!);
          });
        });
      });
    }
  }

  void _acceptIncoming() {
    setState(() {
      _session = _session.copyWith(phase: TradeSquareCallPhase.connecting);
    });
    _advancePhase();
    _joinLiveKit();
  }

  void _endCall() {
    _phaseTimer?.cancel();
    _ticker?.cancel();
    setState(() {
      _session = _session.copyWith(phase: TradeSquareCallPhase.ended);
    });
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  Future<void> _openLanguageSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _LanguageSheet(
        currentCode: _session.localLanguageCode,
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _session = _session.copyWith(localLanguageCode: selected);
    });
  }

  Widget? _remoteVideoView() {
    final track = _liveKit.remoteVideo;
    if (track == null) return null;
    return VideoTrackRenderer(track, fit: VideoViewFit.cover);
  }

  Widget _selfPreview() {
    final track = _liveKit.localVideo;
    if (track != null) {
      return VideoTrackRenderer(
        track,
        fit: VideoViewFit.cover,
        mirrorMode: VideoViewMirrorMode.mirror,
      );
    }
    if (_liveKit.connecting) {
      return const ColoredBox(
        color: AppColors.deepBlue,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.white),
        ),
      );
    }
    if (_session.isCameraOn && _liveKit.error != null) {
      return const TradeSquareLocalWebcam();
    }
    return const ColoredBox(
      color: AppColors.deepBlue,
      child: Center(
        child: Icon(Icons.videocam_off_rounded, color: AppColors.white),
      ),
    );
  }

  String get _statusLabel {
    return switch (_session.phase) {
      TradeSquareCallPhase.outgoing => 'Calling…',
      TradeSquareCallPhase.incoming => _session.isVideo
          ? 'Incoming video call'
          : 'Incoming audio call',
      TradeSquareCallPhase.connecting => 'Connecting…',
      TradeSquareCallPhase.active => _formatElapsed(_elapsed),
      TradeSquareCallPhase.ended => 'Call ended',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_session.isVideo) {
      return _InstagramVideoCall(
        session: _session,
        statusLabel: _statusLabel,
        pulse: _pulseController,
        onClose: _endCall,
        onEnd: _endCall,
        onAccept: _acceptIncoming,
        onToggleMute: () {
          final muted = !_session.isMuted;
          setState(() => _session = _session.copyWith(isMuted: muted));
          _liveKit.setMicrophone(!muted);
        },
        onToggleSpeaker: () => setState(() {
          _session = _session.copyWith(isSpeakerOn: !_session.isSpeakerOn);
        }),
        onToggleCamera: () {
          final enabled = !_session.isCameraOn;
          setState(() => _session = _session.copyWith(isCameraOn: enabled));
          _liveKit.setCamera(enabled);
        },
        onLanguage: _openLanguageSheet,
        remoteVideo: _remoteVideoView(),
        selfPreview: _selfPreview(),
      );
    }

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.deepBlue,
              Color(0xFF003064),
              Color(0xFF001A38),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                _CallTopBar(
                  session: _session,
                  onClose: _endCall,
                ),
                const SizedBox(height: 18),
                TradeSquareTranslationStatusChip(session: _session),
                const SizedBox(height: 28),
                Expanded(
                  child: _AudioStage(
                    session: _session,
                    statusLabel: _statusLabel,
                    pulse: _pulseController,
                  ),
                ),
                TradeSquareCaptionPanel(session: _session),
                const SizedBox(height: 18),
                if (_session.phase == TradeSquareCallPhase.incoming)
                  _IncomingActions(
                    onDecline: _endCall,
                    onAccept: _acceptIncoming,
                    isVideo: _session.isVideo,
                  )
                else
                  TradeSquareCallControlBar(
                    session: _session,
                    onToggleMute: () => setState(() {
                      _session = _session.copyWith(isMuted: !_session.isMuted);
                    }),
                    onToggleSpeaker: () => setState(() {
                      _session =
                          _session.copyWith(isSpeakerOn: !_session.isSpeakerOn);
                    }),
                    onToggleCamera: () => setState(() {
                      _session =
                          _session.copyWith(isCameraOn: !_session.isCameraOn);
                    }),
                    onToggleCaptions: () => setState(() {
                      _session = _session.copyWith(
                        areCaptionsOn: !_session.areCaptionsOn,
                      );
                    }),
                    onToggleTranslation: () => setState(() {
                      _session = _session.copyWith(
                        translationEnabled: !_session.translationEnabled,
                      );
                    }),
                    onLanguage: _openLanguageSheet,
                    onEnd: _endCall,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CallTopBar extends StatelessWidget {
  const _CallTopBar({
    required this.session,
    required this.onClose,
  });

  final TradeSquareCallSession session;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Icon(
                session.isVideo
                    ? Icons.videocam_rounded
                    : Icons.call_rounded,
                size: 16,
                color: AppColors.lightBlue,
              ),
              const SizedBox(width: 6),
              Text(
                session.isVideo ? 'Video' : 'Audio',
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close_rounded, color: AppColors.white),
        ),
      ],
    );
  }
}

class _AudioStage extends StatelessWidget {
  const _AudioStage({
    required this.session,
    required this.statusLabel,
    required this.pulse,
  });

  final TradeSquareCallSession session;
  final String statusLabel;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: pulse,
          builder: (context, child) {
            final scale = 1 + (pulse.value * 0.06);
            return Transform.scale(
              scale: scale,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.lightBlue
                        .withValues(alpha: 0.25 + pulse.value * 0.35),
                    width: 2,
                  ),
                ),
                child: child,
              ),
            );
          },
          child: TradeSquareMessagingAvatar(
            participant: session.participant,
            size: 128,
            showOnline: false,
            showVerified: true,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          session.participant.displayName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          session.participant.businessName,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.lightBlue.withValues(alpha: 0.95),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            statusLabel,
            key: ValueKey(statusLabel),
            style: TextStyle(
              color: AppColors.white.withValues(alpha: 0.82),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _InstagramVideoCall extends StatelessWidget {
  const _InstagramVideoCall({
    required this.session,
    required this.statusLabel,
    required this.pulse,
    required this.onClose,
    required this.onEnd,
    required this.onAccept,
    required this.onToggleMute,
    required this.onToggleSpeaker,
    required this.onToggleCamera,
    required this.onLanguage,
    this.remoteVideo,
    this.selfPreview,
  });

  final TradeSquareCallSession session;
  final String statusLabel;
  final AnimationController pulse;
  final VoidCallback onClose;
  final VoidCallback onEnd;
  final VoidCallback onAccept;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onToggleCamera;
  final VoidCallback onLanguage;
  final Widget? remoteVideo;
  final Widget? selfPreview;

  @override
  Widget build(BuildContext context) {
    final participant = session.participant;
    return Scaffold(
      backgroundColor: const Color(0xFF001A38),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.deepBlue,
                  Color(0xFF003064),
                  Color(0xFF001A38),
                ],
              ),
            ),
          ),
          if (remoteVideo != null) Positioned.fill(child: remoteVideo!),
          if (remoteVideo == null)
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 72),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: pulse,
                        builder: (context, child) => Transform.scale(
                          scale: session.phase == TradeSquareCallPhase.active
                              ? 1
                              : 1 + pulse.value * 0.04,
                          child: child,
                        ),
                        child: TradeSquareMessagingAvatar(
                          participant: participant,
                          size: 132,
                          showOnline: false,
                          showVerified: true,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        participant.displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.82),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 196),
              ],
            ),
          ),
          if (session.phase != TradeSquareCallPhase.incoming)
            _CallerPreview(child: selfPreview),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    _RoundOverlayButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      onTap: onClose,
                    ),
                    const Spacer(),
                    _RoundOverlayButton(
                      icon: Icons.translate_rounded,
                      onTap: onLanguage,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: session.phase == TradeSquareCallPhase.incoming
                    ? _IncomingActions(
                        onDecline: onEnd,
                        onAccept: onAccept,
                        isVideo: true,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TradeSquareCallControlButton(
                            icon: session.isMuted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            label: 'Mute',
                            showLabel: false,
                            active: session.isMuted,
                            onTap: onToggleMute,
                          ),
                          TradeSquareCallControlButton(
                            icon: session.isCameraOn
                                ? Icons.videocam_rounded
                                : Icons.videocam_off_rounded,
                            label: 'Camera',
                            showLabel: false,
                            active: !session.isCameraOn,
                            onTap: onToggleCamera,
                          ),
                          TradeSquareCallControlButton(
                            icon: session.isSpeakerOn
                                ? Icons.volume_up_rounded
                                : Icons.hearing_rounded,
                            label: 'Speaker',
                            showLabel: false,
                            active: session.isSpeakerOn,
                            onTap: onToggleSpeaker,
                          ),
                          TradeSquareCallControlButton(
                            icon: Icons.call_end_rounded,
                            label: 'End',
                            showLabel: false,
                            danger: true,
                            onTap: onEnd,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CallerPreview extends StatelessWidget {
  const _CallerPreview({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.bottomRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 16, bottom: 108),
          child: Container(
            width: 112,
            height: 168,
            decoration: BoxDecoration(
              color: AppColors.deepBlue,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: child ??
                const ColoredBox(
                  color: AppColors.deepBlue,
                  child: Center(
                    child: Icon(
                      Icons.videocam_off_rounded,
                      color: AppColors.white,
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
  }
}

class _RoundOverlayButton extends StatelessWidget {
  const _RoundOverlayButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: AppColors.white),
        ),
      ),
    );
  }
}

class _IncomingActions extends StatelessWidget {
  const _IncomingActions({
    required this.onDecline,
    required this.onAccept,
    required this.isVideo,
  });

  final VoidCallback onDecline;
  final VoidCallback onAccept;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: _IncomingButton(
              label: 'Decline',
              icon: Icons.call_end_rounded,
              color: const Color(0xFFE11D48),
              onTap: onDecline,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _IncomingButton(
              label: isVideo ? 'Join video' : 'Accept',
              icon: isVideo ? Icons.videocam_rounded : Icons.call_rounded,
              color: const Color(0xFF16A34A),
              onTap: onAccept,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingButton extends StatefulWidget {
  const _IncomingButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_IncomingButton> createState() => _IncomingButtonState();
}

class _IncomingButtonState extends State<_IncomingButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, color: AppColors.white),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageSheet extends StatelessWidget {
  const _LanguageSheet({required this.currentCode});

  final String currentCode;

  static const _options = ['en', 'rw', 'fr', 'sw'];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Your call language',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Same-language calls skip AI translation. Different languages turn it on.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, height: 1.35),
            ),
          ),
          const SizedBox(height: 12),
          for (final code in _options)
            ListTile(
              onTap: () => Navigator.of(context).pop(code),
              leading: Icon(
                code == currentCode
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: AppColors.primary,
              ),
              title: Text(
                tradeSquareLanguageLabel(code),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _formatElapsed(Duration elapsed) {
  final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hours = elapsed.inHours;
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

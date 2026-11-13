import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/messaging_models.dart';

class TradeSquareMessagingAvatar extends StatelessWidget {
  const TradeSquareMessagingAvatar({
    required this.participant,
    this.size = 52,
    this.showOnline = true,
    this.showVerified = false,
    super.key,
  });

  final TradeSquareChatParticipant participant;
  final double size;
  final bool showOnline;
  final bool showVerified;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepBlue.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: participant.photoUrl == null
                  ? _InitialsFallback(participant: participant, size: size)
                  : Image.network(
                      participant.photoUrl!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _InitialsFallback(participant: participant, size: size),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return _InitialsFallback(
                          participant: participant,
                          size: size,
                        );
                      },
                    ),
            ),
          ),
          if (showOnline && participant.isOnline)
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
              ),
            ),
          if (showVerified && participant.isVerified)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified,
                  size: size * 0.32,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({
    required this.participant,
    required this.size,
  });

  final TradeSquareChatParticipant participant;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.deepBlue],
        ),
      ),
      child: Text(
        participant.initials,
        style: TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.32,
        ),
      ),
    );
  }
}

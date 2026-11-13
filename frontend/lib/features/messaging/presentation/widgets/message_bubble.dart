import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/messaging_models.dart';

class TradeSquareMessageBubble extends StatelessWidget {
  const TradeSquareMessageBubble({
    required this.message,
    required this.showTail,
    super.key,
  });

  final TradeSquareChatMessage message;
  final bool showTail;

  @override
  Widget build(BuildContext context) {
    if (message.kind == TradeSquareMessageKind.system) {
      return _SystemChip(text: message.text);
    }

    final mine = message.isMine;
    final bubble = switch (message.kind) {
      TradeSquareMessageKind.image => _AttachmentBubble(
          message: message,
          mine: mine,
          icon: Icons.image_outlined,
          title: 'Photo',
          subtitle: message.attachmentLabel ?? 'Image attachment',
        ),
      TradeSquareMessageKind.voice => _VoiceBubble(
          message: message,
          mine: mine,
        ),
      TradeSquareMessageKind.attachment => _AttachmentBubble(
          message: message,
          mine: mine,
          icon: Icons.insert_drive_file_outlined,
          title: message.attachmentLabel ?? 'Attachment',
          subtitle: 'Ready to review',
        ),
      _ => _TextBubble(message: message, mine: mine, showTail: showTail),
    };

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        child: bubble,
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({
    required this.message,
    required this.mine,
    required this.showTail,
  });

  final TradeSquareChatMessage message;
  final bool mine;
  final bool showTail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        top: 2,
        bottom: 2,
        left: mine ? 48 : 0,
        right: mine ? 0 : 48,
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        gradient: mine
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.deepBlue],
              )
            : null,
        color: mine ? null : AppColors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine || !showTail ? 18 : 6),
          bottomRight: Radius.circular(!mine || !showTail ? 18 : 6),
        ),
        border: mine ? null : Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: mine ? 0.16 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: TextStyle(
              color: mine ? AppColors.white : AppColors.text,
              fontSize: 14.5,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(message.sentAt),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: mine
                      ? AppColors.white.withValues(alpha: 0.78)
                      : AppColors.secondaryText,
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 4),
                Icon(
                  message.status == TradeSquareMessageStatus.read
                      ? Icons.done_all_rounded
                      : Icons.done_rounded,
                  size: 14,
                  color: message.status == TradeSquareMessageStatus.read
                      ? AppColors.lightBlue
                      : AppColors.white.withValues(alpha: 0.8),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  const _VoiceBubble({required this.message, required this.mine});

  final TradeSquareChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        color: mine ? AppColors.primary : AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: mine ? null : Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: mine
                  ? AppColors.white.withValues(alpha: 0.18)
                  : AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              color: mine ? AppColors.white : AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: mine
                        ? AppColors.white.withValues(alpha: 0.35)
                        : AppColors.lightBlue.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message.durationLabel ?? '0:00',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: mine ? AppColors.white : AppColors.deepBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentBubble extends StatelessWidget {
  const _AttachmentBubble({
    required this.message,
    required this.mine,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final TradeSquareChatMessage message;
  final bool mine;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: mine ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.deepBlue.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.download_outlined, color: AppColors.primary),
        ],
      ),
    );
  }
}

class _SystemChip extends StatelessWidget {
  const _SystemChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

String _formatTime(DateTime timestamp) {
  final local = timestamp.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

class TradeSquareDaySeparator extends StatelessWidget {
  const TradeSquareDaySeparator({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.border)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }
}

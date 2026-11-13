import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../domain/messaging_models.dart';
import 'messaging_avatar.dart';

class TradeSquareConversationTile extends StatefulWidget {
  const TradeSquareConversationTile({
    required this.conversation,
    required this.onTap,
    super.key,
  });

  final TradeSquareConversationPreview conversation;
  final VoidCallback onTap;

  @override
  State<TradeSquareConversationTile> createState() =>
      _TradeSquareConversationTileState();
}

class _TradeSquareConversationTileState
    extends State<TradeSquareConversationTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final conversation = widget.conversation;
    final unread = conversation.hasUnread;

    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onHighlightChanged: (value) => setState(() => _pressed = value),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
            decoration: BoxDecoration(
              color: unread
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : AppColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: unread
                    ? AppColors.lightBlue.withValues(alpha: 0.55)
                    : AppColors.border.withValues(alpha: 0.9),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepBlue.withValues(alpha: unread ? 0.07 : 0.04),
                  blurRadius: unread ? 16 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                TradeSquareMessagingAvatar(
                  participant: conversation.participant,
                  size: 54,
                  showVerified: true,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.participant.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight:
                                    unread ? FontWeight.w800 : FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimestamp(conversation.lastMessageAt),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w500,
                              color: unread
                                  ? AppColors.primary
                                  : AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        conversation.participant.businessName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.25,
                                fontWeight:
                                    unread ? FontWeight.w600 : FontWeight.w500,
                                color: unread
                                    ? AppColors.text
                                    : AppColors.secondaryText,
                              ),
                            ),
                          ),
                          if (conversation.isMuted) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.notifications_off_outlined,
                              size: 15,
                              color: AppColors.secondaryText,
                            ),
                          ],
                          if (unread) ...[
                            const SizedBox(width: 8),
                            Container(
                              constraints: const BoxConstraints(minWidth: 22),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                conversation.unreadCount > 9
                                    ? '9+'
                                    : '${conversation.unreadCount}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final local = timestamp.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final difference = today.difference(day).inDays;

    if (difference == 0) {
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      final suffix = local.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $suffix';
    }
    if (difference == 1) return 'Yesterday';
    if (difference < 7) {
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[local.weekday - 1];
    }
    return '${local.day}/${local.month}';
  }
}

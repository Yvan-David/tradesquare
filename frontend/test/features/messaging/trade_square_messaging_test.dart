import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tradesquare/app/theme/app_theme.dart';
import 'package:tradesquare/features/messaging/data/messaging_repository.dart';
import 'package:tradesquare/features/messaging/domain/call_models.dart';
import 'package:tradesquare/features/messaging/domain/messaging_models.dart';
import 'package:tradesquare/features/messaging/presentation/messages_page.dart';

import '../../fixtures/catalog_test_fixture.dart';

class _OfflinePhotoMessagingRepository extends TradeSquareMockMessagingRepository {
  @override
  Future<List<TradeSquareConversationPreview>> fetchConversations({
    String? query,
    TradeSquareConversationFilter filter = TradeSquareConversationFilter.all,
  }) async {
    final results = await super.fetchConversations(query: query, filter: filter);
    return [
      for (final conversation in results)
        TradeSquareConversationPreview(
          id: conversation.id,
          participant: TradeSquareChatParticipant(
            id: conversation.participant.id,
            displayName: conversation.participant.displayName,
            businessName: conversation.participant.businessName,
            preferredLanguage: conversation.participant.preferredLanguage,
            roleLabel: conversation.participant.roleLabel,
            isOnline: conversation.participant.isOnline,
            isVerified: conversation.participant.isVerified,
          ),
          lastMessage: conversation.lastMessage,
          lastMessageAt: conversation.lastMessageAt,
          unreadCount: conversation.unreadCount,
          relationship: conversation.relationship,
          isPinned: conversation.isPinned,
          isMuted: conversation.isMuted,
        ),
    ];
  }

  @override
  Future<TradeSquareConversationDetail?> fetchConversation(String id) async {
    final detail = await super.fetchConversation(id);
    if (detail == null) return null;
    return TradeSquareConversationDetail(
      id: detail.id,
      participant: TradeSquareChatParticipant(
        id: detail.participant.id,
        displayName: detail.participant.displayName,
        businessName: detail.participant.businessName,
        preferredLanguage: detail.participant.preferredLanguage,
        roleLabel: detail.participant.roleLabel,
        isOnline: detail.participant.isOnline,
        isVerified: detail.participant.isVerified,
      ),
      messages: detail.messages,
      relationship: detail.relationship,
      unreadCount: detail.unreadCount,
    );
  }
}

void main() {
  setUpAll(loadCatalogTestFixture);

  testWidgets('messages page lists conversations and opens a chat',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: TradeSquareMessagesPage(
          repository: _OfflinePhotoMessagingRepository(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.text('Miriam Kamanzi'), findsOneWidget);
    expect(find.text('Duncan Muriithi'), findsOneWidget);

    await tester.tap(find.text('Miriam Kamanzi'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Audio call'), findsOneWidget);
    expect(find.byTooltip('Video call'), findsOneWidget);
    expect(
      find.textContaining('carton packaging', findRichText: true),
      findsWidgets,
    );
  });

  test('same-language calls bypass translation', () {
    final session = TradeSquareCallSession(
      id: 'c1',
      conversationId: 'conv_001',
      participant: const TradeSquareChatParticipant(
        id: 'usr_003',
        displayName: 'Miriam Kamanzi',
        businessName: 'ElevatePack Uganda',
        preferredLanguage: 'en',
      ),
      media: TradeSquareCallMedia.audio,
      phase: TradeSquareCallPhase.active,
      localLanguageCode: 'en',
      remoteLanguageCode: 'en',
    );

    expect(session.translationState, TradeSquareCallTranslationState.bypassed);
  });

  test('different-language calls activate translation', () {
    final session = TradeSquareCallSession(
      id: 'c2',
      conversationId: 'conv_003',
      participant: const TradeSquareChatParticipant(
        id: 'usr_004',
        displayName: 'Joseph Msuya',
        businessName: 'Greenline Tanzania',
        preferredLanguage: 'sw',
      ),
      media: TradeSquareCallMedia.audio,
      phase: TradeSquareCallPhase.active,
      localLanguageCode: 'en',
      remoteLanguageCode: 'sw',
    );

    expect(session.translationState, TradeSquareCallTranslationState.active);
  });
}

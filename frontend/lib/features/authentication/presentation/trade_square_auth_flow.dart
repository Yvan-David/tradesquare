import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../app/localization/generated/app_localizations.dart';
import '../../../core/api/catalog_store.dart';
import '../../../core/mock_data/mock_data.dart';
import '../../../shared/components/trade_square_navigation_shell.dart';
import '../../../shared/navigation/trade_square_destination.dart';
import '../../business/presentation/trade_square_business_page.dart';
import '../../connections/presentation/trade_square_connections_page.dart';
import '../../discover/presentation/trade_square_discover_page.dart';
import '../../home/domain/trade_square_home_feed.dart';
import '../../home/domain/trade_square_home_partner.dart';
import '../../home/presentation/trade_square_home_page.dart';
import '../../home/presentation/widgets/home_quick_actions.dart';
import '../../marketplace/data/member_marketplace.dart';
import '../../messaging/domain/call_models.dart';
import '../../messaging/domain/messaging_models.dart';
import '../../messaging/presentation/call_screen.dart';
import '../../messaging/presentation/messages_page.dart';
import '../../opportunities/presentation/trade_square_opportunities_page.dart';
import '../data/trade_square_auth_repository.dart';
import '../domain/trade_square_auth_models.dart';
import '../domain/trade_square_auth_session.dart';
import 'trade_square_auth_screens.dart';
import 'trade_square_auth_widgets.dart';

class TradeSquareAuthFlow extends StatefulWidget {
  const TradeSquareAuthFlow({
    required this.onLocaleChanged,
    this.authRepository,
    super.key,
  });

  final ValueChanged<Locale> onLocaleChanged;
  final TradeSquareAuthRepository? authRepository;

  @override
  State<TradeSquareAuthFlow> createState() => _TradeSquareAuthFlowState();
}

enum _AuthStage {
  bootstrapping,
  login,
  home,
  registration,
  eligibility,
  certificate,
  onboarding,
  status,
  emailConfirmation,
}

class _TradeSquareAuthFlowState extends State<TradeSquareAuthFlow> {
  late final TradeSquareAuthRepository _auth =
      widget.authRepository ?? SupabaseAuthRepository();

  _AuthStage _stage = _AuthStage.bootstrapping;
  final _draft = TradeSquareAuthDraft();
  int _onboardingStep = 0;
  TradeSquareAuthUser? _user;
  String? _authError;
  TradeSquareApplicationStatus _applicationStatus =
      TradeSquareApplicationStatus.informationIncomplete;
  TradeSquareDestination _selectedDestination = TradeSquareDestination.overview;
  List<String>? _interestOverrides;
  String? _discoverInitialQuery;

  Locale get _locale => Localizations.localeOf(context);

  TradeSquareAccountRole get _signedInRole =>
      _user?.role ?? TradeSquareAccountRole.both;

  String get _currentLocation => switch (_selectedDestination) {
        TradeSquareDestination.overview => '/home',
        TradeSquareDestination.connections => '/connections',
        TradeSquareDestination.messages => '/messages',
        TradeSquareDestination.discover => '/discover',
        TradeSquareDestination.businessProfile => '/business',
        TradeSquareDestination.buyingRequests => '/opportunities',
        TradeSquareDestination.settings => '/settings',
        TradeSquareDestination.helpSupport => '/support',
        _ => '/home',
      };

  List<TradeSquareHomePartner> get _regionalPartners {
    return tradeSquareMockBusinesses
        .where((business) => business.ownerId != (_user?.profileId ?? ''))
        .map(
          (business) => TradeSquareHomePartner(
            id: business.id,
            name: business.name,
            industry: business.industry,
            location: '${business.city}, ${business.country}',
            isVerified: business.verificationStatus ==
                TradeSquareMockVerificationStatus.approved,
          ),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final restored = await _auth.restoreSession();
      if (!mounted) return;
      setState(() {
        _user = restored;
        _stage = restored == null ? _AuthStage.login : _AuthStage.home;
        _authError = null;
      });
      if (restored != null) await _publishMember();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _user = null;
        _stage = _AuthStage.login;
      });
    }
  }

  TradeSquareAccountRole _roleFromGoals(Set<TradeSquareBusinessGoal> goals) {
    final sells = goals.contains(TradeSquareBusinessGoal.findBuyers) ||
        goals.contains(TradeSquareBusinessGoal.promoteProducts) ||
        goals.contains(TradeSquareBusinessGoal.expandMarkets);
    final buys = goals.contains(TradeSquareBusinessGoal.findSuppliers);
    if (sells && buys) return TradeSquareAccountRole.both;
    if (sells) return TradeSquareAccountRole.supplier;
    if (buys) return TradeSquareAccountRole.buyer;
    return TradeSquareAccountRole.both;
  }

  String _friendlyAuthError(Object error) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('invalid login') ||
          message.contains('invalid credentials')) {
        return 'Incorrect email or password.';
      }
      if (message.contains('email not confirmed')) {
        return 'Confirm your email before signing in.';
      }
      if (message.contains('already registered') ||
          message.contains('already been registered')) {
        return 'An account with this email already exists. Sign in instead.';
      }
      return error.message;
    }
    return error.toString();
  }

  Future<void> _handleSignIn(String email, String password) async {
    setState(() => _authError = null);
    try {
      final user = await _auth.signIn(email: email, password: password);
      if (!mounted) return;
      setState(() {
        _user = user;
        _stage = _AuthStage.home;
        _selectedDestination = TradeSquareDestination.overview;
      });
      await _publishMember();
    } catch (error) {
      if (!mounted) return;
      setState(() => _authError = _friendlyAuthError(error));
    }
  }

  Future<void> _handleRegister(TradeSquareAuthDraft draft) async {
    setState(() => _authError = null);
    try {
      final user = await _auth.signUp(
        fullName: draft.fullName,
        email: draft.email,
        phone: draft.phone,
        password: draft.password,
      );
      if (!mounted) return;
      _draft
        ..fullName = draft.fullName
        ..email = draft.email
        ..phone = draft.phone
        ..password = '';
      // No linked profile yet usually means email confirmation is pending.
      if (user.profileId.isEmpty) {
        setState(() {
          _user = user;
          _stage = _AuthStage.emailConfirmation;
        });
        return;
      }
      setState(() {
        _user = user;
        _stage = _AuthStage.eligibility;
      });
      await _publishMember();
    } catch (error) {
      if (!mounted) return;
      setState(() => _authError = _friendlyAuthError(error));
    }
  }

  Future<void> _publishMember() async {
    final user = _user;
    if (user == null) return;
    if (widget.authRepository != null &&
        widget.authRepository is! SupabaseAuthRepository) {
      return;
    }
    try {
      final businessId = await MemberMarketplace().ensureListed(user);
      if (!mounted) return;
      setState(() => _user = user.copyWith(businessId: businessId));
      await CatalogStore.instance.ensureLoaded(force: true);
      if (mounted) setState(() {});
    } catch (_) {
      // Listing still appears after the marketplace SQL migration is applied.
    }
  }

  Future<void> _connectWith(TradeSquareMockBusiness business) async {
    final mine = _user?.businessId;
    if (mine == null || mine.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your profile is not listed yet. Sign in again after email confirmation.',
          ),
        ),
      );
      return;
    }
    try {
      await MemberMarketplace().requestConnection(
        fromBusinessId: mine,
        toBusinessId: business.id,
      );
      await CatalogStore.instance.ensureLoaded(force: true);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection request sent to ${business.name}.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not connect: $error')),
      );
    }
  }

  void _callMember(TradeSquareMockBusiness business) {
    final localId = _user?.profileId.isNotEmpty == true
        ? _user!.profileId
        : (_user?.authUserId ?? 'me');
    final remoteId =
        business.ownerId.isEmpty ? business.id : business.ownerId;
    final pair = [localId, remoteId]..sort();
    final session = TradeSquareCallSession(
      id: 'call_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: 'pair-${pair.join('-')}',
      participant: TradeSquareChatParticipant(
        id: remoteId,
        displayName: business.name,
        businessName: business.name,
        preferredLanguage: 'en',
      ),
      media: TradeSquareCallMedia.video,
      phase: TradeSquareCallPhase.outgoing,
      localLanguageCode: _locale.languageCode,
      remoteLanguageCode: 'en',
      isCameraOn: true,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TradeSquareCallScreen(
          initialSession: session,
          localIdentity: localId,
          localDisplayName: _user?.fullName,
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    await _auth.signOut();
    if (!mounted) return;
    setState(() {
      _user = null;
      _stage = _AuthStage.login;
      _authError = null;
      _selectedDestination = TradeSquareDestination.overview;
      _interestOverrides = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _AuthStage.bootstrapping:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case _AuthStage.login:
        return TradeSquareLoginScreen(
          locale: _locale,
          onLocaleChanged: widget.onLocaleChanged,
          errorMessage: _authError,
          onRegister: () => setState(() {
            _authError = null;
            _stage = _AuthStage.registration;
          }),
          onSubmit: _handleSignIn,
          onForgotPassword: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Password reset will open once email recovery is enabled in Supabase.',
                ),
              ),
            );
          },
        );
      case _AuthStage.emailConfirmation:
        return TradeSquareAuthFrame(
          locale: _locale,
          onLocaleChanged: widget.onLocaleChanged,
          child: TradeSquareAuthCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TradeSquareAuthHeading(
                  title: 'Confirm your email',
                  subtitle:
                      'We sent a confirmation link to ${_user?.email ?? _draft.email}. '
                      'Open it, then sign in to continue.',
                ),
                const SizedBox(height: 24),
                TradeSquareAuthPrimaryButton(
                  label: 'Back to sign in',
                  onPressed: () => setState(() {
                    _stage = _AuthStage.login;
                    _authError = null;
                  }),
                ),
              ],
            ),
          ),
        );
      case _AuthStage.home:
        return _buildHome();
      case _AuthStage.registration:
        return TradeSquareRegistrationScreen(
          locale: _locale,
          onLocaleChanged: widget.onLocaleChanged,
          errorMessage: _authError,
          onLogin: () => setState(() {
            _authError = null;
            _stage = _AuthStage.login;
          }),
          onContinue: _handleRegister,
        );
      case _AuthStage.eligibility:
        return TradeSquareEligibilityScreen(
          locale: _locale,
          onLocaleChanged: widget.onLocaleChanged,
          draft: _draft,
          onBack: () => setState(() => _stage = _AuthStage.registration),
          onContinue: (_) => setState(() => _stage = _AuthStage.certificate),
        );
      case _AuthStage.certificate:
        return TradeSquareCertificateScreen(
          locale: _locale,
          onLocaleChanged: widget.onLocaleChanged,
          document: _draft.document,
          documentType: _draft.documentType,
          onDocumentChanged: (document) =>
              setState(() => _draft.document = document),
          onDocumentTypeChanged: (type) =>
              setState(() => _draft.documentType = type),
          onBack: () => setState(() => _stage = _AuthStage.eligibility),
          onContinue: () => setState(() {
            _onboardingStep = 0;
            _stage = _AuthStage.onboarding;
          }),
        );
      case _AuthStage.onboarding:
        return TradeSquareBusinessOnboardingScreen(
          key: ValueKey('onboarding-$_onboardingStep'),
          locale: _locale,
          onLocaleChanged: widget.onLocaleChanged,
          draft: _draft,
          step: _onboardingStep,
          onDraftChanged: (draft) => setState(() {}),
          onBack: () => setState(() {
            if (_onboardingStep > 0) {
              _onboardingStep--;
            } else {
              _stage = _AuthStage.certificate;
            }
          }),
          onContinue: () => setState(() => _onboardingStep++),
          onSubmit: () async {
            final inferred = _roleFromGoals(_draft.goals);
            try {
              final updated = await _auth.updateAccountIntent(inferred);
              if (!mounted) return;
              setState(() {
                _user = updated;
                _applicationStatus = _draft.document == null
                    ? TradeSquareApplicationStatus.certificateNotSubmitted
                    : TradeSquareApplicationStatus.submittedForReview;
                _stage = _AuthStage.status;
              });
            } catch (_) {
              if (!mounted) return;
              setState(() {
                _user = _user?.copyWith(role: inferred);
                _applicationStatus = _draft.document == null
                    ? TradeSquareApplicationStatus.certificateNotSubmitted
                    : TradeSquareApplicationStatus.submittedForReview;
                _stage = _AuthStage.status;
              });
            }
          },
        );
      case _AuthStage.status:
        return TradeSquareApplicationStatusScreen(
          locale: _locale,
          onLocaleChanged: widget.onLocaleChanged,
          status: _applicationStatus,
          hasDocument: _draft.document != null,
          onReturn: () {
            setState(() {
              _stage =
                  _user != null ? _AuthStage.home : _AuthStage.login;
            });
          },
          onReviewCertificate: () =>
              setState(() => _stage = _AuthStage.certificate),
          onReviewProfile: () => setState(() {
            _onboardingStep = 6;
            _stage = _AuthStage.onboarding;
          }),
        );
    }
  }

  Widget _buildHome() {
    final localizations = AppLocalizations.of(context)!;
    final roleLabel = switch (_signedInRole) {
      TradeSquareAccountRole.buyer => localizations.authRoleBuyer,
      TradeSquareAccountRole.supplier => localizations.authRoleSupplier,
      TradeSquareAccountRole.both => localizations.authRoleBoth,
    };
    final baseProfile = TradeSquareMockData.homeProfileForRole(_signedInRole);
    final profile = TradeSquareHomeProfile(
      displayName: _user?.fullName.isNotEmpty == true
          ? _user!.fullName
          : baseProfile.displayName,
      businessName: baseProfile.businessName,
      industry: baseProfile.industry,
      category: baseProfile.category,
      businessDescription: baseProfile.businessDescription,
      location: baseProfile.location,
      targetMarkets: baseProfile.targetMarkets,
      interests: _interestOverrides ?? baseProfile.interests,
      productsOffered: baseProfile.productsOffered,
      productsNeeded: baseProfile.productsNeeded,
      intent: baseProfile.intent,
    );
    final sections = TradeSquareMockData.sectionsForRole(_signedInRole);

    final unreadMessages = tradeSquareMockConversations.fold<int>(
      0,
      (sum, conversation) =>
          sum +
          conversation.messages
              .where(
                (message) =>
                    message.senderId != (_user?.profileId ?? '') &&
                    message.readStatus == 'unread',
              )
              .length,
    );

    return TradeSquareNavigationShell(
      body: switch (_selectedDestination) {
        TradeSquareDestination.connections => TradeSquareConnectionsPage(
            connections: tradeSquareMockConnections,
            businesses: tradeSquareMockBusinesses,
            userBusinessId: _user?.businessId,
            onConnect: _connectWith,
            onCall: _callMember,
            onNewConnection: () {},
          ),
        TradeSquareDestination.messages => TradeSquareMessagesPage(
            localLanguageCode: _locale.languageCode,
          ),
        TradeSquareDestination.discover => TradeSquareDiscoverPage(
            key: ValueKey(_discoverInitialQuery ?? 'discover'),
            profile: profile,
            locale: _locale,
            onLocaleChanged: widget.onLocaleChanged,
            initialQuery: _discoverInitialQuery,
            onOpenMessages: () => setState(
              () => _selectedDestination = TradeSquareDestination.messages,
            ),
            onContactBusiness: (_) => setState(
              () => _selectedDestination = TradeSquareDestination.messages,
            ),
            onOpenBusinessProfile: () => setState(
              () =>
                  _selectedDestination = TradeSquareDestination.businessProfile,
            ),
            onOpenOpportunities: () => setState(
              () =>
                  _selectedDestination = TradeSquareDestination.buyingRequests,
            ),
            onOpenHome: () => setState(
              () => _selectedDestination = TradeSquareDestination.overview,
            ),
          ),
        TradeSquareDestination.buyingRequests => TradeSquareOpportunitiesPage(
            buyerBusinessId: _user?.businessId ?? '',
            onCreated: () => setState(() {}),
          ),
        TradeSquareDestination.businessProfile => TradeSquareBusinessPage(
            role: _signedInRole,
            profile: profile,
          ),
        TradeSquareDestination.settings => const _SimplePlaceholderPage(
            title: 'Settings',
            body: 'Account and workspace settings will appear here.',
          ),
        TradeSquareDestination.helpSupport => const _SimplePlaceholderPage(
            title: 'Help & Support',
            body: 'Guides and support options will appear here.',
          ),
        _ => TradeSquareHomePage(
            profile: profile,
            sections: sections,
            partners: _regionalPartners,
            interestOptions: TradeSquareMockData.availableInterests,
            onInterestsChanged: (interests) => setState(() {
              _interestOverrides = interests;
            }),
            onAskAssistant: (question) {
              setState(() {
                _discoverInitialQuery = question;
                _selectedDestination = TradeSquareDestination.discover;
              });
            },
            onQuickAction: (action) {
              setState(() {
                _discoverInitialQuery = switch (action) {
                  TradeSquareHomeQuickAction.findBuyers =>
                    'Find buyers for my products in East Africa',
                  TradeSquareHomeQuickAction.findSuppliers =>
                    'Find reliable suppliers of raw materials in East Africa',
                  TradeSquareHomeQuickAction.findPartners =>
                    'Find distributors for agricultural products in Uganda',
                };
                _selectedDestination = TradeSquareDestination.discover;
              });
            },
          ),
      },
      currentLocation: _currentLocation,
      routes: const {
        TradeSquareDestination.overview: '/home',
        TradeSquareDestination.connections: '/connections',
        TradeSquareDestination.messages: '/messages',
        TradeSquareDestination.discover: '/discover',
        TradeSquareDestination.buyingRequests: '/opportunities',
        TradeSquareDestination.businessProfile: '/business',
        TradeSquareDestination.settings: '/settings',
        TradeSquareDestination.helpSupport: '/support',
      },
      items: TradeSquareNavigationItem.primary(
        badgeCounts: {
          TradeSquareDestination.messages: unreadMessages,
        },
      ),
      onNavigate: (route) {
        if (route == '/connections' || route == '/opportunities') {
          CatalogStore.instance.ensureLoaded(force: true).then((_) {
            if (mounted) setState(() {});
          }).catchError((_) {});
        }
        setState(() {
          _selectedDestination = switch (route) {
            '/connections' => TradeSquareDestination.connections,
            '/messages' => TradeSquareDestination.messages,
            '/discover' => TradeSquareDestination.discover,
            '/opportunities' => TradeSquareDestination.buyingRequests,
            '/business' => TradeSquareDestination.businessProfile,
            '/settings' => TradeSquareDestination.settings,
            '/support' => TradeSquareDestination.helpSupport,
            _ => TradeSquareDestination.overview,
          };
          if (route != '/discover') {
            _discoverInitialQuery = null;
          }
        });
      },
      locale: _locale,
      onLocaleChanged: widget.onLocaleChanged,
      account: TradeSquareAccount(
        name: _user?.email ?? '',
        businessName: roleLabel,
      ),
      onSignOut: _handleSignOut,
    );
  }
}

class _SimplePlaceholderPage extends StatelessWidget {
  const _SimplePlaceholderPage({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF3F6F8),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

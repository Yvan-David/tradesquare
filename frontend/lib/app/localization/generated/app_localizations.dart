import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_rw.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('rw'),
    Locale('sw')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'TradeSquare'**
  String get appTitle;

  /// No description provided for @footerCopyright.
  ///
  /// In en, this message translates to:
  /// **'© {year} {brand}. All rights reserved.'**
  String footerCopyright(int year, String brand);

  /// No description provided for @footerAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get footerAbout;

  /// No description provided for @footerHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get footerHelpSupport;

  /// No description provided for @footerPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get footerPrivacyPolicy;

  /// No description provided for @footerTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get footerTermsOfService;

  /// No description provided for @footerComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get footerComingSoon;

  /// No description provided for @footerPlaceholderSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}, coming soon'**
  String footerPlaceholderSemantics(String label);

  /// No description provided for @footerLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get footerLanguage;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageKinyarwanda.
  ///
  /// In en, this message translates to:
  /// **'Kinyarwanda'**
  String get languageKinyarwanda;

  /// No description provided for @footerVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String footerVersion(String version);

  /// No description provided for @navWorkspace.
  ///
  /// In en, this message translates to:
  /// **'WORKSPACE'**
  String get navWorkspace;

  /// No description provided for @navIntelligence.
  ///
  /// In en, this message translates to:
  /// **'INTELLIGENCE'**
  String get navIntelligence;

  /// No description provided for @navAccount.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get navAccount;

  /// No description provided for @navSupport.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT'**
  String get navSupport;

  /// No description provided for @navOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get navOverview;

  /// No description provided for @navDiscover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get navDiscover;

  /// No description provided for @navProducts.
  ///
  /// In en, this message translates to:
  /// **'My Products'**
  String get navProducts;

  /// No description provided for @navBuyingRequests.
  ///
  /// In en, this message translates to:
  /// **'Buying Requests'**
  String get navBuyingRequests;

  /// No description provided for @navConnections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get navConnections;

  /// No description provided for @navMessages.
  ///
  /// In en, this message translates to:
  /// **'Messages'**
  String get navMessages;

  /// No description provided for @navAiAssistant.
  ///
  /// In en, this message translates to:
  /// **'TradeSquare AI'**
  String get navAiAssistant;

  /// No description provided for @navMarketIntelligence.
  ///
  /// In en, this message translates to:
  /// **'Market Intelligence'**
  String get navMarketIntelligence;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @navBusinessProfile.
  ///
  /// In en, this message translates to:
  /// **'Business Profile'**
  String get navBusinessProfile;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get navHelpSupport;

  /// No description provided for @navAiShort.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get navAiShort;

  /// No description provided for @navProfileShort.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfileShort;

  /// No description provided for @navAiBadge.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get navAiBadge;

  /// No description provided for @navAccountUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Account details unavailable'**
  String get navAccountUnavailable;

  /// No description provided for @navExpandSidebar.
  ///
  /// In en, this message translates to:
  /// **'Expand sidebar'**
  String get navExpandSidebar;

  /// No description provided for @navCollapseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Collapse sidebar'**
  String get navCollapseSidebar;

  /// No description provided for @navOpenMenu.
  ///
  /// In en, this message translates to:
  /// **'Open navigation menu'**
  String get navOpenMenu;

  /// No description provided for @navCloseMenu.
  ///
  /// In en, this message translates to:
  /// **'Close navigation menu'**
  String get navCloseMenu;

  /// No description provided for @navDestinationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{label} is not available in this app yet'**
  String navDestinationUnavailable(String label);

  /// No description provided for @navVerifiedBusiness.
  ///
  /// In en, this message translates to:
  /// **'Verified business'**
  String get navVerifiedBusiness;

  /// No description provided for @navProfileMenu.
  ///
  /// In en, this message translates to:
  /// **'Account menu'**
  String get navProfileMenu;

  /// No description provided for @navViewBusinessProfile.
  ///
  /// In en, this message translates to:
  /// **'View Business Profile'**
  String get navViewBusinessProfile;

  /// No description provided for @navAccountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get navAccountSettings;

  /// No description provided for @navSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get navSignOut;

  /// No description provided for @navSignOutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get navSignOutConfirmation;

  /// No description provided for @navCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get navCancel;

  /// No description provided for @languageKiswahili.
  ///
  /// In en, this message translates to:
  /// **'Kiswahili'**
  String get languageKiswahili;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// No description provided for @topBarSearch.
  ///
  /// In en, this message translates to:
  /// **'Search TradeSquare'**
  String get topBarSearch;

  /// No description provided for @topBarSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search businesses, products and opportunities'**
  String get topBarSearchHint;

  /// No description provided for @topBarImageSearch.
  ///
  /// In en, this message translates to:
  /// **'Search with an image'**
  String get topBarImageSearch;

  /// No description provided for @topBarVoiceSearch.
  ///
  /// In en, this message translates to:
  /// **'Search with your voice'**
  String get topBarVoiceSearch;

  /// No description provided for @topBarCloseSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get topBarCloseSearch;

  /// No description provided for @topBarCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get topBarCreate;

  /// No description provided for @topBarCreateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Create actions are not available yet'**
  String get topBarCreateUnavailable;

  /// No description provided for @topBarAddProduct.
  ///
  /// In en, this message translates to:
  /// **'Add Product Listing'**
  String get topBarAddProduct;

  /// No description provided for @topBarNewBuyingRequest.
  ///
  /// In en, this message translates to:
  /// **'Create Buying Request'**
  String get topBarNewBuyingRequest;

  /// No description provided for @topBarNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get topBarNotifications;

  /// No description provided for @topBarUnreadNotifications.
  ///
  /// In en, this message translates to:
  /// **'{count} unread notifications'**
  String topBarUnreadNotifications(int count);

  /// No description provided for @topBarCloseNotifications.
  ///
  /// In en, this message translates to:
  /// **'Close notifications'**
  String get topBarCloseNotifications;

  /// No description provided for @topBarNotificationsLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading notifications'**
  String get topBarNotificationsLoading;

  /// No description provided for @topBarNotificationsError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notifications.'**
  String get topBarNotificationsError;

  /// No description provided for @topBarNoNotifications.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up.'**
  String get topBarNoNotifications;

  /// No description provided for @topBarRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get topBarRetry;

  /// No description provided for @topBarAccountMenu.
  ///
  /// In en, this message translates to:
  /// **'Account menu'**
  String get topBarAccountMenu;

  /// No description provided for @topBarBusinessProfile.
  ///
  /// In en, this message translates to:
  /// **'Business Profile'**
  String get topBarBusinessProfile;

  /// No description provided for @topBarAccountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get topBarAccountSettings;

  /// No description provided for @topBarLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get topBarLanguage;

  /// No description provided for @topBarHelpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get topBarHelpSupport;

  /// No description provided for @topBarSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get topBarSignOut;

  /// No description provided for @topBarSignOutConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get topBarSignOutConfirmation;

  /// No description provided for @topBarCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get topBarCancel;

  /// No description provided for @homeGreeting.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String homeGreeting(String name);

  /// No description provided for @homeDiscoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover opportunities for your business'**
  String get homeDiscoverTitle;

  /// No description provided for @homeFeedIntro.
  ///
  /// In en, this message translates to:
  /// **'Relevant buyers, suppliers and trade opportunities, selected for your business.'**
  String get homeFeedIntro;

  /// No description provided for @homeFeedIntroBuyer.
  ///
  /// In en, this message translates to:
  /// **'Discover products and suppliers matched to what you need.'**
  String get homeFeedIntroBuyer;

  /// No description provided for @homeFeedIntroSupplier.
  ///
  /// In en, this message translates to:
  /// **'Discover buyers and requests matched to what you offer.'**
  String get homeFeedIntroSupplier;

  /// No description provided for @homePersonalizedFor.
  ///
  /// In en, this message translates to:
  /// **'Opportunities for {industry}'**
  String homePersonalizedFor(String industry);

  /// No description provided for @homeInterests.
  ///
  /// In en, this message translates to:
  /// **'Your business interests'**
  String get homeInterests;

  /// No description provided for @homeManageInterests.
  ///
  /// In en, this message translates to:
  /// **'Manage interests'**
  String get homeManageInterests;

  /// No description provided for @homeManageInterestsTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage business interests'**
  String get homeManageInterestsTitle;

  /// No description provided for @homeManageInterestsHint.
  ///
  /// In en, this message translates to:
  /// **'Choose the topics that help tailor your discovery feed.'**
  String get homeManageInterestsHint;

  /// No description provided for @homeInterestOptionsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Interest options are not available yet.'**
  String get homeInterestOptionsEmpty;

  /// No description provided for @homeInterestsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add interests to make your feed more relevant.'**
  String get homeInterestsEmpty;

  /// No description provided for @homeSaveInterests.
  ///
  /// In en, this message translates to:
  /// **'Save interests'**
  String get homeSaveInterests;

  /// No description provided for @homeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get homeCancel;

  /// No description provided for @homeSectionOpportunities.
  ///
  /// In en, this message translates to:
  /// **'Opportunities for your business'**
  String get homeSectionOpportunities;

  /// No description provided for @homeSectionBuyers.
  ///
  /// In en, this message translates to:
  /// **'Buyers looking for your products'**
  String get homeSectionBuyers;

  /// No description provided for @homeSectionSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Suppliers you may need'**
  String get homeSectionSuppliers;

  /// No description provided for @homeSectionProducts.
  ///
  /// In en, this message translates to:
  /// **'Products related to your business'**
  String get homeSectionProducts;

  /// No description provided for @homeSectionBusinesses.
  ///
  /// In en, this message translates to:
  /// **'Businesses you may want to connect with'**
  String get homeSectionBusinesses;

  /// No description provided for @homeSectionBuyingRequests.
  ///
  /// In en, this message translates to:
  /// **'Recent buying requests'**
  String get homeSectionBuyingRequests;

  /// No description provided for @homeSectionTradeOpportunities.
  ///
  /// In en, this message translates to:
  /// **'Relevant trade opportunities'**
  String get homeSectionTradeOpportunities;

  /// No description provided for @homeSectionMarketInsights.
  ///
  /// In en, this message translates to:
  /// **'Market intelligence and industry insights'**
  String get homeSectionMarketInsights;

  /// No description provided for @homeSectionAiRecommendations.
  ///
  /// In en, this message translates to:
  /// **'TradeSquare AI recommendations'**
  String get homeSectionAiRecommendations;

  /// No description provided for @homeNoSectionItems.
  ///
  /// In en, this message translates to:
  /// **'No relevant opportunities to show yet.'**
  String get homeNoSectionItems;

  /// No description provided for @homeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your discovery feed is getting ready'**
  String get homeEmptyTitle;

  /// No description provided for @homeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'As marketplace information becomes available, relevant opportunities will appear here.'**
  String get homeEmptyBody;

  /// No description provided for @homeLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading your personalized feed'**
  String get homeLoading;

  /// No description provided for @homeLoadError.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t load your feed.'**
  String get homeLoadError;

  /// No description provided for @homeOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Connect to the internet and try again.'**
  String get homeOffline;

  /// No description provided for @homeRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get homeRetry;

  /// No description provided for @homeLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more opportunities'**
  String get homeLoadMore;

  /// No description provided for @homeViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get homeViewDetails;

  /// No description provided for @homeSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get homeSave;

  /// No description provided for @homeSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get homeSaved;

  /// No description provided for @homeContact.
  ///
  /// In en, this message translates to:
  /// **'Contact business'**
  String get homeContact;

  /// No description provided for @homeConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get homeConnect;

  /// No description provided for @homeRespond.
  ///
  /// In en, this message translates to:
  /// **'Respond to request'**
  String get homeRespond;

  /// No description provided for @homeMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More recommendation actions'**
  String get homeMoreActions;

  /// No description provided for @homeMoreLikeThis.
  ///
  /// In en, this message translates to:
  /// **'Show me more like this'**
  String get homeMoreLikeThis;

  /// No description provided for @homeNotInterested.
  ///
  /// In en, this message translates to:
  /// **'Not interested'**
  String get homeNotInterested;

  /// No description provided for @homeWhySeeing.
  ///
  /// In en, this message translates to:
  /// **'Why am I seeing this?'**
  String get homeWhySeeing;

  /// No description provided for @homeWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'Why this is relevant'**
  String get homeWhyTitle;

  /// No description provided for @homeWhyIndustry.
  ///
  /// In en, this message translates to:
  /// **'Matches your business industry'**
  String get homeWhyIndustry;

  /// No description provided for @homeWhyCategory.
  ///
  /// In en, this message translates to:
  /// **'Matches your business category'**
  String get homeWhyCategory;

  /// No description provided for @homeWhyInterest.
  ///
  /// In en, this message translates to:
  /// **'Matches one of your business interests'**
  String get homeWhyInterest;

  /// No description provided for @homeWhyProduct.
  ///
  /// In en, this message translates to:
  /// **'Relates to a product or service you offer or need'**
  String get homeWhyProduct;

  /// No description provided for @homeWhyLocation.
  ///
  /// In en, this message translates to:
  /// **'Relevant to your business location'**
  String get homeWhyLocation;

  /// No description provided for @homeWhyIntent.
  ///
  /// In en, this message translates to:
  /// **'Matches your buying or selling goals'**
  String get homeWhyIntent;

  /// No description provided for @homeWhyRecent.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get homeWhyRecent;

  /// No description provided for @homeWhyGeneric.
  ///
  /// In en, this message translates to:
  /// **'This may be relevant to your business profile.'**
  String get homeWhyGeneric;

  /// No description provided for @homeVerifiedBusiness.
  ///
  /// In en, this message translates to:
  /// **'Verified business'**
  String get homeVerifiedBusiness;

  /// No description provided for @homeAiPromptTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask TradeSquare AI'**
  String get homeAiPromptTitle;

  /// No description provided for @homeAiPromptHint.
  ///
  /// In en, this message translates to:
  /// **'What are you looking to buy or sell?'**
  String get homeAiPromptHint;

  /// No description provided for @homeAiAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get homeAiAsk;

  /// No description provided for @homeFeedbackRecorded.
  ///
  /// In en, this message translates to:
  /// **'Thanks. Your feedback helps improve recommendations.'**
  String get homeFeedbackRecorded;

  /// No description provided for @authBrandSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A trusted network for business trade'**
  String get authBrandSubtitle;

  /// No description provided for @authPrototypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Frontend prototype · No account or verification is created'**
  String get authPrototypeLabel;

  /// No description provided for @authLoginWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authLoginWelcome;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your next business opportunity starts here.'**
  String get authLoginSubtitle;

  /// No description provided for @authAccountRole.
  ///
  /// In en, this message translates to:
  /// **'Business role'**
  String get authAccountRole;

  /// No description provided for @authRoleBuyer.
  ///
  /// In en, this message translates to:
  /// **'Buyer'**
  String get authRoleBuyer;

  /// No description provided for @authRoleSupplier.
  ///
  /// In en, this message translates to:
  /// **'Supplier'**
  String get authRoleSupplier;

  /// No description provided for @authRoleBoth.
  ///
  /// In en, this message translates to:
  /// **'Buyer and supplier'**
  String get authRoleBoth;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get authEmail;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authRememberMe.
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get authRememberMe;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'New to TradeSquare?'**
  String get authNoAccount;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get authCreateAccount;

  /// No description provided for @authRegistrationTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your TradeSquare account'**
  String get authRegistrationTitle;

  /// No description provided for @authRegistrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join a business network built to connect eligible businesses with buyers, suppliers, and opportunities.'**
  String get authRegistrationSubtitle;

  /// No description provided for @authFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get authFullName;

  /// No description provided for @authPhoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get authPhoneNumber;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// No description provided for @authPasswordStrength.
  ///
  /// In en, this message translates to:
  /// **'Password strength'**
  String get authPasswordStrength;

  /// No description provided for @authPasswordWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get authPasswordWeak;

  /// No description provided for @authPasswordFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get authPasswordFair;

  /// No description provided for @authPasswordStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get authPasswordStrong;

  /// No description provided for @authAcceptTerms.
  ///
  /// In en, this message translates to:
  /// **'I agree to the Terms of Service and Privacy Policy.'**
  String get authAcceptTerms;

  /// No description provided for @authTermsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service and Privacy Policy'**
  String get authTermsPrivacy;

  /// No description provided for @authHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get authHaveAccount;

  /// No description provided for @authContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get authContinue;

  /// No description provided for @authBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get authBack;

  /// No description provided for @authRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get authRequired;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authInvalidEmail;

  /// No description provided for @authPasswordMin.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get authPasswordMin;

  /// No description provided for @authPasswordsMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get authPasswordsMismatch;

  /// No description provided for @authAcceptTermsError.
  ///
  /// In en, this message translates to:
  /// **'Please accept the terms to continue.'**
  String get authAcceptTermsError;

  /// No description provided for @authMockSignInMessage.
  ///
  /// In en, this message translates to:
  /// **'Sign-in is a UI preview. Authentication is not connected.'**
  String get authMockSignInMessage;

  /// No description provided for @authMockForgotMessage.
  ///
  /// In en, this message translates to:
  /// **'Password recovery is not connected in this preview.'**
  String get authMockForgotMessage;

  /// No description provided for @authMockSubmittedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your form is saved in this preview only. Nothing was sent.'**
  String get authMockSubmittedMessage;

  /// No description provided for @authStepAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get authStepAccount;

  /// No description provided for @authStepEligibility.
  ///
  /// In en, this message translates to:
  /// **'Business eligibility'**
  String get authStepEligibility;

  /// No description provided for @authStepCertificate.
  ///
  /// In en, this message translates to:
  /// **'Certificate'**
  String get authStepCertificate;

  /// No description provided for @authStepProfile.
  ///
  /// In en, this message translates to:
  /// **'Business profile'**
  String get authStepProfile;

  /// No description provided for @authStepReview.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get authStepReview;

  /// No description provided for @authTellBusiness.
  ///
  /// In en, this message translates to:
  /// **'Tell us about your business'**
  String get authTellBusiness;

  /// No description provided for @authEligibilitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'TradeSquare is designed for legitimate businesses. These details help us understand your business context.'**
  String get authEligibilitySubtitle;

  /// No description provided for @authCountryOfRegistration.
  ///
  /// In en, this message translates to:
  /// **'Country of registration'**
  String get authCountryOfRegistration;

  /// No description provided for @authBusinessName.
  ///
  /// In en, this message translates to:
  /// **'Business name'**
  String get authBusinessName;

  /// No description provided for @authBusinessType.
  ///
  /// In en, this message translates to:
  /// **'Business type'**
  String get authBusinessType;

  /// No description provided for @authRegistrationStatus.
  ///
  /// In en, this message translates to:
  /// **'Business registration status'**
  String get authRegistrationStatus;

  /// No description provided for @authRegistrationNumber.
  ///
  /// In en, this message translates to:
  /// **'Business registration number'**
  String get authRegistrationNumber;

  /// No description provided for @authBusinessLocation.
  ///
  /// In en, this message translates to:
  /// **'Business location'**
  String get authBusinessLocation;

  /// No description provided for @authSelectCountry.
  ///
  /// In en, this message translates to:
  /// **'Select a country'**
  String get authSelectCountry;

  /// No description provided for @authSelectBusinessType.
  ///
  /// In en, this message translates to:
  /// **'Select a business type'**
  String get authSelectBusinessType;

  /// No description provided for @authSelectRegistrationStatus.
  ///
  /// In en, this message translates to:
  /// **'Select a registration status'**
  String get authSelectRegistrationStatus;

  /// No description provided for @authOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get authOptional;

  /// No description provided for @authRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered'**
  String get authRegistered;

  /// No description provided for @authRegistrationPending.
  ///
  /// In en, this message translates to:
  /// **'Registration in progress'**
  String get authRegistrationPending;

  /// No description provided for @authNotRegistered.
  ///
  /// In en, this message translates to:
  /// **'Not registered'**
  String get authNotRegistered;

  /// No description provided for @authEligibilityInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Why we ask about your business'**
  String get authEligibilityInfoTitle;

  /// No description provided for @authEligibilityInfoBody.
  ///
  /// In en, this message translates to:
  /// **'TradeSquare is intended for businesses. Depending on your country and business type, official registration documents may be requested before marketplace access. Eligibility is assessed under applicable policies; selecting a business type does not guarantee eligibility.'**
  String get authEligibilityInfoBody;

  /// No description provided for @authAcceptedDocumentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents that may be considered'**
  String get authAcceptedDocumentsTitle;

  /// No description provided for @authAcceptedDocumentsBody.
  ///
  /// In en, this message translates to:
  /// **'Examples may include a certificate of incorporation, an official registration certificate, or another applicable business registration document. Requirements depend on the country and business type.'**
  String get authAcceptedDocumentsBody;

  /// No description provided for @authEligibilityHelp.
  ///
  /// In en, this message translates to:
  /// **'Need help? You can save this information and return to it later.'**
  String get authEligibilityHelp;

  /// No description provided for @authCountryRwanda.
  ///
  /// In en, this message translates to:
  /// **'Rwanda'**
  String get authCountryRwanda;

  /// No description provided for @authCountryKenya.
  ///
  /// In en, this message translates to:
  /// **'Kenya'**
  String get authCountryKenya;

  /// No description provided for @authCountryUganda.
  ///
  /// In en, this message translates to:
  /// **'Uganda'**
  String get authCountryUganda;

  /// No description provided for @authCountryTanzania.
  ///
  /// In en, this message translates to:
  /// **'Tanzania'**
  String get authCountryTanzania;

  /// No description provided for @authCountryOther.
  ///
  /// In en, this message translates to:
  /// **'Other country'**
  String get authCountryOther;

  /// No description provided for @authTypeLimitedCompany.
  ///
  /// In en, this message translates to:
  /// **'Limited company'**
  String get authTypeLimitedCompany;

  /// No description provided for @authTypeSoleProprietorship.
  ///
  /// In en, this message translates to:
  /// **'Sole proprietorship'**
  String get authTypeSoleProprietorship;

  /// No description provided for @authTypePartnership.
  ///
  /// In en, this message translates to:
  /// **'Partnership'**
  String get authTypePartnership;

  /// No description provided for @authTypeCooperative.
  ///
  /// In en, this message translates to:
  /// **'Cooperative'**
  String get authTypeCooperative;

  /// No description provided for @authTypeRegisteredEnterprise.
  ///
  /// In en, this message translates to:
  /// **'Registered enterprise'**
  String get authTypeRegisteredEnterprise;

  /// No description provided for @authTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other legally recognised business entity'**
  String get authTypeOther;

  /// No description provided for @authCertificateTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify your business identity'**
  String get authCertificateTitle;

  /// No description provided for @authCertificateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Upload an official document confirming your business registration.'**
  String get authCertificateSubtitle;

  /// No description provided for @authDocumentType.
  ///
  /// In en, this message translates to:
  /// **'Document type'**
  String get authDocumentType;

  /// No description provided for @authSelectDocumentType.
  ///
  /// In en, this message translates to:
  /// **'Select a document type'**
  String get authSelectDocumentType;

  /// No description provided for @authDocIncorporation.
  ///
  /// In en, this message translates to:
  /// **'Certificate of Incorporation'**
  String get authDocIncorporation;

  /// No description provided for @authDocRegistration.
  ///
  /// In en, this message translates to:
  /// **'Certificate of Registration'**
  String get authDocRegistration;

  /// No description provided for @authDocBusinessRegistration.
  ///
  /// In en, this message translates to:
  /// **'Official Business Registration Certificate'**
  String get authDocBusinessRegistration;

  /// No description provided for @authDocOther.
  ///
  /// In en, this message translates to:
  /// **'Other applicable official registration document'**
  String get authDocOther;

  /// No description provided for @authDropTitle.
  ///
  /// In en, this message translates to:
  /// **'Drag and drop your document here'**
  String get authDropTitle;

  /// No description provided for @authDropSubtitle.
  ///
  /// In en, this message translates to:
  /// **'or select a file from your device'**
  String get authDropSubtitle;

  /// No description provided for @authBrowseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse files'**
  String get authBrowseFiles;

  /// No description provided for @authFileGuidance.
  ///
  /// In en, this message translates to:
  /// **'PDF, JPG or PNG · Maximum 10 MB'**
  String get authFileGuidance;

  /// No description provided for @authFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'This file is larger than the 10 MB limit.'**
  String get authFileTooLarge;

  /// No description provided for @authFileUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Choose a PDF, JPG or PNG file.'**
  String get authFileUnsupported;

  /// No description provided for @authFilePickerError.
  ///
  /// In en, this message translates to:
  /// **'The file selector could not be opened. Please try again.'**
  String get authFilePickerError;

  /// No description provided for @authRemoveFile.
  ///
  /// In en, this message translates to:
  /// **'Remove document'**
  String get authRemoveFile;

  /// No description provided for @authReplaceFile.
  ///
  /// In en, this message translates to:
  /// **'Replace document'**
  String get authReplaceFile;

  /// No description provided for @authSelectedDocument.
  ///
  /// In en, this message translates to:
  /// **'Selected document'**
  String get authSelectedDocument;

  /// No description provided for @authPreparingDocument.
  ///
  /// In en, this message translates to:
  /// **'Preparing local document preview'**
  String get authPreparingDocument;

  /// No description provided for @authDocumentReady.
  ///
  /// In en, this message translates to:
  /// **'Document ready for preview'**
  String get authDocumentReady;

  /// No description provided for @authLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'This prototype keeps only the file name and size in temporary UI state. The file is not uploaded or transmitted.'**
  String get authLocalOnly;

  /// No description provided for @authReviewNotice.
  ///
  /// In en, this message translates to:
  /// **'Your business certificate will be subject to review. Submission does not guarantee approval or immediate marketplace access.'**
  String get authReviewNotice;

  /// No description provided for @authMissingDocument.
  ///
  /// In en, this message translates to:
  /// **'Choose a document and document type to continue.'**
  String get authMissingDocument;

  /// No description provided for @authUploadContinueWithout.
  ///
  /// In en, this message translates to:
  /// **'Continue without a document'**
  String get authUploadContinueWithout;

  /// No description provided for @authUploadSubmit.
  ///
  /// In en, this message translates to:
  /// **'Continue to business profile'**
  String get authUploadSubmit;

  /// No description provided for @authProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Build your business profile'**
  String get authProfileTitle;

  /// No description provided for @authProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A few details help us tailor your TradeSquare experience. You can update these later.'**
  String get authProfileSubtitle;

  /// No description provided for @authStepBusinessInfo.
  ///
  /// In en, this message translates to:
  /// **'Business information'**
  String get authStepBusinessInfo;

  /// No description provided for @authStepIndustry.
  ///
  /// In en, this message translates to:
  /// **'Industry'**
  String get authStepIndustry;

  /// No description provided for @authStepProductsOffered.
  ///
  /// In en, this message translates to:
  /// **'What you offer'**
  String get authStepProductsOffered;

  /// No description provided for @authStepProductsNeeded.
  ///
  /// In en, this message translates to:
  /// **'What you need'**
  String get authStepProductsNeeded;

  /// No description provided for @authStepGoals.
  ///
  /// In en, this message translates to:
  /// **'Business goals'**
  String get authStepGoals;

  /// No description provided for @authStepInterests.
  ///
  /// In en, this message translates to:
  /// **'Interests and markets'**
  String get authStepInterests;

  /// No description provided for @authDistrictCity.
  ///
  /// In en, this message translates to:
  /// **'District or city'**
  String get authDistrictCity;

  /// No description provided for @authBusinessDescription.
  ///
  /// In en, this message translates to:
  /// **'Business description'**
  String get authBusinessDescription;

  /// No description provided for @authBusinessDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe what your business does'**
  String get authBusinessDescriptionHint;

  /// No description provided for @authChooseIndustry.
  ///
  /// In en, this message translates to:
  /// **'Choose your primary industry'**
  String get authChooseIndustry;

  /// No description provided for @authSearchOptions.
  ///
  /// In en, this message translates to:
  /// **'Search options'**
  String get authSearchOptions;

  /// No description provided for @authIndustryAgriculture.
  ///
  /// In en, this message translates to:
  /// **'Agriculture'**
  String get authIndustryAgriculture;

  /// No description provided for @authIndustryTechnology.
  ///
  /// In en, this message translates to:
  /// **'Information Technology'**
  String get authIndustryTechnology;

  /// No description provided for @authIndustryManufacturing.
  ///
  /// In en, this message translates to:
  /// **'Manufacturing'**
  String get authIndustryManufacturing;

  /// No description provided for @authIndustryRetailWholesale.
  ///
  /// In en, this message translates to:
  /// **'Retail and Wholesale'**
  String get authIndustryRetailWholesale;

  /// No description provided for @authIndustryConstruction.
  ///
  /// In en, this message translates to:
  /// **'Construction'**
  String get authIndustryConstruction;

  /// No description provided for @authIndustryTransport.
  ///
  /// In en, this message translates to:
  /// **'Transportation and Logistics'**
  String get authIndustryTransport;

  /// No description provided for @authIndustryFood.
  ///
  /// In en, this message translates to:
  /// **'Food and Beverage'**
  String get authIndustryFood;

  /// No description provided for @authIndustryHealthcare.
  ///
  /// In en, this message translates to:
  /// **'Healthcare'**
  String get authIndustryHealthcare;

  /// No description provided for @authIndustryEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get authIndustryEducation;

  /// No description provided for @authIndustryTourism.
  ///
  /// In en, this message translates to:
  /// **'Tourism and Hospitality'**
  String get authIndustryTourism;

  /// No description provided for @authIndustryProfessional.
  ///
  /// In en, this message translates to:
  /// **'Professional Services'**
  String get authIndustryProfessional;

  /// No description provided for @authIndustryEnergy.
  ///
  /// In en, this message translates to:
  /// **'Energy'**
  String get authIndustryEnergy;

  /// No description provided for @authIndustryMining.
  ///
  /// In en, this message translates to:
  /// **'Mining'**
  String get authIndustryMining;

  /// No description provided for @authIndustryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get authIndustryOther;

  /// No description provided for @authProductsOffered.
  ///
  /// In en, this message translates to:
  /// **'Products or services offered'**
  String get authProductsOffered;

  /// No description provided for @authProductsNeeded.
  ///
  /// In en, this message translates to:
  /// **'Products or services sought'**
  String get authProductsNeeded;

  /// No description provided for @authListInputHint.
  ///
  /// In en, this message translates to:
  /// **'Add an item and press Enter'**
  String get authListInputHint;

  /// No description provided for @authAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get authAddItem;

  /// No description provided for @authSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get authSkip;

  /// No description provided for @authBusinessGoals.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do on TradeSquare?'**
  String get authBusinessGoals;

  /// No description provided for @authGoalBuyers.
  ///
  /// In en, this message translates to:
  /// **'Find buyers'**
  String get authGoalBuyers;

  /// No description provided for @authGoalSuppliers.
  ///
  /// In en, this message translates to:
  /// **'Find suppliers'**
  String get authGoalSuppliers;

  /// No description provided for @authGoalPromote.
  ///
  /// In en, this message translates to:
  /// **'Promote products'**
  String get authGoalPromote;

  /// No description provided for @authGoalPartners.
  ///
  /// In en, this message translates to:
  /// **'Find business partners'**
  String get authGoalPartners;

  /// No description provided for @authGoalOpportunities.
  ///
  /// In en, this message translates to:
  /// **'Discover opportunities'**
  String get authGoalOpportunities;

  /// No description provided for @authGoalMarkets.
  ///
  /// In en, this message translates to:
  /// **'Expand into new markets'**
  String get authGoalMarkets;

  /// No description provided for @authInterests.
  ///
  /// In en, this message translates to:
  /// **'Business interests'**
  String get authInterests;

  /// No description provided for @authInterestsHint.
  ///
  /// In en, this message translates to:
  /// **'Add topics that matter to your business.'**
  String get authInterestsHint;

  /// No description provided for @authTargetMarkets.
  ///
  /// In en, this message translates to:
  /// **'Target markets'**
  String get authTargetMarkets;

  /// No description provided for @authTargetMarketsHint.
  ///
  /// In en, this message translates to:
  /// **'Add countries or regions you want to trade with.'**
  String get authTargetMarketsHint;

  /// No description provided for @authReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review your information'**
  String get authReviewTitle;

  /// No description provided for @authReviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Check your details before continuing. You can go back to make changes.'**
  String get authReviewSubtitle;

  /// No description provided for @authEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get authEdit;

  /// No description provided for @authSubmitApplication.
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get authSubmitApplication;

  /// No description provided for @authSubmissionNotice.
  ///
  /// In en, this message translates to:
  /// **'This is a frontend-only preview. Submitting will not send information or start a real review.'**
  String get authSubmissionNotice;

  /// No description provided for @authApplicationStatus.
  ///
  /// In en, this message translates to:
  /// **'Application status'**
  String get authApplicationStatus;

  /// No description provided for @authStatusPrototype.
  ///
  /// In en, this message translates to:
  /// **'Prototype status preview'**
  String get authStatusPrototype;

  /// No description provided for @authStatusIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Information incomplete'**
  String get authStatusIncomplete;

  /// No description provided for @authStatusCertificateMissing.
  ///
  /// In en, this message translates to:
  /// **'Certificate not submitted'**
  String get authStatusCertificateMissing;

  /// No description provided for @authStatusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted for review'**
  String get authStatusSubmitted;

  /// No description provided for @authStatusUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get authStatusUnderReview;

  /// No description provided for @authStatusAdditionalInfo.
  ///
  /// In en, this message translates to:
  /// **'Additional information required'**
  String get authStatusAdditionalInfo;

  /// No description provided for @authStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get authStatusApproved;

  /// No description provided for @authStatusNotApproved.
  ///
  /// In en, this message translates to:
  /// **'Not approved'**
  String get authStatusNotApproved;

  /// No description provided for @authStatusIncompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Complete the required business information to continue.'**
  String get authStatusIncompleteBody;

  /// No description provided for @authStatusCertificateMissingBody.
  ///
  /// In en, this message translates to:
  /// **'Add an applicable registration document when you are ready. You may continue this prototype without one.'**
  String get authStatusCertificateMissingBody;

  /// No description provided for @authStatusSubmittedBody.
  ///
  /// In en, this message translates to:
  /// **'Your business information has been submitted in this local preview. No real review has started.'**
  String get authStatusSubmittedBody;

  /// No description provided for @authStatusUnderReviewBody.
  ///
  /// In en, this message translates to:
  /// **'This is a demonstration state only. No verification review has taken place.'**
  String get authStatusUnderReviewBody;

  /// No description provided for @authStatusAdditionalInfoBody.
  ///
  /// In en, this message translates to:
  /// **'This demonstration state indicates that more information could be requested through a future review process.'**
  String get authStatusAdditionalInfoBody;

  /// No description provided for @authStatusApprovedBody.
  ///
  /// In en, this message translates to:
  /// **'Demonstration only: no business has been approved or verified.'**
  String get authStatusApprovedBody;

  /// No description provided for @authStatusNotApprovedBody.
  ///
  /// In en, this message translates to:
  /// **'Demonstration only: no eligibility decision has been made.'**
  String get authStatusNotApprovedBody;

  /// No description provided for @authStatusNextAction.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get authStatusNextAction;

  /// No description provided for @authStatusReturnHome.
  ///
  /// In en, this message translates to:
  /// **'Return to sign in'**
  String get authStatusReturnHome;

  /// No description provided for @authStatusChangePreview.
  ///
  /// In en, this message translates to:
  /// **'Preview a status'**
  String get authStatusChangePreview;

  /// No description provided for @authStatusDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Prototype only · This status is not a real eligibility or verification decision.'**
  String get authStatusDisclaimer;

  /// No description provided for @authStatusCertificateAction.
  ///
  /// In en, this message translates to:
  /// **'Review certificate step'**
  String get authStatusCertificateAction;

  /// No description provided for @authStatusProfileAction.
  ///
  /// In en, this message translates to:
  /// **'Review business information'**
  String get authStatusProfileAction;

  /// No description provided for @authCountryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get authCountryLabel;

  /// No description provided for @authPhoneCountryCode.
  ///
  /// In en, this message translates to:
  /// **'Country code'**
  String get authPhoneCountryCode;

  /// No description provided for @authPhoneRwanda.
  ///
  /// In en, this message translates to:
  /// **'+250'**
  String get authPhoneRwanda;

  /// No description provided for @authPhoneKenya.
  ///
  /// In en, this message translates to:
  /// **'+254'**
  String get authPhoneKenya;

  /// No description provided for @authPhoneUganda.
  ///
  /// In en, this message translates to:
  /// **'+256'**
  String get authPhoneUganda;

  /// No description provided for @authPhoneTanzania.
  ///
  /// In en, this message translates to:
  /// **'+255'**
  String get authPhoneTanzania;

  /// No description provided for @authLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get authLanguage;

  /// No description provided for @authStoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Build stronger connections. Find your next opportunity.'**
  String get authStoryTitle;

  /// No description provided for @authStoryBody.
  ///
  /// In en, this message translates to:
  /// **'One trusted place to introduce your business, meet the right partners and discover new markets.'**
  String get authStoryBody;

  /// No description provided for @authStoryItemOne.
  ///
  /// In en, this message translates to:
  /// **'Create a profile for your business'**
  String get authStoryItemOne;

  /// No description provided for @authStoryItemTwo.
  ///
  /// In en, this message translates to:
  /// **'Share registration information for future eligibility review'**
  String get authStoryItemTwo;

  /// No description provided for @authStoryItemThree.
  ///
  /// In en, this message translates to:
  /// **'Discover buyers, suppliers and trade opportunities'**
  String get authStoryItemThree;

  /// No description provided for @discoverAiBadge.
  ///
  /// In en, this message translates to:
  /// **'TradeSquare AI discovery'**
  String get discoverAiBadge;

  /// No description provided for @discoverHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Find your next business connection'**
  String get discoverHeroTitle;

  /// No description provided for @discoverHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Describe what you need in plain language. Discover matches businesses, products and markets across Rwanda and East Africa.'**
  String get discoverHeroSubtitle;

  /// No description provided for @discoverHeroSubtitleMobile.
  ///
  /// In en, this message translates to:
  /// **'Speak or type what you need. Discover finds businesses across East Africa.'**
  String get discoverHeroSubtitleMobile;

  /// No description provided for @discoverSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Example: I manufacture school furniture in Rwanda and want to sell in Uganda'**
  String get discoverSearchHint;

  /// No description provided for @discoverVoiceHint.
  ///
  /// In en, this message translates to:
  /// **'Listening… tell TradeSquare what you’re looking for'**
  String get discoverVoiceHint;

  /// No description provided for @discoverVoicePreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing microphone…'**
  String get discoverVoicePreparing;

  /// No description provided for @discoverVoiceListening.
  ///
  /// In en, this message translates to:
  /// **'Listening — keep talking'**
  String get discoverVoiceListening;

  /// No description provided for @discoverVoiceCaptured.
  ///
  /// In en, this message translates to:
  /// **'Got it — searching now'**
  String get discoverVoiceCaptured;

  /// No description provided for @discoverVoiceStop.
  ///
  /// In en, this message translates to:
  /// **'Stop listening'**
  String get discoverVoiceStop;

  /// No description provided for @discoverVoiceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Voice listening isn’t available here. Check mic permission or type your search.'**
  String get discoverVoiceUnavailable;

  /// No description provided for @discoverSearchAction.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discoverSearchAction;

  /// No description provided for @discoverTryExamples.
  ///
  /// In en, this message translates to:
  /// **'Try an example'**
  String get discoverTryExamples;

  /// No description provided for @discoverCategoryBusinesses.
  ///
  /// In en, this message translates to:
  /// **'Businesses'**
  String get discoverCategoryBusinesses;

  /// No description provided for @discoverCategoryProducts.
  ///
  /// In en, this message translates to:
  /// **'Products & Services'**
  String get discoverCategoryProducts;

  /// No description provided for @discoverCategoryMatches.
  ///
  /// In en, this message translates to:
  /// **'AI Matches'**
  String get discoverCategoryMatches;

  /// No description provided for @discoverCategoryMarkets.
  ///
  /// In en, this message translates to:
  /// **'Markets'**
  String get discoverCategoryMarkets;

  /// No description provided for @discoverIndustriesTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore industries'**
  String get discoverIndustriesTitle;

  /// No description provided for @discoverIndustriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Browse regional business activity by industry.'**
  String get discoverIndustriesSubtitle;

  /// No description provided for @discoverPersonalizedTitle.
  ///
  /// In en, this message translates to:
  /// **'Relevant for your business'**
  String get discoverPersonalizedTitle;

  /// No description provided for @discoverPersonalizedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Suggestions based on your TradeSquare profile and published interests.'**
  String get discoverPersonalizedSubtitle;

  /// No description provided for @discoverMatchesTitle.
  ///
  /// In en, this message translates to:
  /// **'AI-powered matching'**
  String get discoverMatchesTitle;

  /// No description provided for @discoverMatchesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Potential connections explained with evidence from available records.'**
  String get discoverMatchesSubtitle;

  /// No description provided for @discoverMarketsTitle.
  ///
  /// In en, this message translates to:
  /// **'Explore regional markets'**
  String get discoverMarketsTitle;

  /// No description provided for @discoverMarketsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start with Rwanda, Kenya, Uganda, Tanzania and Burundi.'**
  String get discoverMarketsSubtitle;

  /// No description provided for @discoverMarketCount.
  ///
  /// In en, this message translates to:
  /// **'{count} businesses'**
  String discoverMarketCount(int count);

  /// No description provided for @discoverJourneyTitle.
  ///
  /// In en, this message translates to:
  /// **'Discovery journey'**
  String get discoverJourneyTitle;

  /// No description provided for @discoverClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get discoverClearSearch;

  /// No description provided for @discoverInterpreted.
  ///
  /// In en, this message translates to:
  /// **'Interpreted criteria'**
  String get discoverInterpreted;

  /// No description provided for @discoverStageUnderstanding.
  ///
  /// In en, this message translates to:
  /// **'Understanding your request'**
  String get discoverStageUnderstanding;

  /// No description provided for @discoverStageIdentifying.
  ///
  /// In en, this message translates to:
  /// **'Identifying product, activity and markets'**
  String get discoverStageIdentifying;

  /// No description provided for @discoverStageSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching TradeSquare records'**
  String get discoverStageSearching;

  /// No description provided for @discoverStageRanking.
  ///
  /// In en, this message translates to:
  /// **'Organizing relevant results'**
  String get discoverStageRanking;

  /// No description provided for @discoverEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching businesses yet'**
  String get discoverEmptyTitle;

  /// No description provided for @discoverEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try broadening markets, removing a filter, or searching with a shorter description.'**
  String get discoverEmptyBody;

  /// No description provided for @discoverBroadenSearch.
  ///
  /// In en, this message translates to:
  /// **'Broaden search'**
  String get discoverBroadenSearch;

  /// No description provided for @discoverBusinessResults.
  ///
  /// In en, this message translates to:
  /// **'Matching businesses'**
  String get discoverBusinessResults;

  /// No description provided for @discoverProductsResults.
  ///
  /// In en, this message translates to:
  /// **'Matching products & services'**
  String get discoverProductsResults;

  /// No description provided for @discoverResultsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} results'**
  String discoverResultsCount(int count);

  /// No description provided for @businessPageTitle.
  ///
  /// In en, this message translates to:
  /// **'My Business'**
  String get businessPageTitle;

  /// No description provided for @businessTabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get businessTabOverview;

  /// No description provided for @businessTabProducts.
  ///
  /// In en, this message translates to:
  /// **'Products & Services'**
  String get businessTabProducts;

  /// No description provided for @businessTabOpportunities.
  ///
  /// In en, this message translates to:
  /// **'Opportunities'**
  String get businessTabOpportunities;

  /// No description provided for @businessTabActivity.
  ///
  /// In en, this message translates to:
  /// **'Business Activity'**
  String get businessTabActivity;

  /// No description provided for @businessEditAction.
  ///
  /// In en, this message translates to:
  /// **'Edit business'**
  String get businessEditAction;

  /// No description provided for @businessPreviewAction.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get businessPreviewAction;

  /// No description provided for @businessPublicPreview.
  ///
  /// In en, this message translates to:
  /// **'Public preview'**
  String get businessPublicPreview;

  /// No description provided for @businessExitPreview.
  ///
  /// In en, this message translates to:
  /// **'Exit preview'**
  String get businessExitPreview;

  /// No description provided for @businessAiTitle.
  ///
  /// In en, this message translates to:
  /// **'TradeSquare Business AI'**
  String get businessAiTitle;

  /// No description provided for @businessAiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Optional drafts to improve copy. Review and edit before publishing. Live AI is not connected yet.'**
  String get businessAiSubtitle;

  /// No description provided for @businessVerificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Business verification'**
  String get businessVerificationTitle;

  /// No description provided for @businessLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load your business workspace.'**
  String get businessLoadError;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'rw', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'rw':
      return AppLocalizationsRw();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}

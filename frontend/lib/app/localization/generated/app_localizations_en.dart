// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TradeSquare';

  @override
  String footerCopyright(int year, String brand) {
    return '© $year $brand. All rights reserved.';
  }

  @override
  String get footerAbout => 'About';

  @override
  String get footerHelpSupport => 'Help & Support';

  @override
  String get footerPrivacyPolicy => 'Privacy Policy';

  @override
  String get footerTermsOfService => 'Terms of Service';

  @override
  String get footerComingSoon => 'Coming soon';

  @override
  String footerPlaceholderSemantics(String label) {
    return '$label, coming soon';
  }

  @override
  String get footerLanguage => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKinyarwanda => 'Kinyarwanda';

  @override
  String footerVersion(String version) {
    return 'Version $version';
  }

  @override
  String get navWorkspace => 'WORKSPACE';

  @override
  String get navIntelligence => 'INTELLIGENCE';

  @override
  String get navAccount => 'ACCOUNT';

  @override
  String get navSupport => 'SUPPORT';

  @override
  String get navOverview => 'Overview';

  @override
  String get navDiscover => 'Discover';

  @override
  String get navProducts => 'My Products';

  @override
  String get navBuyingRequests => 'Buying Requests';

  @override
  String get navConnections => 'Connections';

  @override
  String get navMessages => 'Messages';

  @override
  String get navAiAssistant => 'TradeSquare AI';

  @override
  String get navMarketIntelligence => 'Market Intelligence';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navBusinessProfile => 'Business Profile';

  @override
  String get navSettings => 'Settings';

  @override
  String get navHelpSupport => 'Help & Support';

  @override
  String get navAiShort => 'AI';

  @override
  String get navProfileShort => 'Profile';

  @override
  String get navAiBadge => 'AI';

  @override
  String get navAccountUnavailable => 'Account details unavailable';

  @override
  String get navExpandSidebar => 'Expand sidebar';

  @override
  String get navCollapseSidebar => 'Collapse sidebar';

  @override
  String get navOpenMenu => 'Open navigation menu';

  @override
  String get navCloseMenu => 'Close navigation menu';

  @override
  String navDestinationUnavailable(String label) {
    return '$label is not available in this app yet';
  }

  @override
  String get navVerifiedBusiness => 'Verified business';

  @override
  String get navProfileMenu => 'Account menu';

  @override
  String get navViewBusinessProfile => 'View Business Profile';

  @override
  String get navAccountSettings => 'Account Settings';

  @override
  String get navSignOut => 'Sign Out';

  @override
  String get navSignOutConfirmation => 'Are you sure you want to sign out?';

  @override
  String get navCancel => 'Cancel';

  @override
  String get languageKiswahili => 'Kiswahili';

  @override
  String get languageFrench => 'Français';

  @override
  String get topBarSearch => 'Search TradeSquare';

  @override
  String get topBarSearchHint =>
      'Search businesses, products and opportunities';

  @override
  String get topBarImageSearch => 'Search with an image';

  @override
  String get topBarVoiceSearch => 'Search with your voice';

  @override
  String get topBarCloseSearch => 'Close search';

  @override
  String get topBarCreate => 'Create';

  @override
  String get topBarCreateUnavailable => 'Create actions are not available yet';

  @override
  String get topBarAddProduct => 'Add Product Listing';

  @override
  String get topBarNewBuyingRequest => 'Create Buying Request';

  @override
  String get topBarNotifications => 'Notifications';

  @override
  String topBarUnreadNotifications(int count) {
    return '$count unread notifications';
  }

  @override
  String get topBarCloseNotifications => 'Close notifications';

  @override
  String get topBarNotificationsLoading => 'Loading notifications';

  @override
  String get topBarNotificationsError => 'Couldn\'t load notifications.';

  @override
  String get topBarNoNotifications => 'You\'re all caught up.';

  @override
  String get topBarRetry => 'Retry';

  @override
  String get topBarAccountMenu => 'Account menu';

  @override
  String get topBarBusinessProfile => 'Business Profile';

  @override
  String get topBarAccountSettings => 'Account Settings';

  @override
  String get topBarLanguage => 'Language';

  @override
  String get topBarHelpSupport => 'Help & Support';

  @override
  String get topBarSignOut => 'Sign Out';

  @override
  String get topBarSignOutConfirmation => 'Are you sure you want to sign out?';

  @override
  String get topBarCancel => 'Cancel';

  @override
  String homeGreeting(String name) {
    return 'Welcome back, $name';
  }

  @override
  String get homeDiscoverTitle => 'Discover opportunities for your business';

  @override
  String get homeFeedIntro =>
      'Relevant buyers, suppliers and trade opportunities, selected for your business.';

  @override
  String get homeFeedIntroBuyer =>
      'Discover products and suppliers matched to what you need.';

  @override
  String get homeFeedIntroSupplier =>
      'Discover buyers and requests matched to what you offer.';

  @override
  String homePersonalizedFor(String industry) {
    return 'Opportunities for $industry';
  }

  @override
  String get homeInterests => 'Your business interests';

  @override
  String get homeManageInterests => 'Manage interests';

  @override
  String get homeManageInterestsTitle => 'Manage business interests';

  @override
  String get homeManageInterestsHint =>
      'Choose the topics that help tailor your discovery feed.';

  @override
  String get homeInterestOptionsEmpty =>
      'Interest options are not available yet.';

  @override
  String get homeInterestsEmpty =>
      'Add interests to make your feed more relevant.';

  @override
  String get homeSaveInterests => 'Save interests';

  @override
  String get homeCancel => 'Cancel';

  @override
  String get homeSectionOpportunities => 'Opportunities for your business';

  @override
  String get homeSectionBuyers => 'Buyers looking for your products';

  @override
  String get homeSectionSuppliers => 'Suppliers you may need';

  @override
  String get homeSectionProducts => 'Products related to your business';

  @override
  String get homeSectionBusinesses => 'Businesses you may want to connect with';

  @override
  String get homeSectionBuyingRequests => 'Recent buying requests';

  @override
  String get homeSectionTradeOpportunities => 'Relevant trade opportunities';

  @override
  String get homeSectionMarketInsights =>
      'Market intelligence and industry insights';

  @override
  String get homeSectionAiRecommendations => 'TradeSquare AI recommendations';

  @override
  String get homeNoSectionItems => 'No relevant opportunities to show yet.';

  @override
  String get homeEmptyTitle => 'Your discovery feed is getting ready';

  @override
  String get homeEmptyBody =>
      'As marketplace information becomes available, relevant opportunities will appear here.';

  @override
  String get homeLoading => 'Loading your personalized feed';

  @override
  String get homeLoadError => 'We couldn\'t load your feed.';

  @override
  String get homeOffline =>
      'You\'re offline. Connect to the internet and try again.';

  @override
  String get homeRetry => 'Try again';

  @override
  String get homeLoadMore => 'Load more opportunities';

  @override
  String get homeViewDetails => 'View details';

  @override
  String get homeSave => 'Save';

  @override
  String get homeSaved => 'Saved';

  @override
  String get homeContact => 'Contact business';

  @override
  String get homeConnect => 'Connect';

  @override
  String get homeRespond => 'Respond to request';

  @override
  String get homeMoreActions => 'More recommendation actions';

  @override
  String get homeMoreLikeThis => 'Show me more like this';

  @override
  String get homeNotInterested => 'Not interested';

  @override
  String get homeWhySeeing => 'Why am I seeing this?';

  @override
  String get homeWhyTitle => 'Why this is relevant';

  @override
  String get homeWhyIndustry => 'Matches your business industry';

  @override
  String get homeWhyCategory => 'Matches your business category';

  @override
  String get homeWhyInterest => 'Matches one of your business interests';

  @override
  String get homeWhyProduct =>
      'Relates to a product or service you offer or need';

  @override
  String get homeWhyLocation => 'Relevant to your business location';

  @override
  String get homeWhyIntent => 'Matches your buying or selling goals';

  @override
  String get homeWhyRecent => 'Recently added';

  @override
  String get homeWhyGeneric => 'This may be relevant to your business profile.';

  @override
  String get homeVerifiedBusiness => 'Verified business';

  @override
  String get homeAiPromptTitle => 'Ask TradeSquare AI';

  @override
  String get homeAiPromptHint => 'What are you looking to buy or sell?';

  @override
  String get homeAiAsk => 'Ask';

  @override
  String get homeFeedbackRecorded =>
      'Thanks. Your feedback helps improve recommendations.';

  @override
  String get authBrandSubtitle => 'A trusted network for business trade';

  @override
  String get authPrototypeLabel =>
      'Frontend prototype · No account or verification is created';

  @override
  String get authLoginWelcome => 'Welcome back';

  @override
  String get authLoginSubtitle => 'Your next business opportunity starts here.';

  @override
  String get authAccountRole => 'Business role';

  @override
  String get authRoleBuyer => 'Buyer';

  @override
  String get authRoleSupplier => 'Supplier';

  @override
  String get authRoleBoth => 'Buyer and supplier';

  @override
  String get authEmail => 'Email address';

  @override
  String get authPassword => 'Password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authRememberMe => 'Remember me';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authNoAccount => 'New to TradeSquare?';

  @override
  String get authCreateAccount => 'Create an account';

  @override
  String get authRegistrationTitle => 'Create your TradeSquare account';

  @override
  String get authRegistrationSubtitle =>
      'Join a business network built to connect eligible businesses with buyers, suppliers, and opportunities.';

  @override
  String get authFullName => 'Full name';

  @override
  String get authPhoneNumber => 'Phone number';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authPasswordStrength => 'Password strength';

  @override
  String get authPasswordWeak => 'Weak';

  @override
  String get authPasswordFair => 'Fair';

  @override
  String get authPasswordStrong => 'Strong';

  @override
  String get authAcceptTerms =>
      'I agree to the Terms of Service and Privacy Policy.';

  @override
  String get authTermsPrivacy => 'Terms of Service and Privacy Policy';

  @override
  String get authHaveAccount => 'Already have an account?';

  @override
  String get authContinue => 'Continue';

  @override
  String get authBack => 'Back';

  @override
  String get authRequired => 'This field is required.';

  @override
  String get authInvalidEmail => 'Enter a valid email address.';

  @override
  String get authPasswordMin => 'Use at least 8 characters.';

  @override
  String get authPasswordsMismatch => 'Passwords do not match.';

  @override
  String get authAcceptTermsError => 'Please accept the terms to continue.';

  @override
  String get authMockSignInMessage =>
      'Sign-in is a UI preview. Authentication is not connected.';

  @override
  String get authMockForgotMessage =>
      'Password recovery is not connected in this preview.';

  @override
  String get authMockSubmittedMessage =>
      'Your form is saved in this preview only. Nothing was sent.';

  @override
  String get authStepAccount => 'Account';

  @override
  String get authStepEligibility => 'Business eligibility';

  @override
  String get authStepCertificate => 'Certificate';

  @override
  String get authStepProfile => 'Business profile';

  @override
  String get authStepReview => 'Review';

  @override
  String get authTellBusiness => 'Tell us about your business';

  @override
  String get authEligibilitySubtitle =>
      'TradeSquare is designed for legitimate businesses. These details help us understand your business context.';

  @override
  String get authCountryOfRegistration => 'Country of registration';

  @override
  String get authBusinessName => 'Business name';

  @override
  String get authBusinessType => 'Business type';

  @override
  String get authRegistrationStatus => 'Business registration status';

  @override
  String get authRegistrationNumber => 'Business registration number';

  @override
  String get authBusinessLocation => 'Business location';

  @override
  String get authSelectCountry => 'Select a country';

  @override
  String get authSelectBusinessType => 'Select a business type';

  @override
  String get authSelectRegistrationStatus => 'Select a registration status';

  @override
  String get authOptional => 'Optional';

  @override
  String get authRegistered => 'Registered';

  @override
  String get authRegistrationPending => 'Registration in progress';

  @override
  String get authNotRegistered => 'Not registered';

  @override
  String get authEligibilityInfoTitle => 'Why we ask about your business';

  @override
  String get authEligibilityInfoBody =>
      'TradeSquare is intended for businesses. Depending on your country and business type, official registration documents may be requested before marketplace access. Eligibility is assessed under applicable policies; selecting a business type does not guarantee eligibility.';

  @override
  String get authAcceptedDocumentsTitle => 'Documents that may be considered';

  @override
  String get authAcceptedDocumentsBody =>
      'Examples may include a certificate of incorporation, an official registration certificate, or another applicable business registration document. Requirements depend on the country and business type.';

  @override
  String get authEligibilityHelp =>
      'Need help? You can save this information and return to it later.';

  @override
  String get authCountryRwanda => 'Rwanda';

  @override
  String get authCountryKenya => 'Kenya';

  @override
  String get authCountryUganda => 'Uganda';

  @override
  String get authCountryTanzania => 'Tanzania';

  @override
  String get authCountryOther => 'Other country';

  @override
  String get authTypeLimitedCompany => 'Limited company';

  @override
  String get authTypeSoleProprietorship => 'Sole proprietorship';

  @override
  String get authTypePartnership => 'Partnership';

  @override
  String get authTypeCooperative => 'Cooperative';

  @override
  String get authTypeRegisteredEnterprise => 'Registered enterprise';

  @override
  String get authTypeOther => 'Other legally recognised business entity';

  @override
  String get authCertificateTitle => 'Verify your business identity';

  @override
  String get authCertificateSubtitle =>
      'Upload an official document confirming your business registration.';

  @override
  String get authDocumentType => 'Document type';

  @override
  String get authSelectDocumentType => 'Select a document type';

  @override
  String get authDocIncorporation => 'Certificate of Incorporation';

  @override
  String get authDocRegistration => 'Certificate of Registration';

  @override
  String get authDocBusinessRegistration =>
      'Official Business Registration Certificate';

  @override
  String get authDocOther => 'Other applicable official registration document';

  @override
  String get authDropTitle => 'Drag and drop your document here';

  @override
  String get authDropSubtitle => 'or select a file from your device';

  @override
  String get authBrowseFiles => 'Browse files';

  @override
  String get authFileGuidance => 'PDF, JPG or PNG · Maximum 10 MB';

  @override
  String get authFileTooLarge => 'This file is larger than the 10 MB limit.';

  @override
  String get authFileUnsupported => 'Choose a PDF, JPG or PNG file.';

  @override
  String get authFilePickerError =>
      'The file selector could not be opened. Please try again.';

  @override
  String get authRemoveFile => 'Remove document';

  @override
  String get authReplaceFile => 'Replace document';

  @override
  String get authSelectedDocument => 'Selected document';

  @override
  String get authPreparingDocument => 'Preparing local document preview';

  @override
  String get authDocumentReady => 'Document ready for preview';

  @override
  String get authLocalOnly =>
      'This prototype keeps only the file name and size in temporary UI state. The file is not uploaded or transmitted.';

  @override
  String get authReviewNotice =>
      'Your business certificate will be subject to review. Submission does not guarantee approval or immediate marketplace access.';

  @override
  String get authMissingDocument =>
      'Choose a document and document type to continue.';

  @override
  String get authUploadContinueWithout => 'Continue without a document';

  @override
  String get authUploadSubmit => 'Continue to business profile';

  @override
  String get authProfileTitle => 'Build your business profile';

  @override
  String get authProfileSubtitle =>
      'A few details help us tailor your TradeSquare experience. You can update these later.';

  @override
  String get authStepBusinessInfo => 'Business information';

  @override
  String get authStepIndustry => 'Industry';

  @override
  String get authStepProductsOffered => 'What you offer';

  @override
  String get authStepProductsNeeded => 'What you need';

  @override
  String get authStepGoals => 'Business goals';

  @override
  String get authStepInterests => 'Interests and markets';

  @override
  String get authDistrictCity => 'District or city';

  @override
  String get authBusinessDescription => 'Business description';

  @override
  String get authBusinessDescriptionHint => 'Describe what your business does';

  @override
  String get authChooseIndustry => 'Choose your primary industry';

  @override
  String get authSearchOptions => 'Search options';

  @override
  String get authIndustryAgriculture => 'Agriculture';

  @override
  String get authIndustryTechnology => 'Information Technology';

  @override
  String get authIndustryManufacturing => 'Manufacturing';

  @override
  String get authIndustryRetailWholesale => 'Retail and Wholesale';

  @override
  String get authIndustryConstruction => 'Construction';

  @override
  String get authIndustryTransport => 'Transportation and Logistics';

  @override
  String get authIndustryFood => 'Food and Beverage';

  @override
  String get authIndustryHealthcare => 'Healthcare';

  @override
  String get authIndustryEducation => 'Education';

  @override
  String get authIndustryTourism => 'Tourism and Hospitality';

  @override
  String get authIndustryProfessional => 'Professional Services';

  @override
  String get authIndustryEnergy => 'Energy';

  @override
  String get authIndustryMining => 'Mining';

  @override
  String get authIndustryOther => 'Other';

  @override
  String get authProductsOffered => 'Products or services offered';

  @override
  String get authProductsNeeded => 'Products or services sought';

  @override
  String get authListInputHint => 'Add an item and press Enter';

  @override
  String get authAddItem => 'Add';

  @override
  String get authSkip => 'Skip for now';

  @override
  String get authBusinessGoals => 'What would you like to do on TradeSquare?';

  @override
  String get authGoalBuyers => 'Find buyers';

  @override
  String get authGoalSuppliers => 'Find suppliers';

  @override
  String get authGoalPromote => 'Promote products';

  @override
  String get authGoalPartners => 'Find business partners';

  @override
  String get authGoalOpportunities => 'Discover opportunities';

  @override
  String get authGoalMarkets => 'Expand into new markets';

  @override
  String get authInterests => 'Business interests';

  @override
  String get authInterestsHint => 'Add topics that matter to your business.';

  @override
  String get authTargetMarkets => 'Target markets';

  @override
  String get authTargetMarketsHint =>
      'Add countries or regions you want to trade with.';

  @override
  String get authReviewTitle => 'Review your information';

  @override
  String get authReviewSubtitle =>
      'Check your details before continuing. You can go back to make changes.';

  @override
  String get authEdit => 'Edit';

  @override
  String get authSubmitApplication => 'Submit for review';

  @override
  String get authSubmissionNotice =>
      'This is a frontend-only preview. Submitting will not send information or start a real review.';

  @override
  String get authApplicationStatus => 'Application status';

  @override
  String get authStatusPrototype => 'Prototype status preview';

  @override
  String get authStatusIncomplete => 'Information incomplete';

  @override
  String get authStatusCertificateMissing => 'Certificate not submitted';

  @override
  String get authStatusSubmitted => 'Submitted for review';

  @override
  String get authStatusUnderReview => 'Under review';

  @override
  String get authStatusAdditionalInfo => 'Additional information required';

  @override
  String get authStatusApproved => 'Approved';

  @override
  String get authStatusNotApproved => 'Not approved';

  @override
  String get authStatusIncompleteBody =>
      'Complete the required business information to continue.';

  @override
  String get authStatusCertificateMissingBody =>
      'Add an applicable registration document when you are ready. You may continue this prototype without one.';

  @override
  String get authStatusSubmittedBody =>
      'Your business information has been submitted in this local preview. No real review has started.';

  @override
  String get authStatusUnderReviewBody =>
      'This is a demonstration state only. No verification review has taken place.';

  @override
  String get authStatusAdditionalInfoBody =>
      'This demonstration state indicates that more information could be requested through a future review process.';

  @override
  String get authStatusApprovedBody =>
      'Demonstration only: no business has been approved or verified.';

  @override
  String get authStatusNotApprovedBody =>
      'Demonstration only: no eligibility decision has been made.';

  @override
  String get authStatusNextAction => 'Next step';

  @override
  String get authStatusReturnHome => 'Return to sign in';

  @override
  String get authStatusChangePreview => 'Preview a status';

  @override
  String get authStatusDisclaimer =>
      'Prototype only · This status is not a real eligibility or verification decision.';

  @override
  String get authStatusCertificateAction => 'Review certificate step';

  @override
  String get authStatusProfileAction => 'Review business information';

  @override
  String get authCountryLabel => 'Country';

  @override
  String get authPhoneCountryCode => 'Country code';

  @override
  String get authPhoneRwanda => '+250';

  @override
  String get authPhoneKenya => '+254';

  @override
  String get authPhoneUganda => '+256';

  @override
  String get authPhoneTanzania => '+255';

  @override
  String get authLanguage => 'Language';

  @override
  String get authStoryTitle =>
      'Build stronger connections. Find your next opportunity.';

  @override
  String get authStoryBody =>
      'One trusted place to introduce your business, meet the right partners and discover new markets.';

  @override
  String get authStoryItemOne => 'Create a profile for your business';

  @override
  String get authStoryItemTwo =>
      'Share registration information for future eligibility review';

  @override
  String get authStoryItemThree =>
      'Discover buyers, suppliers and trade opportunities';

  @override
  String get discoverAiBadge => 'TradeSquare AI discovery';

  @override
  String get discoverHeroTitle => 'Find your next business connection';

  @override
  String get discoverHeroSubtitle =>
      'Describe what you need in plain language. Discover matches businesses, products and markets across Rwanda and East Africa.';

  @override
  String get discoverHeroSubtitleMobile =>
      'Speak or type what you need. Discover finds businesses across East Africa.';

  @override
  String get discoverSearchHint =>
      'Example: I manufacture school furniture in Rwanda and want to sell in Uganda';

  @override
  String get discoverVoiceHint =>
      'Listening… tell TradeSquare what you’re looking for';

  @override
  String get discoverVoicePreparing => 'Preparing microphone…';

  @override
  String get discoverVoiceListening => 'Listening — keep talking';

  @override
  String get discoverVoiceCaptured => 'Got it — searching now';

  @override
  String get discoverVoiceStop => 'Stop listening';

  @override
  String get discoverVoiceUnavailable =>
      'Voice listening isn’t available here. Check mic permission or type your search.';

  @override
  String get discoverSearchAction => 'Discover';

  @override
  String get discoverTryExamples => 'Try an example';

  @override
  String get discoverCategoryBusinesses => 'Businesses';

  @override
  String get discoverCategoryProducts => 'Products & Services';

  @override
  String get discoverCategoryMatches => 'AI Matches';

  @override
  String get discoverCategoryMarkets => 'Markets';

  @override
  String get discoverIndustriesTitle => 'Explore industries';

  @override
  String get discoverIndustriesSubtitle =>
      'Browse regional business activity by industry.';

  @override
  String get discoverPersonalizedTitle => 'Relevant for your business';

  @override
  String get discoverPersonalizedSubtitle =>
      'Suggestions based on your TradeSquare profile and published interests.';

  @override
  String get discoverMatchesTitle => 'AI-powered matching';

  @override
  String get discoverMatchesSubtitle =>
      'Potential connections explained with evidence from available records.';

  @override
  String get discoverMarketsTitle => 'Explore regional markets';

  @override
  String get discoverMarketsSubtitle =>
      'Start with Rwanda, Kenya, Uganda, Tanzania and Burundi.';

  @override
  String discoverMarketCount(int count) {
    return '$count businesses';
  }

  @override
  String get discoverJourneyTitle => 'Discovery journey';

  @override
  String get discoverClearSearch => 'Clear';

  @override
  String get discoverInterpreted => 'Interpreted criteria';

  @override
  String get discoverStageUnderstanding => 'Understanding your request';

  @override
  String get discoverStageIdentifying =>
      'Identifying product, activity and markets';

  @override
  String get discoverStageSearching => 'Searching TradeSquare records';

  @override
  String get discoverStageRanking => 'Organizing relevant results';

  @override
  String get discoverEmptyTitle => 'No matching businesses yet';

  @override
  String get discoverEmptyBody =>
      'Try broadening markets, removing a filter, or searching with a shorter description.';

  @override
  String get discoverBroadenSearch => 'Broaden search';

  @override
  String get discoverBusinessResults => 'Matching businesses';

  @override
  String get discoverProductsResults => 'Matching products & services';

  @override
  String discoverResultsCount(int count) {
    return '$count results';
  }

  @override
  String get businessPageTitle => 'My Business';

  @override
  String get businessTabOverview => 'Overview';

  @override
  String get businessTabProducts => 'Products & Services';

  @override
  String get businessTabOpportunities => 'Opportunities';

  @override
  String get businessTabActivity => 'Business Activity';

  @override
  String get businessEditAction => 'Edit business';

  @override
  String get businessPreviewAction => 'Preview';

  @override
  String get businessPublicPreview => 'Public preview';

  @override
  String get businessExitPreview => 'Exit preview';

  @override
  String get businessAiTitle => 'TradeSquare Business AI';

  @override
  String get businessAiSubtitle =>
      'Optional drafts to improve copy. Review and edit before publishing. Live AI is not connected yet.';

  @override
  String get businessVerificationTitle => 'Business verification';

  @override
  String get businessLoadError => 'Could not load your business workspace.';
}

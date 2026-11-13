// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class AppLocalizationsSw extends AppLocalizations {
  AppLocalizationsSw([String locale = 'sw']) : super(locale);

  @override
  String get appTitle => 'TradeSquare';

  @override
  String footerCopyright(int year, String brand) {
    return '© $year $brand. Haki zote zimehifadhiwa.';
  }

  @override
  String get footerAbout => 'Kuhusu';

  @override
  String get footerHelpSupport => 'Msaada na Usaidizi';

  @override
  String get footerPrivacyPolicy => 'Sera ya Faragha';

  @override
  String get footerTermsOfService => 'Masharti ya Huduma';

  @override
  String get footerComingSoon => 'Inakuja hivi karibuni';

  @override
  String footerPlaceholderSemantics(String label) {
    return '$label, inakuja hivi karibuni';
  }

  @override
  String get footerLanguage => 'Lugha';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKinyarwanda => 'Kinyarwanda';

  @override
  String footerVersion(String version) {
    return 'Toleo $version';
  }

  @override
  String get navWorkspace => 'ENEO LA KAZI';

  @override
  String get navIntelligence => 'TAARIFA ZA SOKO';

  @override
  String get navAccount => 'AKAUNTI';

  @override
  String get navSupport => 'MSAADA';

  @override
  String get navOverview => 'Muhtasari';

  @override
  String get navDiscover => 'Gundua';

  @override
  String get navProducts => 'Bidhaa Zangu';

  @override
  String get navBuyingRequests => 'Maombi ya Ununuzi';

  @override
  String get navConnections => 'Miunganisho';

  @override
  String get navMessages => 'Ujumbe';

  @override
  String get navAiAssistant => 'TradeSquare AI';

  @override
  String get navMarketIntelligence => 'Taarifa za Soko';

  @override
  String get navNotifications => 'Arifa';

  @override
  String get navBusinessProfile => 'Wasifu wa Biashara';

  @override
  String get navSettings => 'Mipangilio';

  @override
  String get navHelpSupport => 'Msaada na Usaidizi';

  @override
  String get navAiShort => 'AI';

  @override
  String get navProfileShort => 'Wasifu';

  @override
  String get navAiBadge => 'AI';

  @override
  String get navAccountUnavailable => 'Maelezo ya akaunti hayapatikani';

  @override
  String get navExpandSidebar => 'Panua menyu ya pembeni';

  @override
  String get navCollapseSidebar => 'Kunja menyu ya pembeni';

  @override
  String get navOpenMenu => 'Fungua menyu ya urambazaji';

  @override
  String get navCloseMenu => 'Funga menyu ya urambazaji';

  @override
  String navDestinationUnavailable(String label) {
    return '$label bado haipatikani katika programu hii';
  }

  @override
  String get navVerifiedBusiness => 'Biashara iliyothibitishwa';

  @override
  String get navProfileMenu => 'Menyu ya akaunti';

  @override
  String get navViewBusinessProfile => 'Tazama Wasifu wa Biashara';

  @override
  String get navAccountSettings => 'Mipangilio ya Akaunti';

  @override
  String get navSignOut => 'Ondoka';

  @override
  String get navSignOutConfirmation => 'Una uhakika unataka kuondoka?';

  @override
  String get navCancel => 'Ghairi';

  @override
  String get languageKiswahili => 'Kiswahili';

  @override
  String get languageFrench => 'Français';

  @override
  String get topBarSearch => 'Tafuta kwenye TradeSquare';

  @override
  String get topBarSearchHint => 'Tafuta biashara, bidhaa na fursa';

  @override
  String get topBarImageSearch => 'Tafuta kwa kutumia picha';

  @override
  String get topBarVoiceSearch => 'Tafuta kwa kutumia sauti';

  @override
  String get topBarCloseSearch => 'Funga utafutaji';

  @override
  String get topBarCreate => 'Unda';

  @override
  String get topBarCreateUnavailable => 'Vitendo vya kuunda bado havipatikani';

  @override
  String get topBarAddProduct => 'Ongeza Orodha ya Bidhaa';

  @override
  String get topBarNewBuyingRequest => 'Unda Ombi la Ununuzi';

  @override
  String get topBarNotifications => 'Arifa';

  @override
  String topBarUnreadNotifications(int count) {
    return 'Arifa $count ambazo hazijasomwa';
  }

  @override
  String get topBarCloseNotifications => 'Funga arifa';

  @override
  String get topBarNotificationsLoading => 'Inapakia arifa';

  @override
  String get topBarNotificationsError => 'Imeshindwa kupakia arifa.';

  @override
  String get topBarNoNotifications => 'Huna arifa mpya.';

  @override
  String get topBarRetry => 'Jaribu tena';

  @override
  String get topBarAccountMenu => 'Menyu ya akaunti';

  @override
  String get topBarBusinessProfile => 'Wasifu wa Biashara';

  @override
  String get topBarAccountSettings => 'Mipangilio ya Akaunti';

  @override
  String get topBarLanguage => 'Lugha';

  @override
  String get topBarHelpSupport => 'Msaada na Usaidizi';

  @override
  String get topBarSignOut => 'Ondoka';

  @override
  String get topBarSignOutConfirmation => 'Una uhakika unataka kuondoka?';

  @override
  String get topBarCancel => 'Ghairi';

  @override
  String homeGreeting(String name) {
    return 'Karibu tena, $name';
  }

  @override
  String get homeDiscoverTitle => 'Gundua fursa za biashara yako';

  @override
  String get homeFeedIntro =>
      'Wanunuzi, wasambazaji na fursa za biashara zinazofaa kwa biashara yako.';

  @override
  String get homeFeedIntroBuyer =>
      'Gundua bidhaa na wasambazaji wanaolingana na mahitaji yako.';

  @override
  String get homeFeedIntroSupplier =>
      'Gundua wanunuzi na maombi yanayolingana na unachotoa.';

  @override
  String homePersonalizedFor(String industry) {
    return 'Fursa za $industry';
  }

  @override
  String get homeInterests => 'Maslahi ya biashara yako';

  @override
  String get homeManageInterests => 'Dhibiti maslahi';

  @override
  String get homeManageInterestsTitle => 'Dhibiti maslahi ya biashara';

  @override
  String get homeManageInterestsHint =>
      'Chagua mada zinazosaidia kubinafsisha fursa unazogundua.';

  @override
  String get homeInterestOptionsEmpty => 'Chaguo za maslahi bado hazipatikani.';

  @override
  String get homeInterestsEmpty =>
      'Ongeza maslahi ili kupata fursa zinazokufaa zaidi.';

  @override
  String get homeSaveInterests => 'Hifadhi maslahi';

  @override
  String get homeCancel => 'Ghairi';

  @override
  String get homeSectionOpportunities => 'Fursa za biashara yako';

  @override
  String get homeSectionBuyers => 'Wanunuzi wanaotafuta bidhaa zako';

  @override
  String get homeSectionSuppliers => 'Wasambazaji unaoweza kuhitaji';

  @override
  String get homeSectionProducts => 'Bidhaa zinazohusiana na biashara yako';

  @override
  String get homeSectionBusinesses => 'Biashara unazoweza kuungana nazo';

  @override
  String get homeSectionBuyingRequests => 'Maombi mapya ya ununuzi';

  @override
  String get homeSectionTradeOpportunities => 'Fursa husika za biashara';

  @override
  String get homeSectionMarketInsights => 'Taarifa za soko na sekta';

  @override
  String get homeSectionAiRecommendations => 'Mapendekezo ya TradeSquare AI';

  @override
  String get homeNoSectionItems => 'Hakuna fursa husika za kuonyesha kwa sasa.';

  @override
  String get homeEmptyTitle => 'Mlisho wako wa fursa unatayarishwa';

  @override
  String get homeEmptyBody =>
      'Fursa zinazohusiana zitaonekana hapa taarifa za soko zitakapopatikana.';

  @override
  String get homeLoading => 'Inapakia fursa za biashara yako';

  @override
  String get homeLoadError => 'Imeshindwa kupakia fursa zako.';

  @override
  String get homeOffline =>
      'Huna muunganisho wa intaneti. Unganisha kisha ujaribu tena.';

  @override
  String get homeRetry => 'Jaribu tena';

  @override
  String get homeLoadMore => 'Pakia fursa zaidi';

  @override
  String get homeViewDetails => 'Tazama maelezo';

  @override
  String get homeSave => 'Hifadhi';

  @override
  String get homeSaved => 'Imehifadhiwa';

  @override
  String get homeContact => 'Wasiliana na biashara';

  @override
  String get homeConnect => 'Ungana';

  @override
  String get homeRespond => 'Jibu ombi';

  @override
  String get homeMoreActions => 'Vitendo zaidi vya mapendekezo';

  @override
  String get homeMoreLikeThis => 'Nionyeshe zinazofanana na hii';

  @override
  String get homeNotInterested => 'Sipendezwi';

  @override
  String get homeWhySeeing => 'Kwa nini naona hili?';

  @override
  String get homeWhyTitle => 'Kwa nini hili linafaa';

  @override
  String get homeWhyIndustry => 'Linaendana na sekta ya biashara yako';

  @override
  String get homeWhyCategory => 'Linaendana na aina ya biashara yako';

  @override
  String get homeWhyInterest =>
      'Linaendana na mojawapo ya maslahi ya biashara yako';

  @override
  String get homeWhyProduct =>
      'Linahusiana na bidhaa au huduma unayotoa au kuhitaji';

  @override
  String get homeWhyLocation => 'Linafaa kwa eneo la biashara yako';

  @override
  String get homeWhyIntent => 'Linaendana na malengo yako ya kununua au kuuza';

  @override
  String get homeWhyRecent => 'Limeongezwa hivi karibuni';

  @override
  String get homeWhyGeneric =>
      'Huenda hili linafaa kwa wasifu wa biashara yako.';

  @override
  String get homeVerifiedBusiness => 'Biashara iliyothibitishwa';

  @override
  String get homeAiPromptTitle => 'Uliza TradeSquare AI';

  @override
  String get homeAiPromptHint => 'Unatafuta kununua au kuuza nini?';

  @override
  String get homeAiAsk => 'Uliza';

  @override
  String get homeFeedbackRecorded =>
      'Asante. Maoni yako yanasaidia kuboresha mapendekezo.';

  @override
  String get authBrandSubtitle => 'Mtandao wa biashara unaoaminika';

  @override
  String get authPrototypeLabel =>
      'Onyesho la frontend · Hakuna akaunti au uthibitishaji unaofanyika';

  @override
  String get authLoginWelcome => 'Karibu tena';

  @override
  String get authLoginSubtitle =>
      'Fursa yako inayofuata ya biashara inaanzia hapa.';

  @override
  String get authAccountRole => 'Jukumu la biashara';

  @override
  String get authRoleBuyer => 'Mnunuzi';

  @override
  String get authRoleSupplier => 'Msambazaji';

  @override
  String get authRoleBoth => 'Mnunuzi na msambazaji';

  @override
  String get authEmail => 'Anwani ya barua pepe';

  @override
  String get authPassword => 'Nenosiri';

  @override
  String get authShowPassword => 'Onyesha nenosiri';

  @override
  String get authHidePassword => 'Ficha nenosiri';

  @override
  String get authRememberMe => 'Nikumbuke';

  @override
  String get authForgotPassword => 'Umesahau nenosiri?';

  @override
  String get authSignIn => 'Ingia';

  @override
  String get authNoAccount => 'Huna akaunti ya TradeSquare?';

  @override
  String get authCreateAccount => 'Fungua akaunti';

  @override
  String get authRegistrationTitle => 'Fungua akaunti yako ya TradeSquare';

  @override
  String get authRegistrationSubtitle =>
      'Jiunge na mtandao unaounganisha biashara zinazostahiki na wanunuzi, wasambazaji na fursa.';

  @override
  String get authFullName => 'Majina kamili';

  @override
  String get authPhoneNumber => 'Nambari ya simu';

  @override
  String get authConfirmPassword => 'Thibitisha nenosiri';

  @override
  String get authPasswordStrength => 'Nguvu ya nenosiri';

  @override
  String get authPasswordWeak => 'Dhaifu';

  @override
  String get authPasswordFair => 'Wastani';

  @override
  String get authPasswordStrong => 'Imara';

  @override
  String get authAcceptTerms =>
      'Ninakubali Masharti ya Huduma na Sera ya Faragha.';

  @override
  String get authTermsPrivacy => 'Masharti ya Huduma na Sera ya Faragha';

  @override
  String get authHaveAccount => 'Tayari una akaunti?';

  @override
  String get authContinue => 'Endelea';

  @override
  String get authBack => 'Rudi';

  @override
  String get authRequired => 'Sehemu hii inahitajika.';

  @override
  String get authInvalidEmail => 'Weka anwani sahihi ya barua pepe.';

  @override
  String get authPasswordMin => 'Tumia angalau vibambo 8.';

  @override
  String get authPasswordsMismatch => 'Manenosiri hayalingani.';

  @override
  String get authAcceptTermsError => 'Kubali masharti ili uendelee.';

  @override
  String get authMockSignInMessage =>
      'Kuingia ni onyesho la kiolesura pekee. Uthibitishaji haujaunganishwa.';

  @override
  String get authMockForgotMessage =>
      'Urejeshaji wa nenosiri haujaunganishwa kwenye onyesho hili.';

  @override
  String get authMockSubmittedMessage =>
      'Fomu imehifadhiwa kwenye onyesho hili pekee. Hakuna kilichotumwa.';

  @override
  String get authStepAccount => 'Akaunti';

  @override
  String get authStepEligibility => 'Ustahiki wa biashara';

  @override
  String get authStepCertificate => 'Cheti';

  @override
  String get authStepProfile => 'Wasifu wa biashara';

  @override
  String get authStepReview => 'Kagua';

  @override
  String get authTellBusiness => 'Tueleze kuhusu biashara yako';

  @override
  String get authEligibilitySubtitle =>
      'TradeSquare imeundwa kwa biashara halali. Maelezo haya hutusaidia kuelewa biashara yako.';

  @override
  String get authCountryOfRegistration => 'Nchi ya usajili';

  @override
  String get authBusinessName => 'Jina la biashara';

  @override
  String get authBusinessType => 'Aina ya biashara';

  @override
  String get authRegistrationStatus => 'Hali ya usajili wa biashara';

  @override
  String get authRegistrationNumber => 'Nambari ya usajili wa biashara';

  @override
  String get authBusinessLocation => 'Mahali biashara ilipo';

  @override
  String get authSelectCountry => 'Chagua nchi';

  @override
  String get authSelectBusinessType => 'Chagua aina ya biashara';

  @override
  String get authSelectRegistrationStatus => 'Chagua hali ya usajili';

  @override
  String get authOptional => 'Si lazima';

  @override
  String get authRegistered => 'Imesajiliwa';

  @override
  String get authRegistrationPending => 'Usajili unaendelea';

  @override
  String get authNotRegistered => 'Haijasajiliwa';

  @override
  String get authEligibilityInfoTitle =>
      'Kwa nini tunauliza kuhusu biashara yako';

  @override
  String get authEligibilityInfoBody =>
      'TradeSquare imekusudiwa kwa biashara. Kulingana na nchi na aina ya biashara, hati rasmi za usajili zinaweza kuhitajika kabla ya kutumia soko. Ustahiki hutathminiwa kulingana na sera husika; kuchagua aina ya biashara hakuhakikishi ustahiki.';

  @override
  String get authAcceptedDocumentsTitle => 'Hati zinazoweza kukubaliwa';

  @override
  String get authAcceptedDocumentsBody =>
      'Mifano ni cheti cha kuanzishwa kwa kampuni, cheti rasmi cha usajili, au hati nyingine inayofaa ya usajili wa biashara. Mahitaji hutegemea nchi na aina ya biashara.';

  @override
  String get authEligibilityHelp =>
      'Unahitaji msaada? Unaweza kuhifadhi maelezo haya na kuendelea baadaye.';

  @override
  String get authCountryRwanda => 'Rwanda';

  @override
  String get authCountryKenya => 'Kenya';

  @override
  String get authCountryUganda => 'Uganda';

  @override
  String get authCountryTanzania => 'Tanzania';

  @override
  String get authCountryOther => 'Nchi nyingine';

  @override
  String get authTypeLimitedCompany => 'Kampuni yenye dhima ndogo';

  @override
  String get authTypeSoleProprietorship => 'Biashara ya mtu binafsi';

  @override
  String get authTypePartnership => 'Ubia';

  @override
  String get authTypeCooperative => 'Ushirika';

  @override
  String get authTypeRegisteredEnterprise => 'Biashara iliyosajiliwa';

  @override
  String get authTypeOther =>
      'Aina nyingine ya biashara inayotambuliwa kisheria';

  @override
  String get authCertificateTitle => 'Thibitisha utambulisho wa biashara yako';

  @override
  String get authCertificateSubtitle =>
      'Pakia hati rasmi inayothibitisha usajili wa biashara yako.';

  @override
  String get authDocumentType => 'Aina ya hati';

  @override
  String get authSelectDocumentType => 'Chagua aina ya hati';

  @override
  String get authDocIncorporation => 'Cheti cha kuanzishwa kwa kampuni';

  @override
  String get authDocRegistration => 'Cheti cha usajili';

  @override
  String get authDocBusinessRegistration =>
      'Cheti rasmi cha usajili wa biashara';

  @override
  String get authDocOther => 'Hati nyingine rasmi inayofaa ya usajili';

  @override
  String get authDropTitle => 'Buruta na udondoshe hati yako hapa';

  @override
  String get authDropSubtitle => 'au chagua faili kutoka kwenye kifaa chako';

  @override
  String get authBrowseFiles => 'Vinjari faili';

  @override
  String get authFileGuidance => 'PDF, JPG au PNG · Upeo wa 10 MB';

  @override
  String get authFileTooLarge => 'Faili hii inazidi kikomo cha 10 MB.';

  @override
  String get authFileUnsupported => 'Chagua faili ya PDF, JPG au PNG.';

  @override
  String get authFilePickerError =>
      'Kichagua faili hakikufunguka. Tafadhali jaribu tena.';

  @override
  String get authRemoveFile => 'Ondoa hati';

  @override
  String get authReplaceFile => 'Badilisha hati';

  @override
  String get authSelectedDocument => 'Hati iliyochaguliwa';

  @override
  String get authPreparingDocument =>
      'Inatayarisha onyesho la faili kwenye kifaa hiki';

  @override
  String get authDocumentReady => 'Hati iko tayari kuonyeshwa';

  @override
  String get authLocalOnly =>
      'Onyesho hili huhifadhi jina na ukubwa wa faili kwa muda kwenye kiolesura pekee. Faili haipakiziwi wala kutumwa.';

  @override
  String get authReviewNotice =>
      'Cheti cha biashara yako kitakaguliwa. Kuwasilisha hakuhakikishi idhini au ufikiaji wa soko mara moja.';

  @override
  String get authMissingDocument => 'Chagua hati na aina yake ili uendelee.';

  @override
  String get authUploadContinueWithout => 'Endelea bila hati';

  @override
  String get authUploadSubmit => 'Endelea kwenye wasifu wa biashara';

  @override
  String get authProfileTitle => 'Unda wasifu wa biashara yako';

  @override
  String get authProfileSubtitle =>
      'Maelezo machache hutusaidia kubinafsisha matumizi yako ya TradeSquare. Unaweza kuyasasisha baadaye.';

  @override
  String get authStepBusinessInfo => 'Maelezo ya biashara';

  @override
  String get authStepIndustry => 'Sekta';

  @override
  String get authStepProductsOffered => 'Unachotoa';

  @override
  String get authStepProductsNeeded => 'Unachohitaji';

  @override
  String get authStepGoals => 'Malengo ya biashara';

  @override
  String get authStepInterests => 'Maslahi na masoko';

  @override
  String get authDistrictCity => 'Wilaya au jiji';

  @override
  String get authBusinessDescription => 'Maelezo ya biashara';

  @override
  String get authBusinessDescriptionHint => 'Eleza shughuli za biashara yako';

  @override
  String get authChooseIndustry => 'Chagua sekta kuu ya biashara yako';

  @override
  String get authSearchOptions => 'Tafuta chaguo';

  @override
  String get authIndustryAgriculture => 'Kilimo';

  @override
  String get authIndustryTechnology => 'Teknolojia ya Habari';

  @override
  String get authIndustryManufacturing => 'Utengenezaji';

  @override
  String get authIndustryRetailWholesale => 'Rejareja na jumla';

  @override
  String get authIndustryConstruction => 'Ujenzi';

  @override
  String get authIndustryTransport => 'Usafirishaji na ugavi';

  @override
  String get authIndustryFood => 'Chakula na vinywaji';

  @override
  String get authIndustryHealthcare => 'Huduma za afya';

  @override
  String get authIndustryEducation => 'Elimu';

  @override
  String get authIndustryTourism => 'Utalii na ukarimu';

  @override
  String get authIndustryProfessional => 'Huduma za kitaalamu';

  @override
  String get authIndustryEnergy => 'Nishati';

  @override
  String get authIndustryMining => 'Uchimbaji madini';

  @override
  String get authIndustryOther => 'Nyingine';

  @override
  String get authProductsOffered => 'Bidhaa au huduma unazotoa';

  @override
  String get authProductsNeeded => 'Bidhaa au huduma unazohitaji';

  @override
  String get authListInputHint => 'Ongeza kipengee kisha ubonyeze Enter';

  @override
  String get authAddItem => 'Ongeza';

  @override
  String get authSkip => 'Ruka kwa sasa';

  @override
  String get authBusinessGoals => 'Ungependa kufanya nini kwenye TradeSquare?';

  @override
  String get authGoalBuyers => 'Tafuta wanunuzi';

  @override
  String get authGoalSuppliers => 'Tafuta wasambazaji';

  @override
  String get authGoalPromote => 'Tangaza bidhaa';

  @override
  String get authGoalPartners => 'Tafuta washirika wa biashara';

  @override
  String get authGoalOpportunities => 'Gundua fursa';

  @override
  String get authGoalMarkets => 'Panua kwenye masoko mapya';

  @override
  String get authInterests => 'Maslahi ya biashara';

  @override
  String get authInterestsHint => 'Ongeza mada muhimu kwa biashara yako.';

  @override
  String get authTargetMarkets => 'Masoko lengwa';

  @override
  String get authTargetMarketsHint =>
      'Ongeza nchi au maeneo unayotaka kufanya biashara nayo.';

  @override
  String get authReviewTitle => 'Kagua maelezo yako';

  @override
  String get authReviewSubtitle =>
      'Angalia maelezo yako kabla ya kuendelea. Unaweza kurudi kuyarekebisha.';

  @override
  String get authEdit => 'Hariri';

  @override
  String get authSubmitApplication => 'Wasilisha kwa ukaguzi';

  @override
  String get authSubmissionNotice =>
      'Hili ni onyesho la frontend pekee. Kuwasilisha hakutatuma maelezo wala kuanzisha ukaguzi halisi.';

  @override
  String get authApplicationStatus => 'Hali ya ombi';

  @override
  String get authStatusPrototype => 'Onyesho la hali ya mfano';

  @override
  String get authStatusIncomplete => 'Maelezo hayajakamilika';

  @override
  String get authStatusCertificateMissing => 'Cheti hakijawasilishwa';

  @override
  String get authStatusSubmitted => 'Imewasilishwa kwa ukaguzi';

  @override
  String get authStatusUnderReview => 'Inakaguliwa';

  @override
  String get authStatusAdditionalInfo => 'Maelezo zaidi yanahitajika';

  @override
  String get authStatusApproved => 'Imeidhinishwa';

  @override
  String get authStatusNotApproved => 'Haijaidhinishwa';

  @override
  String get authStatusIncompleteBody =>
      'Kamilisha maelezo yanayohitajika ya biashara ili uendelee.';

  @override
  String get authStatusCertificateMissingBody =>
      'Ongeza hati inayofaa ya usajili ukiwa tayari. Unaweza kuendelea na onyesho hili bila hati.';

  @override
  String get authStatusSubmittedBody =>
      'Maelezo ya biashara yamewasilishwa kwenye onyesho hili la kifaa. Hakuna ukaguzi halisi ulioanza.';

  @override
  String get authStatusUnderReviewBody =>
      'Hii ni hali ya maonyesho pekee. Hakuna ukaguzi wa uthibitishaji uliofanyika.';

  @override
  String get authStatusAdditionalInfoBody =>
      'Hali hii ya maonyesho inaonyesha kuwa maelezo zaidi yanaweza kuhitajika katika mchakato wa baadaye.';

  @override
  String get authStatusApprovedBody =>
      'Onyesho pekee: hakuna biashara iliyoidhinishwa au kuthibitishwa.';

  @override
  String get authStatusNotApprovedBody =>
      'Onyesho pekee: hakuna uamuzi wa ustahiki uliofanywa.';

  @override
  String get authStatusNextAction => 'Hatua inayofuata';

  @override
  String get authStatusReturnHome => 'Rudi kwenye ukurasa wa kuingia';

  @override
  String get authStatusChangePreview => 'Onyesha hali nyingine';

  @override
  String get authStatusDisclaimer =>
      'Onyesho pekee · Hali hii si uamuzi halisi wa ustahiki au uthibitishaji.';

  @override
  String get authStatusCertificateAction => 'Kagua hatua ya cheti';

  @override
  String get authStatusProfileAction => 'Kagua maelezo ya biashara';

  @override
  String get authCountryLabel => 'Nchi';

  @override
  String get authPhoneCountryCode => 'Msimbo wa nchi';

  @override
  String get authPhoneRwanda => '+250';

  @override
  String get authPhoneKenya => '+254';

  @override
  String get authPhoneUganda => '+256';

  @override
  String get authPhoneTanzania => '+255';

  @override
  String get authLanguage => 'Lugha';

  @override
  String get authStoryTitle =>
      'Jenga mahusiano imara. Pata fursa yako inayofuata.';

  @override
  String get authStoryBody =>
      'Mahali pa kuaminika pa kutambulisha biashara yako, kukutana na washirika sahihi na kugundua masoko mapya.';

  @override
  String get authStoryItemOne => 'Unda wasifu wa biashara yako';

  @override
  String get authStoryItemTwo =>
      'Shiriki maelezo ya usajili kwa ukaguzi wa ustahiki wa baadaye';

  @override
  String get authStoryItemThree =>
      'Gundua wanunuzi, wasambazaji na fursa za biashara';

  @override
  String get discoverAiBadge => 'Ugunduzi wa AI wa TradeSquare';

  @override
  String get discoverHeroTitle => 'Pata muunganisho wako ujao wa biashara';

  @override
  String get discoverHeroSubtitle =>
      'Eleza unachohitaji kwa lugha rahisi. Discover inatafuta biashara, bidhaa na masoko nchini Rwanda na Afrika Mashariki.';

  @override
  String get discoverHeroSubtitleMobile =>
      'Sema au andika unachohitaji. Discover inatafuta biashara Afrika Mashariki.';

  @override
  String get discoverSearchHint =>
      'Mfano: Ninatengeneza fanicha za shule nchini Rwanda na nataka kuuza Uganda';

  @override
  String get discoverVoiceHint =>
      'Inasikiliza… mwambie TradeSquare unachotafuta';

  @override
  String get discoverVoicePreparing => 'Inaandaa maikrofoni…';

  @override
  String get discoverVoiceListening => 'Inasikiliza — endelea kuzungumza';

  @override
  String get discoverVoiceCaptured => 'Imepokelewa — inatafuta sasa';

  @override
  String get discoverVoiceStop => 'Acha kusikiliza';

  @override
  String get discoverVoiceUnavailable =>
      'Sauti haipatikani hapa. Angalia ruhusa ya maikrofoni au andika utafutaji.';

  @override
  String get discoverSearchAction => 'Gundua';

  @override
  String get discoverTryExamples => 'Jaribu mfano';

  @override
  String get discoverCategoryBusinesses => 'Biashara';

  @override
  String get discoverCategoryProducts => 'Bidhaa na huduma';

  @override
  String get discoverCategoryMatches => 'Mechi za AI';

  @override
  String get discoverCategoryMarkets => 'Masoko';

  @override
  String get discoverIndustriesTitle => 'Chunguza viwanda';

  @override
  String get discoverIndustriesSubtitle =>
      'Vinjari shughuli za kikanda kwa sekta.';

  @override
  String get discoverPersonalizedTitle => 'Zinazofaa biashara yako';

  @override
  String get discoverPersonalizedSubtitle =>
      'Mapendekezo kutoka wasifu wako wa TradeSquare na maslahi yaliyochapishwa.';

  @override
  String get discoverMatchesTitle => 'Ulinganishaji wa AI';

  @override
  String get discoverMatchesSubtitle =>
      'Miunganisho inayowezekana ikielezewa kwa ushahidi uliopo.';

  @override
  String get discoverMarketsTitle => 'Chunguza masoko ya kikanda';

  @override
  String get discoverMarketsSubtitle =>
      'Anza na Rwanda, Kenya, Uganda, Tanzania na Burundi.';

  @override
  String discoverMarketCount(int count) {
    return 'Biashara $count';
  }

  @override
  String get discoverJourneyTitle => 'Safari ya ugunduzi';

  @override
  String get discoverClearSearch => 'Futa';

  @override
  String get discoverInterpreted => 'Vigezo vilivyoeleweka';

  @override
  String get discoverStageUnderstanding => 'Kuelewa ombi lako';

  @override
  String get discoverStageIdentifying => 'Kutambua bidhaa, shughuli na masoko';

  @override
  String get discoverStageSearching => 'Kutafuta rekodi za TradeSquare';

  @override
  String get discoverStageRanking => 'Kupanga matokeo muhimu';

  @override
  String get discoverEmptyTitle => 'Hakuna biashara zinazolingana';

  @override
  String get discoverEmptyBody =>
      'Panua masoko, ondoa kichujio, au fupisha maelezo yako.';

  @override
  String get discoverBroadenSearch => 'Panua utafutaji';

  @override
  String get discoverBusinessResults => 'Biashara zinazolingana';

  @override
  String get discoverProductsResults => 'Bidhaa na huduma zinazolingana';

  @override
  String discoverResultsCount(int count) {
    return 'Matokeo $count';
  }

  @override
  String get businessPageTitle => 'Biashara Yangu';

  @override
  String get businessTabOverview => 'Muhtasari';

  @override
  String get businessTabProducts => 'Bidhaa na huduma';

  @override
  String get businessTabOpportunities => 'Fursa';

  @override
  String get businessTabActivity => 'Shughuli za biashara';

  @override
  String get businessEditAction => 'Hariri biashara';

  @override
  String get businessPreviewAction => 'Hakiki';

  @override
  String get businessPublicPreview => 'Hakiki ya umma';

  @override
  String get businessExitPreview => 'Toka hakiki';

  @override
  String get businessAiTitle => 'TradeSquare Business AI';

  @override
  String get businessAiSubtitle =>
      'Rasimu za hiari kuboresha maandishi. Kagua na hariri kabla ya kuchapisha. AI haijaunganishwa bado.';

  @override
  String get businessVerificationTitle => 'Uthibitishaji wa biashara';

  @override
  String get businessLoadError => 'Imeshindwa kupakia nafasi ya biashara yako.';
}

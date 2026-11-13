// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kinyarwanda (`rw`).
class AppLocalizationsRw extends AppLocalizations {
  AppLocalizationsRw([String locale = 'rw']) : super(locale);

  @override
  String get appTitle => 'TradeSquare';

  @override
  String footerCopyright(int year, String brand) {
    return '© $year $brand. Uburenganzira bwose burabitswe.';
  }

  @override
  String get footerAbout => 'Ibyerekeye';

  @override
  String get footerHelpSupport => 'Ubufasha n\'ubujyanama';

  @override
  String get footerPrivacyPolicy => 'Politiki y\'ibanga';

  @override
  String get footerTermsOfService => 'Amabwiriza yo gukoresha';

  @override
  String get footerComingSoon => 'Biteganyijwe vuba';

  @override
  String footerPlaceholderSemantics(String label) {
    return '$label, biteganyijwe vuba';
  }

  @override
  String get footerLanguage => 'Ururimi';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKinyarwanda => 'Kinyarwanda';

  @override
  String footerVersion(String version) {
    return 'Verisiyo $version';
  }

  @override
  String get navWorkspace => 'AHO UKORERA';

  @override
  String get navIntelligence => 'UBWENGE';

  @override
  String get navAccount => 'KONTI';

  @override
  String get navSupport => 'UBUFASHA';

  @override
  String get navOverview => 'Incamake';

  @override
  String get navDiscover => 'Shakisha';

  @override
  String get navProducts => 'Ibicuruzwa Byanjye';

  @override
  String get navBuyingRequests => 'Ibyifuzo byo Kugura';

  @override
  String get navConnections => 'Abo Wahujwe Na Bo';

  @override
  String get navMessages => 'Ubutumwa';

  @override
  String get navAiAssistant => 'TradeSquare AI';

  @override
  String get navMarketIntelligence => 'Amakuru y\'Isoko';

  @override
  String get navNotifications => 'Imenyesha';

  @override
  String get navBusinessProfile => 'Umwirondoro w\'Ubucuruzi';

  @override
  String get navSettings => 'Amagenamiterere';

  @override
  String get navHelpSupport => 'Ubufasha n\'Ubujyanama';

  @override
  String get navAiShort => 'AI';

  @override
  String get navProfileShort => 'Umwirondoro';

  @override
  String get navAiBadge => 'AI';

  @override
  String get navAccountUnavailable => 'Amakuru ya konti ntaboneka';

  @override
  String get navExpandSidebar => 'Kwagura uruhande rw\'ibikubiyemo';

  @override
  String get navCollapseSidebar => 'Kugabanya uruhande rw\'ibikubiyemo';

  @override
  String get navOpenMenu => 'Fungura ibikubiyemo';

  @override
  String get navCloseMenu => 'Funga ibikubiyemo';

  @override
  String navDestinationUnavailable(String label) {
    return '$label ntiraboneka muri iyi porogaramu';
  }

  @override
  String get navVerifiedBusiness => 'Ubucuruzi bwemejwe';

  @override
  String get navProfileMenu => 'Ibikubiyemo bya konti';

  @override
  String get navViewBusinessProfile => 'Reba Umwirondoro w\'Ubucuruzi';

  @override
  String get navAccountSettings => 'Amagenamiterere ya Konti';

  @override
  String get navSignOut => 'Sohoka';

  @override
  String get navSignOutConfirmation => 'Urashaka koko gusohoka?';

  @override
  String get navCancel => 'Hagarika';

  @override
  String get languageKiswahili => 'Kiswahili';

  @override
  String get languageFrench => 'Français';

  @override
  String get topBarSearch => 'Shakisha muri TradeSquare';

  @override
  String get topBarSearchHint => 'Shakisha ubucuruzi, ibicuruzwa n\'amahirwe';

  @override
  String get topBarImageSearch => 'Shakisha ukoresheje ifoto';

  @override
  String get topBarVoiceSearch => 'Shakisha ukoresheje ijwi';

  @override
  String get topBarCloseSearch => 'Funga ishakisha';

  @override
  String get topBarCreate => 'Kora';

  @override
  String get topBarCreateUnavailable => 'Ibikorwa byo gukora ntibiraboneka';

  @override
  String get topBarAddProduct => 'Ongeraho Igicuruzwa';

  @override
  String get topBarNewBuyingRequest => 'Kora Icyifuzo cyo Kugura';

  @override
  String get topBarNotifications => 'Imenyesha';

  @override
  String topBarUnreadNotifications(int count) {
    return 'Imenyesha $count ridasomwe';
  }

  @override
  String get topBarCloseNotifications => 'Funga imenyesha';

  @override
  String get topBarNotificationsLoading => 'Imenyesha ririmo gutegurwa';

  @override
  String get topBarNotificationsError => 'Imenyesha ntiryashoboye gufunguka.';

  @override
  String get topBarNoNotifications => 'Nta menyesha rishya ufite.';

  @override
  String get topBarRetry => 'Ongera ugerageze';

  @override
  String get topBarAccountMenu => 'Ibikubiyemo bya konti';

  @override
  String get topBarBusinessProfile => 'Umwirondoro w\'Ubucuruzi';

  @override
  String get topBarAccountSettings => 'Amagenamiterere ya Konti';

  @override
  String get topBarLanguage => 'Ururimi';

  @override
  String get topBarHelpSupport => 'Ubufasha n\'Ubujyanama';

  @override
  String get topBarSignOut => 'Sohoka';

  @override
  String get topBarSignOutConfirmation => 'Urashaka koko gusohoka?';

  @override
  String get topBarCancel => 'Hagarika';

  @override
  String homeGreeting(String name) {
    return 'Murakaza neza nanone, $name';
  }

  @override
  String get homeDiscoverTitle => 'Menya amahirwe y\'ubucuruzi bwawe';

  @override
  String get homeFeedIntro =>
      'Abaguzi, abatanga ibicuruzwa n\'amahirwe bijyanye n\'ubucuruzi bwawe.';

  @override
  String get homeFeedIntroBuyer =>
      'Menya ibicuruzwa n\'ababitanga bijyanye n\'ibyo ukeneye.';

  @override
  String get homeFeedIntroSupplier =>
      'Menya abaguzi n\'ibyifuzo bijyanye n\'ibyo utanga.';

  @override
  String homePersonalizedFor(String industry) {
    return 'Amahirwe ajyanye na $industry';
  }

  @override
  String get homeInterests => 'Ibyo ubucuruzi bwawe bwitabira';

  @override
  String get homeManageInterests => 'Hindura ibyo ukunda';

  @override
  String get homeManageInterestsTitle =>
      'Hindura ibyo ubucuruzi bwawe bwitabira';

  @override
  String get homeManageInterestsHint =>
      'Hitamo ingingo zigufasha kubona amahirwe akubereye.';

  @override
  String get homeInterestOptionsEmpty => 'Ibyiciro byo guhitamo ntibiraboneka.';

  @override
  String get homeInterestsEmpty =>
      'Ongeraho ibyo ukunda kugira ngo ubone amahirwe akubereye.';

  @override
  String get homeSaveInterests => 'Bika ibyo wahisemo';

  @override
  String get homeCancel => 'Kureka';

  @override
  String get homeSectionOpportunities => 'Amahirwe ajyanye n\'ubucuruzi bwawe';

  @override
  String get homeSectionBuyers => 'Abaguzi bashaka ibyo ugurisha';

  @override
  String get homeSectionSuppliers => 'Abatanga ibicuruzwa ushobora gukenera';

  @override
  String get homeSectionProducts => 'Ibicuruzwa bijyanye n\'ubucuruzi bwawe';

  @override
  String get homeSectionBusinesses => 'Ubucuruzi ushobora gukorana na bwo';

  @override
  String get homeSectionBuyingRequests => 'Ibyifuzo bishya byo kugura';

  @override
  String get homeSectionTradeOpportunities => 'Andi mahirwe y\'ubucuruzi';

  @override
  String get homeSectionMarketInsights => 'Amakuru y\'isoko n\'inganda';

  @override
  String get homeSectionAiRecommendations => 'Ibyifuzo bya TradeSquare AI';

  @override
  String get homeNoSectionItems =>
      'Nta mahirwe ajyanye n\'ibyo ukora ahari ubu.';

  @override
  String get homeEmptyTitle => 'Urutonde rw\'amahirwe rurimo gutegurwa';

  @override
  String get homeEmptyBody =>
      'Amahirwe ajyanye n\'ubucuruzi bwawe azagaragara igihe amakuru y\'isoko azaba ahari.';

  @override
  String get homeLoading => 'Turimo kuzana amahirwe ajyanye n\'ubucuruzi bwawe';

  @override
  String get homeLoadError => 'Ntitwabashije kuzana amahirwe yawe.';

  @override
  String get homeOffline =>
      'Nta murongo wa interineti. Ongera uhuze ugerageze nanone.';

  @override
  String get homeRetry => 'Ongera ugerageze';

  @override
  String get homeLoadMore => 'Reba andi mahirwe';

  @override
  String get homeViewDetails => 'Reba ibisobanuro';

  @override
  String get homeSave => 'Bika';

  @override
  String get homeSaved => 'Byabitswe';

  @override
  String get homeContact => 'Vugana n\'ubucuruzi';

  @override
  String get homeConnect => 'Saba gukorana';

  @override
  String get homeRespond => 'Subiza icyifuzo';

  @override
  String get homeMoreActions => 'Andi mahitamo y\'ibyifuzo';

  @override
  String get homeMoreLikeThis => 'Nyereka ibindi bisa n\'ibi';

  @override
  String get homeNotInterested => 'Ibi ntibinshishikaje';

  @override
  String get homeWhySeeing => 'Kuki mbona ibi?';

  @override
  String get homeWhyTitle => 'Impamvu ibi bikubereye';

  @override
  String get homeWhyIndustry => 'Bijyanye n\'urwego rw\'ubucuruzi bwawe';

  @override
  String get homeWhyCategory => 'Bijyanye n\'icyiciro cy\'ubucuruzi bwawe';

  @override
  String get homeWhyInterest => 'Bijyanye n\'ibyo ubucuruzi bwawe bwitabira';

  @override
  String get homeWhyProduct => 'Bijyanye n\'ibyo ugurisha cyangwa ukeneye';

  @override
  String get homeWhyLocation => 'Bijyanye n\'aho ubucuruzi bwawe buri';

  @override
  String get homeWhyIntent =>
      'Bijyanye n\'intego zawe zo kugura cyangwa kugurisha';

  @override
  String get homeWhyRecent => 'Byashyizweho vuba';

  @override
  String get homeWhyGeneric =>
      'Ibi bishobora kuba bijyanye n\'umwirondoro w\'ubucuruzi bwawe.';

  @override
  String get homeVerifiedBusiness => 'Ubucuruzi bwagenzuwe';

  @override
  String get homeAiPromptTitle => 'Baza TradeSquare AI';

  @override
  String get homeAiPromptHint => 'Urashaka kugura cyangwa kugurisha iki?';

  @override
  String get homeAiAsk => 'Baza';

  @override
  String get homeFeedbackRecorded =>
      'Murakoze. Igitekerezo cyawe kidufasha kunoza ibyifuzo.';

  @override
  String get authBrandSubtitle => 'Urubuga rwizewe rw\'ubucuruzi';

  @override
  String get authPrototypeLabel =>
      'Igerageza rya frontend · Konti cyangwa igenzura ntibikorwa';

  @override
  String get authLoginWelcome => 'Murakaza neza nanone';

  @override
  String get authLoginSubtitle => 'Amahirwe yawe akurikira atangirira hano.';

  @override
  String get authAccountRole => 'Uruhare mu bucuruzi';

  @override
  String get authRoleBuyer => 'Umuguzi';

  @override
  String get authRoleSupplier => 'Utanga ibicuruzwa';

  @override
  String get authRoleBoth => 'Umuguzi n\'utanga ibicuruzwa';

  @override
  String get authEmail => 'Aderesi ya imeyili';

  @override
  String get authPassword => 'Ijambo ry\'ibanga';

  @override
  String get authShowPassword => 'Erekana ijambo ry\'ibanga';

  @override
  String get authHidePassword => 'Hisha ijambo ry\'ibanga';

  @override
  String get authRememberMe => 'Unyibuke';

  @override
  String get authForgotPassword => 'Wibagiwe ijambo ry\'ibanga?';

  @override
  String get authSignIn => 'Injira';

  @override
  String get authNoAccount => 'Ntabwo urakoresha TradeSquare?';

  @override
  String get authCreateAccount => 'Fungura konti';

  @override
  String get authRegistrationTitle => 'Fungura konti ya TradeSquare';

  @override
  String get authRegistrationSubtitle =>
      'Injira mu rubuga ruhuza ubucuruzi bwemewe n\'abaguzi, abatanga ibicuruzwa n\'amahirwe.';

  @override
  String get authFullName => 'Amazina yose';

  @override
  String get authPhoneNumber => 'Nimero ya telefoni';

  @override
  String get authConfirmPassword => 'Emeza ijambo ry\'ibanga';

  @override
  String get authPasswordStrength => 'Imbaraga z\'ijambo ry\'ibanga';

  @override
  String get authPasswordWeak => 'Ryoroshye';

  @override
  String get authPasswordFair => 'Riringaniye';

  @override
  String get authPasswordStrong => 'Rikomeye';

  @override
  String get authAcceptTerms =>
      'Nemera Amabwiriza yo gukoresha na Politiki y\'ibanga.';

  @override
  String get authTermsPrivacy =>
      'Amabwiriza yo gukoresha na Politiki y\'ibanga';

  @override
  String get authHaveAccount => 'Usanzwe ufite konti?';

  @override
  String get authContinue => 'Komeza';

  @override
  String get authBack => 'Subira inyuma';

  @override
  String get authRequired => 'Iki gice kirakenewe.';

  @override
  String get authInvalidEmail => 'Andika aderesi ya imeyili yemewe.';

  @override
  String get authPasswordMin => 'Koresha inyuguti nibura 8.';

  @override
  String get authPasswordsMismatch => 'Amagambo y\'ibanga ntahuye.';

  @override
  String get authAcceptTermsError => 'Emera amabwiriza kugira ngo ukomeze.';

  @override
  String get authMockSignInMessage =>
      'Kwinjira ni igaragaza ry\'imiterere gusa. Nta kwemeza konti kurimo.';

  @override
  String get authMockForgotMessage =>
      'Kugarura ijambo ry\'ibanga ntibirashyirwa muri iri gerageza.';

  @override
  String get authMockSubmittedMessage =>
      'Ifishi ibitswe muri iri gerageza gusa. Nta kintu cyoherejwe.';

  @override
  String get authStepAccount => 'Konti';

  @override
  String get authStepEligibility => 'Kwemererwa k\'ubucuruzi';

  @override
  String get authStepCertificate => 'Icyemezo';

  @override
  String get authStepProfile => 'Umwirondoro w\'ubucuruzi';

  @override
  String get authStepReview => 'Gusuzuma';

  @override
  String get authTellBusiness => 'Tubwire iby\'ubucuruzi bwawe';

  @override
  String get authEligibilitySubtitle =>
      'TradeSquare igenewe ubucuruzi bwemewe. Aya makuru adufasha kumenya uko ubucuruzi bwawe buhagaze.';

  @override
  String get authCountryOfRegistration => 'Igihugu ubucuruzi bwanditswemo';

  @override
  String get authBusinessName => 'Izina ry\'ubucuruzi';

  @override
  String get authBusinessType => 'Ubwoko bw\'ubucuruzi';

  @override
  String get authRegistrationStatus => 'Imiterere yo kwandikisha ubucuruzi';

  @override
  String get authRegistrationNumber => 'Nimero yo kwandikisha ubucuruzi';

  @override
  String get authBusinessLocation => 'Aho ubucuruzi buri';

  @override
  String get authSelectCountry => 'Hitamo igihugu';

  @override
  String get authSelectBusinessType => 'Hitamo ubwoko bw\'ubucuruzi';

  @override
  String get authSelectRegistrationStatus => 'Hitamo uko kwandikisha bihagaze';

  @override
  String get authOptional => 'Ntibitegetswe';

  @override
  String get authRegistered => 'Bwaranditswe';

  @override
  String get authRegistrationPending => 'Kwandikwa biracyakorwa';

  @override
  String get authNotRegistered => 'Ntabwo bwanditswe';

  @override
  String get authEligibilityInfoTitle => 'Impamvu tubaza iby\'ubucuruzi bwawe';

  @override
  String get authEligibilityInfoBody =>
      'TradeSquare igenewe ubucuruzi. Bitewe n\'igihugu n\'ubwoko bw\'ubucuruzi, hashobora gusabwa inyandiko zemewe zo kwandikisha mbere yo gukoresha isoko. Kwemererwa gukurikiza amategeko abigenga; guhitamo ubwoko ntibivuga ko wemerewe.';

  @override
  String get authAcceptedDocumentsTitle => 'Inyandiko zishobora kwemerwa';

  @override
  String get authAcceptedDocumentsBody =>
      'Urugero ni icyemezo cyo gushinga ikigo, icyemezo cyo kwandikisha cyangwa indi nyandiko yemewe ijyanye n\'ubwoko bw\'ubucuruzi. Ibisabwa biterwa n\'igihugu n\'ubwoko bw\'ubucuruzi.';

  @override
  String get authEligibilityHelp =>
      'Ukeneye ubufasha? Ushobora kubika aya makuru ukazagaruka nyuma.';

  @override
  String get authCountryRwanda => 'Rwanda';

  @override
  String get authCountryKenya => 'Kenya';

  @override
  String get authCountryUganda => 'Uganda';

  @override
  String get authCountryTanzania => 'Tanzania';

  @override
  String get authCountryOther => 'Ikindi gihugu';

  @override
  String get authTypeLimitedCompany =>
      'Ikigo cy\'ubucuruzi gifite inshingano ntarengwa';

  @override
  String get authTypeSoleProprietorship => 'Ubucuruzi bw\'umuntu ku giti cye';

  @override
  String get authTypePartnership => 'Ubucuruzi bw\'abafatanyije';

  @override
  String get authTypeCooperative => 'Koperative';

  @override
  String get authTypeRegisteredEnterprise => 'Ikigo cyanditswe';

  @override
  String get authTypeOther => 'Ubundi bwoko bw\'ubucuruzi bwemewe n\'amategeko';

  @override
  String get authCertificateTitle => 'Emeza umwirondoro w\'ubucuruzi';

  @override
  String get authCertificateSubtitle =>
      'Shyiraho inyandiko yemewe igaragaza ko ubucuruzi bwanditswe.';

  @override
  String get authDocumentType => 'Ubwoko bw\'inyandiko';

  @override
  String get authSelectDocumentType => 'Hitamo ubwoko bw\'inyandiko';

  @override
  String get authDocIncorporation => 'Icyemezo cyo gushinga ikigo';

  @override
  String get authDocRegistration => 'Icyemezo cyo kwandikisha';

  @override
  String get authDocBusinessRegistration =>
      'Icyemezo cyemewe cyo kwandikisha ubucuruzi';

  @override
  String get authDocOther => 'Indi nyandiko yemewe yo kwandikisha';

  @override
  String get authDropTitle => 'Kurura inyandiko uyishyire hano';

  @override
  String get authDropSubtitle =>
      'cyangwa uhitemo dosiye iri mu gikoresho cyawe';

  @override
  String get authBrowseFiles => 'Hitamo dosiye';

  @override
  String get authFileGuidance => 'PDF, JPG cyangwa PNG · Ntarengwa 10 MB';

  @override
  String get authFileTooLarge => 'Iyi dosiye irenze ingano ntarengwa ya 10 MB.';

  @override
  String get authFileUnsupported => 'Hitamo dosiye ya PDF, JPG cyangwa PNG.';

  @override
  String get authFilePickerError =>
      'Guhitamo dosiye ntibyashobotse. Ongera ugerageze.';

  @override
  String get authRemoveFile => 'Kuraho inyandiko';

  @override
  String get authReplaceFile => 'Hindura inyandiko';

  @override
  String get authSelectedDocument => 'Inyandiko wahisemo';

  @override
  String get authPreparingDocument =>
      'Turimo gutegura igaragaza rya dosiye kuri iki gikoresho';

  @override
  String get authDocumentReady => 'Inyandiko yiteguye kugaragazwa';

  @override
  String get authLocalOnly =>
      'Iri gerageza ribika izina n\'ingano ya dosiye mu gihe gito gusa. Dosiye ntiyoherezwa cyangwa ngo yimurwe.';

  @override
  String get authReviewNotice =>
      'Icyemezo cy\'ubucuruzi bwawe kizakenera gusuzumwa. Kohereza ntibyemeza ko uzemerwa cyangwa ko uzahita ukoresha isoko.';

  @override
  String get authMissingDocument =>
      'Hitamo inyandiko n\'ubwoko bwayo kugira ngo ukomeze.';

  @override
  String get authUploadContinueWithout => 'Komeza nta nyandiko';

  @override
  String get authUploadSubmit => 'Komeza ku mwirondoro w\'ubucuruzi';

  @override
  String get authProfileTitle => 'Tegura umwirondoro w\'ubucuruzi bwawe';

  @override
  String get authProfileSubtitle =>
      'Amakuru make adufasha kunoza uko ukoresha TradeSquare. Ushobora kuyahindura nyuma.';

  @override
  String get authStepBusinessInfo => 'Amakuru y\'ubucuruzi';

  @override
  String get authStepIndustry => 'Urwego rw\'ubucuruzi';

  @override
  String get authStepProductsOffered => 'Ibyo utanga';

  @override
  String get authStepProductsNeeded => 'Ibyo ukeneye';

  @override
  String get authStepGoals => 'Intego z\'ubucuruzi';

  @override
  String get authStepInterests => 'Ibyo ukunda n\'amasoko';

  @override
  String get authDistrictCity => 'Akarere cyangwa umujyi';

  @override
  String get authBusinessDescription => 'Ibisobanuro by\'ubucuruzi';

  @override
  String get authBusinessDescriptionHint =>
      'Sobanura ibyo ubucuruzi bwawe bukora';

  @override
  String get authChooseIndustry => 'Hitamo urwego rw\'ibanze rw\'ubucuruzi';

  @override
  String get authSearchOptions => 'Shakisha mu mahitamo';

  @override
  String get authIndustryAgriculture => 'Ubuhinzi';

  @override
  String get authIndustryTechnology => 'Ikoranabuhanga mu itumanaho';

  @override
  String get authIndustryManufacturing => 'Inganda';

  @override
  String get authIndustryRetailWholesale =>
      'Ubucuruzi bucuruza ku giti no ku bwinshi';

  @override
  String get authIndustryConstruction => 'Ubwubatsi';

  @override
  String get authIndustryTransport => 'Ubwikorezi n\'ibikoresho';

  @override
  String get authIndustryFood => 'Ibiribwa n\'ibinyobwa';

  @override
  String get authIndustryHealthcare => 'Ubuzima';

  @override
  String get authIndustryEducation => 'Uburezi';

  @override
  String get authIndustryTourism => 'Ubukerarugendo n\'amahoteli';

  @override
  String get authIndustryProfessional => 'Serivisi z\'umwuga';

  @override
  String get authIndustryEnergy => 'Ingufu';

  @override
  String get authIndustryMining => 'Ubucukuzi bw\'amabuye y\'agaciro';

  @override
  String get authIndustryOther => 'Ibindi';

  @override
  String get authProductsOffered => 'Ibicuruzwa cyangwa serivisi utanga';

  @override
  String get authProductsNeeded => 'Ibicuruzwa cyangwa serivisi ushaka';

  @override
  String get authListInputHint => 'Ongeraho ikintu ukande Enter';

  @override
  String get authAddItem => 'Ongeraho';

  @override
  String get authSkip => 'Bireke ubu';

  @override
  String get authBusinessGoals => 'Wifuza gukora iki kuri TradeSquare?';

  @override
  String get authGoalBuyers => 'Shaka abaguzi';

  @override
  String get authGoalSuppliers => 'Shaka abatanga ibicuruzwa';

  @override
  String get authGoalPromote => 'Kwamamaza ibicuruzwa';

  @override
  String get authGoalPartners => 'Shaka abafatanyabikorwa';

  @override
  String get authGoalOpportunities => 'Menya amahirwe';

  @override
  String get authGoalMarkets => 'Kwagura amasoko';

  @override
  String get authInterests => 'Ibyo ubucuruzi bwitabira';

  @override
  String get authInterestsHint =>
      'Ongeraho ingingo z\'ingenzi ku bucuruzi bwawe.';

  @override
  String get authTargetMarkets => 'Amasoko ugamije';

  @override
  String get authTargetMarketsHint =>
      'Ongeraho ibihugu cyangwa uturere wifuza gukorana na two.';

  @override
  String get authReviewTitle => 'Ongera urebe amakuru yawe';

  @override
  String get authReviewSubtitle =>
      'Reba amakuru yawe mbere yo gukomeza. Ushobora gusubira inyuma ukayahindura.';

  @override
  String get authEdit => 'Hindura';

  @override
  String get authSubmitApplication => 'Ohereza ngo bisuzumwe';

  @override
  String get authSubmissionNotice =>
      'Iri ni igerageza rya frontend gusa. Kohereza ntibizohereza amakuru cyangwa ngo bitangize isuzuma.';

  @override
  String get authApplicationStatus => 'Imiterere y\'ubusabe';

  @override
  String get authStatusPrototype => 'Igerageza ry\'imiterere y\'ubusabe';

  @override
  String get authStatusIncomplete => 'Amakuru atuzuye';

  @override
  String get authStatusCertificateMissing => 'Nta cyemezo cyatanzwe';

  @override
  String get authStatusSubmitted => 'Byoherejwe ngo bisuzumwe';

  @override
  String get authStatusUnderReview => 'Birimo gusuzumwa';

  @override
  String get authStatusAdditionalInfo => 'Harakenewe andi makuru';

  @override
  String get authStatusApproved => 'Byemewe';

  @override
  String get authStatusNotApproved => 'Ntibyemewe';

  @override
  String get authStatusIncompleteBody =>
      'Uzuza amakuru akenewe y\'ubucuruzi kugira ngo ukomeze.';

  @override
  String get authStatusCertificateMissingBody =>
      'Ongeraho inyandiko yo kwandikisha igihe witeguye. Ushobora gukomeza iri gerageza nta yo.';

  @override
  String get authStatusSubmittedBody =>
      'Amakuru y\'ubucuruzi bwawe yoherejwe muri iri gerageza ryo kuri iki gikoresho. Nta suzuma nyaryo ryatangiye.';

  @override
  String get authStatusUnderReviewBody =>
      'Iyi ni imiterere yo kwerekana gusa. Nta suzuma cyangwa igenzura ryabaye.';

  @override
  String get authStatusAdditionalInfoBody =>
      'Iyi miterere yerekana ko amakuru y\'inyongera ashobora gusabwa mu isuzuma rizaza.';

  @override
  String get authStatusApprovedBody =>
      'Igerageza gusa: nta bucuruzi bwemejwe cyangwa ngo bugenzurwe.';

  @override
  String get authStatusNotApprovedBody =>
      'Igerageza gusa: nta cyemezo cyo kwemererwa cyafashwe.';

  @override
  String get authStatusNextAction => 'Intambwe ikurikira';

  @override
  String get authStatusReturnHome => 'Subira ku kwinjira';

  @override
  String get authStatusChangePreview => 'Hitamo uko bigaragara';

  @override
  String get authStatusDisclaimer =>
      'Igerageza gusa · Iyi miterere si icyemezo nyacyo cyo kwemererwa cyangwa kugenzura.';

  @override
  String get authStatusCertificateAction => 'Subira ku ntambwe y\'icyemezo';

  @override
  String get authStatusProfileAction => 'Subira ku makuru y\'ubucuruzi';

  @override
  String get authCountryLabel => 'Igihugu';

  @override
  String get authPhoneCountryCode => 'Kode y\'igihugu';

  @override
  String get authPhoneRwanda => '+250';

  @override
  String get authPhoneKenya => '+254';

  @override
  String get authPhoneUganda => '+256';

  @override
  String get authPhoneTanzania => '+255';

  @override
  String get authLanguage => 'Ururimi';

  @override
  String get authStoryTitle => 'Wubake umubano ukomeye. Shaka amahirwe mashya.';

  @override
  String get authStoryBody =>
      'Ahantu hizewe ho kumenyekanisha ubucuruzi bwawe, guhura n\'abafatanyabikorwa no kubona amasoko mashya.';

  @override
  String get authStoryItemOne => 'Kora umwirondoro w\'ubucuruzi bwawe';

  @override
  String get authStoryItemTwo =>
      'Tanga amakuru yo kwandikisha azakoreshwa mu isuzuma ry\'ubuziranenge';

  @override
  String get authStoryItemThree =>
      'Menya abaguzi, abatanga ibicuruzwa n\'amahirwe y\'ubucuruzi';

  @override
  String get discoverAiBadge => 'Gushakisha kwa AI muri TradeSquare';

  @override
  String get discoverHeroTitle => 'Shaka umufatanyabikorwa wawe utaha';

  @override
  String get discoverHeroSubtitle =>
      'Sobanura icyo ushaka mu magambo yoroshy. Discover igufasha kubona ubucuruzi, ibicuruzwa n\'amasoko mu Rwanda no muri Afurika y\'Iburasirazuba.';

  @override
  String get discoverHeroSubtitleMobile =>
      'Vuga cyangwa wandike icyo ushaka. Discover ishakisha ubucuruzi muri Afurika y\'Iburasirazuba.';

  @override
  String get discoverSearchHint =>
      'Urugero: Nkorera ibikoresho by\'amashuri mu Rwanda kandi nshaka kugurisha mu Uganda';

  @override
  String get discoverVoiceHint => 'Irajejwe… bwiira TradeSquare icyo ushaka';

  @override
  String get discoverVoicePreparing => 'Gutegura mikoro…';

  @override
  String get discoverVoiceListening => 'Irajejwe — komeza uvuga';

  @override
  String get discoverVoiceCaptured => 'Byakiriwe — turashakisha';

  @override
  String get discoverVoiceStop => 'Hagarika kumva';

  @override
  String get discoverVoiceUnavailable =>
      'Ijwi ntirishoboka hano. Reba uruhushya rwa mikoro cyangwa wandike.';

  @override
  String get discoverSearchAction => 'Shakisha';

  @override
  String get discoverTryExamples => 'Gerageza urugero';

  @override
  String get discoverCategoryBusinesses => 'Ubucuruzi';

  @override
  String get discoverCategoryProducts => 'Ibicuruzwa n\'ubuvuzi';

  @override
  String get discoverCategoryMatches => 'Bihuye na AI';

  @override
  String get discoverCategoryMarkets => 'Amasoko';

  @override
  String get discoverIndustriesTitle => 'Shakisha inganda';

  @override
  String get discoverIndustriesSubtitle =>
      'Reba ibikorwa by\'akarere hashingiwe ku nganda.';

  @override
  String get discoverPersonalizedTitle => 'Bikubereye ubucuruzi bwawe';

  @override
  String get discoverPersonalizedSubtitle =>
      'Ibyifuzo hashingiye ku mwirondoro wawe wa TradeSquare n\'inyungu wanditse.';

  @override
  String get discoverMatchesTitle => 'Guhuza binyuze muri AI';

  @override
  String get discoverMatchesSubtitle =>
      'Imishyikirano isobanurwa hashingiye ku makuru ahari.';

  @override
  String get discoverMarketsTitle => 'Shakisha amasoko y\'akarere';

  @override
  String get discoverMarketsSubtitle =>
      'Tangira na Rwanda, Kenya, Uganda, Tanzania na Burundi.';

  @override
  String discoverMarketCount(int count) {
    return 'Ubucuruzi $count';
  }

  @override
  String get discoverJourneyTitle => 'Urugendo rwo gushakisha';

  @override
  String get discoverClearSearch => 'Siba';

  @override
  String get discoverInterpreted => 'Ibisabwa byasobanuriwe';

  @override
  String get discoverStageUnderstanding => 'Gusobanukirwa icyo usabye';

  @override
  String get discoverStageIdentifying =>
      'Kumenya igicuruzwa, igikorwa n\'amasoko';

  @override
  String get discoverStageSearching => 'Gushakisha mu makuru ya TradeSquare';

  @override
  String get discoverStageRanking => 'Gutegura ibisubizo bikwiye';

  @override
  String get discoverEmptyTitle => 'Nta bucuruzi buhuye';

  @override
  String get discoverEmptyBody =>
      'Gerageza kwagura amasoko, gukuraho filter cyangwa gufata ibisobanuro bigufi.';

  @override
  String get discoverBroadenSearch => 'Kagura ishakisha';

  @override
  String get discoverBusinessResults => 'Ubucuruzi buhuye';

  @override
  String get discoverProductsResults => 'Ibicuruzwa n\'ubuvuzi bihuye';

  @override
  String discoverResultsCount(int count) {
    return 'Ibisubizo $count';
  }

  @override
  String get businessPageTitle => 'Ubucuruzi Bwanjye';

  @override
  String get businessTabOverview => 'Incamake';

  @override
  String get businessTabProducts => 'Ibicuruzwa n\'ubuvuzi';

  @override
  String get businessTabOpportunities => 'Amahirwe';

  @override
  String get businessTabActivity => 'Ibikorwa by\'ubucuruzi';

  @override
  String get businessEditAction => 'Hindura ubucuruzi';

  @override
  String get businessPreviewAction => 'Reba';

  @override
  String get businessPublicPreview => 'Ukugaragara ku bantu';

  @override
  String get businessExitPreview => 'Sohoka';

  @override
  String get businessAiTitle => 'TradeSquare Business AI';

  @override
  String get businessAiSubtitle =>
      'Inyandiko z\'ubufasha zo kunoza ibisobanuro. Reba kandi uhindure mbere yo gutangaza. AI ntikiri ihujwe.';

  @override
  String get businessVerificationTitle => 'Kwemeza ubucuruzi';

  @override
  String get businessLoadError =>
      'Ntibishoboye gufungura aho ubucuruzi bukorera.';
}

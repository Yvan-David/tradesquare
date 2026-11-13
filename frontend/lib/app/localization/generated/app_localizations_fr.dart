// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'TradeSquare';

  @override
  String footerCopyright(int year, String brand) {
    return '© $year $brand. Tous droits réservés.';
  }

  @override
  String get footerAbout => 'À propos';

  @override
  String get footerHelpSupport => 'Aide et assistance';

  @override
  String get footerPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get footerTermsOfService => 'Conditions d’utilisation';

  @override
  String get footerComingSoon => 'Bientôt disponible';

  @override
  String footerPlaceholderSemantics(String label) {
    return '$label, bientôt disponible';
  }

  @override
  String get footerLanguage => 'Langue';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKinyarwanda => 'Kinyarwanda';

  @override
  String footerVersion(String version) {
    return 'Version $version';
  }

  @override
  String get navWorkspace => 'ESPACE DE TRAVAIL';

  @override
  String get navIntelligence => 'INTELLIGENCE';

  @override
  String get navAccount => 'COMPTE';

  @override
  String get navSupport => 'ASSISTANCE';

  @override
  String get navOverview => 'Vue d’ensemble';

  @override
  String get navDiscover => 'Découvrir';

  @override
  String get navProducts => 'Mes produits';

  @override
  String get navBuyingRequests => 'Demandes d’achat';

  @override
  String get navConnections => 'Relations';

  @override
  String get navMessages => 'Messages';

  @override
  String get navAiAssistant => 'TradeSquare AI';

  @override
  String get navMarketIntelligence => 'Intelligence de marché';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navBusinessProfile => 'Profil de l’entreprise';

  @override
  String get navSettings => 'Paramètres';

  @override
  String get navHelpSupport => 'Aide et assistance';

  @override
  String get navAiShort => 'IA';

  @override
  String get navProfileShort => 'Profil';

  @override
  String get navAiBadge => 'IA';

  @override
  String get navAccountUnavailable => 'Informations du compte indisponibles';

  @override
  String get navExpandSidebar => 'Développer la barre latérale';

  @override
  String get navCollapseSidebar => 'Réduire la barre latérale';

  @override
  String get navOpenMenu => 'Ouvrir le menu de navigation';

  @override
  String get navCloseMenu => 'Fermer le menu de navigation';

  @override
  String navDestinationUnavailable(String label) {
    return '$label n’est pas encore disponible dans l’application';
  }

  @override
  String get navVerifiedBusiness => 'Entreprise vérifiée';

  @override
  String get navProfileMenu => 'Menu du compte';

  @override
  String get navViewBusinessProfile => 'Voir le profil de l’entreprise';

  @override
  String get navAccountSettings => 'Paramètres du compte';

  @override
  String get navSignOut => 'Se déconnecter';

  @override
  String get navSignOutConfirmation =>
      'Voulez-vous vraiment vous déconnecter ?';

  @override
  String get navCancel => 'Annuler';

  @override
  String get languageKiswahili => 'Kiswahili';

  @override
  String get languageFrench => 'Français';

  @override
  String get topBarSearch => 'Rechercher dans TradeSquare';

  @override
  String get topBarSearchHint =>
      'Rechercher des entreprises, produits et opportunités';

  @override
  String get topBarImageSearch => 'Rechercher avec une image';

  @override
  String get topBarVoiceSearch => 'Rechercher avec la voix';

  @override
  String get topBarCloseSearch => 'Fermer la recherche';

  @override
  String get topBarCreate => 'Créer';

  @override
  String get topBarCreateUnavailable =>
      'Les actions de création ne sont pas encore disponibles';

  @override
  String get topBarAddProduct => 'Ajouter une annonce produit';

  @override
  String get topBarNewBuyingRequest => 'Créer une demande d’achat';

  @override
  String get topBarNotifications => 'Notifications';

  @override
  String topBarUnreadNotifications(int count) {
    return '$count notifications non lues';
  }

  @override
  String get topBarCloseNotifications => 'Fermer les notifications';

  @override
  String get topBarNotificationsLoading => 'Chargement des notifications';

  @override
  String get topBarNotificationsError =>
      'Impossible de charger les notifications.';

  @override
  String get topBarNoNotifications => 'Vous êtes à jour.';

  @override
  String get topBarRetry => 'Réessayer';

  @override
  String get topBarAccountMenu => 'Menu du compte';

  @override
  String get topBarBusinessProfile => 'Profil de l’entreprise';

  @override
  String get topBarAccountSettings => 'Paramètres du compte';

  @override
  String get topBarLanguage => 'Langue';

  @override
  String get topBarHelpSupport => 'Aide et assistance';

  @override
  String get topBarSignOut => 'Se déconnecter';

  @override
  String get topBarSignOutConfirmation =>
      'Voulez-vous vraiment vous déconnecter ?';

  @override
  String get topBarCancel => 'Annuler';

  @override
  String homeGreeting(String name) {
    return 'Bon retour, $name';
  }

  @override
  String get homeDiscoverTitle =>
      'Découvrez les opportunités pour votre entreprise';

  @override
  String get homeFeedIntro =>
      'Des acheteurs, fournisseurs et opportunités commerciales adaptés à votre entreprise.';

  @override
  String get homeFeedIntroBuyer =>
      'Découvrez des produits et fournisseurs adaptés à vos besoins.';

  @override
  String get homeFeedIntroSupplier =>
      'Découvrez des acheteurs et des demandes adaptés à votre offre.';

  @override
  String homePersonalizedFor(String industry) {
    return 'Opportunités pour $industry';
  }

  @override
  String get homeInterests => 'Centres d’intérêt de votre entreprise';

  @override
  String get homeManageInterests => 'Gérer les centres d’intérêt';

  @override
  String get homeManageInterestsTitle =>
      'Gérer les centres d’intérêt de l’entreprise';

  @override
  String get homeManageInterestsHint =>
      'Choisissez les sujets qui personnalisent les opportunités proposées.';

  @override
  String get homeInterestOptionsEmpty =>
      'Les centres d’intérêt ne sont pas encore disponibles.';

  @override
  String get homeInterestsEmpty =>
      'Ajoutez des centres d’intérêt pour recevoir des opportunités plus pertinentes.';

  @override
  String get homeSaveInterests => 'Enregistrer les centres d’intérêt';

  @override
  String get homeCancel => 'Annuler';

  @override
  String get homeSectionOpportunities => 'Opportunités pour votre entreprise';

  @override
  String get homeSectionBuyers => 'Acheteurs recherchant vos produits';

  @override
  String get homeSectionSuppliers =>
      'Fournisseurs dont vous pourriez avoir besoin';

  @override
  String get homeSectionProducts => 'Produits liés à votre entreprise';

  @override
  String get homeSectionBusinesses =>
      'Entreprises avec lesquelles vous pourriez nouer des relations';

  @override
  String get homeSectionBuyingRequests => 'Demandes d’achat récentes';

  @override
  String get homeSectionTradeOpportunities =>
      'Opportunités commerciales pertinentes';

  @override
  String get homeSectionMarketInsights => 'Veille et tendances du marché';

  @override
  String get homeSectionAiRecommendations => 'Recommandations TradeSquare AI';

  @override
  String get homeNoSectionItems =>
      'Aucune opportunité pertinente à afficher pour le moment.';

  @override
  String get homeEmptyTitle => 'Votre fil d’opportunités se prépare';

  @override
  String get homeEmptyBody =>
      'Les opportunités pertinentes apparaîtront ici lorsque des informations du marché seront disponibles.';

  @override
  String get homeLoading => 'Chargement des opportunités pour votre entreprise';

  @override
  String get homeLoadError => 'Impossible de charger votre fil.';

  @override
  String get homeOffline =>
      'Vous êtes hors ligne. Connectez-vous à Internet et réessayez.';

  @override
  String get homeRetry => 'Réessayer';

  @override
  String get homeLoadMore => 'Afficher plus d’opportunités';

  @override
  String get homeViewDetails => 'Voir les détails';

  @override
  String get homeSave => 'Enregistrer';

  @override
  String get homeSaved => 'Enregistré';

  @override
  String get homeContact => 'Contacter l’entreprise';

  @override
  String get homeConnect => 'Entrer en relation';

  @override
  String get homeRespond => 'Répondre à la demande';

  @override
  String get homeMoreActions => 'Autres actions de recommandation';

  @override
  String get homeMoreLikeThis => 'Proposer des éléments similaires';

  @override
  String get homeNotInterested => 'Cela ne m’intéresse pas';

  @override
  String get homeWhySeeing => 'Pourquoi cette suggestion ?';

  @override
  String get homeWhyTitle => 'Pourquoi cette suggestion est pertinente';

  @override
  String get homeWhyIndustry => 'Correspond au secteur de votre entreprise';

  @override
  String get homeWhyCategory => 'Correspond à la catégorie de votre entreprise';

  @override
  String get homeWhyInterest =>
      'Correspond à l’un des centres d’intérêt de votre entreprise';

  @override
  String get homeWhyProduct =>
      'Concerne un produit ou service que vous proposez ou recherchez';

  @override
  String get homeWhyLocation =>
      'Est pertinente pour la zone de votre entreprise';

  @override
  String get homeWhyIntent => 'Correspond à vos objectifs d’achat ou de vente';

  @override
  String get homeWhyRecent => 'Ajoutée récemment';

  @override
  String get homeWhyGeneric =>
      'Cette suggestion peut correspondre au profil de votre entreprise.';

  @override
  String get homeVerifiedBusiness => 'Entreprise vérifiée';

  @override
  String get homeAiPromptTitle => 'Demander à TradeSquare AI';

  @override
  String get homeAiPromptHint => 'Que souhaitez-vous acheter ou vendre ?';

  @override
  String get homeAiAsk => 'Demander';

  @override
  String get homeFeedbackRecorded =>
      'Merci. Votre avis contribue à améliorer les recommandations.';

  @override
  String get authBrandSubtitle => 'Un réseau professionnel de confiance';

  @override
  String get authPrototypeLabel =>
      'Prototype frontend · Aucun compte ni contrôle n’est créé';

  @override
  String get authLoginWelcome => 'Bon retour';

  @override
  String get authLoginSubtitle =>
      'Votre prochaine opportunité commerciale commence ici.';

  @override
  String get authAccountRole => 'Rôle commercial';

  @override
  String get authRoleBuyer => 'Acheteur';

  @override
  String get authRoleSupplier => 'Fournisseur';

  @override
  String get authRoleBoth => 'Acheteur et fournisseur';

  @override
  String get authEmail => 'Adresse e-mail';

  @override
  String get authPassword => 'Mot de passe';

  @override
  String get authShowPassword => 'Afficher le mot de passe';

  @override
  String get authHidePassword => 'Masquer le mot de passe';

  @override
  String get authRememberMe => 'Se souvenir de moi';

  @override
  String get authForgotPassword => 'Mot de passe oublié ?';

  @override
  String get authSignIn => 'Se connecter';

  @override
  String get authNoAccount => 'Nouveau sur TradeSquare ?';

  @override
  String get authCreateAccount => 'Créer un compte';

  @override
  String get authRegistrationTitle => 'Créer votre compte TradeSquare';

  @override
  String get authRegistrationSubtitle =>
      'Rejoignez un réseau conçu pour mettre en relation les entreprises éligibles avec des acheteurs, fournisseurs et opportunités.';

  @override
  String get authFullName => 'Nom complet';

  @override
  String get authPhoneNumber => 'Numéro de téléphone';

  @override
  String get authConfirmPassword => 'Confirmer le mot de passe';

  @override
  String get authPasswordStrength => 'Robustesse du mot de passe';

  @override
  String get authPasswordWeak => 'Faible';

  @override
  String get authPasswordFair => 'Moyenne';

  @override
  String get authPasswordStrong => 'Forte';

  @override
  String get authAcceptTerms =>
      'J’accepte les Conditions d’utilisation et la Politique de confidentialité.';

  @override
  String get authTermsPrivacy =>
      'Conditions d’utilisation et Politique de confidentialité';

  @override
  String get authHaveAccount => 'Vous avez déjà un compte ?';

  @override
  String get authContinue => 'Continuer';

  @override
  String get authBack => 'Retour';

  @override
  String get authRequired => 'Ce champ est obligatoire.';

  @override
  String get authInvalidEmail => 'Saisissez une adresse e-mail valide.';

  @override
  String get authPasswordMin => 'Utilisez au moins 8 caractères.';

  @override
  String get authPasswordsMismatch => 'Les mots de passe ne correspondent pas.';

  @override
  String get authAcceptTermsError =>
      'Veuillez accepter les conditions pour continuer.';

  @override
  String get authMockSignInMessage =>
      'La connexion est une prévisualisation. L’authentification n’est pas connectée.';

  @override
  String get authMockForgotMessage =>
      'La récupération du mot de passe n’est pas disponible dans cette prévisualisation.';

  @override
  String get authMockSubmittedMessage =>
      'Le formulaire est enregistré uniquement dans cette prévisualisation. Rien n’a été envoyé.';

  @override
  String get authStepAccount => 'Compte';

  @override
  String get authStepEligibility => 'Éligibilité de l’entreprise';

  @override
  String get authStepCertificate => 'Certificat';

  @override
  String get authStepProfile => 'Profil de l’entreprise';

  @override
  String get authStepReview => 'Vérification';

  @override
  String get authTellBusiness => 'Parlez-nous de votre entreprise';

  @override
  String get authEligibilitySubtitle =>
      'TradeSquare est conçu pour les entreprises légitimes. Ces informations nous aident à comprendre votre activité.';

  @override
  String get authCountryOfRegistration => 'Pays d’immatriculation';

  @override
  String get authBusinessName => 'Nom de l’entreprise';

  @override
  String get authBusinessType => 'Type d’entreprise';

  @override
  String get authRegistrationStatus => 'Statut d’immatriculation';

  @override
  String get authRegistrationNumber => 'Numéro d’immatriculation';

  @override
  String get authBusinessLocation => 'Emplacement de l’entreprise';

  @override
  String get authSelectCountry => 'Sélectionner un pays';

  @override
  String get authSelectBusinessType => 'Sélectionner un type d’entreprise';

  @override
  String get authSelectRegistrationStatus =>
      'Sélectionner un statut d’immatriculation';

  @override
  String get authOptional => 'Facultatif';

  @override
  String get authRegistered => 'Immatriculée';

  @override
  String get authRegistrationPending => 'Immatriculation en cours';

  @override
  String get authNotRegistered => 'Non immatriculée';

  @override
  String get authEligibilityInfoTitle =>
      'Pourquoi nous demandons ces informations';

  @override
  String get authEligibilityInfoBody =>
      'TradeSquare est destiné aux entreprises. Selon votre pays et votre type d’activité, des documents officiels d’immatriculation peuvent être demandés avant l’accès à la marketplace. L’éligibilité est évaluée selon les politiques applicables ; le choix d’un type d’entreprise ne garantit pas l’éligibilité.';

  @override
  String get authAcceptedDocumentsTitle =>
      'Documents susceptibles d’être acceptés';

  @override
  String get authAcceptedDocumentsBody =>
      'Il peut s’agir d’un certificat de constitution, d’un certificat officiel d’immatriculation ou d’un autre document applicable. Les exigences varient selon le pays et le type d’entreprise.';

  @override
  String get authEligibilityHelp =>
      'Besoin d’aide ? Vous pouvez enregistrer ces informations et y revenir plus tard.';

  @override
  String get authCountryRwanda => 'Rwanda';

  @override
  String get authCountryKenya => 'Kenya';

  @override
  String get authCountryUganda => 'Ouganda';

  @override
  String get authCountryTanzania => 'Tanzanie';

  @override
  String get authCountryOther => 'Autre pays';

  @override
  String get authTypeLimitedCompany => 'Société à responsabilité limitée';

  @override
  String get authTypeSoleProprietorship => 'Entreprise individuelle';

  @override
  String get authTypePartnership => 'Société de personnes';

  @override
  String get authTypeCooperative => 'Coopérative';

  @override
  String get authTypeRegisteredEnterprise => 'Entreprise immatriculée';

  @override
  String get authTypeOther => 'Autre entité légalement reconnue';

  @override
  String get authCertificateTitle => 'Vérifier l’identité de votre entreprise';

  @override
  String get authCertificateSubtitle =>
      'Ajoutez un document officiel attestant l’immatriculation de votre entreprise.';

  @override
  String get authDocumentType => 'Type de document';

  @override
  String get authSelectDocumentType => 'Sélectionner un type de document';

  @override
  String get authDocIncorporation => 'Certificat de constitution';

  @override
  String get authDocRegistration => 'Certificat d’immatriculation';

  @override
  String get authDocBusinessRegistration =>
      'Certificat officiel d’immatriculation de l’entreprise';

  @override
  String get authDocOther =>
      'Autre document officiel d’immatriculation applicable';

  @override
  String get authDropTitle => 'Déposez votre document ici';

  @override
  String get authDropSubtitle =>
      'ou sélectionnez un fichier sur votre appareil';

  @override
  String get authBrowseFiles => 'Parcourir les fichiers';

  @override
  String get authFileGuidance => 'PDF, JPG ou PNG · 10 Mo maximum';

  @override
  String get authFileTooLarge => 'Ce fichier dépasse la limite de 10 Mo.';

  @override
  String get authFileUnsupported => 'Choisissez un fichier PDF, JPG ou PNG.';

  @override
  String get authFilePickerError =>
      'Impossible d’ouvrir le sélecteur de fichiers. Réessayez.';

  @override
  String get authRemoveFile => 'Supprimer le document';

  @override
  String get authReplaceFile => 'Remplacer le document';

  @override
  String get authSelectedDocument => 'Document sélectionné';

  @override
  String get authPreparingDocument =>
      'Préparation de l’aperçu local du document';

  @override
  String get authDocumentReady => 'Document prêt pour l’aperçu';

  @override
  String get authLocalOnly =>
      'Ce prototype conserve uniquement le nom et la taille du fichier dans l’interface temporaire. Le fichier n’est ni téléversé ni transmis.';

  @override
  String get authReviewNotice =>
      'Votre certificat d’entreprise fera l’objet d’un examen. Le dépôt ne garantit ni l’approbation ni l’accès immédiat à la marketplace.';

  @override
  String get authMissingDocument =>
      'Choisissez un document et son type pour continuer.';

  @override
  String get authUploadContinueWithout => 'Continuer sans document';

  @override
  String get authUploadSubmit => 'Continuer vers le profil de l’entreprise';

  @override
  String get authProfileTitle => 'Créer le profil de votre entreprise';

  @override
  String get authProfileSubtitle =>
      'Quelques informations nous aident à personnaliser TradeSquare. Vous pourrez les modifier plus tard.';

  @override
  String get authStepBusinessInfo => 'Informations sur l’entreprise';

  @override
  String get authStepIndustry => 'Secteur d’activité';

  @override
  String get authStepProductsOffered => 'Votre offre';

  @override
  String get authStepProductsNeeded => 'Vos besoins';

  @override
  String get authStepGoals => 'Objectifs commerciaux';

  @override
  String get authStepInterests => 'Centres d’intérêt et marchés';

  @override
  String get authDistrictCity => 'District ou ville';

  @override
  String get authBusinessDescription => 'Description de l’entreprise';

  @override
  String get authBusinessDescriptionHint =>
      'Décrivez l’activité de votre entreprise';

  @override
  String get authChooseIndustry => 'Choisissez votre secteur principal';

  @override
  String get authSearchOptions => 'Rechercher des options';

  @override
  String get authIndustryAgriculture => 'Agriculture';

  @override
  String get authIndustryTechnology => 'Technologies de l’information';

  @override
  String get authIndustryManufacturing => 'Industrie manufacturière';

  @override
  String get authIndustryRetailWholesale => 'Commerce de détail et de gros';

  @override
  String get authIndustryConstruction => 'Construction';

  @override
  String get authIndustryTransport => 'Transport et logistique';

  @override
  String get authIndustryFood => 'Alimentation et boissons';

  @override
  String get authIndustryHealthcare => 'Santé';

  @override
  String get authIndustryEducation => 'Éducation';

  @override
  String get authIndustryTourism => 'Tourisme et hôtellerie';

  @override
  String get authIndustryProfessional => 'Services professionnels';

  @override
  String get authIndustryEnergy => 'Énergie';

  @override
  String get authIndustryMining => 'Mines';

  @override
  String get authIndustryOther => 'Autre';

  @override
  String get authProductsOffered => 'Produits ou services proposés';

  @override
  String get authProductsNeeded => 'Produits ou services recherchés';

  @override
  String get authListInputHint => 'Ajoutez un élément puis appuyez sur Entrée';

  @override
  String get authAddItem => 'Ajouter';

  @override
  String get authSkip => 'Ignorer pour le moment';

  @override
  String get authBusinessGoals => 'Que souhaitez-vous faire sur TradeSquare ?';

  @override
  String get authGoalBuyers => 'Trouver des acheteurs';

  @override
  String get authGoalSuppliers => 'Trouver des fournisseurs';

  @override
  String get authGoalPromote => 'Promouvoir des produits';

  @override
  String get authGoalPartners => 'Trouver des partenaires commerciaux';

  @override
  String get authGoalOpportunities => 'Découvrir des opportunités';

  @override
  String get authGoalMarkets => 'Développer de nouveaux marchés';

  @override
  String get authInterests => 'Centres d’intérêt commerciaux';

  @override
  String get authInterestsHint =>
      'Ajoutez des sujets importants pour votre entreprise.';

  @override
  String get authTargetMarkets => 'Marchés cibles';

  @override
  String get authTargetMarketsHint =>
      'Ajoutez les pays ou régions avec lesquels vous souhaitez commercer.';

  @override
  String get authReviewTitle => 'Vérifier vos informations';

  @override
  String get authReviewSubtitle =>
      'Vérifiez vos informations avant de continuer. Vous pouvez revenir en arrière pour les modifier.';

  @override
  String get authEdit => 'Modifier';

  @override
  String get authSubmitApplication => 'Soumettre pour examen';

  @override
  String get authSubmissionNotice =>
      'Ceci est un prototype frontend. La soumission n’envoie aucune information et ne lance aucun examen réel.';

  @override
  String get authApplicationStatus => 'Statut de la demande';

  @override
  String get authStatusPrototype => 'Aperçu du statut prototype';

  @override
  String get authStatusIncomplete => 'Informations incomplètes';

  @override
  String get authStatusCertificateMissing => 'Certificat non soumis';

  @override
  String get authStatusSubmitted => 'Soumise pour examen';

  @override
  String get authStatusUnderReview => 'En cours d’examen';

  @override
  String get authStatusAdditionalInfo =>
      'Informations complémentaires requises';

  @override
  String get authStatusApproved => 'Approuvée';

  @override
  String get authStatusNotApproved => 'Non approuvée';

  @override
  String get authStatusIncompleteBody =>
      'Complétez les informations requises sur l’entreprise pour continuer.';

  @override
  String get authStatusCertificateMissingBody =>
      'Ajoutez un document d’immatriculation applicable lorsque vous êtes prêt. Vous pouvez poursuivre ce prototype sans document.';

  @override
  String get authStatusSubmittedBody =>
      'Les informations de votre entreprise ont été soumises dans cet aperçu local. Aucun examen réel n’a commencé.';

  @override
  String get authStatusUnderReviewBody =>
      'Cet état est une démonstration uniquement. Aucun examen de vérification n’a eu lieu.';

  @override
  String get authStatusAdditionalInfoBody =>
      'Cet état de démonstration indique que des informations supplémentaires pourraient être demandées dans un futur processus d’examen.';

  @override
  String get authStatusApprovedBody =>
      'Démonstration uniquement : aucune entreprise n’a été approuvée ou vérifiée.';

  @override
  String get authStatusNotApprovedBody =>
      'Démonstration uniquement : aucune décision d’éligibilité n’a été prise.';

  @override
  String get authStatusNextAction => 'Prochaine étape';

  @override
  String get authStatusReturnHome => 'Retour à la connexion';

  @override
  String get authStatusChangePreview => 'Prévisualiser un statut';

  @override
  String get authStatusDisclaimer =>
      'Prototype uniquement · Ce statut ne constitue pas une décision réelle d’éligibilité ou de vérification.';

  @override
  String get authStatusCertificateAction => 'Revoir l’étape du certificat';

  @override
  String get authStatusProfileAction =>
      'Revoir les informations de l’entreprise';

  @override
  String get authCountryLabel => 'Pays';

  @override
  String get authPhoneCountryCode => 'Indicatif du pays';

  @override
  String get authPhoneRwanda => '+250';

  @override
  String get authPhoneKenya => '+254';

  @override
  String get authPhoneUganda => '+256';

  @override
  String get authPhoneTanzania => '+255';

  @override
  String get authLanguage => 'Langue';

  @override
  String get authStoryTitle =>
      'Créez des liens solides. Trouvez votre prochaine opportunité.';

  @override
  String get authStoryBody =>
      'Un espace de confiance pour présenter votre entreprise, rencontrer les bons partenaires et découvrir de nouveaux marchés.';

  @override
  String get authStoryItemOne => 'Créer le profil de votre entreprise';

  @override
  String get authStoryItemTwo =>
      'Partager les informations d’immatriculation pour un futur examen d’éligibilité';

  @override
  String get authStoryItemThree =>
      'Découvrir des acheteurs, fournisseurs et opportunités commerciales';

  @override
  String get discoverAiBadge => 'Découverte IA TradeSquare';

  @override
  String get discoverHeroTitle => 'Trouvez votre prochaine connexion business';

  @override
  String get discoverHeroSubtitle =>
      'Décrivez votre besoin en langage simple. Discover trouve entreprises, produits et marchés au Rwanda et en Afrique de l’Est.';

  @override
  String get discoverHeroSubtitleMobile =>
      'Parlez ou tapez votre besoin. Discover trouve des entreprises en Afrique de l’Est.';

  @override
  String get discoverSearchHint =>
      'Exemple : Je fabrique du mobilier scolaire au Rwanda et je veux vendre en Ouganda';

  @override
  String get discoverVoiceHint =>
      'Écoute… dites à TradeSquare ce que vous cherchez';

  @override
  String get discoverVoicePreparing => 'Préparation du micro…';

  @override
  String get discoverVoiceListening => 'Écoute — continuez à parler';

  @override
  String get discoverVoiceCaptured => 'Compris — recherche en cours';

  @override
  String get discoverVoiceStop => 'Arrêter l’écoute';

  @override
  String get discoverVoiceUnavailable =>
      'L’écoute vocale n’est pas disponible ici. Vérifiez le micro ou tapez votre recherche.';

  @override
  String get discoverSearchAction => 'Découvrir';

  @override
  String get discoverTryExamples => 'Essayer un exemple';

  @override
  String get discoverCategoryBusinesses => 'Entreprises';

  @override
  String get discoverCategoryProducts => 'Produits & services';

  @override
  String get discoverCategoryMatches => 'Correspondances IA';

  @override
  String get discoverCategoryMarkets => 'Marchés';

  @override
  String get discoverIndustriesTitle => 'Explorer les industries';

  @override
  String get discoverIndustriesSubtitle =>
      'Parcourir l’activité régionale par industrie.';

  @override
  String get discoverPersonalizedTitle => 'Pertinent pour votre entreprise';

  @override
  String get discoverPersonalizedSubtitle =>
      'Suggestions basées sur votre profil TradeSquare et vos intérêts publiés.';

  @override
  String get discoverMatchesTitle => 'Correspondance assistée';

  @override
  String get discoverMatchesSubtitle =>
      'Connexions potentielles expliquées avec les éléments disponibles.';

  @override
  String get discoverMarketsTitle => 'Explorer les marchés régionaux';

  @override
  String get discoverMarketsSubtitle =>
      'Commencez par le Rwanda, le Kenya, l’Ouganda, la Tanzanie et le Burundi.';

  @override
  String discoverMarketCount(int count) {
    return '$count entreprises';
  }

  @override
  String get discoverJourneyTitle => 'Parcours de découverte';

  @override
  String get discoverClearSearch => 'Effacer';

  @override
  String get discoverInterpreted => 'Critères interprétés';

  @override
  String get discoverStageUnderstanding => 'Compréhension de votre demande';

  @override
  String get discoverStageIdentifying =>
      'Identification du produit, de l’activité et des marchés';

  @override
  String get discoverStageSearching =>
      'Recherche dans les enregistrements TradeSquare';

  @override
  String get discoverStageRanking => 'Organisation des résultats pertinents';

  @override
  String get discoverEmptyTitle => 'Aucune entreprise correspondante';

  @override
  String get discoverEmptyBody =>
      'Élargissez les marchés, retirez un filtre ou raccourcissez votre description.';

  @override
  String get discoverBroadenSearch => 'Élargir la recherche';

  @override
  String get discoverBusinessResults => 'Entreprises correspondantes';

  @override
  String get discoverProductsResults => 'Produits et services correspondants';

  @override
  String discoverResultsCount(int count) {
    return '$count résultats';
  }

  @override
  String get businessPageTitle => 'Mon entreprise';

  @override
  String get businessTabOverview => 'Aperçu';

  @override
  String get businessTabProducts => 'Produits et services';

  @override
  String get businessTabOpportunities => 'Opportunités';

  @override
  String get businessTabActivity => 'Activité de l’entreprise';

  @override
  String get businessEditAction => 'Modifier l’entreprise';

  @override
  String get businessPreviewAction => 'Aperçu';

  @override
  String get businessPublicPreview => 'Aperçu public';

  @override
  String get businessExitPreview => 'Quitter l’aperçu';

  @override
  String get businessAiTitle => 'TradeSquare Business AI';

  @override
  String get businessAiSubtitle =>
      'Brouillons facultatifs pour améliorer vos textes. Relisez et modifiez avant publication. L’IA en direct n’est pas encore connectée.';

  @override
  String get businessVerificationTitle => 'Vérification de l’entreprise';

  @override
  String get businessLoadError => 'Impossible de charger l’espace entreprise.';
}

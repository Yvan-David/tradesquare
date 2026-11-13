enum TradeSquareBusinessType {
  limitedCompany,
  soleProprietorship,
  partnership,
  cooperative,
  registeredEnterprise,
  other,
}

enum TradeSquareRegistrationStatus {
  registered,
  pending,
  notRegistered,
}

enum TradeSquareBusinessIndustry {
  agriculture,
  informationTechnology,
  manufacturing,
  retailWholesale,
  construction,
  transportationLogistics,
  foodBeverage,
  healthcare,
  education,
  tourismHospitality,
  professionalServices,
  energy,
  mining,
  other,
}

enum TradeSquareBusinessGoal {
  findBuyers,
  findSuppliers,
  promoteProducts,
  findPartners,
  discoverOpportunities,
  expandMarkets,
}

enum TradeSquareAccountRole { buyer, supplier, both }

enum TradeSquareApplicationStatus {
  informationIncomplete,
  certificateNotSubmitted,
  submittedForReview,
  underReview,
  additionalInformationRequired,
  approved,
  notApproved,
}

class TradeSquareLocalDocument {
  const TradeSquareLocalDocument({
    required this.name,
    required this.extension,
    required this.sizeBytes,
  });

  final String name;
  final String extension;
  final int sizeBytes;

  String get formattedSize {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class TradeSquareAuthDraft {
  TradeSquareAuthDraft({
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.password = '',
    this.businessName = '',
    this.country = '',
    this.businessType,
    this.registrationStatus,
    this.registrationNumber = '',
    this.location = '',
    this.description = '',
    this.industry,
    this.productsOffered = const [],
    this.productsNeeded = const [],
    this.goals = const {},
    this.interests = const [],
    this.targetMarkets = const [],
    this.documentType,
    this.document,
  });

  String fullName;
  String email;
  String phone;
  /// Cleared after Supabase sign-up; never persisted.
  String password;
  String businessName;
  String country;
  TradeSquareBusinessType? businessType;
  TradeSquareRegistrationStatus? registrationStatus;
  String registrationNumber;
  String location;
  String description;
  TradeSquareBusinessIndustry? industry;
  List<String> productsOffered;
  List<String> productsNeeded;
  Set<TradeSquareBusinessGoal> goals;
  List<String> interests;
  List<String> targetMarkets;
  String? documentType;
  TradeSquareLocalDocument? document;
}

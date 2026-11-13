enum TradeSquareMockAuthState {
  login,
  registration,
  forgotPassword,
  accountCreation,
  businessEligibility,
  businessInformation,
  certificateUpload,
  registrationComplete,
}

class TradeSquareMockAuthUiState {
  const TradeSquareMockAuthUiState({
    required this.state,
    required this.title,
    required this.description,
    required this.isSuccessful,
    required this.validationErrors,
  });

  final TradeSquareMockAuthState state;
  final String title;
  final String description;
  final bool isSuccessful;
  final List<String> validationErrors;

  factory TradeSquareMockAuthUiState.fromJson(Map<String, dynamic> json) {
    return TradeSquareMockAuthUiState(
      state: TradeSquareMockAuthState.values.firstWhere(
        (value) => value.name == json['state'],
        orElse: () => TradeSquareMockAuthState.login,
      ),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isSuccessful: json['isSuccessful'] as bool? ?? false,
      validationErrors:
          List<String>.from(json['validationErrors'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toJson() => {
        'state': state.name,
        'title': title,
        'description': description,
        'isSuccessful': isSuccessful,
        'validationErrors': validationErrors,
      };
}

List<TradeSquareMockAuthUiState> get tradeSquareMockAuthStates => const [];

class TradeSquareMockUploadMetadata {
  const TradeSquareMockUploadMetadata({
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.uploadProgress,
    required this.uploadStatus,
    required this.submissionDate,
    required this.reviewStatus,
    required this.reviewMessage,
  });

  final String fileName;
  final String fileType;
  final int fileSize;
  final double uploadProgress;
  final String uploadStatus;
  final DateTime submissionDate;
  final String reviewStatus;
  final String reviewMessage;

  factory TradeSquareMockUploadMetadata.fromJson(Map<String, dynamic> json) {
    return TradeSquareMockUploadMetadata(
      fileName: json['fileName'] as String? ?? '',
      fileType: json['fileType'] as String? ?? 'pdf',
      fileSize: (json['fileSize'] as num?)?.toInt() ?? 0,
      uploadProgress: (json['uploadProgress'] as num?)?.toDouble() ?? 0,
      uploadStatus: json['uploadStatus'] as String? ?? 'selected',
      submissionDate: json['submissionDate'] is String
          ? DateTime.tryParse(json['submissionDate'] as String) ??
              DateTime.utc(2026, 1, 1)
          : DateTime.utc(2026, 1, 1),
      reviewStatus: json['reviewStatus'] as String? ?? 'under review',
      reviewMessage: json['reviewMessage'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'fileName': fileName,
        'fileType': fileType,
        'fileSize': fileSize,
        'uploadProgress': uploadProgress,
        'uploadStatus': uploadStatus,
        'submissionDate': submissionDate.toIso8601String(),
        'reviewStatus': reviewStatus,
        'reviewMessage': reviewMessage,
      };
}

List<TradeSquareMockUploadMetadata> get tradeSquareMockUploads => const [];

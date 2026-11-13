import 'package:flutter/foundation.dart';

/// Lightweight partner preview for the homepage.
/// Sourced from existing business records — not AI-generated matches.
@immutable
class TradeSquareHomePartner {
  const TradeSquareHomePartner({
    required this.id,
    required this.name,
    required this.industry,
    required this.location,
    this.isVerified = false,
  });

  final String id;
  final String name;
  final String industry;
  final String location;
  final bool isVerified;

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return 'TS';
    if (list.length == 1) {
      final value = list.first;
      return value.substring(0, value.length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${list.first[0]}${list.last[0]}'.toUpperCase();
  }
}

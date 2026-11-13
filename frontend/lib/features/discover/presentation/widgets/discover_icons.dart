import 'package:flutter/material.dart';

/// Cohesive Material Symbols set for Discover — outlined/rounded only.
abstract final class DiscoverIcons {
  static const businesses = Icons.apartment_outlined;
  static const products = Icons.inventory_2_outlined;
  static const aiMatches = Icons.auto_awesome_outlined;
  static const markets = Icons.public_outlined;
  static const search = Icons.search_rounded;
  static const spark = Icons.auto_awesome_rounded;
  static const verified = Icons.verified_rounded;
  static const location = Icons.location_on_outlined;
  static const chevron = Icons.arrow_forward_rounded;
  static const tune = Icons.tune_rounded;
  static const close = Icons.close_rounded;
  static const contact = Icons.chat_bubble_outline_rounded;
  static const view = Icons.open_in_new_rounded;
  static const empty = Icons.travel_explore_outlined;
  static const language = Icons.language_rounded;

  static IconData industry(String iconName) {
    return switch (iconName) {
      'agriculture' => Icons.eco_outlined,
      'manufacturing' => Icons.precision_manufacturing_outlined,
      'technology' => Icons.memory_outlined,
      'textiles' => Icons.checkroom_outlined,
      'logistics' => Icons.local_shipping_outlined,
      'wholesale' => Icons.storefront_outlined,
      'food_processing' => Icons.restaurant_outlined,
      'construction' => Icons.foundation_outlined,
      _ => Icons.category_outlined,
    };
  }

  static IconData market(String country) {
    return switch (country) {
      'Rwanda' => Icons.flag_outlined,
      'Kenya' => Icons.flag_outlined,
      'Uganda' => Icons.flag_outlined,
      'Tanzania' => Icons.flag_outlined,
      'Burundi' => Icons.flag_outlined,
      _ => Icons.public_outlined,
    };
  }
}

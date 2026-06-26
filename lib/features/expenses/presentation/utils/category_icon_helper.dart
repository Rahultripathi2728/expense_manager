import 'package:flutter/material.dart';

/// Helper mapping categories to modern outlined Material Icons.
/// Placed in presentation layer to keep CategorizeService pure-Dart server-compatible.
class CategoryIconHelper {
  CategoryIconHelper._();

  static IconData getIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.local_pizza_outlined;
      case 'groceries':
        return Icons.shopping_basket_outlined;
      case 'travel':
        return Icons.flight_takeoff_outlined;
      case 'stays':
        return Icons.bed_outlined;
      case 'bills':
        return Icons.receipt_long_outlined;
      case 'subscription':
        return Icons.credit_card_outlined;
      case 'shopping':
        return Icons.local_mall_outlined;
      case 'gifts':
        return Icons.redeem_outlined;
      case 'drinks':
        return Icons.local_cafe_outlined;
      case 'fuel':
        return Icons.local_gas_station_outlined;
      case 'udhaar':
        return Icons.swap_horiz_outlined;
      case 'health':
        return Icons.medical_services_outlined;
      case 'entertainment':
        return Icons.movie_creation_outlined;
      case 'misc':
      default:
        return Icons.category_outlined;
    }
  }
}

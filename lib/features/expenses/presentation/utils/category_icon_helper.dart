import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

/// Helper mapping categories to modern rounded Material Icons and colorful badges.
class CategoryIconHelper {
  CategoryIconHelper._();

  static IconData getIcon(String category) {
    switch (category.toLowerCase().trim()) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'groceries':
        return Icons.shopping_cart_rounded;
      case 'travel':
      case 'cab':
      case 'taxi':
        return Icons.directions_car_rounded;
      case 'stays':
      case 'rent':
      case 'hotel':
        return Icons.home_rounded;
      case 'bills':
      case 'utilities':
        return Icons.receipt_long_rounded;
      case 'subscription':
      case 'ott':
        return Icons.subscriptions_rounded;
      case 'shopping':
      case 'clothes':
        return Icons.shopping_bag_rounded;
      case 'gifts':
        return Icons.card_giftcard_rounded;
      case 'drinks':
      case 'party':
        return Icons.local_bar_rounded;
      case 'fuel':
      case 'petrol':
      case 'diesel':
        return Icons.local_gas_station_rounded;
      case 'udhaar':
      case 'loan':
      case 'transfer':
        return Icons.swap_horiz_rounded;
      case 'health':
      case 'medical':
      case 'doctor':
      case 'medicine':
        return Icons.favorite_rounded;
      case 'entertainment':
      case 'movies':
      case 'games':
        return Icons.movie_filter_rounded;
      case 'education':
      case 'books':
      case 'course':
        return Icons.school_rounded;
      case 'misc':
      default:
        return Icons.auto_awesome_rounded;
    }
  }

  /// Builds a modern colorful badge container for a category icon.
  static Widget buildBadge(String category, {double size = 44, double iconSize = 22}) {
    final color = AppColors.categoryColor(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: color.withValues(alpha: 0.22),
          width: 1.2,
        ),
      ),
      child: Center(
        child: Icon(
          getIcon(category),
          color: color,
          size: iconSize,
        ),
      ),
    );
  }
}

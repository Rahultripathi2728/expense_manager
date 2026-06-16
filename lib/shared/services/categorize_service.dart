/// Auto-categorization service using keyword matching.
/// Maps expense descriptions to categories.
/// Reused in both client-side and server-side (Appwrite Function).
class CategorizeService {
  CategorizeService._();

  static const Map<String, List<String>> _categoryKeywords = {
    'food': [
      'zomato',
      'swiggy',
      'restaurant',
      'lunch',
      'dinner',
      'breakfast',
      'cafe',
      'coffee',
      'pizza',
      'burger',
      'biryani',
      'chai',
      'tea',
      'snack',
      'food',
      'eat',
      'meal',
      'dominos',
      'mcdonalds',
      'kfc',
      'groceries',
      'grocery',
      'vegetables',
      'fruits',
      'milk',
      'bread',
      'chicken',
      'mutton',
      'fish',
      'rice',
      'dal',
      'paneer',
      'bakery',
    ],
    'transport': [
      'uber',
      'ola',
      'rapido',
      'fuel',
      'petrol',
      'diesel',
      'gas',
      'auto',
      'rickshaw',
      'taxi',
      'cab',
      'bus',
      'metro',
      'train',
      'parking',
      'toll',
      'car',
      'bike',
      'servicing',
      'repair',
    ],
    'bills': [
      'electricity',
      'water',
      'gas bill',
      'internet',
      'wifi',
      'broadband',
      'phone',
      'mobile',
      'recharge',
      'dth',
      'tv',
      'rent',
      'emi',
      'insurance',
      'loan',
      'credit card',
      'maintenance',
      'society',
    ],
    'shopping': [
      'amazon',
      'flipkart',
      'myntra',
      'ajio',
      'clothes',
      'shoes',
      'shirt',
      'jeans',
      'dress',
      'electronics',
      'gadget',
      'phone',
      'laptop',
      'headphones',
      'watch',
      'accessories',
      'cosmetics',
      'skincare',
      'makeup',
      'perfume',
      'shopping',
    ],
    'entertainment': [
      'movie',
      'cinema',
      'pvr',
      'inox',
      'netflix',
      'prime',
      'hotstar',
      'spotify',
      'youtube',
      'game',
      'gaming',
      'concert',
      'event',
      'party',
      'club',
      'bar',
      'pub',
      'drinks',
      'alcohol',
      'beer',
      'wine',
      'subscription',
    ],
    'health': [
      'doctor',
      'hospital',
      'medicine',
      'pharmacy',
      'medical',
      'health',
      'gym',
      'fitness',
      'yoga',
      'lab',
      'test',
      'checkup',
      'dental',
      'eye',
      'therapy',
      'consultation',
      'apollo',
      'medplus',
    ],
    'education': [
      'book',
      'course',
      'class',
      'tuition',
      'coaching',
      'exam',
      'fees',
      'college',
      'school',
      'university',
      'udemy',
      'coursera',
      'study',
      'stationery',
      'notebook',
      'pen',
      'library',
    ],
    'travel': [
      'flight',
      'hotel',
      'booking',
      'airbnb',
      'oyo',
      'trip',
      'travel',
      'vacation',
      'holiday',
      'makemytrip',
      'goibibo',
      'irctc',
      'visa',
      'passport',
      'luggage',
      'suitcase',
    ],
  };

  /// Categorize a description string. Returns the best-matching category.
  static String categorize(String description) {
    final lowerDesc = description.toLowerCase();

    int bestScore = 0;
    String bestCategory = 'other';

    for (final entry in _categoryKeywords.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        final regex = RegExp(r'\b' + RegExp.escape(keyword) + r'\b');
        if (regex.hasMatch(lowerDesc)) {
          score++;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestCategory = entry.key;
      }
    }

    return bestCategory;
  }

  /// All available categories.
  static const List<String> allCategories = [
    'food',
    'transport',
    'bills',
    'shopping',
    'entertainment',
    'health',
    'education',
    'travel',
    'other',
  ];

  /// Get display name for a category.
  static String displayName(String category) {
    return category[0].toUpperCase() + category.substring(1);
  }

  /// Get icon data for a category.
  static String iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return '🍔';
      case 'transport':
        return '🚗';
      case 'bills':
        return '📄';
      case 'shopping':
        return '🛍️';
      case 'entertainment':
        return '🎬';
      case 'health':
        return '💊';
      case 'education':
        return '📚';
      case 'travel':
        return '✈️';
      default:
        return '📦';
    }
  }
}

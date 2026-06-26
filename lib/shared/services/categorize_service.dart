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
    ],
    'groceries': [
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
      'zepto',
      'blinkit',
      'instamart',
      'supermarket',
      'mart',
    ],
    'travel': [
      'flight',
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
      'uber',
      'ola',
      'rapido',
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
    ],
    'stays': [
      'hotel',
      'stays',
      'airbnb',
      'oyo',
      'room',
      'hostel',
      'stay',
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
    'subscription': [
      'subscription',
      'netflix',
      'prime',
      'hotstar',
      'spotify',
      'youtube',
      'playstore',
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
    'gifts': [
      'gift',
      'present',
      'flowers',
      'anniversary',
      'birthday',
    ],
    'drinks': [
      'drinks',
      'beverage',
      'soda',
      'juice',
      'alcohol',
      'beer',
      'wine',
      'whiskey',
      'pub',
      'bar',
      'club',
      'starbucks',
    ],
    'fuel': [
      'fuel',
      'petrol',
      'diesel',
      'cng',
      'gas station',
      'shell',
      'hp petrol',
    ],
    'udhaar': [
      'udhaar',
      'debt',
      'borrow',
      'lent',
      'split',
      'settlement',
      'pay back',
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
    'entertainment': [
      'movie',
      'cinema',
      'pvr',
      'inox',
      'game',
      'gaming',
      'concert',
      'event',
      'party',
      'drinks',
      'play',
      'ticket',
      'show',
    ],
  };

  /// Categorize a description string. Returns the best-matching category.
  /// If no keywords match, returns an empty string "" to prompt select/skip validation.
  static String categorize(String description) {
    final lowerDesc = description.toLowerCase();

    int bestScore = 0;
    String bestCategory = '';

    for (final entry in _categoryKeywords.entries) {
      int score = 0;
      for (final keyword in entry.value) {
        if (lowerDesc.contains(keyword)) {
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
    'groceries',
    'travel',
    'stays',
    'bills',
    'subscription',
    'shopping',
    'gifts',
    'drinks',
    'fuel',
    'udhaar',
    'health',
    'entertainment',
    'misc',
  ];

  /// Get display name for a category.
  static String displayName(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return 'Food';
      case 'groceries':
        return 'Groceries';
      case 'travel':
        return 'Travel';
      case 'stays':
        return 'Stays';
      case 'bills':
        return 'Bills';
      case 'subscription':
        return 'Subscription';
      case 'shopping':
        return 'Shopping';
      case 'gifts':
        return 'Gifts';
      case 'drinks':
        return 'Drinks';
      case 'fuel':
        return 'Fuel';
      case 'udhaar':
        return 'Udhaar(Debt)';
      case 'health':
        return 'Health';
      case 'entertainment':
        return 'Entertainment';
      case 'misc':
        return 'Misc.';
      default:
        if (category.isEmpty) return 'Select Category';
        return category[0].toUpperCase() + category.substring(1);
    }
  }

  /// Get icon data for a category.
  static String iconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return '🍽️';
      case 'groceries':
        return '🧺';
      case 'travel':
        return '🧳';
      case 'stays':
        return '🛌';
      case 'bills':
        return '📄';
      case 'subscription':
        return '📺';
      case 'shopping':
        return '🛍️';
      case 'gifts':
        return '🎁';
      case 'drinks':
        return '🥤';
      case 'fuel':
        return '⛽';
      case 'udhaar':
        return '💸';
      case 'health':
        return '❤️';
      case 'entertainment':
        return '🎟️';
      case 'misc':
        return '📦';
      default:
        return '📦';
    }
  }
}

enum AppLanguage { english, bangla }

class AppStrings {
  static const Map<String, Map<AppLanguage, String>> _localizedValues = {
    'app_title': {
      AppLanguage.english: 'MediTrack',
      AppLanguage.bangla: 'মেডিট্র্যাক',
    },
    'home': {
      AppLanguage.english: 'Home',
      AppLanguage.bangla: 'হোম',
    },
    'ai_assistant': {
      AppLanguage.english: 'AI Assistant',
      AppLanguage.bangla: 'এআই সহকারী',
    },
    'buy_list': {
      AppLanguage.english: 'Buy List',
      AppLanguage.bangla: 'কেনার তালিকা',
    },
    'profile': {
      AppLanguage.english: 'Profile',
      AppLanguage.bangla: 'প্রোফাইল',
    },
    'ongoing_routine': {
      AppLanguage.english: 'Ongoing Routine',
      AppLanguage.bangla: 'বর্তমান রুটিন',
    },
    'scan_rx': {
      AppLanguage.english: 'Scan Rx',
      AppLanguage.bangla: 'প্রেসক্রিপশন স্ক্যান',
    },
    'rx_vault': {
      AppLanguage.english: 'Rx Vault',
      AppLanguage.bangla: 'প্রেসক্রিপশন ভল্ট',
    },
    'low_stock_alerts': {
      AppLanguage.english: 'Low Stock Alerts',
      AppLanguage.bangla: 'স্টক শেষ হওয়ার সতর্কতা',
    },
    'expiring_soon': {
      AppLanguage.english: 'Expiring Soon',
      AppLanguage.bangla: 'মেয়াদোত্তীর্ণ হওয়ার সতর্কতা',
    },
    'my_inventory': {
      AppLanguage.english: 'My Inventory',
      AppLanguage.bangla: 'আমার ওষুধ তালিকা',
    },
    'search_medicines': {
      AppLanguage.english: 'Search medicines or prescriptions...',
      AppLanguage.bangla: 'ওষুধ বা প্রেসক্রিপশন খুঁজুন...',
    },
    'take_now': {
      AppLanguage.english: 'Take',
      AppLanguage.bangla: 'খেয়েছি',
    },
    'skip': {
      AppLanguage.english: 'Skip',
      AppLanguage.bangla: 'বাদ দিন',
    },
    'taken': {
      AppLanguage.english: 'Taken',
      AppLanguage.bangla: 'গৃহীত',
    },
    'missed': {
      AppLanguage.english: 'Missed',
      AppLanguage.bangla: 'মিস হয়েছে',
    },
    'settings': {
      AppLanguage.english: 'Settings',
      AppLanguage.bangla: 'সেটিংস',
    },
    'language': {
      AppLanguage.english: 'Language',
      AppLanguage.bangla: 'ভাষা',
    },
    'family_members': {
      AppLanguage.english: 'Family Members',
      AppLanguage.bangla: 'পরিবারের সদস্য',
    },
    'notifications': {
      AppLanguage.english: 'Notifications',
      AppLanguage.bangla: 'বিজ্ঞপ্তি',
    },
    'refill_threshold': {
      AppLanguage.english: 'Refill Alert Days Before',
      AppLanguage.bangla: 'কত দিন আগে রিফিল সতর্কতা',
    },
    'expiry_threshold': {
      AppLanguage.english: 'Expiry Alert Days Before',
      AppLanguage.bangla: 'কত দিন আগে মেয়াদ সতর্কতা',
    },
    'price_lookup': {
      AppLanguage.english: 'Price & Generic Lookup',
      AppLanguage.bangla: 'ওষুধের দাম ও জেনেরিক অনুসন্ধান',
    },
    'nearby_pharmacies': {
      AppLanguage.english: 'Nearby Pharmacies',
      AppLanguage.bangla: 'নিকটবর্তী ফার্মেসি',
    },
    'export_pdf': {
      AppLanguage.english: 'Export Doctor Summary (PDF)',
      AppLanguage.bangla: 'ডাক্তারের সারাংশ এক্সপোর্ট (PDF)',
    },
    'dark_mode': {
      AppLanguage.english: 'Dark Mode',
      AppLanguage.bangla: 'ডার্ক মোড',
    },
  };

  static String get(String key, AppLanguage language) {
    final entry = _localizedValues[key];
    if (entry == null) return key;
    return entry[language] ?? entry[AppLanguage.english] ?? key;
  }
}

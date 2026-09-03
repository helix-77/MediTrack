enum AppLanguage { english, bangla }

class AppStrings {
  static const Map<String, Map<AppLanguage, String>> _localizedValues = {
    // App & Navigation
    'app_title': {
      AppLanguage.english: 'MediTrack',
      AppLanguage.bangla: 'মেডিট্র্যাক',
    },
    'home': {
      AppLanguage.english: 'Home',
      AppLanguage.bangla: 'হোম',
    },
    'schedule': {
      AppLanguage.english: 'Schedule',
      AppLanguage.bangla: 'সময়সূচি',
    },
    'ai_chat': {
      AppLanguage.english: 'AI Chat',
      AppLanguage.bangla: 'এআই চ্যাট',
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
    'settings': {
      AppLanguage.english: 'Settings',
      AppLanguage.bangla: 'সেটিংস',
    },

    // Greetings & Headers
    'good_morning': {
      AppLanguage.english: 'Good morning',
      AppLanguage.bangla: 'শুভ সকাল',
    },
    'good_afternoon': {
      AppLanguage.english: 'Good afternoon',
      AppLanguage.bangla: 'শুভ দুপুর',
    },
    'good_evening': {
      AppLanguage.english: 'Good evening',
      AppLanguage.bangla: 'শুভ সন্ধ্যা',
    },
    'search_medicines_hint': {
      AppLanguage.english: 'Search medicines or prescriptions...',
      AppLanguage.bangla: 'ওষুধ বা প্রেসক্রিপশন খুঁজুন...',
    },

    // Daily Adherence & Routine
    'daily_adherence': {
      AppLanguage.english: 'Daily Adherence',
      AppLanguage.bangla: 'আজকের নিয়ম মানার হার',
    },
    'doses_taken_today': {
      AppLanguage.english: 'Doses taken today',
      AppLanguage.bangla: 'আজকের গৃহীত ডোজ',
    },
    'adherence_great_job': {
      AppLanguage.english: 'Great job! All scheduled doses completed.',
      AppLanguage.bangla: 'দারুণ! আজকের সকল ডোজ সম্পন্ন হয়েছে।',
    },
    'adherence_keep_up': {
      AppLanguage.english: 'Keep it up! You\'re on track with your routine.',
      AppLanguage.bangla: 'চালিয়ে যান! আপনি সঠিক নিয়মে ওষুধ নিচ্ছেন।',
    },
    'adherence_take_on_time': {
      AppLanguage.english: 'Take scheduled doses on time to stay healthy.',
      AppLanguage.bangla: 'সুস্থ থাকতে সময়মতো নির্ধারিত ডোজ গ্রহণ করুন।',
    },
    'todays_routine': {
      AppLanguage.english: 'Today\'s Routine',
      AppLanguage.bangla: 'আজকের রুটিন',
    },
    'routine_time_slots': {
      AppLanguage.english: 'Routine Time Slots',
      AppLanguage.bangla: 'রুটিনের সময়সূচি',
    },
    'morning': {
      AppLanguage.english: 'Morning',
      AppLanguage.bangla: 'সকাল',
    },
    'noon': {
      AppLanguage.english: 'Noon',
      AppLanguage.bangla: 'দুপুর',
    },
    'evening': {
      AppLanguage.english: 'Evening',
      AppLanguage.bangla: 'সন্ধ্যা',
    },
    'night': {
      AppLanguage.english: 'Night',
      AppLanguage.bangla: 'রাত',
    },
    'all': {
      AppLanguage.english: 'All',
      AppLanguage.bangla: 'সকল',
    },
    'no_doses_today': {
      AppLanguage.english: 'No doses scheduled for today',
      AppLanguage.bangla: 'আজকের জন্য কোনো ডোজ নির্ধারিত নেই',
    },
    'add_medicine_sub': {
      AppLanguage.english: 'Add a medicine to start tracking your daily routine.',
      AppLanguage.bangla: 'দৈনিক রুটিন ট্র্যাক করতে নতুন ওষুধ যুক্ত করুন।',
    },
    'add_medicine': {
      AppLanguage.english: 'Add Medicine',
      AppLanguage.bangla: 'ওষুধ যোগ করুন',
    },

    // Stock & Inventory
    'low_stock_alerts': {
      AppLanguage.english: 'Low Stock Alerts',
      AppLanguage.bangla: 'কম স্টক সতর্কতা',
    },
    'stock_sufficient': {
      AppLanguage.english: 'All medicines have sufficient stock',
      AppLanguage.bangla: 'সকল ওষুধের পর্যাপ্ত স্টক রয়েছে',
    },
    'expiring_soon': {
      AppLanguage.english: 'Expiring Soon',
      AppLanguage.bangla: 'মেয়াদোত্তীর্ণ হওয়ার সতর্কতা',
    },
    'my_inventory': {
      AppLanguage.english: 'My Inventory',
      AppLanguage.bangla: 'আমার ওষুধের তালিকা',
    },
    'left_in_stock': {
      AppLanguage.english: 'left',
      AppLanguage.bangla: 'টি বাকি',
    },

    // Quick Tools
    'quick_tools': {
      AppLanguage.english: 'Quick Tools & Actions',
      AppLanguage.bangla: 'প্রয়োজনীয় টুলস ও সেবা',
    },
    'ongoing_routine': {
      AppLanguage.english: 'Ongoing Routine',
      AppLanguage.bangla: 'চলমান রুটিন',
    },
    'scan_rx': {
      AppLanguage.english: 'Scan Rx',
      AppLanguage.bangla: 'প্রেসক্রিপশন স্ক্যান',
    },
    'rx_vault': {
      AppLanguage.english: 'Rx Vault',
      AppLanguage.bangla: 'প্রেসক্রিপশন ভল্ট',
    },
    'low_stock': {
      AppLanguage.english: 'Low Stock',
      AppLanguage.bangla: 'কম স্টক',
    },
    'expiring': {
      AppLanguage.english: 'Expiring',
      AppLanguage.bangla: 'মেয়াদ শেষ',
    },
    'my_meds': {
      AppLanguage.english: 'My Meds',
      AppLanguage.bangla: 'আমার ওষুধ',
    },
    'pharmacies': {
      AppLanguage.english: 'Pharmacies',
      AppLanguage.bangla: 'ফার্মেসি',
    },
    'pdf_export': {
      AppLanguage.english: 'PDF Export',
      AppLanguage.bangla: 'পিডিএফ রিপোর্ট',
    },
    'price_lookup': {
      AppLanguage.english: 'Price & Generic Lookup',
      AppLanguage.bangla: 'ওষুধের দাম ও জেনেরিক',
    },
    'nearby_pharmacies': {
      AppLanguage.english: 'Nearby Pharmacies',
      AppLanguage.bangla: 'নিকটবর্তী ফার্মেসি',
    },
    'export_pdf': {
      AppLanguage.english: 'Export Doctor Summary (PDF)',
      AppLanguage.bangla: 'ডাক্তারের সারাংশ এক্সপোর্ট (PDF)',
    },

    // Actions & Dose statuses
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
    'save': {
      AppLanguage.english: 'Save',
      AppLanguage.bangla: 'সংরক্ষণ',
    },
    'cancel': {
      AppLanguage.english: 'Cancel',
      AppLanguage.bangla: 'বাতিল',
    },
    'delete': {
      AppLanguage.english: 'Delete',
      AppLanguage.bangla: 'মুছে ফেলুন',
    },
    'edit': {
      AppLanguage.english: 'Edit',
      AppLanguage.bangla: 'সম্পাদনা',
    },
    'see_all': {
      AppLanguage.english: 'See all',
      AppLanguage.bangla: 'সব দেখুন',
    },

    // Schedule / Calendar Screen
    'schedule_and_routine': {
      AppLanguage.english: 'Schedule & Routine',
      AppLanguage.bangla: 'রুটিন ও সময়সূচি',
    },
    'todays_progress': {
      AppLanguage.english: 'Today\'s Intake Progress',
      AppLanguage.bangla: 'আজকের ওষুধ গ্রহণের অগ্রগতি',
    },
    'scheduled_timeline': {
      AppLanguage.english: 'Scheduled Timeline',
      AppLanguage.bangla: 'নির্ধারিত সময়রেখা',
    },
    'no_medication_scheduled': {
      AppLanguage.english: 'No medication scheduled for this time',
      AppLanguage.bangla: 'এই সময়ের জন্য কোনো ওষুধ নির্ধারিত নেই',
    },

    // Settings Screen
    'account_preferences': {
      AppLanguage.english: 'Account & Preferences',
      AppLanguage.bangla: 'অ্যাকাউন্ট ও সেটিংস',
    },
    'notifications_alarms': {
      AppLanguage.english: 'Notifications & Alarms',
      AppLanguage.bangla: 'বিজ্ঞপ্তি ও অ্যালার্ম',
    },
    'pause_notifications': {
      AppLanguage.english: 'Pause Notifications',
      AppLanguage.bangla: 'বিজ্ঞপ্তি সাময়িক বন্ধ',
    },
    'reminder_alert_rules': {
      AppLanguage.english: 'Reminder & Alert Rules',
      AppLanguage.bangla: 'রিমাইন্ডার ও সতর্কবার্তা নিয়ম',
    },
    'preferences_display': {
      AppLanguage.english: 'Preferences & Display',
      AppLanguage.bangla: 'পছন্দ ও ডিসপ্লে',
    },
    'dark_mode': {
      AppLanguage.english: 'Dark Mode',
      AppLanguage.bangla: 'ডার্ক মোড',
    },
    'language': {
      AppLanguage.english: 'Language / ভাষা',
      AppLanguage.bangla: 'ভাষা / Language',
    },
    'routine_time_schedule': {
      AppLanguage.english: 'Routine Time Schedule',
      AppLanguage.bangla: 'রুটিন সময়সূচি বিন্যাস',
    },
    'routine_schedule_sub': {
      AppLanguage.english: 'Set Morning, Noon, Evening & Night home grid ranges',
      AppLanguage.bangla: 'সকাল, দুপুর, সন্ধ্যা ও রাতের সময়সীমা নির্ধারণ করুন',
    },
    'bdapps_sms_service': {
      AppLanguage.english: 'BD Apps SMS Service',
      AppLanguage.bangla: 'বিডি অ্যাপস এসএমএস সেবা',
    },
    'carrier_alert_diagnostics': {
      AppLanguage.english: 'Carrier alert diagnostics',
      AppLanguage.bangla: 'মোবাইল এসএমএস সতর্কতা যাচাই',
    },
    'help_legal_policies': {
      AppLanguage.english: 'Help, Legal & Policies',
      AppLanguage.bangla: 'সাহায্য, নীতি ও শর্তাবলী',
    },
    'faq_help_guide': {
      AppLanguage.english: 'FAQ & Help Guide',
      AppLanguage.bangla: 'সাধারণ জিজ্ঞাসা ও নির্দেশিকা',
    },
    'terms_of_service': {
      AppLanguage.english: 'Terms of Service',
      AppLanguage.bangla: 'ব্যবহারের শর্তাবলী',
    },
    'privacy_policy': {
      AppLanguage.english: 'Privacy & Security Policy',
      AppLanguage.bangla: 'গোপনীয়তা ও নিরাপত্তা নীতি',
    },
    'delete_account': {
      AppLanguage.english: 'Delete Account',
      AppLanguage.bangla: 'অ্যাকাউন্ট মুছে ফেলুন',
    },
    'log_out': {
      AppLanguage.english: 'Log Out',
      AppLanguage.bangla: 'লগআউট',
    },
    'logout_confirm_msg': {
      AppLanguage.english: 'Are you sure you want to log out of your MediTrack account?',
      AppLanguage.bangla: 'আপনি কি নিশ্চিত যে মেডিট্র্যাক অ্যাকাউন্ট থেকে লগআউট করতে চান?',
    },
    'select_language': {
      AppLanguage.english: 'Select Language / ভাষা নির্বাচন',
      AppLanguage.bangla: 'ভাষা নির্বাচন / Select Language',
    },

    // Profile & Family
    'profile_and_family': {
      AppLanguage.english: 'Profile & Family',
      AppLanguage.bangla: 'প্রোফাইল ও পরিবার',
    },
    'profile_sub': {
      AppLanguage.english: 'Manage health records and family profiles',
      AppLanguage.bangla: 'স্বাস্থ্য বিবরণী ও পরিবারের সদস্যদের তথ্য পরিচালনা করুন',
    },
    'clinical_health_profile': {
      AppLanguage.english: 'Clinical Health Profile',
      AppLanguage.bangla: 'স্বাস্থ্য বিবরণী প্রোফাইল',
    },
    'clinical_health_sub': {
      AppLanguage.english: 'Important health data for clinical reference & doctor visits',
      AppLanguage.bangla: 'ডাক্তারের পরামর্শ ও চিকিৎসার জন্য প্রয়োজনীয় স্বাস্থ্য তথ্য',
    },
    'family_members': {
      AppLanguage.english: 'Family Members',
      AppLanguage.bangla: 'পরিবারের সদস্যবৃন্দ',
    },
    'add_family_member': {
      AppLanguage.english: 'Add Family Member',
      AppLanguage.bangla: 'নতুন সদস্য যুক্ত করুন',
    },
    'blood_group': {
      AppLanguage.english: 'Blood Group',
      AppLanguage.bangla: 'রক্তের গ্রুপ',
    },
    'allergies': {
      AppLanguage.english: 'Allergies',
      AppLanguage.bangla: 'অ্যালার্জি ও সংবেদনশীলতা',
    },
    'save_changes': {
      AppLanguage.english: 'Save Changes',
      AppLanguage.bangla: 'পরিবর্তন সংরক্ষণ করুন',
    },
    'switch_profile': {
      AppLanguage.english: 'Switch Profile',
      AppLanguage.bangla: 'প্রোফাইল পরিবর্তন',
    },

    // AI Assistant
    'medibot': {
      AppLanguage.english: 'MediBot AI',
      AppLanguage.bangla: 'মেডিবট এআই',
    },
    'ai_chat_sub': {
      AppLanguage.english: 'Instant medication advice, dosage & interaction insights',
      AppLanguage.bangla: 'ওষুধের নিয়ম, ডোজ ও স্বাস্থ্য বিষয়ক তাৎক্ষণিক পরামর্শ',
    },
    'ask_ai_hint': {
      AppLanguage.english: 'Ask about medication, dosage, side effects...',
      AppLanguage.bangla: 'ওষুধের মাত্রা, নিয়ম বা পার্শ্বপ্রতিক্রিয়া সম্পর্কে লিখুন...',
    },
    'clear_chat': {
      AppLanguage.english: 'Clear Chat',
      AppLanguage.bangla: 'চ্যাট মুছুন',
    },
    'ai_disclaimer': {
      AppLanguage.english: 'MediBot is an AI assistant and not a substitute for professional medical advice.',
      AppLanguage.bangla: 'মেডিবট একটি এআই সহকারী এবং এটি সরাসরি চিকিৎসকের বিকল্প নয়।',
    },

    // Buy List
    'buy_list_title': {
      AppLanguage.english: 'Medicine Buy List',
      AppLanguage.bangla: 'ওষুধ কেনার তালিকা',
    },
    'items_to_purchase': {
      AppLanguage.english: 'Items to Purchase',
      AppLanguage.bangla: 'কেনার জন্য প্রয়োজনীয় ওষুধ',
    },
    'add_item': {
      AppLanguage.english: 'Add Item',
      AppLanguage.bangla: 'নতুন আইটেম যোগ করুন',
    },
    'mark_purchased': {
      AppLanguage.english: 'Mark Purchased',
      AppLanguage.bangla: 'কেনা হয়েছে',
    },
    'all_items_purchased': {
      AppLanguage.english: 'All items purchased',
      AppLanguage.bangla: 'সকল ওষুধ কেনা সম্পন্ন হয়েছে',
    },

    // Prescriptions
    'prescription_vault': {
      AppLanguage.english: 'Prescription Vault',
      AppLanguage.bangla: 'প্রেসক্রিপশন ভল্ট',
    },
    'rx_vault_sub': {
      AppLanguage.english: 'Your digital medical prescriptions & archives',
      AppLanguage.bangla: 'আপনার ডিজিটাল প্রেসক্রিপশন ও মেডিকেল রেকর্ডসমূহ',
    },
    'upload_rx': {
      AppLanguage.english: 'Upload Prescription',
      AppLanguage.bangla: 'প্রেসক্রিপশন আপলোড',
    },
    'scan_new_rx': {
      AppLanguage.english: 'Scan New Rx',
      AppLanguage.bangla: 'নতুন প্রেসক্রিপশন স্ক্যান',
    },
    'no_rx_found': {
      AppLanguage.english: 'No prescriptions found',
      AppLanguage.bangla: 'কোনো প্রেসক্রিপশন পাওয়া যায়নি',
    },

    // Nearby Pharmacies
    'nearby_pharmacies_title': {
      AppLanguage.english: 'Nearby Pharmacies',
      AppLanguage.bangla: 'নিকটবর্তী ফার্মেসি',
    },
    'pharmacies_sub': {
      AppLanguage.english: 'Find 24/7 pharmacies and medicine stores near you',
      AppLanguage.bangla: 'আপনার আশেপাশে ২৪/৭ খোলা ওষুধের দোকান ও ফার্মেসি খুঁজুন',
    },
    'search_pharmacies_hint': {
      AppLanguage.english: 'Search pharmacies in your area...',
      AppLanguage.bangla: 'ফার্মেসি বা ওষুধের দোকান খুঁজুন...',
    },
    'call': {
      AppLanguage.english: 'Call',
      AppLanguage.bangla: 'কল করুন',
    },
    'directions': {
      AppLanguage.english: 'Directions',
      AppLanguage.bangla: 'দিকনির্দেশনা',
    },
    'safety_disclaimer': {
      AppLanguage.english:
          'AI is an assistant, not a doctor. Always consult a healthcare professional for medical decisions.',
      AppLanguage.bangla:
          'এআই একজন সহকারী, চিকিৎসক নয়। যেকোনো স্বাস্থ্যগত সিদ্ধান্তের জন্য বিশেষজ্ঞ চিকিৎসকের পরামর্শ নিন।',
    },
    'copy': {
      AppLanguage.english: 'Copy',
      AppLanguage.bangla: 'কপি করুন',
    },
    'copy_text': {
      AppLanguage.english: 'Copy Text',
      AppLanguage.bangla: 'টেক্সট কপি করুন',
    },
    'message_copied': {
      AppLanguage.english: 'Message copied to clipboard',
      AppLanguage.bangla: 'বার্তাটি ক্লিপবোর্ডে কপি করা হয়েছে',
    },

    // Prescription notes (disease / visit reason)
    'prescription_note_label': {
      AppLanguage.english: 'Prescription Note (e.g. disease / reason)',
      AppLanguage.bangla: 'প্রেসক্রিপশন নোট (যেমন: রোগ / কারণ)',
    },
    'prescription_note_hint': {
      AppLanguage.english: 'e.g. Fever and cough follow-up',
      AppLanguage.bangla: 'যেমন: জ্বর ও কাশির ফলোআপ',
    },
    'note': {
      AppLanguage.english: 'Note',
      AppLanguage.bangla: 'নোট',
    },
    'no_note': {
      AppLanguage.english: 'No note added yet',
      AppLanguage.bangla: 'এখনও কোনো নোট যোগ করা হয়নি',
    },
    'edit_note': {
      AppLanguage.english: 'Edit Note',
      AppLanguage.bangla: 'নোট সম্পাদনা করুন',
    },
    'note_saved': {
      AppLanguage.english: 'Note saved',
      AppLanguage.bangla: 'নোট সংরক্ষিত হয়েছে',
    },

    // PDF export
    'pdf_export_success': {
      AppLanguage.english: 'PDF exported',
      AppLanguage.bangla: 'পিডিএফ এক্সপোর্ট হয়েছে',
    },
    'pdf_export_failed': {
      AppLanguage.english: 'Could not export PDF',
      AppLanguage.bangla: 'পিডিএফ এক্সপোর্ট করা যায়নি',
    },
  };

  static String get(String key, AppLanguage language, [Map<String, String>? params]) {
    final entry = _localizedValues[key];
    String text;
    if (entry == null) {
      text = key;
    } else {
      text = entry[language] ?? entry[AppLanguage.english] ?? key;
    }

    if (params != null && params.isNotEmpty) {
      params.forEach((paramKey, paramValue) {
        text = text.replaceAll('{$paramKey}', paramValue);
      });
    }

    return text;
  }
}


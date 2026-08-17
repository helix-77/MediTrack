/// Pure validation and normalization helper for Bangladeshi mobile numbers,
/// specifically Robi (`018`) and Airtel (`016`) carrier billing prefixes.
class BdMobileValidator {
  const BdMobileValidator._();

  /// Normalizes any variation of Bangladeshi mobile input (e.g. `+88018...`,
  /// `88018...`, `018...`, `018-XXX`) to an 11-digit string starting with `0`.
  static String normalize(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D+'), '');
    if (digits.length == 13 && digits.startsWith('880')) {
      digits = '0${digits.substring(3)}';
    } else if (digits.length == 12 && digits.startsWith('88')) {
      digits = '0${digits.substring(2)}';
    }
    return digits;
  }

  /// Returns `true` if the normalized number is a valid 11-digit BD mobile number (`013`–`019`).
  static bool isValidBdMobile(String raw) {
    final digits = normalize(raw);
    return RegExp(r'^01[3-9][0-9]{8}$').hasMatch(digits);
  }

  /// Returns `true` if the normalized number belongs to Robi (`018`) or Airtel (`016`).
  static bool isValidRobiAirtel(String raw) {
    final digits = normalize(raw);
    return RegExp(r'^01[68][0-9]{8}$').hasMatch(digits);
  }

  /// Returns the operator name if known (e.g. 'Robi', 'Airtel', 'Grameenphone', 'Banglalink', 'Teletalk').
  static String? getOperator(String raw) {
    final digits = normalize(raw);
    if (digits.length != 11) return null;
    if (digits.startsWith('018')) return 'Robi';
    if (digits.startsWith('016')) return 'Airtel';
    if (digits.startsWith('017') || digits.startsWith('013')) return 'Grameenphone';
    if (digits.startsWith('019') || digits.startsWith('014')) return 'Banglalink';
    if (digits.startsWith('015')) return 'Teletalk';
    return null;
  }

  /// Returns a user-facing validation error message if invalid, or `null` if valid.
  static String? validateRobiAirtel(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Please enter your mobile number';
    }
    final digits = normalize(raw.trim());
    if (digits.length != 11 || !digits.startsWith('01')) {
      return 'Please enter a valid 11-digit mobile number';
    }
    if (!isValidRobiAirtel(digits)) {
      return 'Only Robi (018) and Airtel (016) numbers are supported';
    }
    return null;
  }

  /// Formats the number with partial masking for privacy (e.g. `018****5678`).
  static String maskMobile(String raw) {
    final digits = normalize(raw);
    if (digits.length != 11) return digits;
    return '${digits.substring(0, 3)}****${digits.substring(7)}';
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../features/bdapps/bd_apps_service.dart';
import '../features/bdapps/subscription_offer_config.dart';
import '../logic/bd_mobile_validator.dart';
import '../services/entitlement_service.dart';
import '../theme/colors.dart';
import 'account_upgrade_screen.dart';

class SubscriptionOfferScreen extends StatefulWidget {
  const SubscriptionOfferScreen({super.key});

  @override
  State<SubscriptionOfferScreen> createState() => _SubscriptionOfferScreenState();
}

class _SubscriptionOfferScreenState extends State<SubscriptionOfferScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _isMonthly = false;
  bool _hasConsented = false;
  String? _inlineError;

  @override
  void initState() {
    super.initState();
    final bdService = context.read<BdAppsService>();
    if (bdService.bdMobile != null && bdService.bdMobile!.isNotEmpty) {
      _mobileController.text = bdService.bdMobile!;
    }
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terms & Conditions'),
        content: SingleChildScrollView(
          child: Text(
            SubscriptionOfferConfig.termsAndConditions,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: SingleChildScrollView(
          child: Text(
            SubscriptionOfferConfig.privacyPolicy,
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _recordConsent(String mobile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('profile')
          .doc('main')
          .set({
        'bdMobile': mobile,
        'subscriptionConsentVersion': SubscriptionOfferConfig.consentVersion,
        'subscriptionConsentAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Consent recording notice: $e');
    }
  }

  Future<void> _handleSendOtp() async {
    final rawNumber = _mobileController.text.trim();
    final validationError = BdMobileValidator.validateRobiAirtel(rawNumber);
    if (validationError != null) {
      setState(() => _inlineError = validationError);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      final upgraded = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const AccountUpgradeScreen()),
      );
      if (upgraded != true && (FirebaseAuth.instance.currentUser?.isAnonymous ?? true)) {
        return;
      }
    }

    setState(() => _inlineError = null);
    final normalized = BdMobileValidator.normalize(rawNumber);
    await _recordConsent(normalized);

    if (!mounted) return;
    final bdService = context.read<BdAppsService>();
    final ok = await bdService.sendOtp(mobileNumber: normalized);
    if (!mounted) return;

    if (bdService.isRegistered) {
      final entitlementService = context.read<EntitlementService>();
      entitlementService.updateSubscribedState(true);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('profile')
              .doc('main')
              .set({
            'bdMobile': normalized,
            'subscriptionStatus': 'REGISTERED',
            'subscriptionVerifiedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 You are already subscribed! MediTrack Premium is unlocked.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
      return;
    }

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP sent to $normalized via SMS. Enter code below.'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handleCheckExistingStatus() async {
    final rawNumber = _mobileController.text.trim();
    final validationError = BdMobileValidator.validateRobiAirtel(rawNumber);
    if (validationError != null) {
      setState(() => _inlineError = validationError);
      return;
    }

    setState(() => _inlineError = null);
    final normalized = BdMobileValidator.normalize(rawNumber);

    final bdService = context.read<BdAppsService>();
    final entitlementService = context.read<EntitlementService>();

    bdService.updateBdMobile(normalized);
    await bdService.refreshSubscriptionStatus();

    if (!mounted) return;

    if (bdService.isRegistered) {
      entitlementService.updateSubscribedState(true);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('profile')
              .doc('main')
              .set({
            'bdMobile': normalized,
            'subscriptionStatus': 'REGISTERED',
            'subscriptionVerifiedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Active subscription found! MediTrack Premium is unlocked.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No active subscription found for $normalized (${bdService.subscriptionStatus ?? 'UNREGISTERED'}). Please send SMS OTP to subscribe.',
          ),
          backgroundColor: AppColors.textSecondary,
        ),
      );
    }
  }

  Future<void> _handleVerifyOtp() async {
    final code = _otpController.text.trim();
    if (code.isEmpty) {
      setState(() => _inlineError = 'Please enter the 6-digit OTP code');
      return;
    }

    setState(() => _inlineError = null);
    final bdService = context.read<BdAppsService>();
    final entitlementService = context.read<EntitlementService>();

    final ok = await bdService.verifyOtp(otp: code);
    if (ok && mounted) {
      entitlementService.updateSubscribedState(true);
      final user = FirebaseAuth.instance.currentUser;
      final rawNumber = _mobileController.text.trim();
      final normalized = BdMobileValidator.normalize(rawNumber);
      if (user != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('profile')
              .doc('main')
              .set({
            'bdMobile': normalized,
            'subscriptionStatus': 'REGISTERED',
            'subscriptionVerifiedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 MediTrack Premium activated successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.darkBackground,
                    const Color(0xFF1B201D),
                    const Color(0xFF222620),
                  ]
                : [
                    const Color(0xFFFDFBF7),
                    const Color(0xFFF6F0E6),
                    const Color(0xFFFBF4E8),
                    const Color(0xFFFDF0D5), // warm golden glow on bottom-right
                  ],
            stops: const [0.0, 0.35, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: Consumer<BdAppsService>(
            builder: (context, bdService, _) {
              return Column(
                children: [
                  _buildTopBar(isDark),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleRow(isDark),
                          const SizedBox(height: 16),
                          _buildPricingCard(isDark, bdService),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Circular Back Button
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
                border: Border.all(
                  color: isDark ? AppColors.darkDivider : const Color(0xFFECE4D9),
                ),
              ),
              child: Icon(
                Icons.arrow_back,
                size: 20,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF2C3530),
              ),
            ),
          ),

          // Segmented Toggle Pill (Annual / Monthly)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark ? AppColors.darkDivider : const Color(0xFFECE4D9),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildToggleOption(
                  title: 'Daily',
                  isSelected: !_isMonthly,
                  isDark: isDark,
                  onTap: () => setState(() => _isMonthly = false),
                ),
                _buildToggleOption(
                  title: 'Monthly',
                  isSelected: _isMonthly,
                  isDark: isDark,
                  onTap: () => setState(() => _isMonthly = true),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption({
    required String title,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.primaryGreenLight : const Color(0xFF262D29))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.darkTextSecondary : const Color(0xFF6E7470)),
          ),
        ),
      ),
    );
  }

  Widget _buildTitleRow(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Pricing',
          style: GoogleFonts.poppins(
            fontSize: 34,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.6,
            color: isDark ? AppColors.darkTextPrimary : const Color(0xFF222925),
          ),
        ),
        // Dashed Indicator (Matches the 3 dashes in reference image)
        Row(
          children: [
            Container(
              width: 14,
              height: 3.5,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF262D29),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 14,
              height: 3.5,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF262D29),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 14,
              height: 3.5,
              decoration: BoxDecoration(
                color: const Color(0xFFE5B03C), // Warm yellow/gold accent dash
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPricingCard(bool isDark, BdAppsService bdService) {
    final hasPendingOtp = bdService.pendingReferenceNo != null;
    final isBusy = bdService.isSendingOtp || bdService.isVerifyingOtp;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : const Color(0xFFF0EAE1),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : const Color(0xFF47594E).withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Plan Name & Popular Badge
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isMonthly ? 'MediTrack Plus' : 'MediTrack Pro',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : const Color(0xFF262D29),
                      ),
                    ),
                  ],
                ),
                // Popular Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1B261F)
                        : const Color(0xFFF3EFE9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Popular',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : const Color(0xFF4A524D),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4DAA52),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Price and Billed Frequency
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _isMonthly ? '৳50' : '৳2.00',
                  style: GoogleFonts.poppins(
                    fontSize: 42,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1.0,
                    color: isDark ? AppColors.darkTextPrimary : const Color(0xFF1E2420),
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isMonthly ? '/ month (BDT)' : '/ day (BDT)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF7A827E),
                      ),
                    ),
                    Text(
                      _isMonthly
                          ? '৳500 billed yearly (Save 16%)'
                          : '৳60 billed monthly • ${SubscriptionOfferConfig.taxSuffix}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF9AA29D),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Subtitle description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Maximize medicine adherence with AI prescription scans, smart health assistant, price lookup, and nearby pharmacy finder.',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                height: 1.45,
                color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B736E),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Dotted Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: CustomPaint(
              size: const Size(double.infinity, 2),
              painter: _DottedLinePainter(
                color: isDark ? AppColors.darkDivider : const Color(0xFFDDD5CA),
                dotRadius: 1.2,
                spacing: 5.0,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Feature Checklist
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                _buildCheckItem('Access to Gemini 3.6 AI prescription OCR', isDark),
                _buildCheckItem('MediTrack AI health assistant & advisor', isDark),
                _buildCheckItem('Bangladesh medicine price & generic MRP database', isDark),
                _buildCheckItem('Nearby open pharmacy locator with directions', isDark),
                _buildCheckItem('Smart automatic refill & routine reminders', isDark),
                _buildCheckItem('Family profile management & schedule sharing', isDark),
                _buildCheckItem('Priority 24/7 SMS & in-app support', isDark),
                _buildCheckItem('Ad-free, privacy-protected health experience', isDark),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Carrier Info Chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : const Color(0xFFF9F6F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.darkDivider : const Color(0xFFECE4D9),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.sim_card_outlined,
                    size: 18,
                    color: isDark ? AppColors.primaryGreenLight : AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Direct Carrier Billing via Robi (018) & Airtel (016)',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : const Color(0xFF3B433E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Phone Number Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _mobileController,
                  enabled: !isBusy,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Robi / Airtel Mobile Number',
                    labelStyle: GoogleFonts.inter(fontSize: 13),
                    hintText: '018XXXXXXXX or 016XXXXXXXX',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                    prefixIcon: const Icon(Icons.phone_android, color: AppColors.primaryGreen),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkDivider : const Color(0xFFE2D8CC),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.darkDivider : const Color(0xFFE2D8CC),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppColors.primaryGreen,
                        width: 1.5,
                      ),
                    ),
                    errorText: _inlineError,
                  ),
                ),
                const SizedBox(height: 10),
                _buildConsentCheckbox(isDark),
              ],
            ),
          ),

          // Error Display
          if (bdService.errorMessage != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bdService.errorMessage!,
                        style: GoogleFonts.inter(color: AppColors.danger, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Primary Subscribe Button (Matches Pill Button in Reference)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? AppColors.primaryGreenLight : const Color(0xFF38463D),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: (!_hasConsented || isBusy) ? null : _handleSendOtp,
                child: isBusy && bdService.isSendingOtp
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        hasPendingOtp
                            ? 'Resend SMS OTP'
                            : (_isMonthly ? 'Start 7-Days Free Trial' : 'Subscribe for ৳2.00/day'),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
              ),
            ),
          ),

          // Already Subscribed Check
          const SizedBox(height: 6),
          Center(
            child: TextButton.icon(
              onPressed: isBusy ? null : _handleCheckExistingStatus,
              icon: const Icon(Icons.refresh, size: 15, color: AppColors.primaryGreen),
              label: Text(
                'Already subscribed? Check status',
                style: GoogleFonts.inter(
                  color: AppColors.primaryGreen,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),

          // OTP Verification Section
          if (hasPendingOtp) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1D2821)
                      : AppColors.primaryGreenLight.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primaryGreenLight.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.mark_email_read_outlined,
                          color: AppColors.primaryGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'SMS OTP sent to ${BdMobileValidator.maskMobile(_mobileController.text)}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextPrimary : const Color(0xFF2E3D34),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _otpController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 4,
                      ),
                      decoration: InputDecoration(
                        labelText: '6-Digit OTP Code',
                        counterText: '',
                        hintText: '123456',
                        prefixIcon: const Icon(Icons.pin, color: AppColors.primaryGreen),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        icon: bdService.isVerifyingOtp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.verified_outlined, size: 18),
                        label: Text(
                          bdService.isVerifyingOtp
                              ? 'Activating Premium...'
                              : 'Verify OTP & Activate',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: isBusy ? null : _handleVerifyOtp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Filled Green Circle Checkmark
          Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
              color: Color(0xFF67A452),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check,
              size: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w400,
                color: isDark ? AppColors.darkTextPrimary : const Color(0xFF38403B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCheckbox(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _hasConsented,
            activeColor: AppColors.primaryGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (val) {
              setState(() {
                _hasConsented = val ?? false;
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Wrap(
              children: [
                Text(
                  'I agree to subscribe to MediTrack Premium at ৳2.00/day +(VAT+SD+SC) on auto-renewal basis and accept the ',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    height: 1.3,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B736E),
                  ),
                ),
                GestureDetector(
                  onTap: _showTermsDialog,
                  child: Text(
                    'Terms & Conditions',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  ' and ',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B736E),
                  ),
                ),
                GestureDetector(
                  onTap: _showPrivacyDialog,
                  child: Text(
                    'Privacy Policy',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  '.',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B736E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for the dotted horizontal line
class _DottedLinePainter extends CustomPainter {
  final Color color;
  final double dotRadius;
  final double spacing;

  _DottedLinePainter({
    required this.color,
    this.dotRadius = 1.2,
    this.spacing = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    double startX = 0;
    final y = size.height / 2;
    while (startX < size.width) {
      canvas.drawCircle(Offset(startX, y), dotRadius, paint);
      startX += spacing;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.dotRadius != dotRadius ||
      oldDelegate.spacing != spacing;
}

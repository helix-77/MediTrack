import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/bdapps/bd_apps_service.dart';
import '../features/bdapps/subscription_offer_config.dart';
import '../logic/bd_mobile_validator.dart';
import '../services/entitlement_service.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/section_header.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';
import '../widgets/soft_text_field.dart';
import '../widgets/status_pill.dart';
import 'account_upgrade_screen.dart';

class SubscriptionOfferScreen extends StatefulWidget {
  const SubscriptionOfferScreen({super.key});

  @override
  State<SubscriptionOfferScreen> createState() =>
      _SubscriptionOfferScreenState();
}

class _SubscriptionOfferScreenState extends State<SubscriptionOfferScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _agreedToTerms = false;
  bool _otpSent = false;
  String? _detectedOperator;

  Timer? _resendTimer;
  int _resendSeconds = 60;
  bool _canResendOtp = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_onPhoneChanged);
    _loadExistingMobile();
  }

  void _onPhoneChanged() {
    final text = _phoneController.text.trim();
    final op = BdMobileValidator.getOperator(text);
    if (op != _detectedOperator) {
      setState(() {
        _detectedOperator = op;
      });
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendSeconds = 60;
      _canResendOtp = false;
    });

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() {
          _resendSeconds = 0;
          _canResendOtp = true;
        });
      } else {
        setState(() {
          _resendSeconds--;
        });
      }
    });
  }

  void _loadExistingMobile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) return;
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('profile')
          .doc('main')
          .get();
      if (doc.exists && mounted) {
        final mobile = doc.data()?['bdMobile'] as String?;
        if (mobile != null &&
            mobile.isNotEmpty &&
            _phoneController.text.isEmpty) {
          setState(() {
            _phoneController.text = mobile;
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.removeListener(_onPhoneChanged);
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showTermsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkDivider : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Terms & Conditions',
                    style: AppTypography.headingMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    SubscriptionOfferConfig.termsAndConditions,
                    style: AppTypography.bodySmall.copyWith(
                      height: 1.5,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SoftPrimaryButton(
                label: 'I Understand',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPrivacyDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkDivider : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Privacy Policy',
                    style: AppTypography.headingMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    SubscriptionOfferConfig.privacyPolicy,
                    style: AppTypography.bodySmall.copyWith(
                      height: 1.5,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SoftPrimaryButton(
                label: 'I Understand',
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
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

  Future<void> _persistSubscription(String mobile) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('profile')
          .doc('main')
          .set({
        'bdMobile': mobile,
        'subscriptionStatus': 'REGISTERED',
        'subscriptionVerifiedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Subscription profile save error: $e');
    }
  }

  void _sendOtp(BdAppsService bdService, EntitlementService entitlement) async {
    final phone = _phoneController.text.trim();
    final validationError = BdMobileValidator.validateRobiAirtel(phone);
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      final upgraded = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const AccountUpgradeScreen()),
      );
      if (upgraded != true &&
          (FirebaseAuth.instance.currentUser?.isAnonymous ?? true)) {
        return;
      }
    }

    final normalized = BdMobileValidator.normalize(phone);
    await _recordConsent(normalized);

    // Check BD Apps first: if this number is already an active subscriber
    final checkResult = await bdService.checkNumberBeforeOtp(
      mobileNumber: normalized,
    );
    if (!mounted) return;

    if (checkResult == BdNumberCheckResult.alreadyActive) {
      await _persistSubscription(normalized);
      entitlement.updateSubscribedState(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🎉 You are already a MediTrack Premium subscriber. Unlocking features...',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
      return;
    }

    final success = await bdService.sendOtp(mobileNumber: normalized);
    if (!mounted) return;

    if (success) {
      if (bdService.subscriptionStatus == 'REGISTERED') {
        await _persistSubscription(normalized);
        entitlement.updateSubscribedState(true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🎉 Your MediTrack Premium subscription is active! Unlocking features...',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _otpSent = true;
      });
      _startResendTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent via SMS! Please enter the 6-digit code.'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bdService.errorMessage ?? 'Failed to send OTP'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _verifyOtp(
    BdAppsService bdService,
    EntitlementService entitlement,
  ) async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty || otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the OTP received in your SMS'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final phone = _phoneController.text.trim();
    final normalized = BdMobileValidator.normalize(phone);

    final success = await bdService.verifyOtp(otp: otp);
    if (!mounted) return;

    if (success) {
      await _persistSubscription(normalized);
      entitlement.updateSubscribedState(true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 Congratulations! You are now MediTrack Premium.'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(bdService.errorMessage ?? 'OTP verification failed'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  IconData _getFeatureIcon(String? iconName) {
    switch (iconName) {
      case 'document_scanner':
        return Icons.document_scanner_rounded;
      case 'auto_awesome':
        return Icons.auto_awesome_rounded;
      case 'search':
        return Icons.search_rounded;
      case 'local_pharmacy':
        return Icons.local_pharmacy_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }

  Color _getFeatureAccentColor(int index) {
    switch (index % 4) {
      case 0:
        return const Color(0xFF3B82F6); // Blue
      case 1:
        return const Color(0xFF8B5CF6); // Purple
      case 2:
        return const Color(0xFF10B981); // Emerald
      case 3:
        return const Color(0xFFF59E0B); // Amber
      default:
        return AppColors.primaryBlue;
    }
  }

  String _getFeatureTag(int index) {
    switch (index % 4) {
      case 0:
        return 'Gemini 3.6 Flash';
      case 1:
        return 'Smart AI';
      case 2:
        return 'BD MRPs';
      case 3:
        return 'Live Maps';
      default:
        return 'Premium';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bdService = context.watch<BdAppsService>();
    final entitlement = context.watch<EntitlementService>();
    final isBusy =
        bdService.isSendingOtp ||
        bdService.isVerifyingOtp ||
        bdService.isRequestingSubscription ||
        bdService.isCheckingSubscription;

    final phoneText = _phoneController.text.trim();
    final isRobi = phoneText.startsWith('018') || phoneText.startsWith('+88018') || phoneText.startsWith('88018');
    final isAirtel = phoneText.startsWith('016') || phoneText.startsWith('+88016') || phoneText.startsWith('88016');

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        title: const Text('MediTrack Premium'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: SoftIconButton(
            icon: Icons.arrow_back_rounded,
            size: 40,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== PREMIUM HERO CARD ====================
            _buildHeroBanner(isDark),
            const SizedBox(height: 20),

            // ==================== SUPPORTED CARRIERS ====================
            _buildCarrierBar(isDark, isRobi, isAirtel),
            const SizedBox(height: 24),

            // ==================== INCLUDED FEATURES ====================
            const SectionHeader(
              title: 'Included Premium Features',
            ),
            const SizedBox(height: 4),
            _buildFeaturesList(isDark),
            const SizedBox(height: 24),

            // ==================== SUBSCRIPTION INPUT CARD ====================
            _buildSubscriptionCard(isDark, isBusy, bdService, entitlement),
            const SizedBox(height: 28),

            // // ==================== FAQ ACCORDION ====================
            // _buildFaqSection(isDark),
            // const SizedBox(height: 20),

          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: AppRadii.cardRadius,
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4F6BFF), // 0%
            Color(0xFF78A5FF), // 100%
          ],
          stops: [0.0, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F6BFF)
                .withValues(alpha: isDark ? 0.35 : 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: AppRadii.cardRadius,
        child: Stack(
          children: [
            // Background ambient circles for subtle depth
            Positioned(
              right: -24,
              top: -24,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -30,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Tag Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: AppRadii.pillRadius,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.workspace_premium_rounded,
                              color: Color(0xFFFDE047), // Gold star
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'PRO MEMBERSHIP',
                              style: AppTypography.pillText.copyWith(
                                color: Colors.white,
                                letterSpacing: 0.5,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: AppRadii.pillRadius,
                        ),
                        child: Text(
                          'Direct Carrier Billing',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Headline
                  Text(
                    SubscriptionOfferConfig.headline,
                    style: AppTypography.headingLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 22,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    SubscriptionOfferConfig.subHeadline,
                    style: AppTypography.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.35,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Price Card container
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  SubscriptionOfferConfig.formattedPrice,
                                  style: AppTypography.displayLarge.copyWith(
                                    fontSize: 30,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Text(
                                  ' / day',
                                  style: AppTypography.headingSmall.copyWith(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '+ ${SubscriptionOfferConfig.taxSuffix} applicable.',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.25),
                            borderRadius: AppRadii.pillRadius,
                            border: Border.all(
                              color: const Color(0xFF10B981).withValues(alpha: 0.6),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: Color(0xFF6EE7B7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Cancel Anytime',
                                style: AppTypography.caption.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarrierBar(bool isDark, bool isRobi, bool isAirtel) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: AppRadii.standardRadius,
        boxShadow: isDark ? AppShadows.darkCard : AppShadows.subtle,
        border: Border.all(
          color: isDark ? AppColors.darkDivider : AppColors.borderLight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sim_card_rounded,
                size: 20,
                color: isDark ? AppColors.darkTextSecondary : AppColors.primaryBlue,
              ),
              const SizedBox(width: 10),
              Text(
                'Supported Carriers:',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCarrierChip(
                label: 'Robi (018)',
                isActive: isRobi,
                activeColor: const Color(0xFFDC2626),
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildCarrierChip(
                label: 'Airtel (016)',
                isActive: isAirtel,
                activeColor: const Color(0xFFE11D48),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCarrierChip({
    required String label,
    required bool isActive,
    required Color activeColor,
    required bool isDark,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? activeColor.withValues(alpha: 0.15)
            : (isDark ? AppColors.darkSurfaceElevated : AppColors.borderLight),
        borderRadius: AppRadii.pillRadius,
        border: Border.all(
          color: isActive
              ? activeColor
              : (isDark ? AppColors.darkDivider : AppColors.border),
          width: isActive ? 1.4 : 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) ...[
            Icon(Icons.check_circle_rounded, size: 12, color: activeColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTypography.pillText.copyWith(
              fontSize: 11,
              color: isActive
                  ? activeColor
                  : (isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary),
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesList(bool isDark) {
    return Column(
      children: List.generate(SubscriptionOfferConfig.features.length, (index) {
        final feat = SubscriptionOfferConfig.features[index];
        final accent = _getFeatureAccentColor(index);
        final iconData = _getFeatureIcon(feat['icon']);
        final tag = _getFeatureTag(index);

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: SoftSurface(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            borderRadius: AppRadii.standardRadius,
            color: isDark ? AppColors.darkSurface : AppColors.surface,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.25),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      iconData,
                      color: accent,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              feat['title']!,
                              style: AppTypography.headingSmall.copyWith(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tag,
                              style: AppTypography.caption.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        feat['subtitle'] ?? '',
                        style: AppTypography.bodySmall.copyWith(
                          fontSize: 12,
                          height: 1.35,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSubscriptionCard(
    bool isDark,
    bool isBusy,
    BdAppsService bdService,
    EntitlementService entitlement,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Subscribe with Mobile Number',
          trailing: StatusPill(
            label: _otpSent ? 'STEP 2 OF 2' : 'STEP 1 OF 2',
            type: _otpSent ? PillType.success : PillType.primary,
          ),
        ),
        const SizedBox(height: 8),
        SoftSurface(
          padding: const EdgeInsets.all(20),
          borderRadius: AppRadii.cardRadius,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: _otpSent
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: _buildPhoneStep(isDark),
                secondChild: _buildOtpStep(isDark, bdService, entitlement),
              ),
              const SizedBox(height: 18),

              // Consent Checkbox with T&C / Privacy links
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _agreedToTerms,
                      activeColor: AppColors.primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) =>
                          setState(() => _agreedToTerms = val ?? false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'I agree to subscribe to MediTrack Premium at ৳2.99/day ${SubscriptionOfferConfig.taxSuffix} and accept the terms below.',
                          style: AppTypography.caption.copyWith(
                            height: 1.35,
                            fontSize: 11.5,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            GestureDetector(
                              onTap: _showTermsDialog,
                              child: Text(
                                'Terms & Conditions',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            Text(
                              'and',
                              style: AppTypography.caption.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                            GestureDetector(
                              onTap: _showPrivacyDialog,
                              child: Text(
                                'Privacy Policy',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action CTA Button
              if (!_otpSent)
                SoftPrimaryButton(
                  label: 'Send Activation OTP',
                  icon: Icons.sms_outlined,
                  isLoading: isBusy,
                  onPressed: _agreedToTerms && !isBusy
                      ? () => _sendOtp(bdService, entitlement)
                      : null,
                )
              else
                SoftPrimaryButton(
                  label: 'Verify OTP & Activate Premium',
                  icon: Icons.verified_user_rounded,
                  backgroundColor: const Color(0xFF10B981),
                  isLoading: isBusy,
                  onPressed: _agreedToTerms && !isBusy
                      ? () => _verifyOtp(bdService, entitlement)
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneStep(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftTextField(
          controller: _phoneController,
          labelText: 'Robi / Airtel Phone Number',
          hintText: '018XXXXXXXX or 016XXXXXXXX',
          keyboardType: TextInputType.phone,
          enabled: !_otpSent,
          prefixIcon: const Icon(
            Icons.phone_android_rounded,
            color: AppColors.primaryBlue,
            size: 20,
          ),
        ),
        if (_detectedOperator != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 14,
                color: _detectedOperator == 'Robi' || _detectedOperator == 'Airtel'
                    ? AppColors.success
                    : AppColors.warning,
              ),
              const SizedBox(width: 6),
              Text(
                'Detected Operator: $_detectedOperator',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: _detectedOperator == 'Robi' || _detectedOperator == 'Airtel'
                      ? AppColors.success
                      : AppColors.warning,
                ),
              ),
            ],
          ),
        ],
        // const SizedBox(height: 6),
        // Text(
        //   'A 6-digit verification code will be sent to this number via BD Apps SMS.',
        //   style: AppTypography.caption.copyWith(
        //     color: isDark
        //         ? AppColors.darkTextSecondary
        //         : AppColors.textSecondary,
        //   ),
        // ),
      ],
    );
  }

  Widget _buildOtpStep(
    bool isDark,
    BdAppsService bdService,
    EntitlementService entitlement,
  ) {
    final phone = _phoneController.text.trim();
    final masked = BdMobileValidator.maskMobile(phone);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceElevated : AppColors.primaryBlueLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.mark_email_read_rounded,
                color: AppColors.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'OTP sent to $masked',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _otpSent = false;
                    _otpController.clear();
                  });
                },
                child: Text(
                  'Change',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SoftTextField(
          controller: _otpController,
          labelText: '6-Digit OTP Code',
          hintText: 'Enter code from SMS',
          keyboardType: TextInputType.number,
          prefixIcon: const Icon(
            Icons.lock_clock_outlined,
            color: AppColors.primaryBlue,
            size: 20,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Didn\'t receive code?',
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            if (_canResendOtp)
              GestureDetector(
                onTap: () => _sendOtp(bdService, entitlement),
                child: Text(
                  'Resend OTP',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              )
            else
              Text(
                'Resend in ${_resendSeconds}s',
                style: AppTypography.caption.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }

  // Widget _buildFaqSection(bool isDark) {
  //   final faqs = [
  //     {
  //       'q': 'How does carrier billing work?',
  //       'a':
  //           'The daily fee of ৳2.99 (+VAT/taxes) is automatically charged directly from your Robi or Airtel mobile account balance. No credit card or bank account is required.',
  //     },
  //     {
  //       'q': 'Can I cancel my subscription at any time?',
  //       'a':
  //           'Yes, absolutely. You can cancel instantly with zero penalty at any time from your Profile tab or by dialing *213# on your Robi/Airtel phone.',
  //     },
  //     {
  //       'q': 'What happens if my SIM balance is low?',
  //       'a':
  //           'If your SIM balance is insufficient, your premium access will pause until balance is recharged. There are no overdraft penalties or hidden fees.',
  //     },
  //     {
  //       'q': 'Is my medical data and prescriptions safe?',
  //       'a':
  //           'Your medical information and scanned prescriptions are stored securely under your private Firebase account with user-scoped security rules. We never share your health records with any third party.',
  //     },
  //   ];

  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       const SectionHeader(
  //         title: 'Frequently Asked Questions',
  //       ),
  //       const SizedBox(height: 6),
  //       ...faqs.map(
  //         (faq) => _FaqCard(
  //           question: faq['q']!,
  //           answer: faq['a']!,
  //           isDark: isDark,
  //         ),
  //       ),
  //     ],
  //   );
  // }
}

class _FaqCard extends StatefulWidget {
  final String question;
  final String answer;
  final bool isDark;

  const _FaqCard({
    required this.question,
    required this.answer,
    required this.isDark,
  });

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: widget.isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: AppRadii.standardRadius,
        border: Border.all(
          color: widget.isDark ? AppColors.darkDivider : AppColors.borderLight,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: AppRadii.standardRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: AppTypography.headingSmall.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: widget.isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    widget.answer,
                    style: AppTypography.bodySmall.copyWith(
                      height: 1.45,
                      color: widget.isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


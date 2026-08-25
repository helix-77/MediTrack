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

  @override
  void initState() {
    super.initState();
    _loadExistingMobile();
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
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Text('Terms & Conditions', style: AppTypography.headingMedium),
        content: SingleChildScrollView(
          child: Text(
            SubscriptionOfferConfig.termsAndConditions,
            style: AppTypography.caption.copyWith(height: 1.4),
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
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Text('Privacy Policy', style: AppTypography.headingMedium),
        content: SingleChildScrollView(
          child: Text(
            SubscriptionOfferConfig.privacyPolicy,
            style: AppTypography.caption.copyWith(height: 1.4),
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        title: const Text('MediTrack Premium'),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pro Header Card
            SoftSurface(
              padding: const EdgeInsets.all(22),
              borderRadius: AppRadii.cardRadius,
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryBlueLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: AppColors.primaryBlue,
                          size: 26,
                        ),
                      ),
                      const StatusPill(
                        label: 'DIRECT CARRIER BILLING',
                        type: PillType.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    SubscriptionOfferConfig.headline,
                    style: AppTypography.headingLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    SubscriptionOfferConfig.subHeadline,
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        SubscriptionOfferConfig.formattedPrice,
                        style: AppTypography.displayLarge.copyWith(
                          fontSize: 32,
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        ' / day',
                        style: AppTypography.headingSmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '+ ${SubscriptionOfferConfig.taxSuffix} applicable. ${SubscriptionOfferConfig.autoRenewalDisclosure}',
                    style: AppTypography.caption.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Carrier Badges
            Row(
              children: [
                Text(
                  'Supported Carriers:',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                const StatusPill(label: 'Robi (018)', type: PillType.primary),
                const SizedBox(width: 6),
                const StatusPill(label: 'Airtel (016)', type: PillType.pink),
              ],
            ),
            const SizedBox(height: 20),

            // Features Checklist
            const SectionHeader(
              title: 'Included Premium Features',
              subtitle: 'Everything you need for complete medication adherence',
            ),
            ...SubscriptionOfferConfig.features.map(
              (feat) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: SoftSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              feat['title']!,
                              style: AppTypography.headingSmall.copyWith(
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              feat['subtitle'] ?? '',
                              style: AppTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Subscription Flow Form
            const SectionHeader(
              title: 'Subscribe with Mobile Number',
              subtitle: 'Fee charged directly from your mobile balance',
            ),
            SoftSurface(
              padding: const EdgeInsets.all(18),
              child: Column(
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
                  if (_otpSent) ...[
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
                  ],
                  const SizedBox(height: 14),

                  // Consent Checkbox with T&C / Privacy links
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _agreedToTerms,
                        activeColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) =>
                            setState(() => _agreedToTerms = val ?? false),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'I agree to subscribe to MediTrack Premium at ৳2.00/day ${SubscriptionOfferConfig.taxSuffix} and accept the terms below.',
                                style: AppTypography.caption.copyWith(
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
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
                                  Text(' and ', style: AppTypography.caption),
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Action CTA
                  if (!_otpSent)
                    SoftPrimaryButton(
                      label: 'Send Activation OTP',
                      isLoading: isBusy,
                      onPressed: _agreedToTerms && !isBusy
                          ? () => _sendOtp(bdService, entitlement)
                          : null,
                    )
                  else
                    SoftPrimaryButton(
                      label: 'Verify OTP & Activate Premium',
                      isLoading: isBusy,
                      onPressed: _agreedToTerms && !isBusy
                          ? () => _verifyOtp(bdService, entitlement)
                          : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}

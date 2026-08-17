import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/bdapps/bd_apps_service.dart';
import '../features/bdapps/subscription_offer_config.dart';
import '../logic/bd_mobile_validator.dart';
import '../services/entitlement_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import 'account_upgrade_screen.dart';

class SubscriptionOfferScreen extends StatefulWidget {
  const SubscriptionOfferScreen({super.key});

  @override
  State<SubscriptionOfferScreen> createState() => _SubscriptionOfferScreenState();
}

class _SubscriptionOfferScreenState extends State<SubscriptionOfferScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  bool _hasConsented = false;
  bool _useOtpFallback = false;
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

  Future<void> _handleSubscribe() async {
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
    final entitlementService = context.read<EntitlementService>();

    final success = await bdService.requestSubscription(mobileNumber: normalized);

    if (success && mounted) {
      entitlementService.updateSubscribedState(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Welcome to MediTrack Premium!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
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
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP sent to $normalized via SMS. Enter code below.'),
          backgroundColor: AppColors.success,
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('MediTrack Premium'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Consumer<BdAppsService>(
        builder: (context, bdService, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroCard(),
                const SizedBox(height: 16),
                _buildCarrierBadges(),
                const SizedBox(height: 20),
                _buildFeaturesList(),
                const SizedBox(height: 20),
                if (!_useOtpFallback)
                  _buildDirectCarrierSection(bdService)
                else
                  _buildOtpSection(bdService),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2E3D34),
            AppColors.primaryGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.stars, color: AppColors.accentPinkLight, size: 16),
                    SizedBox(width: 6),
                    Text(
                      'PREMIUM PASS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.auto_awesome,
                color: AppColors.accentPinkLight,
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            SubscriptionOfferConfig.headline,
            style: AppTypography.headingLarge.copyWith(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            SubscriptionOfferConfig.subHeadline,
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                SubscriptionOfferConfig.formattedPrice,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ day ${SubscriptionOfferConfig.taxSuffix}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            SubscriptionOfferConfig.autoRenewalDisclosure,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarrierBadges() {
    return Row(
      children: [
        const Text(
          'Supported Carriers:',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 10),
        _buildChip('Robi (018)', const Color(0xFFE31B23)),
        const SizedBox(width: 8),
        _buildChip('Airtel (016)', const Color(0xFFED1C24)),
      ],
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What you get with Premium',
            style: AppTypography.headingSmall.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 12),
          ...SubscriptionOfferConfig.features.map((f) {
            final iconData = switch (f['icon']) {
              'document_scanner' => Icons.document_scanner_rounded,
              'auto_awesome' => Icons.auto_awesome,
              'search' => Icons.manage_search,
              'local_pharmacy' => Icons.local_pharmacy,
              _ => Icons.check_circle_outline,
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreenLight.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, color: AppColors.primaryGreen, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f['title']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          f['subtitle']!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDirectCarrierSection(BdAppsService service) {
    final state = service.subscriptionState;
    final isBusy = service.isRequestingSubscription;
    final isPending = state == SubscriptionState.pending;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPending ? AppColors.primaryGreen : AppColors.divider,
          width: isPending ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Instant 1-Click Subscription',
            style: AppTypography.headingSmall.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enter your Robi or Airtel number to receive a confirmation prompt on your phone.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _mobileController,
            enabled: !isBusy,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Robi / Airtel Number',
              hintText: '018XXXXXXXX or 016XXXXXXXX',
              prefixIcon: const Icon(Icons.phone_android, color: AppColors.primaryGreen),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              errorText: _inlineError,
            ),
          ),
          const SizedBox(height: 12),

          // Consent Checkbox
          _buildConsentCheckbox(),

          if (isPending) ...[
            const SizedBox(height: 16),
            _buildPendingStateBox(service),
          ],

          if (service.errorMessage != null && !isPending) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      service.errorMessage!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: (!_hasConsented || isBusy) ? null : _handleSubscribe,
              child: isBusy
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isPending
                              ? 'Waiting for carrier confirmation...'
                              : 'Connecting to carrier...',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  : Text(
                      'Subscribe for ${SubscriptionOfferConfig.formattedPrice}/day',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.sms_outlined, size: 16),
              label: const Text(
                'Prefer SMS OTP verification instead? Tap here',
                style: TextStyle(fontSize: 12),
              ),
              onPressed: isBusy ? null : () => setState(() => _useOtpFallback = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingStateBox(BdAppsService service) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentPinkLight.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGreenLight),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Check your phone screen!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'A carrier confirmation prompt has been sent to ${BdMobileValidator.maskMobile(_mobileController.text)}.\nPlease press 1 or reply YES to confirm.',
                      style: const TextStyle(fontSize: 11, height: 1.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (service.pollingSecondsRemaining > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Auto-checking: ${service.pollingSecondsRemaining}s',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOtpSection(BdAppsService service) {
    final hasPendingOtp = service.pendingReferenceNo != null;
    final isBusy = service.isSendingOtp || service.isVerifyingOtp;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subscribe via SMS OTP',
                style: AppTypography.headingSmall.copyWith(fontSize: 15),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Back to 1-Click',
                onPressed: () => setState(() => _useOtpFallback = false),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _mobileController,
            enabled: !isBusy,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Robi / Airtel Number',
              hintText: '018XXXXXXXX',
              prefixIcon: const Icon(Icons.phone_android),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              errorText: _inlineError,
            ),
          ),
          const SizedBox(height: 12),
          _buildConsentCheckbox(),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
              ),
              icon: service.isSendingOtp
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sms, size: 18),
              label: Text(
                service.isSendingOtp ? 'Sending OTP...' : 'Send SMS OTP',
              ),
              onPressed: (!_hasConsented || isBusy) ? null : _handleSendOtp,
            ),
          ),

          if (hasPendingOtp) ...[
            const SizedBox(height: 16),
            const Divider(),
            const Text(
              'Enter Received 6-Digit OTP Code',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'OTP Code',
                hintText: '123456',
                prefixIcon: const Icon(Icons.pin),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                icon: service.isVerifyingOtp
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                  service.isVerifyingOtp ? 'Verifying...' : 'Verify OTP & Activate',
                ),
                onPressed: isBusy ? null : _handleVerifyOtp,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConsentCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _hasConsented,
          activeColor: AppColors.primaryGreen,
          onChanged: (val) {
            setState(() {
              _hasConsented = val ?? false;
            });
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              children: [
                const Text(
                  'I agree to subscribe to MediTrack Premium at ৳2.78/day +(VAT+SD+SC) on auto-renewal basis and accept the ',
                  style: TextStyle(fontSize: 11, height: 1.3),
                ),
                GestureDetector(
                  onTap: _showTermsDialog,
                  child: const Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const Text(' and ', style: TextStyle(fontSize: 11)),
                GestureDetector(
                  onTap: _showPrivacyDialog,
                  child: const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const Text('.', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

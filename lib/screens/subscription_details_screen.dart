import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../features/bdapps/bd_apps_service.dart';
import '../features/bdapps/subscription_offer_config.dart';
import '../logic/bd_mobile_validator.dart';
import '../models/user_profile.dart';
import '../services/entitlement_service.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_modal_sheet.dart';
import '../widgets/soft_surface.dart';
import '../widgets/status_pill.dart';
import 'subscription_offer_screen.dart';

/// Screen displaying the subscriber's active MediTrack Premium subscription,
/// plan details, live carrier verification status, daily usage meters,
/// and comprehensive cancellation options (in-app, SMS, and USSD).
class SubscriptionDetailsScreen extends StatefulWidget {
  final UserProfile? profile;

  const SubscriptionDetailsScreen({
    super.key,
    this.profile,
  });

  @override
  State<SubscriptionDetailsScreen> createState() =>
      _SubscriptionDetailsScreenState();
}

class _SubscriptionDetailsScreenState extends State<SubscriptionDetailsScreen> {
  bool _isRefreshing = false;
  bool _isCancelling = false;

  Future<void> _refreshStatus() async {
    setState(() => _isRefreshing = true);
    final bdService = context.read<BdAppsService>();
    final entitlement = context.read<EntitlementService>();

    final phone = widget.profile?.bdMobile ?? bdService.bdMobile;
    if (phone != null && phone.isNotEmpty) {
      bdService.updateBdMobile(phone);
    }

    await Future.wait([
      bdService.refreshSubscriptionStatus(),
      entitlement.refreshEntitlement(forceCarrierCheck: true),
    ]);

    if (mounted) {
      setState(() => _isRefreshing = false);
      final isSubscribed = entitlement.isSubscribed || bdService.isRegistered;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSubscribed
                ? '✅ Carrier subscription verified active.'
                : 'ℹ️ Subscription status: ${bdService.subscriptionStatus ?? "Inactive"}',
          ),
          backgroundColor:
              isSubscribed ? AppColors.success : AppColors.textSecondary,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleInAppCancellation() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showAppModalBottomSheet<bool>(
      context: context,
      builder: (modalContext) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Danger Header icon & title
            Row(
              children: [
                const Icon(
                  Icons.heart_broken_rounded,
                  color: AppColors.danger,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cancel Subscription?',
                        style: AppTypography.headingMedium.copyWith(
                          fontSize: 17,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Do you really want to unsubscribe from Premium?',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
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
            const SizedBox(height: 18),

            // Information summary card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBackground
                    : AppColors.primaryBlueLight.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  _buildModalImpactRow(
                    isDark: isDark,
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: AppColors.success,
                    title: 'Immediate Stop of Charges',
                    desc: 'Daily ৳2.78 carrier billing stops right away.',
                  ),
                  const SizedBox(height: 10),
                  _buildModalImpactRow(
                    isDark: isDark,
                    icon: Icons.lock_outline_rounded,
                    iconColor: AppColors.danger,
                    title: 'Locked Premium Features',
                    desc: 'AI Prescription OCR and Health Assistant will be locked.',
                  ),
                  const SizedBox(height: 10),
                  _buildModalImpactRow(
                    isDark: isDark,
                    icon: Icons.health_and_safety_outlined,
                    iconColor: AppColors.primaryBlue,
                    title: 'Free Core Features Stay Safe',
                    desc: 'Pill alarms, schedules, and prescription vault remain free forever.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Dual CTA Buttons
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(modalContext, true),
                    child: Text(
                      'Yes, Unsubscribe',
                      style: AppTypography.buttonText.copyWith(
                        fontSize: 13,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: SoftPrimaryButton(
                    label: 'Keep Subscription',
                    height: 46,
                    backgroundColor: AppColors.primaryBlue,
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.pop(modalContext, false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    final bdService = context.read<BdAppsService>();
    final entitlement = context.read<EntitlementService>();
    final messenger = ScaffoldMessenger.of(context);

    final success = await bdService.unsubscribe();

    if (mounted) {
      setState(() => _isCancelling = false);
      if (success) {
        await entitlement.recordUnsubscribed(userId: widget.profile?.uid);

        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Subscription successfully cancelled. Daily charges have stopped.',
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        _showCarrierCancellationSheet(bdService.errorMessage);
      }
    }
  }

  Future<void> _showCarrierCancellationSheet(String? reason) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entitlement = context.read<EntitlementService>();
    final messenger = ScaffoldMessenger.of(context);

    await showAppModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppColors.warning,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Carrier Direct Confirmation Needed',
                        style: AppTypography.headingMedium.copyWith(
                          fontSize: 16,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Robi / Airtel carrier privacy protection',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBackground
                    : AppColors.warningLight.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                'Due to carrier user privacy rules on your SIM, automated 3rd-party unsubscription is restricted by BDApps. To guarantee that daily billing stops immediately, please cancel directly through your carrier using SMS or USSD:',
                style: AppTypography.bodySmall.copyWith(
                  height: 1.45,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 18),
            // Carrier Action 1: SMS
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                side: BorderSide(
                  color: isDark
                      ? AppColors.darkBorder
                      : AppColors.primaryBlue.withValues(alpha: 0.5),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(sheetContext);
                _launchSms();
              },
              icon: const Icon(Icons.sms_rounded,
                  size: 20, color: AppColors.primaryBlue),
              label: Text(
                'Send SMS "STOP meditrack" to 21213',
                style: AppTypography.buttonText.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Carrier Action 2: USSD
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                side: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(sheetContext);
                _launchUssd();
              },
              icon: const Icon(Icons.dialpad_rounded, size: 20),
              label: Text(
                'Dial *213# on your phone',
                style: AppTypography.buttonText.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // Carrier Action 3: Sync In-App
            TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                Navigator.pop(sheetContext);
                await entitlement.recordUnsubscribed(userId: widget.profile?.uid);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      '✅ In-app status synced to Free Tier. Carrier charges will stop once processed.',
                    ),
                    backgroundColor: AppColors.success,
                    duration: Duration(seconds: 4),
                  ),
                );
              },
              icon: const Icon(Icons.sync_rounded,
                  size: 18, color: AppColors.textSecondary),
              label: Text(
                'I Already Cancelled with Carrier (Sync In-App)',
                style: AppTypography.caption.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchSms() async {
    final uri = Uri.parse('sms:21213?body=STOP%20meditrack');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(const ClipboardData(text: 'STOP meditrack'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Copied "STOP meditrack" to clipboard. Send it to 21213 in your SMS app.',
              ),
              backgroundColor: AppColors.info,
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: 'STOP meditrack'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Copied "STOP meditrack" to clipboard. Send it to 21213 in your SMS app.',
            ),
            backgroundColor: AppColors.info,
          ),
        );
      }
    }
  }

  Future<void> _launchUssd() async {
    final uri = Uri.parse('tel:*213%23');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _copyToClipboard(
          '*213#',
          'Copied "*213#" to clipboard. Dial it on your phone.',
        );
      }
    } catch (_) {
      _copyToClipboard(
        '*213#',
        'Copied "*213#" to clipboard. Dial it on your phone.',
      );
    }
  }



  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.info,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entitlement = context.watch<EntitlementService>();
    final bdService = context.watch<BdAppsService>();

    final isSubscribed = entitlement.isSubscribed || bdService.isRegistered;
    final phone = widget.profile?.bdMobile ?? bdService.bdMobile;
    final operator = phone != null ? BdMobileValidator.getOperator(phone) : null;
    final verifiedDate = entitlement.lastVerifiedAt ??
        widget.profile?.subscriptionVerifiedAt ??
        DateTime.now();
    final formattedVerified =
        DateFormat('MMM d, yyyy • h:mm a').format(verifiedDate);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          'Subscription Details',
          style: AppTypography.headingSmall.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Refresh Status',
            onPressed: _isRefreshing ? null : _refreshStatus,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryBlue,
                      ),
                    ),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HERO ACTIVE STATUS CARD
            _buildHeroStatusCard(
              isDark: isDark,
              isSubscribed: isSubscribed,
              phone: phone,
              operator: operator,
              formattedVerified: formattedVerified,
            ),
            const SizedBox(height: 20),

            // 2. DAILY QUOTA & USAGE METERS
            if (isSubscribed) ...[
              _buildDailyUsageSection(isDark, entitlement),
              const SizedBox(height: 20),
            ],

            // 3. INCLUDED PREMIUM PRIVILEGES (Bento Tiles)
            _buildPrivilegesSection(isDark),
            const SizedBox(height: 24),

            // 4. CANCELLATION & MANAGEMENT SECTION
            if (isSubscribed) ...[
              _buildCancellationHeader(isDark),
              const SizedBox(height: 14),
              _buildInAppCancelCard(isDark),
              const SizedBox(height: 14),
              _buildSmsCancelCard(isDark),
              const SizedBox(height: 14),
              _buildUssdCancelCard(isDark),
              const SizedBox(height: 24),
            ] else ...[
              _buildInactiveBanner(isDark),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStatusCard({
    required bool isDark,
    required bool isSubscribed,
    required String? phone,
    required String? operator,
    required String formattedVerified,
  }) {
    return SoftSurface(
      padding: const EdgeInsets.all(20),
      borderRadius: AppRadii.cardRadius,
      color: isSubscribed
          ? (isDark
              ? const Color(0xFF064E3B).withValues(alpha: 0.35)
              : AppColors.successLight)
          : (isDark
              ? const Color(0xFF450A0A).withValues(alpha: 0.35)
              : AppColors.dangerLight),
      borderColor: isSubscribed
          ? (isDark
              ? const Color(0xFF059669).withValues(alpha: 0.5)
              : const Color(0xFFA7F3D0))
          : (isDark
              ? const Color(0xFFDC2626).withValues(alpha: 0.4)
              : const Color(0xFFFECACA)),
      borderWidth: 1.2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSubscribed
                          ? (isDark
                              ? const Color(0xFF059669).withValues(alpha: 0.4)
                              : AppColors.success.withValues(alpha: 0.2))
                          : (isDark
                              ? const Color(0xFFDC2626).withValues(alpha: 0.3)
                              : AppColors.danger.withValues(alpha: 0.15)),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSubscribed
                          ? Icons.verified_rounded
                          : Icons.cancel_rounded,
                      color:
                          isSubscribed ? AppColors.success : AppColors.danger,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isSubscribed ? 'MediTrack Premium' : 'Free Tier (Inactive)',
                    style: AppTypography.headingMedium.copyWith(
                      fontSize: 16,
                      color: isSubscribed
                          ? (isDark
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFF065F46))
                          : (isDark
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFF991B1B)),
                    ),
                  ),
                ],
              ),
              StatusPill(
                label: isSubscribed ? 'ACTIVE' : 'INACTIVE',
                type: isSubscribed ? PillType.success : PillType.neutral,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Price & Cycle Info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SUBSCRIPTION RATE',
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${SubscriptionOfferConfig.formattedPrice} / day',
                      style: AppTypography.headingSmall.copyWith(
                        fontSize: 15,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      SubscriptionOfferConfig.taxSuffix,
                      style: AppTypography.caption.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LINKED OPERATOR',
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone != null && phone.isNotEmpty
                          ? BdMobileValidator.maskMobile(phone)
                          : 'Not linked',
                      style: AppTypography.headingSmall.copyWith(
                        fontSize: 14.5,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      operator != null
                          ? '$operator (BDApps)'
                          : 'Robi / Airtel Carrier',
                      style: AppTypography.caption.copyWith(fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Verified row
          Row(
            children: [
              Icon(
                Icons.sync_rounded,
                size: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Last Verified: $formattedVerified',
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyUsageSection(
    bool isDark,
    EntitlementService entitlement,
  ) {
    final aiUsed = entitlement.aiMessagesToday;
    final aiMax = 50;
    final aiProgress = (aiUsed / aiMax).clamp(0.0, 1.0);

    final scanUsed = entitlement.prescriptionScansToday;
    final scanMax = 20;
    final scanProgress = (scanUsed / scanMax).clamp(0.0, 1.0);

    return SoftSurface(
      padding: const EdgeInsets.all(18),
      borderRadius: AppRadii.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's AI Quota & Usage",
                style: AppTypography.headingSmall.copyWith(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              Text(
                'Resets midnight',
                style: AppTypography.caption.copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // AI Chat Usage Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 15,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'AI Assistant Messages',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '$aiUsed / $aiMax',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: aiProgress > 0.8
                      ? AppColors.warning
                      : (isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: aiProgress,
              minHeight: 6,
              backgroundColor: isDark
                  ? AppColors.darkDivider
                  : AppColors.primaryBlueLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                aiProgress > 0.8 ? AppColors.warning : AppColors.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Prescription Scan Usage Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.document_scanner_rounded,
                    size: 15,
                    color: AppColors.accentPink,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Prescription Scans',
                    style: AppTypography.bodyMedium.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                '$scanUsed / $scanMax',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: scanProgress > 0.8
                      ? AppColors.warning
                      : (isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: scanProgress,
              minHeight: 6,
              backgroundColor: isDark
                  ? AppColors.darkDivider
                  : AppColors.accentPinkLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                scanProgress > 0.8 ? AppColors.warning : AppColors.accentPink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivilegesSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Included Premium Privileges',
          style: AppTypography.headingSmall.copyWith(
            fontSize: 14,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.45,
          children: [
            _buildPrivilegeCard(
              isDark: isDark,
              icon: Icons.document_scanner_rounded,
              color: AppColors.primaryBlue,
              title: 'AI Prescription OCR',
              subtitle: 'Multi-page OpenRouter extraction',
            ),
            _buildPrivilegeCard(
              isDark: isDark,
              icon: Icons.auto_awesome_rounded,
              color: AppColors.accentPink,
              title: 'Smart Assistant',
              subtitle: 'Dosage & health consultation',
            ),
            _buildPrivilegeCard(
              isDark: isDark,
              icon: Icons.search_rounded,
              color: AppColors.accentOrange,
              title: 'Price & Generics',
              subtitle: 'Bangladesh MRP price finder',
            ),
            _buildPrivilegeCard(
              isDark: isDark,
              icon: Icons.local_pharmacy_rounded,
              color: AppColors.success,
              title: 'Nearby Pharmacies',
              subtitle: 'Live GPS open locator & route',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrivilegeCard({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return SoftSurface(
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTypography.headingSmall.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: AppTypography.caption.copyWith(
              fontSize: 10,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCancellationHeader(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cancel Subscription',
          style: AppTypography.headingSmall.copyWith(
            fontSize: 14,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildInAppCancelCard(bool isDark) {
    return SoftSurface(
      padding: const EdgeInsets.all(16),
      borderRadius: AppRadii.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.phonelink_erase_rounded,
                color: AppColors.danger,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Method 1: Instant In-App Cancel',
                  style: AppTypography.headingSmall.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _isCancelling ? null : _handleInAppCancellation,
            icon: _isCancelling
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.danger),
                    ),
                  )
                : const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.danger,
                  ),
            label: Text(
              'Cancel Subscription',
              style: AppTypography.buttonText.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmsCancelCard(bool isDark) {
    const smsKeyword = 'STOP meditrack';
    const smsShortCode = '21213';

    return SoftSurface(
      padding: const EdgeInsets.all(16),
      borderRadius: AppRadii.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.sms_rounded,
                color: AppColors.primaryBlue,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Method 2: Cancel via SMS',
                  style: AppTypography.headingSmall.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Code pill container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBackground
                  : AppColors.primaryBlueLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TYPE IN SMS:',
                      style: AppTypography.caption.copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$smsKeyword to $smsShortCode',
                      style: AppTypography.headingSmall.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    // side: BorderSide(
                    //   color: isDark
                    //       ? AppColors.darkBorder
                    //       : AppColors.primaryBlue.withValues(alpha: 0.4),
                    // ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _launchSms,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open SMS App'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    // side: BorderSide(
                    //   color: isDark
                    //       ? AppColors.darkBorder
                    //       : AppColors.border,
                    // ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _copyToClipboard(
                    smsKeyword,
                    'Copied "$smsKeyword" to clipboard',
                  ),
                  icon: const Icon(Icons.content_copy_rounded, size: 16),
                  label: const Text('Copy Text'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUssdCancelCard(bool isDark) {
    const ussdCode = '*213#';

    return SoftSurface(
      padding: const EdgeInsets.all(16),
      borderRadius: AppRadii.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.dialpad_rounded,
                color: AppColors.accentOrange,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Method 3: Cancel via USSD (*213#)',
                  style: AppTypography.headingSmall.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBackground
                  : AppColors.accentOrangeLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DIAL USSD CODE:',
                      style: AppTypography.caption.copyWith(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$ussdCode (Robi / Airtel)',
                      style: AppTypography.headingSmall.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _launchUssd,
                  icon: const Icon(Icons.call_rounded, size: 16),
                  label: const Text('Dial *213#'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => _copyToClipboard(
                    ussdCode,
                    'Copied "$ussdCode" to clipboard',
                  ),
                  icon: const Icon(Icons.content_copy_rounded, size: 16),
                  label: const Text('Copy Code'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveBanner(bool isDark) {
    return SoftSurface(
      padding: const EdgeInsets.all(18),
      borderRadius: AppRadii.cardRadius,
      child: Column(
        children: [
          const Icon(
            Icons.workspace_premium_outlined,
            size: 36,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(height: 10),
          Text(
            'Your Subscription is Currently Inactive',
            style: AppTypography.headingSmall.copyWith(
              fontSize: 15,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Upgrade to MediTrack Premium for ৳2.78/day via Robi / Airtel carrier billing to unlock full AI and OCR powers.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          SoftPrimaryButton(
            label: 'Upgrade to Premium',
            icon: Icons.bolt_rounded,
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const SubscriptionOfferScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }



  Widget _buildModalImpactRow({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                desc,
                style: AppTypography.caption.copyWith(
                  fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

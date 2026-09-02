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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.danger,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cancel Subscription?',
                style: AppTypography.headingSmall.copyWith(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel MediTrack Premium? Your carrier billing (৳2.99/day) will be stopped immediately.',
              style: AppTypography.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBackground
                    : AppColors.primaryBlueLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.health_and_safety_outlined,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your medicine vault, pill alarms, and routines remain 100% free and saved forever.',
                      style: AppTypography.caption.copyWith(
                        fontSize: 11.5,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Keep Premium',
              style: AppTypography.buttonText.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    final bdService = context.read<BdAppsService>();
    final entitlement = context.read<EntitlementService>();
    final messenger = ScaffoldMessenger.of(context);

    final success = await bdService.unsubscribe();

    if (mounted) {
      if (success) {
        await entitlement.recordUnsubscribed(userId: widget.profile?.uid);
        setState(() => _isCancelling = false);

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
        setState(() => _isCancelling = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              bdService.errorMessage ??
                  'Failed to cancel via app. Please try SMS or USSD method below.',
            ),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _launchSms() async {
    const recipient = '21213';
    const message = 'STOP meditrack';
    final smsUri = Uri(
      scheme: 'sms',
      path: recipient,
      queryParameters: <String, String>{'body': message},
    );

    try {
      final launched = await launchUrl(
        smsUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        final rawUri = Uri.parse('sms:$recipient?body=STOP%20meditrack');
        final rawLaunched = await launchUrl(
          rawUri,
          mode: LaunchMode.externalApplication,
        );
        if (!rawLaunched) {
          throw Exception('Could not launch SMS app');
        }
      }
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: message));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Copied "$message" to clipboard. Send it to $recipient in your SMS app.',
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
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await Clipboard.setData(const ClipboardData(text: '*213#'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied dial code *213# to clipboard.'),
              backgroundColor: AppColors.info,
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: '*213#'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Copied dial code *213# to clipboard.'),
            backgroundColor: AppColors.info,
          ),
        );
      }
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

            // 5. TELCO BILLING FAQ & POLICIES
            _buildFaqSection(isDark),
            const SizedBox(height: 32),
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
              subtitle: 'Multi-page Gemini 3.6 extraction',
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
        const SizedBox(height: 4),
        Text(
          'Choose any of the three options below to stop auto-renewal at zero penalty:',
          style: AppTypography.caption.copyWith(
            fontSize: 11.5,
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildInAppCancelCard(bool isDark) {
    return SoftSurface(
      padding: const EdgeInsets.all(16),
      borderRadius: AppRadii.cardRadius,
      borderColor: isDark
          ? const Color(0xFFDC2626).withValues(alpha: 0.3)
          : const Color(0xFFFECACA),
      borderWidth: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.phonelink_erase_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Method 1: Instant In-App Cancel',
                      style: AppTypography.headingSmall.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Deactivates directly via AppsPro API',
                      style: AppTypography.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Stops daily ৳2.99 carrier billing immediately. You can re-enable anytime.',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          SoftPrimaryButton(
            label: 'Cancel Subscription in App',
            isLoading: _isCancelling,
            backgroundColor: AppColors.danger,
            icon: Icons.close_rounded,
            onPressed: _isCancelling ? null : _handleInAppCancellation,
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.sms_rounded,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Method 2: Cancel via Telco SMS',
                      style: AppTypography.headingSmall.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Works from any phone with your SIM',
                      style: AppTypography.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Send an SMS from your registered Robi or Airtel number to de-register via BDApps gateway:',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
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
                IconButton(
                  tooltip: 'Copy SMS format',
                  onPressed: () => _copyToClipboard(
                    smsKeyword,
                    'Copied "$smsKeyword" to clipboard',
                  ),
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: AppColors.primaryBlue,
                  ),
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
                    side: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.primaryBlue.withValues(alpha: 0.4),
                    ),
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
                    side: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.border,
                    ),
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
    return SoftSurface(
      padding: const EdgeInsets.all(16),
      borderRadius: AppRadii.cardRadius,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.dialpad_rounded,
                  color: AppColors.accentOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Method 3: Cancel via USSD Menu',
                      style: AppTypography.headingSmall.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Robi & Airtel Telco Menu (*213#)',
                      style: AppTypography.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Dial *213# on your phone, choose "Active Services", and select MediTrack to cancel.',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              side: BorderSide(
                color: isDark
                    ? AppColors.darkBorder
                    : AppColors.accentOrange.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: _launchUssd,
            icon: const Icon(
              Icons.phone_forwarded_rounded,
              size: 16,
              color: AppColors.accentOrange,
            ),
            label: Text(
              'Dial *213# on Dialer',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
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
            'Upgrade to MediTrack Premium for ৳2.99/day via Robi / Airtel carrier billing to unlock full AI and OCR powers.',
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

  Widget _buildFaqSection(bool isDark) {
    return SoftSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: AppRadii.cardRadius,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading: const Icon(
            Icons.help_outline_rounded,
            color: AppColors.primaryBlue,
            size: 22,
          ),
          title: Text(
            'Carrier Billing FAQs & Help',
            style: AppTypography.headingSmall.copyWith(
              fontSize: 13.5,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          children: [
            _buildFaqItem(
              isDark: isDark,
              question: 'How does daily billing work?',
              answer:
                  'The ৳2.99 (+VAT, SD, SC) charge is deducted every 24 hours directly from your Robi or Airtel mobile balance by BDApps.',
            ),
            const SizedBox(height: 10),
            _buildFaqItem(
              isDark: isDark,
              question: 'What happens to my data if I cancel?',
              answer:
                  'Your pill schedules, prescriptions in vault, and medicine logs are always 100% free and stored securely. Only AI/OCR API centers are locked.',
            ),
            const SizedBox(height: 10),
            _buildFaqItem(
              isDark: isDark,
              question: 'How do I reactivate later?',
              answer:
                  'You can upgrade again at any time from your Profile tab with 1-tap OTP verification.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem({
    required bool isDark,
    required String question,
    required String answer,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.primaryBlueLight.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: AppTypography.bodyMedium.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

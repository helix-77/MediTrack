import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/locale_notifier.dart';
import '../models/buy_list_item.dart';
import '../models/medicine.dart';
import '../models/medicine_schedule.dart';
import '../logic/entitlement_guard.dart';
import '../services/buy_list_service.dart';
import '../services/entitlement_service.dart';
import '../services/openrouter_ai_service.dart';
import '../services/medicine_service.dart';
import '../services/notification_service.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/voice_input_helper.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_modal_sheet.dart';
import '../widgets/soft_surface.dart';
import 'subscription_offer_screen.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final OpenRouterAiService _aiService = OpenRouterAiService();
  final MedicineService _medicineService = MedicineService();
  final BuyListService _buyListService = BuyListService();
  final NotificationService _notificationService = NotificationService();
  final VoiceInputHelper _voiceHelper = VoiceInputHelper();

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<AiChatMessage> _messages = [];
  bool _isLoading = false;
  File? _selectedImage;

  final List<String> _quickPrompts = [
    'Should I take Napa before or after meals?',
    'What should I do if I missed my morning dose?',
    'Find generic alternatives for Seclo 20mg',
    'Add Paracetamol 500mg twice daily to my routine',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      AiChatMessage(
        role: 'model',
        content:
            'Hello! I am your **MediTrack AI Health Assistant**.\n\nYou can ask me questions about dosage instructions, medication schedules, Bangladesh generic equivalents, or upload a prescription image for advice.',
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      // Cap resolution before it ever touches the network — an
      // uncompressed camera photo sent inline to OpenRouter is the single
      // biggest driver of slow AI responses for image messages.
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  void _showAttachmentPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showAppModalBottomSheet(
      context: context,
      maxHeightFactor: 0.45,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Attach Image',
              style: AppTypography.headingMedium.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Capture or select a prescription or medicine strip',
              style: AppTypography.bodySmall.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildAttachmentOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    subtitle: 'Take a photo',
                    color: AppColors.primaryBlue,
                    bgColor: AppColors.primaryBlueLight,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildAttachmentOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    subtitle: 'Choose photo',
                    color: AppColors.accentPink,
                    bgColor: AppColors.accentPinkLight,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: isDark
          ? AppColors.darkSurfaceElevated
          : bgColor.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isDark ? color.withValues(alpha: 0.2) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: AppShadows.subtle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: AppTypography.headingSmall.copyWith(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage([String? promptOverride]) async {
    final text = promptOverride ?? _inputController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    final entitlement = context.read<EntitlementService>();
    final allowed = await entitlement.requirePremium(
      context,
      feature: EntitlementFeature.aiAssistant,
    );
    if (!allowed || !mounted) return;

    final userImage = _selectedImage;
    _inputController.clear();
    setState(() {
      _selectedImage = null;
      _messages.add(
        AiChatMessage(
          role: 'user',
          content: text,
          imagePath: userImage?.path,
        ),
      );
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await _aiService.sendMessage(
        history: _messages,
        userPrompt: text,
        imageFile: userImage,
      );

      unawaited(entitlement.recordAiUsage());

      setState(() {
        _messages.add(response);
      });
    } catch (e) {
      setState(() {
        _messages.add(
          AiChatMessage(
            role: 'model',
            content:
                'I apologize, but I encountered an error: $e\nPlease try again.',
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  void _showArchitectureInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Row(
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            Text('OpenRouter AI Security', style: AppTypography.headingMedium),
          ],
        ),
        content: Text(
          'MediTrack integrates OpenRouter AI using the OpenRouter Free router model.\n\n'
          '• Encrypted client access with per-user authentication.\n'
          '• User data is scoped strictly to users/{uid}/...\n'
          '• On-device ML Kit fallback for offline text scanning.',
          style: AppTypography.bodySmall.copyWith(height: 1.45),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Understood',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _executeAction(AiAction action) async {
    if (action.type == AiActionType.addMedicine) {
      final data = action.data;
      final name = data['name'] as String? ?? 'New Medicine';
      final form = data['form'] as String? ?? 'tablet';
      final dosage = data['dosage'] as String?;
      final times =
          (data['doseTimes'] as List<dynamic>?)?.cast<String>() ??
          ['08:00', '20:00'];

      final newMed = Medicine(
        id: '',
        name: name,
        dosageForm: form,
        strength: dosage,
        quantityCurrent: 30,
        quantityTotal: 30,
        lowStockThreshold: 5,
        schedule: MedicineSchedule(
          doseAmount: 1,
          timesPerDay: times.length,
          doseTimes: times,
          daysOfWeek: [1, 2, 3, 4, 5, 6, 7],
          startDate: DateTime.now(),
          active: true,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final saved = await _medicineService.saveMedicine(newMed);
      try {
        await _notificationService.scheduleMedicineNotifications(saved);
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $name added to your daily schedule!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } else if (action.type == AiActionType.addBuyItem) {
      final data = action.data;
      final name = data['name'] as String? ?? 'Medicine';
      final qty = (data['quantity'] as num?)?.toInt() ?? 1;

      final item = BuyListItem(
        id: '',
        name: name,
        quantityToBuy: qty,
        createdAt: DateTime.now(),
      );

      await _buyListService.saveBuyItem(item);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $name added to your Buy List!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final entitlement = context.watch<EntitlementService>();
    final isPro = entitlement.isSubscribed;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: AppColors.primaryBlueLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.primaryBlue,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.tr('ai_health_assistant'),
              style: AppTypography.headingMedium.copyWith(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SoftIconButton(
              icon: Icons.shield_outlined,
              size: 40,
              iconColor: AppColors.primaryBlue,
              tooltip: 'Security & AI Info',
              onPressed: _showArchitectureInfoDialog,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Safety Disclaimer Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark
                ? const Color(0xFF1E242F)
                : AppColors.primaryBlueLight.withValues(alpha: 0.5),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('safety_disclaimer'),
                    style: AppTypography.caption.copyWith(fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),

          // Quota Banner: AI Assistant is a Premium-only feature
          // (no free-tier allowance), plus a live daily-cap readout for
          // already-subscribed users.
          if (!isPro)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: isDark ? const Color(0xFF2B2215) : AppColors.warningLight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      context.isBangla ? 'মেডিট্র্যাক এআই প্রিমিয়াম সেবা (৳২.৯৯/দিন)' : 'MediTrack AI is a Premium feature (৳2.99/day)',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SubscriptionOfferScreen(),
                      ),
                    ),
                    child: Text(
                      context.isBangla ? 'সাবস্ক্রাইব ⚡' : 'Subscribe ⚡',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Builder(
              builder: (context) {
                final quota = entitlement.checkAiQuota();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Text(
                    quota.statusMessage,
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),

          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message, isDark);
              },
            ),
          ),

          // Quick Suggestion Chips (if not busy)
          if (!_isLoading && _messages.length <= 2)
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _quickPrompts.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ActionChip(
                      label: Text(_quickPrompts[index]),
                      backgroundColor: isDark
                          ? AppColors.darkSurface
                          : AppColors.surface,
                      labelStyle: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      side: BorderSide.none,
                      onPressed: () => _sendMessage(_quickPrompts[index]),
                    ),
                  );
                },
              ),
            ),

          // Image Attachment Preview
          if (_selectedImage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.borderLight,
                ),
                boxShadow: AppShadows.subtle,
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prescription Image',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Ready to analyze with AI',
                          style: AppTypography.caption.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                    onPressed: () => setState(() => _selectedImage = null),
                  ),
                ],
              ),
            ),

          // Bottom Input Bar
          _buildInputBar(isDark),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(AiChatMessage msg, bool isDark) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(top: 2),
              decoration: const BoxDecoration(
                color: AppColors.primaryBlueLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.primaryBlue,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primaryBlue
                        : (isDark ? AppColors.darkSurface : AppColors.surface),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: AppShadows.subtle,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg.imagePath != null &&
                          File(msg.imagePath!).existsSync()) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            File(msg.imagePath!),
                            height: 140,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (isUser)
                        Text(
                          msg.content,
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                            height: 1.45,
                          ),
                        )
                      else
                        _buildFormattedMarkdown(msg.content, isDark),
                    ],
                  ),
                ),

                // Interactive Action Card
                if (msg.action != null) ...[
                  const SizedBox(height: 8),
                  SoftSurface(
                    padding: const EdgeInsets.all(12),
                    color: isDark
                        ? const Color(0xFF16253A)
                        : AppColors.primaryBlueLight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.touch_app_rounded,
                          color: AppColors.primaryBlue,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          msg.action!.type == AiActionType.addMedicine
                              ? 'Action: Add ${msg.action!.data["name"] ?? "Medicine"} to Routine'
                              : 'Action: Add to Buy List',
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SoftPrimaryButton(
                          label: 'Confirm',
                          height: 32,
                          width: 80,
                          onPressed: () => _executeAction(msg.action!),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedMarkdown(String content, bool isDark) {
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;
    final secondaryTextColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textSecondary;
    final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;

    return MarkdownBody(
      data: content,
      selectable: false,
      onTapLink: (text, href, title) {
        if (href != null) {
          final uri = Uri.tryParse(href);
          if (uri != null) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }
      },
      styleSheet: MarkdownStyleSheet(
        p: AppTypography.bodyMedium.copyWith(color: textColor, height: 1.55),
        pPadding: const EdgeInsets.only(bottom: 8),
        h1: AppTypography.headingLarge.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
        h1Padding: const EdgeInsets.only(top: 8, bottom: 6),
        h2: AppTypography.headingMedium.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
        h2Padding: const EdgeInsets.only(top: 8, bottom: 6),
        h3: AppTypography.headingSmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
        h3Padding: const EdgeInsets.only(top: 6, bottom: 4),
        strong: AppTypography.bodyMedium.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
        em: AppTypography.bodyMedium.copyWith(
          color: textColor,
          fontStyle: FontStyle.italic,
        ),
        listBullet: AppTypography.bodyMedium.copyWith(
          color: AppColors.primaryBlue,
          fontWeight: FontWeight.w700,
        ),
        listBulletPadding: const EdgeInsets.only(right: 6),
        listIndent: 18,
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: dividerColor, width: 1.0)),
        ),
        blockquote: AppTypography.bodySmall.copyWith(
          color: secondaryTextColor,
          height: 1.45,
          fontStyle: FontStyle.italic,
        ),
        blockquoteDecoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B)
              : AppColors.primaryBlueLight.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            left: BorderSide(color: AppColors.primaryBlue, width: 3.5),
          ),
        ),
        blockquotePadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        code: GoogleFonts.firaCode(
          fontSize: 12,
          color: AppColors.primaryBlueDark,
          backgroundColor: isDark
              ? const Color(0xFF1E293B)
              : const Color(0xFFF1F5F9),
        ),
        codeblockDecoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.border,
            width: 0.5,
          ),
        ),
        codeblockPadding: const EdgeInsets.all(10),
        tableBody: AppTypography.bodySmall.copyWith(color: textColor),
        tableHead: AppTypography.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
        tableBorder: TableBorder.all(
          color: isDark ? AppColors.darkBorder : AppColors.border,
          width: 0.5,
          borderRadius: BorderRadius.circular(6),
        ),
        tableCellsPadding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: bottomPadding > 0 ? bottomPadding + 6 : 14,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCanvas : AppColors.canvas,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkSurfaceElevated
              : const Color(0xFFF0F4F9),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : const Color(0xFFE5EBF2),
            width: 0.8,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Attach Paperclip Icon
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _showAttachmentPicker,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Transform.rotate(
                    angle: -0.5,
                    child: Icon(
                      Icons.attach_file_rounded,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : const Color(0xFF718096),
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),

            // Message TextField
            Expanded(
              child: TextField(
                controller: _inputController,
                onSubmitted: (_) => _sendMessage(),
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: AppTypography.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: context.tr('ask_ai_hint'),
                  hintStyle: AppTypography.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                ),
              ),
            ),

            // Voice mic input button if available
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () {
                  _voiceHelper.startListening(
                    onResult: (text) => _inputController.text = text,
                    onError: (e) => ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e))),
                  );
                },
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Icon(
                    Icons.mic_none_rounded,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
              ),
            ),

            // Send Icon Button
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: _isLoading ? null : () => _sendMessage(),
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryBlue,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: AppColors.primaryBlue,
                          size: 22,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

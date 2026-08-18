import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/buy_list_item.dart';
import '../models/medicine.dart';
import '../models/medicine_schedule.dart';
import '../services/buy_list_service.dart';
import '../services/entitlement_service.dart';
import '../services/gemini_ai_service.dart';
import '../services/medicine_service.dart';
import '../services/notification_service.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../utils/voice_input_helper.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';
import 'subscription_offer_screen.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final GeminiAiService _aiService = GeminiAiService();
  final MedicineService _medicineService = MedicineService();
  final BuyListService _buyListService = BuyListService();
  final NotificationService _notificationService = NotificationService();
  final VoiceInputHelper _voiceHelper = VoiceInputHelper();

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<GeminiChatMessage> _messages = [];
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
      GeminiChatMessage(
        role: 'model',
        content:
            'Hello! I am your MediTrack AI Health Assistant. You can ask me questions about dosage instructions, medication schedules, Bangladesh generic equivalents, or upload a prescription image for advice.',
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
    final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _sendMessage([String? promptOverride]) async {
    final text = promptOverride ?? _inputController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    final userImage = _selectedImage;
    _inputController.clear();
    setState(() {
      _selectedImage = null;
      _messages.add(
        GeminiChatMessage(
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

      setState(() {
        _messages.add(response);
      });
    } catch (e) {
      setState(() {
        _messages.add(
          GeminiChatMessage(
            role: 'model',
            content: 'I apologize, but I encountered an error: $e\nPlease try again.',
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
            Text('Firebase AI Security', style: AppTypography.headingMedium),
          ],
        ),
        content: Text(
          'MediTrack integrates Gemini 3.6 Flash directly via Firebase AI Logic.\n\n'
          '• Direct client SDK access gated by Firebase App Check & Auth.\n'
          '• User data is scoped strictly to users/{uid}/...\n'
          '• On-device ML Kit fallback for offline text scanning.',
          style: AppTypography.bodySmall.copyWith(height: 1.45),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _executeAction(GeminiAction action) async {
    if (action.type == GeminiActionType.addMedicine) {
      final data = action.data;
      final name = data['name'] as String? ?? 'New Medicine';
      final form = data['form'] as String? ?? 'tablet';
      final dosage = data['dosage'] as String?;
      final times = (data['doseTimes'] as List<dynamic>?)?.cast<String>() ?? ['08:00', '20:00'];

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
    } else if (action.type == GeminiActionType.addBuyItem) {
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
              decoration: BoxDecoration(
                color: AppColors.primaryBlueLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.primaryBlue, size: 18),
            ),
            const SizedBox(width: 8),
            Text(
              'AI Assistant',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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
            color: isDark ? const Color(0xFF1E242F) : AppColors.primaryBlueLight.withValues(alpha: 0.5),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI advice is for reference. Consult your registered doctor for clinical decisions.',
                    style: AppTypography.caption.copyWith(fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),

          // Quota Banner for Free tier
          if (!isPro)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: isDark ? const Color(0xFF2B2215) : AppColors.warningLight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Free Tier: 5 AI requests/day remaining',
                    style: AppTypography.caption.copyWith(fontWeight: FontWeight.w600, color: AppColors.warning),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SubscriptionOfferScreen()),
                    ),
                    child: Text(
                      'Upgrade Unlimited ⚡',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
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
                      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
                      labelStyle: AppTypography.caption.copyWith(fontWeight: FontWeight.w500),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? AppColors.darkSurface : Colors.white,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_selectedImage!, width: 44, height: 44, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Prescription image attached', style: AppTypography.caption),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
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

  Widget _buildMessageBubble(GeminiChatMessage msg, bool isDark) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppColors.primaryBlueLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome, color: AppColors.primaryBlue, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      if (msg.imagePath != null && File(msg.imagePath!).existsSync()) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(File(msg.imagePath!), height: 140, fit: BoxFit.cover),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        msg.content,
                        style: AppTypography.bodyMedium.copyWith(
                          color: isUser ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),

                // Interactive Action Card
                if (msg.action != null) ...[
                  const SizedBox(height: 8),
                  SoftSurface(
                    padding: const EdgeInsets.all(12),
                    color: isDark ? const Color(0xFF16253A) : AppColors.primaryBlueLight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.touch_app_rounded, color: AppColors.primaryBlue, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          msg.action!.type == GeminiActionType.addMedicine
                              ? 'Action: Add ${msg.action!.data["name"] ?? "Medicine"} to Routine'
                              : 'Action: Add to Buy List',
                          style: AppTypography.caption.copyWith(fontWeight: FontWeight.w700),
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

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF18233D).withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          SoftIconButton(
            icon: Icons.camera_alt_outlined,
            size: 38,
            iconSize: 18,
            onPressed: () => _pickImage(ImageSource.camera),
          ),
          const SizedBox(width: 6),
          SoftIconButton(
            icon: Icons.photo_library_outlined,
            size: 38,
            iconSize: 18,
            onPressed: () => _pickImage(ImageSource.gallery),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _inputController,
              onSubmitted: (_) => _sendMessage(),
              style: AppTypography.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Ask AI or upload prescription...',
                filled: true,
                fillColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.mic, color: AppColors.primaryBlue, size: 20),
                  onPressed: () {
                    _voiceHelper.startListening(
                      onResult: (text) => _inputController.text = text,
                      onError: (e) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e))),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
              boxShadow: AppShadows.subtle,
            ),
            child: IconButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              onPressed: _isLoading ? null : () => _sendMessage(),
            ),
          ),
        ],
      ),
    );
  }
}

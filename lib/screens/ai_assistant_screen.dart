import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/buy_list_item.dart';
import '../models/medicine.dart';
import '../models/medicine_schedule.dart';
import '../services/buy_list_service.dart';
import '../services/grok_ai_service.dart';
import '../services/medicine_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final List<GrokChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  final MedicineService _medicineService = MedicineService();
  final BuyListService _buyListService = BuyListService();

  File? _selectedImage;
  bool _isLoading = false;
  String _runtimeApiKey = '';

  @override
  void initState() {
    super.initState();
    // Welcome message
    _messages.add(
      GrokChatMessage(
        role: 'assistant',
        content:
            'Hello! I am your MediTrack AI Assistant powered by Grok. 🤖✨\n\nHow can I help you today?\n• Create a new medicine routine\n• Add items to your buy list\n• Analyze prescription photos\n• Answer health & medication questions',
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
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
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
        });
      }
    } catch (e) {
      _showSnackbar('Failed to pick image: $e', isError: true);
    }
  }

  Future<void> _sendMessage({String? customText}) async {
    final text = (customText ?? _textController.text).trim();
    if (text.isEmpty && _selectedImage == null) return;

    final userMsg = GrokChatMessage(
      role: 'user',
      content: text.isEmpty && _selectedImage != null
          ? 'Analyze prescription image'
          : text,
      imagePath: _selectedImage?.path,
    );

    final imageToSend = _selectedImage;

    setState(() {
      _messages.add(userMsg);
      _textController.clear();
      _selectedImage = null;
      _isLoading = true;
    });

    _scrollToBottom();

    final grokService = GrokAiService();
    final aiResponse = await grokService.sendMessage(
      history: _messages,
      userPrompt: text,
      imageFile: imageToSend,
      runtimeApiKey: _runtimeApiKey,
    );

    setState(() {
      _messages.add(aiResponse);
      _isLoading = false;
    });

    _scrollToBottom();
  }

  Future<void> _executeAddMedicine(GrokAction action) async {
    final name = (action.data['name'] as String?) ?? 'New Medicine';
    final dosage = (action.data['dosage'] as String?) ?? '1 tablet';
    final stock = (action.data['stock'] as int?) ?? 30;
    final now = DateTime.now();

    final schedule = MedicineSchedule(
      doseAmount: 1,
      timesPerDay: 2,
      doseTimes: const ['08:00', '20:00'],
      daysOfWeek: const [1, 2, 3, 4, 5, 6, 7],
      startDate: now,
    );

    final med = Medicine(
      id: '',
      name: name,
      strength: dosage,
      quantityCurrent: stock,
      quantityTotal: stock,
      schedule: schedule,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _medicineService.saveMedicine(med);
      _showSnackbar('✅ Added "$name" to your Routine!');
    } catch (e) {
      _showSnackbar('Failed to add medicine: $e', isError: true);
    }
  }

  Future<void> _executeAddBuyItem(GrokAction action) async {
    final name = (action.data['name'] as String?) ?? 'Grocery Item';
    final qty = (action.data['quantity'] as int?) ?? 1;

    final item = BuyListItem(
      id: '',
      name: name,
      quantityToBuy: qty,
      isPurchased: false,
      createdAt: DateTime.now(),
    );

    try {
      await _buyListService.saveBuyItem(item);
      _showSnackbar('✅ Added "$name" to your Buy List!');
    } catch (e) {
      _showSnackbar('Failed to add item to Buy List: $e', isError: true);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.primaryGreen,
      ),
    );
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController(text: _runtimeApiKey);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Grok API Key Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste your Grok API Key below or edit `lib/config/api_config.dart`.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Grok API Key',
                hintText: 'xai-...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                _runtimeApiKey = controller.text.trim();
              });
              Navigator.pop(ctx);
              _showSnackbar('Grok API Key updated for this session.');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.accentPinkLight),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MediTrack AI Assistant',
                  style: AppTypography.headingSmall
                      .copyWith(color: Colors.white),
                ),
                Text(
                  'Powered by Grok API',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.accentPinkLight, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Grok API Key Settings',
            onPressed: _showApiKeyDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          // Loading Indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Grok is thinking...',
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),

          // Selected Image Banner
          if (_selectedImage != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImage!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Prescription Image attached'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.danger),
                    onPressed: () => setState(() => _selectedImage = null),
                  ),
                ],
              ),
            ),

          // Quick Suggestion Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                _buildQuickChip(
                  '💊 Add Routine',
                  'Add a new medicine routine for Paracetamol 500mg daily',
                ),
                _buildQuickChip(
                  '🛒 Add Buy List',
                  'Add Vitamin C to my buy list',
                ),
                _buildQuickChip(
                  '💡 Health Tip',
                  'Give me a tip on how to remember medications daily',
                ),
              ],
            ),
          ),

          // Bottom Input Bar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_a_photo_outlined,
                        color: AppColors.primaryGreen),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (ctx) => SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.camera_alt),
                                title: const Text('Take Photo'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pickImage(ImageSource.camera);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.photo_library),
                                title: const Text('Choose from Gallery'),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pickImage(ImageSource.gallery);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Ask Grok or command actions...',
                        hintStyle: AppTypography.bodySmall,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.send),
                    onPressed: () => _sendMessage(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, String prompt) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.divider),
        onPressed: () => _sendMessage(customText: prompt),
      ),
    );
  }

  Widget _buildMessageBubble(GrokChatMessage msg) {
    final isUser = msg.isUser;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primaryGreen,
                  child: Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primaryGreen
                        : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (msg.imagePath != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(msg.imagePath!),
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        msg.content,
                        style: AppTypography.bodyMedium.copyWith(
                          color: isUser ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isUser) const SizedBox(width: 8),
            ],
          ),

          // Render Action Card if Grok returned an action
          if (!isUser && msg.action != null) ...[
            const SizedBox(height: 8),
            _buildActionCard(msg.action!),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard(GrokAction action) {
    if (action.type == GrokActionType.addMedicine) {
      final name = (action.data['name'] as String?) ?? 'Medicine';
      final dosage = (action.data['dosage'] as String?) ?? '500mg';
      final frequency = (action.data['frequency'] as String?) ?? 'Daily';
      final stock = (action.data['stock'] as int?) ?? 30;

      return Container(
        margin: const EdgeInsets.only(left: 40, right: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.accentPinkLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGreenLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medication, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  'Suggested Routine Action',
                  style: AppTypography.headingSmall.copyWith(
                    color: AppColors.primaryGreen,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('• Name: $name'),
            Text('• Dosage: $dosage'),
            Text('• Schedule: $frequency'),
            Text('• Total Stock: $stock tablets'),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 36),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: Text('Confirm & Add "$name" to Routine'),
              onPressed: () => _executeAddMedicine(action),
            ),
          ],
        ),
      );
    } else if (action.type == GrokActionType.addBuyItem) {
      final name = (action.data['name'] as String?) ?? 'Grocery Item';
      final qty = (action.data['quantity'] as int?) ?? 1;

      return Container(
        margin: const EdgeInsets.only(left: 40, right: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.accentPinkLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryGreenLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_bag, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  'Suggested Buy List Action',
                  style: AppTypography.headingSmall.copyWith(
                    color: AppColors.primaryGreen,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('• Item: $name'),
            Text('• Quantity: $qty'),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 36),
              ),
              icon: const Icon(Icons.add_shopping_cart, size: 18),
              label: Text('Confirm & Add "$name" to Buy List'),
              onPressed: () => _executeAddBuyItem(action),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

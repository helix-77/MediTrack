import 'package:flutter/material.dart';
import '../models/buy_list_item.dart';
import '../models/medicine.dart';
import '../services/buy_list_service.dart';
import '../services/medicine_service.dart';
import '../logic/refill_calculator.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/section_header.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';
import '../widgets/soft_text_field.dart';
import '../widgets/status_pill.dart';

class BuyListScreen extends StatefulWidget {
  const BuyListScreen({super.key});

  @override
  State<BuyListScreen> createState() => _BuyListScreenState();
}

class _BuyListScreenState extends State<BuyListScreen> {
  final BuyListService _buyListService = BuyListService();
  final MedicineService _medicineService = MedicineService();

  void _showAddBuyItemDialog([Medicine? suggestedMed]) {
    final nameController = TextEditingController(text: suggestedMed?.name ?? '');
    final qtyController = TextEditingController(text: '1');
    final notesController = TextEditingController(text: suggestedMed != null ? 'Refill needed' : '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        title: Text(
          suggestedMed != null ? 'Add Refill to Buy List' : 'Add Item to Buy List',
          style: AppTypography.headingMedium,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SoftTextField(
              controller: nameController,
              labelText: 'Medicine / Item Name',
              hintText: 'e.g. Napa 500mg, Bandages',
            ),
            const SizedBox(height: 12),
            SoftTextField(
              controller: qtyController,
              labelText: 'Packs / Quantity to Buy',
              hintText: '1',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            SoftTextField(
              controller: notesController,
              labelText: 'Notes (optional)',
              hintText: 'e.g. Pharmacy preference',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: AppRadii.standardRadius),
            ),
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              final item = BuyListItem(
                id: '',
                medicineId: suggestedMed?.id,
                name: name,
                quantityToBuy: int.tryParse(qtyController.text) ?? 1,
                notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                createdAt: DateTime.now(),
              );

              Navigator.pop(dialogContext);
              await _buyListService.saveBuyItem(item);
            },
            child: const Text('Add Item', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        title: Text(
          'Medicine Buy List',
          style: AppTypography.headingMedium.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: SoftIconButton(
              icon: Icons.add_shopping_cart_rounded,
              size: 40,
              iconColor: AppColors.primaryBlue,
              tooltip: 'Add Item',
              onPressed: () => _showAddBuyItemDialog(),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Medicine>>(
        stream: _medicineService.streamMedicines(),
        builder: (context, medSnapshot) {
          final medicines = medSnapshot.data ?? [];
          final lowStockMeds = medicines
              .where((m) => RefillCalculator.isLowStock(m.quantityCurrent, m.lowStockThreshold))
              .toList();

          return StreamBuilder<List<BuyListItem>>(
            stream: _buyListService.streamBuyList(),
            builder: (context, buySnapshot) {
              if (buySnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primaryBlue),
                );
              }

              final buyItems = buySnapshot.data ?? [];
              final remainingCount = buyItems.where((i) => !i.isPurchased).length;

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                children: [
                  // Auto-Suggest Low Stock Banner
                  if (lowStockMeds.isNotEmpty) ...[
                    _buildLowStockSuggestionBanner(lowStockMeds, buyItems, isDark),
                    const SizedBox(height: 20),
                  ],

                  // Buy List Header
                  SectionHeader(
                    title: 'Shopping List',
                    subtitle: 'Medicines & supplies to purchase',
                    trailing: StatusPill(
                      label: '$remainingCount remaining',
                      type: remainingCount > 0 ? PillType.primary : PillType.success,
                    ),
                  ),
                  const SizedBox(height: 4),

                  if (buyItems.isEmpty)
                    EmptyStateView(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Your Buy List is Empty',
                      description: 'Add prescription refills, supplements, or medical items to track your purchases.',
                      buttonLabel: 'Add First Item',
                      onButtonPressed: () => _showAddBuyItemDialog(),
                    )
                  else
                    ...buyItems.map((item) => _buildBuyItemCard(item, isDark)),
                  const SizedBox(height: 40),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLowStockSuggestionBanner(
    List<Medicine> lowStockMeds,
    List<BuyListItem> existingBuyItems,
    bool isDark,
  ) {
    final unaddedLowMeds = lowStockMeds.where((m) => !existingBuyItems.any((b) => b.medicineId == m.id)).toList();

    if (unaddedLowMeds.isEmpty) return const SizedBox.shrink();

    return SoftSurface(
      padding: const EdgeInsets.all(16),
      color: isDark ? const Color(0xFF2B2215) : AppColors.warningLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
              const SizedBox(width: 8),
              Text(
                'Low Stock Refill Suggestions',
                style: AppTypography.headingSmall.copyWith(
                  color: AppColors.warning,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'The following medicines are running low. Tap to add to your Buy List:',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: unaddedLowMeds
                .map(
                  (m) => ActionChip(
                    avatar: const Icon(Icons.add, size: 16, color: AppColors.primaryBlue),
                    label: Text('${m.name} (${m.quantityCurrent} left)'),
                    backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                    side: BorderSide.none,
                    labelStyle: AppTypography.caption.copyWith(fontWeight: FontWeight.w600),
                    onPressed: () => _showAddBuyItemDialog(m),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyItemCard(BuyListItem item, bool isDark) {
    return Dismissible(
      key: Key('buy_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: AppRadii.cardRadius,
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      onDismissed: (_) async {
        await _buyListService.deleteBuyItem(item.id);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: SoftSurface(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Checkbox(
                value: item.isPurchased,
                activeColor: AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                onChanged: (val) async {
                  if (val == null) return;
                  await _buyListService.togglePurchased(item, val);
                  if (val && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('✅ ${item.name} purchased! Stock updated.'),
                        backgroundColor: AppColors.success,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: AppTypography.headingSmall.copyWith(
                        fontSize: 14,
                        decoration: item.isPurchased ? TextDecoration.lineThrough : null,
                        color: item.isPurchased
                            ? (isDark ? AppColors.darkTextSecondary : AppColors.textMuted)
                            : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Qty to buy: ${item.quantityToBuy} ${item.notes != null ? "• ${item.notes}" : ""}',
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              if (item.isPurchased)
                const StatusPill(
                  label: 'Purchased',
                  type: PillType.success,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

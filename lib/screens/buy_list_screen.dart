import 'package:flutter/material.dart';
import '../models/buy_list_item.dart';
import '../models/medicine.dart';
import '../services/buy_list_service.dart';
import '../services/medicine_service.dart';
import '../logic/refill_calculator.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

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
        title: Text(suggestedMed != null ? 'Add Refill to Buy List' : 'Add Item to Buy List'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Item / Medicine Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Packs / Quantity to Buy'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
            child: const Text('Add Item'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medicine Buy List', style: AppTypography.headingLarge.copyWith(color: AppColors.primaryGreen)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddBuyItemDialog(),
        icon: const Icon(Icons.add_shopping_cart),
        label: const Text('Add Item'),
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
                return const Center(child: CircularProgressIndicator());
              }

              final buyItems = buySnapshot.data ?? [];

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  // Auto-Suggest Low Stock Banner
                  if (lowStockMeds.isNotEmpty) ...[
                    _buildLowStockSuggestionBanner(lowStockMeds, buyItems),
                    const SizedBox(height: 20),
                  ],

                  // Buy List Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Shopping List', style: AppTypography.headingMedium),
                      Chip(
                        label: Text('${buyItems.where((i) => !i.isPurchased).length} remaining'),
                        backgroundColor: AppColors.accentPinkLight,
                        labelStyle: AppTypography.bodySmall.copyWith(color: AppColors.primaryGreen, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (buyItems.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            const Icon(Icons.shopping_bag_outlined, size: 48, color: AppColors.primaryGreen),
                            const SizedBox(height: 12),
                            Text('Your Buy List is Empty', style: AppTypography.headingMedium),
                            const SizedBox(height: 8),
                            Text(
                              'Add prescription refills, supplements, or medical items to track your purchases.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...buyItems.map((item) => _buildBuyItemCard(item)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLowStockSuggestionBanner(List<Medicine> lowStockMeds, List<BuyListItem> existingBuyItems) {
    final unaddedLowMeds = lowStockMeds.where((m) => !existingBuyItems.any((b) => b.medicineId == m.id)).toList();

    if (unaddedLowMeds.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                'Low Stock Refill Suggestions',
                style: AppTypography.headingSmall.copyWith(color: AppColors.warning),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                    avatar: const Icon(Icons.add, size: 16),
                    label: Text('${m.name} (${m.quantityCurrent} left)'),
                    onPressed: () => _showAddBuyItemDialog(m),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyItemCard(BuyListItem item) {
    return Dismissible(
      key: Key('buy_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (_) async {
        await _buyListService.deleteBuyItem(item.id);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: CheckboxListTile(
          value: item.isPurchased,
          activeColor: AppColors.success,
          onChanged: (val) async {
            if (val == null) return;
            await _buyListService.togglePurchased(item, val);
            if (val && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item.name} marked as purchased! Stock updated.'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          },
          title: Text(
            item.name,
            style: AppTypography.headingSmall.copyWith(
              decoration: item.isPurchased ? TextDecoration.lineThrough : null,
              color: item.isPurchased ? AppColors.textSecondary : AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            'Qty to buy: ${item.quantityToBuy} ${item.notes != null ? "• ${item.notes}" : ""}',
            style: AppTypography.bodySmall,
          ),
        ),
      ),
    );
  }
}

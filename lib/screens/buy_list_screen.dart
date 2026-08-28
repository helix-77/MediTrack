import 'package:flutter/material.dart';
import '../l10n/locale_notifier.dart';
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

  int _selectedFilterIndex = 0; // 0: All, 1: Low Stock, 2: Custom, 3: Purchased
  bool _isSyncing = false;

  Future<void> _autoSyncLowStock(List<Medicine> lowStockMeds) async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      await _buyListService.syncLowStockMedicines(lowStockMeds);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Synced ${lowStockMeds.length} low-stock medicines to buy list'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sync: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showAddBuyItemDialog({Medicine? suggestedMed, List<Medicine>? allMedicines}) {
    final nameController = TextEditingController(text: suggestedMed?.name ?? '');
    final qtyController = TextEditingController(text: '1');
    final notesController = TextEditingController(text: suggestedMed != null ? 'Refill needed' : '');
    Medicine? selectedMed = suggestedMed;
    bool isLowStockRefill = suggestedMed != null;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final medicinesList = allMedicines ?? [];

          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
            title: Text(
              isLowStockRefill ? 'Add Medicine Refill' : 'Add Item to Buy List',
              style: AppTypography.headingMedium.copyWith(
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type selection: Refill vs Custom
                  Row(
                    children: [
                      ChoiceChip(
                        label: const Text('Low-Stock Refill'),
                        selected: isLowStockRefill,
                        selectedColor: AppColors.primaryBlue,
                        backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.canvas,
                        labelStyle: AppTypography.caption.copyWith(
                          color: isLowStockRefill ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide.none,
                        onSelected: (selected) {
                          setDialogState(() {
                            isLowStockRefill = true;
                            if (selectedMed != null) {
                              nameController.text = selectedMed!.name;
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Custom Item'),
                        selected: !isLowStockRefill,
                        selectedColor: AppColors.primaryBlue,
                        backgroundColor: isDark ? AppColors.darkSurfaceElevated : AppColors.canvas,
                        labelStyle: AppTypography.caption.copyWith(
                          color: !isLowStockRefill ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide.none,
                        onSelected: (selected) {
                          setDialogState(() {
                            isLowStockRefill = false;
                            selectedMed = null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (isLowStockRefill && medicinesList.isNotEmpty) ...[
                    Text('Select Tracked Medicine', style: AppTypography.caption),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurfaceElevated : AppColors.canvas,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Medicine>(
                          isExpanded: true,
                          value: selectedMed,
                          dropdownColor: isDark ? AppColors.darkSurfaceElevated : Colors.white,
                          hint: Text('Choose medicine', style: AppTypography.bodySmall),
                          items: medicinesList.map((m) {
                            return DropdownMenuItem<Medicine>(
                              value: m,
                              child: Text(
                                '${m.name} (${m.quantityCurrent} ${m.dosageForm ?? "units"} left)',
                                style: AppTypography.bodySmall.copyWith(
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (med) {
                            if (med != null) {
                              setDialogState(() {
                                selectedMed = med;
                                nameController.text = med.name;
                                notesController.text = 'Refill (${med.quantityCurrent} left)';
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  SoftTextField(
                    controller: nameController,
                    labelText: 'Item Name',
                    hintText: 'e.g. Napa Extra 500mg, Savlon, Bandages',
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
                    hintText: 'e.g. 1 strip (10 tablets), pharmacy note',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
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
                    medicineId: selectedMed?.id,
                    name: name,
                    quantityToBuy: int.tryParse(qtyController.text) ?? 1,
                    isPurchased: false,
                    isAutoLowStock: isLowStockRefill,
                    currentStockAtAdd: selectedMed?.quantityCurrent,
                    dosageForm: selectedMed?.dosageForm,
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                    createdAt: DateTime.now(),
                  );

                  Navigator.pop(dialogContext);
                  await _buyListService.saveBuyItem(item);
                },
                child: const Text('Add Item', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
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
          context.tr('buy_list_title'),
          style: AppTypography.headingMedium.copyWith(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.cleaning_services_rounded, size: 20),
            tooltip: 'Clear Purchased Items',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
                  title: const Text('Clear Purchased Items?'),
                  content: const Text('This will remove all items already marked as purchased.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Clear', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _buyListService.clearPurchasedItems();
              }
            },
          ),
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

              final allBuyItems = buySnapshot.data ?? [];
              final pendingCount = allBuyItems.where((i) => !i.isPurchased).length;

              // Filtered lists
              final lowStockItems = allBuyItems.where((i) => i.isAutoLowStock || i.medicineId != null).toList();
              final customItems = allBuyItems.where((i) => !i.isAutoLowStock && i.medicineId == null).toList();

              List<BuyListItem> displayedItems;
              switch (_selectedFilterIndex) {
                case 1: // Low Stock Refills
                  displayedItems = lowStockItems;
                  break;
                case 2: // Custom Items
                  displayedItems = customItems;
                  break;
                case 3: // Purchased
                  displayedItems = allBuyItems.where((i) => i.isPurchased).toList();
                  break;
                case 0:
                default: // All
                  displayedItems = allBuyItems;
                  break;
              }

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                children: [
                  // 1. Overview & Auto-Sync Banner
                  _buildSummaryHeroCard(
                    totalItems: allBuyItems.length,
                    pendingCount: pendingCount,
                    lowStockCount: lowStockMeds.length,
                    onSyncPressed: () => _autoSyncLowStock(lowStockMeds),
                    isDark: isDark,
                  ),
                  const SizedBox(height: 18),

                  // 2. Filter Chips
                  _buildFilterChips(
                    allCount: allBuyItems.length,
                    lowStockCount: lowStockItems.length,
                    customCount: customItems.length,
                    purchasedCount: allBuyItems.where((i) => i.isPurchased).length,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 20),

                  // 3. Main Item Lists
                  if (_selectedFilterIndex == 0) ...[
                    // Grouped View: Auto Low-Stock Refills Section
                    if (lowStockItems.isNotEmpty) ...[
                      SectionHeader(
                        title: context.isBangla ? 'স্বল্প স্টকের রিফিল' : 'Low-Stock Refills',
                        trailing: StatusPill(
                          label: '${lowStockItems.where((i) => !i.isPurchased).length} ${context.isBangla ? 'টি কিনতে হবে' : 'to buy'}',
                          type: PillType.warning,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...lowStockItems.map((item) => _buildBuyItemCard(item, isDark)),
                      const SizedBox(height: 20),
                    ],

                    // Grouped View: Custom Shopping Items Section
                    SectionHeader(
                      title: context.isBangla ? 'সাধারণ সরবরাহ ও অন্যান্য' : 'General Supplies & Custom',
                      trailing: StatusPill(
                        label: '${customItems.where((i) => !i.isPurchased).length} ${context.isBangla ? 'টি কিনতে হবে' : 'to buy'}',
                        type: PillType.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (customItems.isEmpty && lowStockItems.isEmpty)
                      EmptyStateView(
                        icon: Icons.shopping_bag_outlined,
                        title: context.tr('buy_list_empty'),
                        description: context.isBangla
                            ? 'আপনার কেনাকাটার তালিকায় কোনো ওষুধ বা সামগ্রী নেই।'
                            : 'Add prescription refills, supplements, or medical items to track your purchases.',
                        buttonLabel: context.isBangla ? 'প্রথম আইটেম যোগ করুন' : 'Add First Item',
                        onButtonPressed: () => _showAddBuyItemDialog(allMedicines: medicines),
                      )
                    else if (customItems.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Text(
                            'No custom items yet. Tap + to add non-prescription supplies.',
                            style: AppTypography.caption,
                          ),
                        ),
                      )
                    else
                      ...customItems.map((item) => _buildBuyItemCard(item, isDark)),
                  ] else ...[
                    // Filtered Flat View
                    if (displayedItems.isEmpty)
                      EmptyStateView(
                        icon: Icons.check_circle_outline_rounded,
                        title: 'No Items Found',
                        description: 'No items match the selected category.',
                        buttonLabel: 'Add Item',
                        onButtonPressed: () => _showAddBuyItemDialog(allMedicines: medicines),
                      )
                    else
                      ...displayedItems.map((item) => _buildBuyItemCard(item, isDark)),
                  ],

                  const SizedBox(height: 40),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HERO SUMMARY & AUTO-SYNC BANNER
  // ---------------------------------------------------------------------------
  Widget _buildSummaryHeroCard({
    required int totalItems,
    required int pendingCount,
    required int lowStockCount,
    required VoidCallback onSyncPressed,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF162032) : const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: isDark ? 0.08 : 0.06),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shopping_basket_rounded, color: AppColors.primaryBlue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Medicine Buy List',
                        style: AppTypography.headingMedium.copyWith(fontSize: 16),
                      ),
                      Text(
                        '$pendingCount pending • $lowStockCount low stock',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ],
              ),
              if (lowStockCount > 0)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: onSyncPressed,
                  icon: _isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Auto-Sync', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FILTER CHIPS
  // ---------------------------------------------------------------------------
  Widget _buildFilterChips({
    required int allCount,
    required int lowStockCount,
    required int customCount,
    required int purchasedCount,
    required bool isDark,
  }) {
    final filters = [
      {'label': 'All ($allCount)', 'index': 0},
      {'label': 'Low Stock ($lowStockCount)', 'index': 1},
      {'label': 'Custom ($customCount)', 'index': 2},
      {'label': 'Purchased ($purchasedCount)', 'index': 3},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilterIndex == f['index'];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(f['label'] as String),
              selected: isSelected,
              selectedColor: AppColors.primaryBlue,
              backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
              labelStyle: AppTypography.caption.copyWith(
                color: isSelected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              side: BorderSide.none,
              onSelected: (selected) {
                setState(() => _selectedFilterIndex = f['index'] as int);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BUY ITEM CARD
  // ---------------------------------------------------------------------------
  Widget _buildBuyItemCard(BuyListItem item, bool isDark) {
    final isLowStock = item.isAutoLowStock || item.medicineId != null;

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Checkbox for purchasing
              Checkbox(
                value: item.isPurchased,
                activeColor: AppColors.success,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                onChanged: (val) async {
                  if (val == null) return;
                  await _buyListService.togglePurchased(item, val);
                  if (val && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isLowStock
                              ? '✅ ${item.name} purchased! Stock updated in medicine cabinet.'
                              : '✅ ${item.name} marked as purchased!',
                        ),
                        backgroundColor: AppColors.success,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),

              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: AppTypography.headingSmall.copyWith(
                              fontSize: 14,
                              decoration: item.isPurchased ? TextDecoration.lineThrough : null,
                              color: item.isPurchased
                                  ? (isDark ? AppColors.darkTextSecondary : AppColors.textMuted)
                                  : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                            ),
                          ),
                        ),
                        if (isLowStock)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            margin: const EdgeInsets.only(left: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2B2215) : AppColors.warningLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Auto Refill',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Qty: ${item.quantityToBuy} pack(s) ${item.notes != null ? "• ${item.notes}" : ""}',
                      style: AppTypography.caption.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),
              if (item.isPurchased)
                const StatusPill(
                  label: 'Purchased',
                  type: PillType.success,
                )
              else if (item.currentStockAtAdd != null)
                StatusPill(
                  label: '${item.currentStockAtAdd} left',
                  type: PillType.warning,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

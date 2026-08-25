import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../logic/entitlement_guard.dart';
import '../models/buy_list_item.dart';
import '../models/medicine_reference.dart';
import '../services/buy_list_service.dart';
import '../services/medicine_reference_service.dart';
import '../theme/app_tokens.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/empty_state_view.dart';
import '../widgets/premium_gate.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';

class MedicineSearchScreen extends StatefulWidget {
  const MedicineSearchScreen({super.key});

  @override
  State<MedicineSearchScreen> createState() => _MedicineSearchScreenState();
}

class _MedicineSearchScreenState extends State<MedicineSearchScreen> {
  final MedicineReferenceService _searchService = MedicineReferenceService();
  final BuyListService _buyListService = BuyListService();
  final TextEditingController _queryController = TextEditingController();

  List<MedicineReference> _results = [];
  bool _isLoading = false;
  String _searchedQuery = '';
  final Set<String> _expandedAlternatives = {};

  final _currencyFormat = NumberFormat.currency(symbol: '৳', decimalDigits: 2);

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    setState(() {
      _isLoading = true;
      _searchedQuery = clean;
      _expandedAlternatives.clear();
    });

    try {
      final res = await _searchService.searchMedicines(clean);
      setState(() => _results = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addToBuyList(MedicineReference med) async {
    final priceStr = med.unitPriceBdt != null
        ? '${_currencyFormat.format(med.unitPriceBdt)}/unit'
        : 'Price N/A';
    final item = BuyListItem(
      id: '',
      name: '${med.brandName} ${med.strength ?? ""}'.trim(),
      quantityToBuy: 1,
      notes: 'Generic: ${med.genericName} • $priceStr',
      createdAt: DateTime.now(),
    );

    await _buyListService.saveBuyItem(item);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ ${med.brandName} added to Buy List!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PremiumGate(
      feature: EntitlementFeature.priceLookup,
      builder: _buildScreen,
    );
  }

  Widget _buildScreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBar: AppBar(
        title: const Text('Medicine Price & Generic Lookup'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: SoftIconButton(
            icon: Icons.arrow_back_rounded,
            size: 40,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: SoftSurface(
              padding: EdgeInsets.zero,
              borderRadius: BorderRadius.circular(30),
              child: TextField(
                controller: _queryController,
                onSubmitted: _performSearch,
                textInputAction: TextInputAction.search,
                style: AppTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText:
                      'Search brand or generic (e.g. Napa, Seclo, Paracetamol)...',
                  hintStyle: AppTypography.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textMuted,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.primaryBlue,
                    size: 22,
                  ),
                  suffixIcon: _queryController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _queryController.clear();
                            setState(() {
                              _results.clear();
                              _searchedQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // Official MRP Disclaimer Banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1B2330)
                  : AppColors.primaryBlueLight.withValues(alpha: 0.6),
              borderRadius: AppRadii.smallRadius,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.primaryBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Prices reflect DGDA Bangladesh Maximum Retail Prices (MRP). Actual pharmacy prices may vary.',
                    style: AppTypography.caption.copyWith(fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Results List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryBlue,
                    ),
                  )
                : _searchedQuery.isEmpty
                ? Center(
                    child: EmptyStateView(
                      icon: Icons.medication_liquid_outlined,
                      title: 'Search Bangladesh Medicines',
                      description:
                          'Enter a medicine brand name or generic compound to compare prices and find cheaper alternatives.',
                    ),
                  )
                : _results.isEmpty
                ? Center(
                    child: EmptyStateView(
                      icon: Icons.search_off_rounded,
                      title: 'No Medicines Found',
                      description:
                          'No matching DGDA medicine found for "$_searchedQuery". Check spelling and try again.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final med = _results[index];
                      return _buildMedicineResultCard(med, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineResultCard(MedicineReference med, bool isDark) {
    final isExpanded = _expandedAlternatives.contains(med.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: SoftSurface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${med.brandName} ${med.strength ?? ""}',
                        style: AppTypography.headingSmall.copyWith(
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        med.genericName,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  med.unitPriceBdt != null
                      ? _currencyFormat.format(med.unitPriceBdt!)
                      : 'N/A',
                  style: AppTypography.headingSmall.copyWith(
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${med.dosageForm?.toUpperCase() ?? "MEDICINE"} • ${med.manufacturer ?? "Bangladesh"}',
                  style: AppTypography.caption,
                ),
                Text('/ unit MRP', style: AppTypography.caption),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: SoftSecondaryButton(
                    label: isExpanded
                        ? 'Hide Cheaper Brands'
                        : 'Find Cheaper Brands',
                    icon: isExpanded
                        ? Icons.expand_less
                        : Icons.swap_horiz_rounded,
                    height: 36,
                    onPressed: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedAlternatives.remove(med.id);
                        } else {
                          _expandedAlternatives.add(med.id);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                SoftIconButton(
                  icon: Icons.add_shopping_cart_rounded,
                  size: 36,
                  iconSize: 18,
                  iconColor: AppColors.primaryBlue,
                  tooltip: 'Add to Buy List',
                  onPressed: () => _addToBuyList(med),
                ),
              ],
            ),

            // Expandable Generic Alternatives
            if (isExpanded) ...[
              const SizedBox(height: 14),
              FutureBuilder<List<MedicineReference>>(
                future: _searchService.getAlternativesForGeneric(
                  med.genericName,
                  excludeBrandId: med.id,
                ),
                builder: (context, altSnapshot) {
                  if (altSnapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryBlue,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }

                  final alts = altSnapshot.data ?? [];
                  if (alts.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'No other brands found for this exact generic and strength.',
                        style: AppTypography.caption,
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alternative Brands for ${med.genericName}:',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...alts.map(
                        (alt) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurfaceElevated
                                : AppColors.canvas,
                            borderRadius: AppRadii.smallRadius,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      alt.brandName,
                                      style: AppTypography.caption.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      alt.manufacturer ?? 'Bangladesh',
                                      style: AppTypography.caption.copyWith(
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    alt.unitPriceBdt != null
                                        ? _currencyFormat.format(
                                            alt.unitPriceBdt!,
                                          )
                                        : 'N/A',
                                    style: AppTypography.caption.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color:
                                          (alt.unitPriceBdt != null &&
                                              med.unitPriceBdt != null &&
                                              alt.unitPriceBdt! <
                                                  med.unitPriceBdt!)
                                          ? AppColors.success
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SoftIconButton(
                                    icon: Icons.add_shopping_cart_rounded,
                                    size: 28,
                                    iconSize: 14,
                                    onPressed: () => _addToBuyList(alt),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

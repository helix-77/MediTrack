import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/buy_list_item.dart';
import '../models/medicine_reference.dart';
import '../services/buy_list_service.dart';
import '../services/medicine_reference_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class MedicineSearchScreen extends StatefulWidget {
  final String? initialQuery;

  const MedicineSearchScreen({super.key, this.initialQuery});

  @override
  State<MedicineSearchScreen> createState() => _MedicineSearchScreenState();
}

class _MedicineSearchScreenState extends State<MedicineSearchScreen> {
  final MedicineReferenceService _referenceService = MedicineReferenceService();
  final BuyListService _buyListService = BuyListService();
  final TextEditingController _searchController = TextEditingController();
  final NumberFormat _currencyFormat = NumberFormat.currency(
    symbol: '৳ ',
    decimalDigits: 2,
  );

  List<MedicineReference> _results = [];
  bool _isLoading = false;
  String? _selectedGeneric;
  List<MedicineReference> _alternatives = [];
  bool _isLoadingAlternatives = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _searchController.text = widget.initialQuery!;
      _performSearch(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) {
      setState(() {
        _results = [];
        _selectedGeneric = null;
        _alternatives = [];
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final list = await _referenceService.searchMedicines(trimmed);
      setState(() {
        _results = list;
        _selectedGeneric = null;
        _alternatives = [];
      });
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

  Future<void> _showAlternatives(MedicineReference med) async {
    setState(() {
      _selectedGeneric = med.genericName;
      _isLoadingAlternatives = true;
    });

    try {
      final list = await _referenceService.getAlternativesForGeneric(
        med.genericName,
        excludeBrandId: med.id,
      );
      setState(() {
        _alternatives = list;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingAlternatives = false);
    }
  }

  Future<void> _addToBuyList(MedicineReference med) async {
    try {
      final item = BuyListItem(
        id: '',
        name: '${med.brandName} ${med.strength ?? ''}'.trim(),
        quantityToBuy: 1,
        estimatedPrice: med.unitPriceBdt,
        notes: 'Generic: ${med.genericName} (${med.manufacturer ?? 'Pharma'})',
        createdAt: DateTime.now(),
      );
      await _buyListService.saveBuyItem(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${med.brandName} added to Buy List!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not add to Buy List: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Price & Generic Lookup',
          style: AppTypography.headingMedium.copyWith(
            color: AppColors.primaryGreen,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Input Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => _performSearch(val),
              decoration: InputDecoration(
                hintText: 'Search brand or generic (e.g. Napa, Seclo)...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.primaryGreen,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
          ),

          // Disclaimer Banner
          _buildDisclaimerBanner(),

          // Main Results & Alternatives View
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  )
                : _results.isEmpty
                    ? _buildEmptyState()
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Text(
                            'Search Results (${_results.length})',
                            style: AppTypography.headingSmall.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._results.map((med) => _buildMedicineCard(med)),

                          // Cheaper Alternatives Section
                          if (_selectedGeneric != null) ...[
                            const SizedBox(height: 20),
                            _buildAlternativesSection(),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.accentPinkLight.withValues(alpha: 0.6),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.primaryGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Prices shown are manufacturer MRP reference values (MedEx seed), not live pharmacy shelf prices.',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 11,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineCard(MedicineReference med) {
    final hasPrice = med.unitPriceBdt != null;
    final isExpanded = _selectedGeneric == med.genericName;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med.brandName,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Generic: ${med.genericName}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (med.manufacturer != null)
                        Text(
                          'Company: ${med.manufacturer}',
                          style: AppTypography.bodySmall,
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasPrice)
                      Text(
                        _currencyFormat.format(med.unitPriceBdt),
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      )
                    else
                      Text(
                        'Price N/A',
                        style: AppTypography.bodySmall.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (med.dosageForm != null || med.strength != null)
                      Text(
                        '${med.dosageForm ?? ''} ${med.strength ?? ''}'.trim(),
                        style: AppTypography.bodySmall.copyWith(fontSize: 11),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isExpanded
                            ? AppColors.primaryGreen
                            : AppColors.divider,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _showAlternatives(med),
                    icon: const Icon(Icons.compare_arrows, size: 16),
                    label: const Text('Find Cheaper Brands'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Add to Buy List',
                  icon: const Icon(
                    Icons.add_shopping_cart,
                    color: AppColors.primaryGreen,
                  ),
                  onPressed: () => _addToBuyList(med),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlternativesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryGreen.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.savings_outlined,
                color: AppColors.success,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Other brands with $_selectedGeneric (Sorted by price)',
                  style: AppTypography.headingSmall.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingAlternatives)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
            )
          else if (_alternatives.isEmpty)
            const Text('No other brands found for this generic in the database.')
          else
            ..._alternatives.map((alt) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${alt.manufacturer ?? ''} • ${alt.strength ?? ''}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (alt.unitPriceBdt != null)
                      Text(
                        _currencyFormat.format(alt.unitPriceBdt),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      )
                    else
                      const Text('Price N/A', style: TextStyle(fontSize: 11)),
                    IconButton(
                      icon: const Icon(
                        Icons.add_shopping_cart,
                        size: 18,
                        color: AppColors.primaryGreen,
                      ),
                      onPressed: () => _addToBuyList(alt),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.medication_liquid_rounded,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Search Bangladesh Medicine Database',
              style: AppTypography.headingSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Type a medicine brand name or generic name to see manufacturer prices and cheaper generic alternatives.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/foreign_investor_provider.dart';

class FilterChips extends StatelessWidget {
  const FilterChips({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // 시장 필터
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  '시장: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Consumer<ForeignInvestorProvider>(
                  builder: (context, provider, _) {
                    return Wrap(
                    spacing: 8,
                    children: [
                      _buildChoiceChip(
                        context,
                        label: '전체',
                        value: 'ALL',
                        selected: provider.selectedMarket == 'ALL',
                        onSelected: provider.isLoading ? null : (selected) {
                          if (selected) provider.setMarketFilter('ALL');
                        },
                      ),
                      _buildChoiceChip(
                        context,
                        label: 'KOSPI',
                        value: 'KOSPI',
                        selected: provider.selectedMarket == 'KOSPI',
                        onSelected: provider.isLoading ? null : (selected) {
                          if (selected) provider.setMarketFilter('KOSPI');
                        },
                      ),
                      _buildChoiceChip(
                        context,
                        label: 'KOSDAQ',
                        value: 'KOSDAQ',
                        selected: provider.selectedMarket == 'KOSDAQ',
                        onSelected: provider.isLoading ? null : (selected) {
                          if (selected) provider.setMarketFilter('KOSDAQ');
                        },
                      ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 기간 필터
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  '기간: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Consumer<ForeignInvestorProvider>(
                  builder: (context, provider, _) {
                    return Wrap(
                    spacing: 8,
                    children: [
                      _buildChoiceChip(
                        context,
                        label: '1일',
                        value: '1D',
                        selected: provider.selectedDateRange == '1D',
                        onSelected: provider.isLoading ? null : (selected) {
                          if (selected) provider.setDateRange('1D');
                        },
                      ),
                      _buildChoiceChip(
                        context,
                        label: '7일',
                        value: '7D',
                        selected: provider.selectedDateRange == '7D',
                        onSelected: provider.isLoading ? null : (selected) {
                          if (selected) provider.setDateRange('7D');
                        },
                      ),
                      _buildChoiceChip(
                        context,
                        label: '30일',
                        value: '30D',
                        selected: provider.selectedDateRange == '30D',
                        onSelected: provider.isLoading ? null : (selected) {
                          if (selected) provider.setDateRange('30D');
                        },
                      ),
                      _buildChoiceChip(
                        context,
                        label: '3개월',
                        value: '3M',
                        selected: provider.selectedDateRange == '3M',
                        onSelected: provider.isLoading ? null : (selected) {
                          if (selected) provider.setDateRange('3M');
                        },
                      ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip(
    BuildContext context, {
    required String label,
    required String value,
    required bool selected,
    required ValueChanged<bool>? onSelected,
  }) {
    final isDisabled = onSelected == null;
    
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isDisabled 
              ? Colors.grey.shade400
              : selected 
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: isDisabled 
          ? Colors.grey.shade300 
          : Theme.of(context).colorScheme.primary,
      backgroundColor: isDisabled 
          ? Colors.grey.shade100 
          : Theme.of(context).colorScheme.surface,
      side: BorderSide(
        color: isDisabled 
            ? Colors.grey.shade300
            : selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
        width: 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../../app/theme/app_colors.dart';
import '../../../../profile/domain/profile_model.dart';
import '../../../../../core/utils/date_helpers.dart';

class UnequalSplitSheet extends StatefulWidget {
  final List<Profile> profiles;
  final double totalAmount;
  final Map<String, double> initialAmounts;
  final Function(Map<String, double>) onApply;

  const UnequalSplitSheet({
    super.key,
    required this.profiles,
    required this.totalAmount,
    required this.initialAmounts,
    required this.onApply,
  });

  @override
  State<UnequalSplitSheet> createState() => _UnequalSplitSheetState();
}

class _UnequalSplitSheetState extends State<UnequalSplitSheet> {
  bool _isPercentageMode = false;
  final Set<String> _selectedUserIds = {};
  
  // Data maps
  final Map<String, double> _amounts = {};
  final Map<String, double> _percentages = {};
  
  // Controllers
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize selected users and amounts based on non-zero initial values, 
    // or select all by default if map is empty/zeroed out
    bool hasAnyValue = widget.initialAmounts.values.any((v) => v > 0);
    
    for (var prof in widget.profiles) {
      final amt = widget.initialAmounts[prof.userId] ?? 0.0;
      _amounts[prof.userId] = amt;
      _percentages[prof.userId] = widget.totalAmount > 0 
          ? (amt / widget.totalAmount) * 100 
          : 0.0;
      
      if (hasAnyValue) {
        if (amt > 0) _selectedUserIds.add(prof.userId);
      } else {
        _selectedUserIds.add(prof.userId);
      }

      _controllers[prof.userId] = TextEditingController(
        text: amt > 0 ? (amt % 1 == 0 ? amt.toInt().toString() : amt.toStringAsFixed(2)) : '',
      );
    }
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _toggleMode(bool toPercentage) {
    if (_isPercentageMode == toPercentage) return;
    setState(() {
      _isPercentageMode = toPercentage;
      // Update text controllers to reflect the new mode
      for (var entry in _controllers.entries) {
        final userId = entry.key;
        final c = entry.value;
        if (!_selectedUserIds.contains(userId)) {
          c.text = '';
          continue;
        }
        
        if (toPercentage) {
          final pct = _percentages[userId] ?? 0.0;
          c.text = pct > 0 ? (pct % 1 == 0 ? pct.toInt().toString() : pct.toStringAsFixed(1)) : '';
        } else {
          final amt = _amounts[userId] ?? 0.0;
          c.text = amt > 0 ? (amt % 1 == 0 ? amt.toInt().toString() : amt.toStringAsFixed(2)) : '';
        }
      }
    });
  }

  void _onValueChanged(String userId, String val) {
    final parsed = double.tryParse(val) ?? 0.0;
    setState(() {
      if (_isPercentageMode) {
        _percentages[userId] = parsed;
        _amounts[userId] = widget.totalAmount * (parsed / 100);
      } else {
        _amounts[userId] = parsed;
        _percentages[userId] = widget.totalAmount > 0 
            ? (parsed / widget.totalAmount) * 100 
            : 0.0;
      }
    });
  }

  void _toggleSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
        _amounts[userId] = 0.0;
        _percentages[userId] = 0.0;
        _controllers[userId]?.text = '';
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }
  
  void _applySharesToAmounts() {
    // If in percentage mode, just switch to amount mode visually.
    // The amounts are already calculated in real-time.
    _toggleMode(false);
  }

  @override
  Widget build(BuildContext context) {
    double currentTotalAmount = 0.0;
    for (final amt in _amounts.values) {
      currentTotalAmount += amt;
    }
    final remaining = widget.totalAmount - currentTotalAmount;

    double currentTotalPct = 0.0;
    for (final pct in _percentages.values) {
      currentTotalPct += pct;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle and Header
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Unequal split',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Mode Toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _toggleMode(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isPercentageMode ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'By amount',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: !_isPercentageMode ? AppColors.onPrimary : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _toggleMode(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isPercentageMode ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'By shares',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: _isPercentageMode ? AppColors.onPrimary : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // List Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Split Among (Tap to unselect)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    _isPercentageMode ? 'Enter %' : 'Enter Amount',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // User List
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: widget.profiles.length,
                itemBuilder: (context, index) {
                  final prof = widget.profiles[index];
                  final isSelected = _selectedUserIds.contains(prof.userId);
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.surface : AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? AppColors.borderLight : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleSelection(prof.userId),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? AppColors.textPrimary : Colors.transparent,
                              border: Border.all(
                                color: isSelected ? AppColors.textPrimary : AppColors.border,
                                width: 2,
                              ),
                            ),
                            child: isSelected 
                                ? Icon(Icons.check, size: 14, color: AppColors.surface)
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prof.fullName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                ),
                              ),
                              if (_isPercentageMode && isSelected && _amounts[prof.userId]! > 0) ...[
                                const SizedBox(height: 2),
                                  Text(
                                    DateHelpers.formatCurrency(_amounts[prof.userId]!),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                              ]
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _controllers[prof.userId],
                            enabled: isSelected,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.right,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            onChanged: (val) => _onValueChanged(prof.userId, val),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? AppColors.textPrimary : AppColors.textDisabled,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(color: AppColors.textDisabled),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              filled: true,
                              fillColor: AppColors.background,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: AppColors.borderLight),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: AppColors.borderLight),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide(color: AppColors.primaryMuted),
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(color: Colors.transparent),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // Footer Info
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'People: ${_selectedUserIds.length} / ${widget.profiles.length}',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (!_isPercentageMode)
                    Text(
                      remaining.abs() < 0.01 
                          ? 'Total matched' 
                          : remaining > 0 
                              ? 'Remaining: ${DateHelpers.formatCurrency(remaining)}'
                              : 'Over by: ${DateHelpers.formatCurrency(-remaining)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: remaining.abs() < 0.01 
                            ? const Color(0xFF22C55E)
                            : AppColors.error,
                      ),
                    )
                  else
                    Text(
                      'Total: ${currentTotalPct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: (currentTotalPct - 100).abs() < 0.1 
                            ? const Color(0xFF22C55E)
                            : AppColors.error,
                      ),
                    ),
                ],
              ),
            ),
            
            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  if (_isPercentageMode)
                    OutlinedButton(
                      onPressed: _applySharesToAmounts,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Apply shares', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text('amounts', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  if (_isPercentageMode) const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      // Apply final amounts to provider and close
                      widget.onApply(_amounts);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                      elevation: 0,
                    ),
                    child: const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

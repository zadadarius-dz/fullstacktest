import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class StockBadge extends StatelessWidget {
  const StockBadge({
    super.key,
    required this.stock,
    required this.minStock,
  });

  final int stock;
  final int minStock;

  @override
  Widget build(BuildContext context) {
    final isLow = stock <= minStock;
    final background = isLow ? AppColors.warningSoft : AppColors.successSoft;
    final foreground = isLow ? AppColors.warning : AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$stock',
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class TypeBadge extends StatelessWidget {
  const TypeBadge({super.key, required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final isIn = type == 'IN';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isIn ? AppColors.successSoft : AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type,
        style: TextStyle(
          color: isIn ? AppColors.success : AppColors.danger,
          fontWeight: FontWeight.w700,
          fontSize: 11,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

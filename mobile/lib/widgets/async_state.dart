import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message = 'Memuat data...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Terjadi kesalahan',
  });

  final String message;
  final VoidCallback? onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AppColors.danger,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Coba lagi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inventory_2_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InlineMessage extends StatelessWidget {
  const InlineMessage({
    super.key,
    required this.message,
    this.isError = true,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final background = isError ? AppColors.dangerSoft : AppColors.successSoft;
    final foreground = isError ? AppColors.danger : AppColors.success;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: foreground.withAlpha(64)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: foreground,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: foreground, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

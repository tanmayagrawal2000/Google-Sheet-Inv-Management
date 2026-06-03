import 'package:flutter/material.dart';

import '../cubit/data_state.dart';

/// Renders loading / error / empty / content states for a [DataState].
class DataView<T> extends StatelessWidget {
  const DataView({
    super.key,
    required this.state,
    required this.builder,
    required this.onRetry,
    this.isEmpty,
    this.emptyMessage = 'Nothing here yet.',
  });

  final DataState<T> state;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback onRetry;
  final bool Function(T data)? isEmpty;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    switch (state.status) {
      case DataStatus.initial:
      case DataStatus.loading:
        content = const Center(child: CircularProgressIndicator());
      case DataStatus.error:
        content = _ErrorState(
            message: state.error ?? 'Something went wrong.', onRetry: onRetry);
      case DataStatus.ready:
        final data = state.data;
        if (data == null) {
          content = _ErrorState(message: 'No data.', onRetry: onRetry);
        } else if (isEmpty?.call(data) ?? false) {
          content = _EmptyState(message: emptyMessage);
        } else {
          content = builder(context, data);
        }
    }

    return Column(
      children: [
        if (state.refreshing) const LinearProgressIndicator(),
        Expanded(child: content),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

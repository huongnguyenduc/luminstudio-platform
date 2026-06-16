import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lumin_studio_mobile/features/cart/presentation/cubit/cart_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/domain/catalog_product.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/cubit/product_detail_cubit.dart';
import 'package:lumin_studio_mobile/features/catalog/presentation/product_model_viewer.dart';

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<CartCubit, CartState>(
      listenWhen: (previous, current) =>
          previous.message != current.message && current.message != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.message ?? 'Cart updated')),
        );
      },
      child: BlocBuilder<ProductDetailCubit, ProductDetailState>(
        builder: (context, state) {
          final title = state.detail?.name ?? 'Product detail';

          return Scaffold(
            appBar: AppBar(title: Text(title)),
            body: switch (state.status) {
              ProductDetailStatus.initial ||
              ProductDetailStatus.loading => const _ProductDetailLoading(),
              ProductDetailStatus.failure => _ProductDetailFailure(
                message: state.message,
              ),
              ProductDetailStatus.ready => _ProductDetailReady(
                detail: state.detail!,
                selectedMeshColors: state.selectedMeshColors,
              ),
            },
            bottomNavigationBar: state.status == ProductDetailStatus.ready
                ? _ProductDetailBottomBar(
                    detail: state.detail!,
                    selectedMeshColors: state.selectedMeshColors,
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _ProductDetailLoading extends StatelessWidget {
  const _ProductDetailLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: 32,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    );
  }
}

class _ProductDetailFailure extends StatelessWidget {
  const _ProductDetailFailure({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 32),
            const SizedBox(height: 12),
            Text(
              message ?? 'Product detail is unavailable',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: context.read<ProductDetailCubit>().load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductDetailReady extends StatelessWidget {
  const _ProductDetailReady({
    required this.detail,
    required this.selectedMeshColors,
  });

  final CatalogProductDetail detail;
  final Map<String, String> selectedMeshColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Product detail for ${detail.name}',
      child: ListView(
        key: const PageStorageKey<String>('product-detail-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          _ProductDetailHighlights(detail: detail),
          const SizedBox(height: 14),
          _InteractiveModelPanel(detail: detail),
          const SizedBox(height: 18),
          Text(detail.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            _formatMoney(detail.price.amountCents, detail.price.currency),
            key: const ValueKey<String>('product-detail-price'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          if (detail.meshColorConfig.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SelectedConfigurationSummary(
              detail: detail,
              selectedMeshColors: selectedMeshColors,
            ),
            const SizedBox(height: 16),
            Text('Customize color', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Choose a finish before adding this item to your cart.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final options in detail.meshColorConfig) ...[
              _MeshColorOptions(
                options: options,
                selectedColor:
                    selectedMeshColors[options.meshId] ?? options.defaultColor,
              ),
              const SizedBox(height: 10),
            ],
          ],
          const SizedBox(height: 12),
          Text(detail.description, style: theme.textTheme.bodyLarge),
          if (detail.informationSections.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Product information', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final section in detail.informationSections) ...[
              _InformationSection(section: section),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

String _formatMoney(int cents, String currency) {
  final whole = cents ~/ 100;
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return '$currency $whole.$fraction';
}

String _friendlyMeshName(String meshId) {
  final normalized = meshId
      .replaceFirst(RegExp('^mesh_'), '')
      .replaceAll('_', ' ');
  if (normalized.isEmpty) {
    return meshId;
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}

class _InteractiveModelPanel extends StatelessWidget {
  const _InteractiveModelPanel({required this.detail});

  final CatalogProductDetail detail;

  @override
  Widget build(BuildContext context) {
    final modelViewerBuilder = context.read<ProductModelViewerBuilder>();
    final screenHeight = MediaQuery.sizeOf(context).height;
    final panelHeight = (screenHeight * 0.24).clamp(176.0, 224.0);

    return SizedBox(
      key: ValueKey<String>('product-model-panel-${detail.id}'),
      height: panelHeight,
      width: double.infinity,
      child: modelViewerBuilder(context, detail),
    );
  }
}

class _ProductDetailHighlights extends StatelessWidget {
  const _ProductDetailHighlights({required this.detail});

  final CatalogProductDetail detail;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _HighlightChip(
          icon: Icons.view_in_ar,
          label: 'Model tier: ${detail.modelTier.wireName}',
        ),
        if (detail.spriteUri != null)
          const _HighlightChip(
            icon: Icons.threesixty,
            label: '360 preview ready',
          ),
        if (detail.categories.isNotEmpty)
          _HighlightChip(
            icon: Icons.category_outlined,
            label: detail.categories.first.name,
          ),
      ],
    );
  }
}

class _HighlightChip extends StatelessWidget {
  const _HighlightChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _ProductDetailBottomBar extends StatelessWidget {
  const _ProductDetailBottomBar({
    required this.detail,
    required this.selectedMeshColors,
  });

  final CatalogProductDetail detail;
  final Map<String, String> selectedMeshColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedLabel = _selectedChoiceLabels(
      detail,
      selectedMeshColors,
    ).join(' · ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatMoney(
                        detail.price.amountCents,
                        detail.price.currency,
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Text(
                      selectedLabel.isEmpty
                          ? 'Ready to add'
                          : 'Selected $selectedLabel',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              BlocBuilder<CartCubit, CartState>(
                builder: (context, cartState) {
                  return FilledButton.icon(
                    key: const ValueKey<String>('add-selected-product-to-cart'),
                    onPressed: cartState.isMutating
                        ? null
                        : () {
                            context.read<CartCubit>().addProduct(
                              detail,
                              selectedMeshColors,
                            );
                          },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add to cart'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedConfigurationSummary extends StatelessWidget {
  const _SelectedConfigurationSummary({
    required this.detail,
    required this.selectedMeshColors,
  });

  final CatalogProductDetail detail;
  final Map<String, String> selectedMeshColors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = _selectedChoiceLabels(detail, selectedMeshColors);

    return Semantics(
      label: labels.isEmpty
          ? 'No product configuration selected'
          : 'Selected configuration ${labels.join(', ')}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Selected finish', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (labels.isEmpty)
                    Text(
                      'Standard configuration',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    for (final label in labels)
                      _SelectedConfigurationChip(label: label),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedConfigurationChip extends StatelessWidget {
  const _SelectedConfigurationChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(label, style: theme.textTheme.labelMedium),
      ),
    );
  }
}

class _InformationSection extends StatelessWidget {
  const _InformationSection({required this.section});

  final CatalogInformationSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 6),
          Text(section.body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

List<String> _selectedChoiceLabels(
  CatalogProductDetail detail,
  Map<String, String> selectedMeshColors,
) {
  return [
    for (final options in detail.meshColorConfig)
      '${_friendlyMeshName(options.meshId)} ${selectedMeshColors[options.meshId] ?? options.defaultColor}',
  ];
}

class _MeshColorOptions extends StatelessWidget {
  const _MeshColorOptions({required this.options, required this.selectedColor});

  final CatalogMeshColorOptions options;
  final String selectedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _friendlyMeshName(options.meshId),
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in options.allowedColors)
                _ColorSwatch(
                  meshId: options.meshId,
                  color: color,
                  isDefault: color == options.defaultColor,
                  isSelected: color == selectedColor,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.meshId,
    required this.color,
    required this.isDefault,
    required this.isSelected,
  });

  final String meshId;
  final String color;
  final bool isDefault;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = _parseHexColor(color);
    final swatchColor = parsed == null
        ? theme.colorScheme.surface
        : Color(0xFF000000 | parsed);
    final iconColor = _iconColorFor(swatchColor);
    final label =
        '$meshId color $color${isDefault ? ' default' : ''}${isSelected ? ' selected' : ''}';

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          key: ValueKey<String>('mesh-color-$meshId-$color'),
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            context.read<ProductDetailCubit>().selectMeshColor(meshId, color);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: swatchColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.26,
                        ),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(Icons.check, size: 18, color: iconColor)
                : null,
          ),
        ),
      ),
    );
  }

  int? _parseHexColor(String value) {
    final normalized = value.startsWith('#') ? value.substring(1) : value;
    if (normalized.length != 6) {
      return null;
    }
    return int.tryParse(normalized, radix: 16);
  }

  Color _iconColorFor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
}

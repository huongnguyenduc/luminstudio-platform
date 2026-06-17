import 'package:flutter/material.dart';

const _spriteFrameCount = 24;
const _spriteColumns = 6;
const _spriteRows = 4;
const _subtlePreviewFrames = <int>[0, 1, 2, 1, 0, 23, 22, 23];

class CatalogSpriteFrame extends StatelessWidget {
  const CatalogSpriteFrame({
    required this.uri,
    required this.productName,
    this.frame = 0,
    super.key,
  });

  final Uri uri;
  final String productName;
  final int frame;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Product image frame for $productName',
      child: _CroppedSpriteFrame(uri: uri, frame: frame),
    );
  }
}

class CatalogSubtleSpritePreview extends StatefulWidget {
  const CatalogSubtleSpritePreview({
    required this.uri,
    required this.productName,
    super.key,
  });

  final Uri uri;
  final String productName;

  @override
  State<CatalogSubtleSpritePreview> createState() =>
      _CatalogSubtleSpritePreviewState();
}

class _CatalogSubtleSpritePreviewState extends State<CatalogSubtleSpritePreview>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Subtle 360 preview active for ${widget.productName}',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final sequenceIndex =
              (_controller.value * _subtlePreviewFrames.length).floor() %
              _subtlePreviewFrames.length;
          return _CroppedSpriteFrame(
            uri: widget.uri,
            frame: _subtlePreviewFrames[sequenceIndex],
          );
        },
      ),
    );
  }
}

class _CroppedSpriteFrame extends StatelessWidget {
  const _CroppedSpriteFrame({required this.uri, required this.frame});

  final Uri uri;
  final int frame;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedFrame = frame.clamp(0, _spriteFrameCount - 1);
    final column = normalizedFrame % _spriteColumns;
    final row = normalizedFrame ~/ _spriteColumns;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        return ClipRect(
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: -width * column,
                top: -height * row,
                width: width * _spriteColumns,
                height: height * _spriteRows,
                child: Image.network(
                  uri.toString(),
                  fit: BoxFit.fill,
                  errorBuilder: (context, error, stackTrace) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer.withValues(
                        alpha: 0.48,
                      ),
                    ),
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

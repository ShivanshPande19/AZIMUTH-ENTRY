import 'package:flutter/material.dart';

import '../services/visitor_service.dart';
import '../theme.dart';

/// A rounded-square avatar for a visitor.
///
/// Shows the visitor's photo (from the `visitor-photos` bucket) when one exists,
/// otherwise falls back to coloured initials — matching the app's existing
/// avatar style. Designed to be light on older devices:
///   * the thumbnail is decoded at the display size via [Image.network]'s
///     `cacheWidth`, so full-size images never sit in memory;
///   * while loading or on error it simply shows the initials, so the list
///     never blocks or janks waiting on the network.
///
/// Tapping (when [enableView] is true and a photo exists) opens a full-size,
/// pinch-to-zoom preview.
class VisitorAvatar extends StatelessWidget {
  const VisitorAvatar({
    super.key,
    required this.name,
    this.photoPath,
    this.size = 46,
    this.enableView = true,
  });

  final String name;
  final String? photoPath;
  final double size;
  final bool enableView;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = avatarColor(name, scheme);
    final radius = size * 0.3;

    final initials = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        initialsOf(name),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
        ),
      ),
    );

    final url = VisitorService().photoUrl(photoPath);
    if (url == null) return initials;

    // Decode at (roughly) the on-screen pixel size to keep memory tiny.
    final cacheW = (size * MediaQuery.of(context).devicePixelRatio).round();

    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: cacheW,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : initials,
        errorBuilder: (context, error, stack) => initials,
      ),
    );

    if (!enableView) return thumb;
    return GestureDetector(
      onTap: () => _showFullImage(context, url),
      child: thumb,
    );
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius),
                child: InteractiveViewer(
                  maxScale: 4,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) => progress ==
                            null
                        ? child
                        : const SizedBox(
                            height: 220,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                    errorBuilder: (context, error, stack) => const SizedBox(
                      height: 220,
                      child: Center(
                        child: Icon(Icons.broken_image_outlined,
                            color: Colors.white70, size: 48),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            IconButton.filledTonal(
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

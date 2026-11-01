import 'package:flutter/material.dart';

import '../../core/icons.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/photo_store.dart';
import 'common.dart';

/// One stock row: thumbnail, name, quantity, status, and inline +/- so a
/// routine single-unit change needs no navigation.
class ItemTile extends StatelessWidget {
  const ItemTile({
    super.key,
    required this.item,
    required this.s,
    required this.categoryIconKey,
    required this.onTap,
    this.onPlus,
    this.onMinus,
  });

  final Item item;
  final S s;
  final String categoryIconKey;
  final VoidCallback onTap;
  final VoidCallback? onPlus;
  final VoidCallback? onMinus;

  @override
  Widget build(BuildContext context) {
    final sub = item.subtitle();
    final fg = statusFg(item.status);

    return Material(
      color: AppTheme.card,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: AppTheme.rowHeight),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Thumb(
                icon: AppIcons.forCategory(categoryIconKey),
                file: PhotoStore.file(item.photoPath),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppTheme.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    StatusPill(
                      status: item.status,
                      label: statusLabel(item.status, s),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 42,
                child: Text(
                  '${item.quantity}',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
              if (onMinus != null || onPlus != null) ...[
                const SizedBox(width: 6),
                _Quick(
                  icon: AppIcons.minus,
                  onTap: item.quantity > 0 ? onMinus : null,
                ),
                const SizedBox(width: 6),
                _Quick(icon: AppIcons.add, onTap: onPlus),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? AppTheme.surface : AppTheme.surface.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: 38,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: AppTheme.line),
          ),
          child: Icon(
            icon,
            size: 19,
            color: enabled ? AppTheme.text : AppTheme.line,
          ),
        ),
      ),
    );
  }
}

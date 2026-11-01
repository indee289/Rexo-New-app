import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/repository.dart';
import 'widgets/common.dart';
import 'widgets/qty_sheet.dart';

/// Single place where a stock change is applied, so every entry point
/// (dashboard, stock list, low stock, item detail) behaves identically.
Future<void> changeStock(
  BuildContext context,
  AppRepo repo,
  Item item, {
  required bool isIn,
}) async {
  final s = repo.s;
  final result = await QtySheet.show(
    context,
    s: s,
    isIn: isIn,
    itemName: item.name,
    currentQuantity: item.quantity,
  );
  if (result == null) return;

  try {
    await repo.applyMovement(
      itemId: item.id,
      delta: isIn ? result.quantity : -result.quantity,
      reason: result.reason,
      note: result.note,
    );
    if (context.mounted) showSnack(context, s.saved);
  } on NotEnoughStock catch (e) {
    if (context.mounted) showSnack(context, '${s.notEnough} (${e.available})');
  }
}

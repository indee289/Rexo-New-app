import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/icons.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models.dart';

class QtyResult {
  const QtyResult(this.quantity, this.reason, this.note);
  final int quantity;
  final MovementReason reason;
  final String? note;
}

/// Bottom sheet for a stock in or stock out. Quantity defaults to 1 and the
/// reason is pre-selected, so the common case is one tap on Save.
class QtySheet extends StatefulWidget {
  const QtySheet({
    super.key,
    required this.s,
    required this.isIn,
    required this.itemName,
    required this.currentQuantity,
  });

  final S s;
  final bool isIn;
  final String itemName;
  final int currentQuantity;

  static Future<QtyResult?> show(
    BuildContext context, {
    required S s,
    required bool isIn,
    required String itemName,
    required int currentQuantity,
  }) {
    return showModalBottomSheet<QtyResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => QtySheet(
        s: s,
        isIn: isIn,
        itemName: itemName,
        currentQuantity: currentQuantity,
      ),
    );
  }

  @override
  State<QtySheet> createState() => _QtySheetState();
}

class _QtySheetState extends State<QtySheet> {
  late final TextEditingController _qty = TextEditingController(text: '1');
  late final TextEditingController _note = TextEditingController();
  late MovementReason _reason =
      widget.isIn ? MovementReason.purchase : MovementReason.sale;
  bool _showNote = false;

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  int get _value => int.tryParse(_qty.text.trim()) ?? 0;

  void _bump(int by) {
    final next = (_value + by).clamp(1, 99999);
    _qty.text = '$next';
    setState(() {});
  }

  int get _resulting => widget.isIn
      ? widget.currentQuantity + _value
      : widget.currentQuantity - _value;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final tint = widget.isIn ? AppTheme.ok : AppTheme.low;
    final tooMany = !widget.isIn && _value > widget.currentQuantity;
    final valid = _value > 0 && !tooMany;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.line,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  widget.isIn ? AppIcons.stockIn : AppIcons.stockOut,
                  color: tint,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${widget.currentQuantity}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                _StepButton(
                  icon: AppIcons.minus,
                  onTap: () => _bump(-1),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _qty,
                    textAlign: TextAlign.center,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: tint,
                    ),
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _StepButton(icon: AppIcons.add, onTap: () => _bump(1)),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                tooMany
                    ? '${s.notEnough} (${widget.currentQuantity})'
                    : '${widget.currentQuantity}  →  $_resulting',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: tooMany ? AppTheme.low : AppTheme.muted,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in MovementReason.forDirection(widget.isIn))
                  ChoiceChip(
                    label: Text(r.label(s)),
                    selected: _reason == r,
                    onSelected: (_) => setState(() => _reason = r),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_showNote)
              TextField(
                controller: _note,
                decoration: InputDecoration(hintText: s.note),
                textInputAction: TextInputAction.done,
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _showNote = true),
                  icon: const Icon(AppIcons.note, size: 18),
                  label: Text(s.note),
                ),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: tint,
                minimumSize: const Size.fromHeight(AppTheme.qtyButtonHeight),
              ),
              onPressed: valid
                  ? () => Navigator.pop(
                        context,
                        QtyResult(
                          _value,
                          _reason,
                          _note.text.trim().isEmpty ? null : _note.text.trim(),
                        ),
                      )
                  : null,
              icon: const Icon(AppIcons.save),
              label: Text(s.save),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.line),
          ),
          child: Icon(icon, size: 26),
        ),
      ),
    );
  }
}

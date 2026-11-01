import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/icons.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/photo_store.dart';
import '../data/repository.dart';
import 'item_detail_screen.dart';
import 'widgets/common.dart';

class ItemFormScreen extends StatefulWidget {
  const ItemFormScreen({super.key, this.item});

  /// Null when adding, set when editing.
  final Item? item;

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _location = TextEditingController();
  final _note = TextEditingController();
  final _opening = TextEditingController(text: '0');
  final _min = TextEditingController();

  String? _categoryId;
  String? _photoPath;
  bool _photoCleared = false;
  String? _nameError;
  Item? _duplicate;
  bool _saving = false;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    if (item != null) {
      _name.text = item.name;
      _brand.text = item.brand ?? '';
      _model.text = item.model ?? '';
      _location.text = item.location ?? '';
      _note.text = item.note ?? '';
      _min.text = '${item.minStock}';
      _categoryId = item.categoryId;
      _photoPath = item.photoPath;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _model.dispose();
    _location.dispose();
    _note.dispose();
    _opening.dispose();
    _min.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepo>();
    final s = repo.s;
    _categoryId ??= repo.fallbackCategory.id;
    if (_min.text.isEmpty) _min.text = '${repo.defaultMinStock}';

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? s.edit : s.addItem)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          Center(child: _photoPicker(repo)),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: s.name,
              prefixIcon: const Icon(AppIcons.stock, size: 20),
              errorText: _nameError,
            ),
            onChanged: (_) {
              if (_nameError != null || _duplicate != null) {
                setState(() {
                  _nameError = null;
                  _duplicate = null;
                });
              }
            },
            onEditingComplete: () {
              _checkDuplicate(repo);
              FocusScope.of(context).nextFocus();
            },
          ),
          if (_duplicate != null) _duplicateBanner(repo),
          const SizedBox(height: 14),
          SectionTitle(icon: AppIcons.category, text: s.category),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in repo.categories)
                ChoiceChip(
                  avatar: Icon(AppIcons.forCategory(c.iconKey), size: 16),
                  label: Text(c.name(s)),
                  selected: _categoryId == c.id,
                  onSelected: (_) => setState(() => _categoryId = c.id),
                ),
              ActionChip(
                avatar: const Icon(AppIcons.add, size: 16),
                label: Text(s.newCategory),
                onPressed: () => _newCategory(repo),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _suggestions(repo.brands, _brand),
          TextField(
            controller: _brand,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: s.brand,
              prefixIcon: const Icon(AppIcons.brand, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          _suggestions(repo.models, _model),
          TextField(
            controller: _model,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: s.model,
              prefixIcon: const Icon(AppIcons.model, size: 20),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (!_isEdit)
                Expanded(
                  child: _NumField(
                    label: s.qty,
                    icon: AppIcons.quantity,
                    controller: _opening,
                  ),
                ),
              if (!_isEdit) const SizedBox(width: 12),
              Expanded(
                child: _NumField(
                  label: s.minQty,
                  icon: AppIcons.lowStock,
                  controller: _min,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _location,
            decoration: InputDecoration(
              labelText: s.shelf,
              prefixIcon: const Icon(AppIcons.shelf, size: 20),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _note,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: s.note,
              prefixIcon: const Icon(AppIcons.note, size: 20),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: FilledButton.icon(
            onPressed: _saving ? null : () => _save(repo),
            icon: const Icon(AppIcons.save),
            label: Text(s.save),
          ),
        ),
      ),
    );
  }

  Widget _suggestions(List<String> options, TextEditingController target) {
    if (options.isEmpty) return const SizedBox.shrink();
    final shown = options.take(10).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final o in shown)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ActionChip(
                  label: Text(o, style: const TextStyle(fontSize: 13)),
                  onPressed: () => setState(() => target.text = o),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _photoPicker(AppRepo repo) {
    final s = repo.s;
    final file = _photoCleared ? null : PhotoStore.file(_photoPath);
    return Column(
      children: [
        GestureDetector(
          onTap: () => _photoOptions(repo),
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: file == null
                ? const Icon(AppIcons.camera, size: 32, color: AppTheme.muted)
                : Image.file(file, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          s.photo,
          style: const TextStyle(fontSize: 13, color: AppTheme.muted),
        ),
      ],
    );
  }

  Future<void> _photoOptions(AppRepo repo) async {
    final s = repo.s;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(AppIcons.camera),
              title: Text(s.camera),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(AppIcons.photo),
              title: Text(s.gallery),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (_photoPath != null && !_photoCleared)
              ListTile(
                leading: const Icon(AppIcons.delete, color: AppTheme.low),
                title: Text(s.remove),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return;

    if (choice == 'remove') {
      setState(() {
        _photoCleared = true;
      });
      return;
    }
    try {
      final path = await PhotoStore.pick(
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
      if (path != null) {
        setState(() {
          _photoPath = path;
          _photoCleared = false;
        });
      }
    } catch (_) {
      if (mounted) showSnack(context, s.error);
    }
  }

  Future<void> _newCategory(AppRepo repo) async {
    final s = repo.s;
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.newCategory),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(hintText: s.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(s.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    final cat = await repo.addCategory(name);
    if (mounted) setState(() => _categoryId = cat.id);
  }

  void _checkDuplicate(AppRepo repo) {
    final found = repo.findDuplicate(
      name: _name.text,
      brand: _brand.text,
      model: _model.text,
      excludeId: widget.item?.id,
    );
    if (found != null) setState(() => _duplicate = found);
  }

  Widget _duplicateBanner(AppRepo repo) {
    final s = repo.s;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppTheme.lowBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.info, size: 18, color: AppTheme.low),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.duplicate,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.low,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final id = _duplicate!.id;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => ItemDetailScreen(itemId: id)),
              );
            },
            child: Text(s.open),
          ),
        ],
      ),
    );
  }

  Future<void> _save(AppRepo repo) async {
    final s = repo.s;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = s.nameRequired);
      return;
    }

    setState(() => _saving = true);
    final minStock = int.tryParse(_min.text.trim()) ?? repo.defaultMinStock;

    try {
      if (_isEdit) {
        await repo.updateItem(
          widget.item!,
          name: name,
          categoryId: _categoryId!,
          brand: _brand.text,
          model: _model.text,
          minStock: minStock,
          photoPath: _photoPath,
          clearPhoto: _photoCleared,
          location: _location.text,
          note: _note.text,
        );
        if (mounted) {
          showSnack(context, s.saved);
          Navigator.pop(context);
        }
      } else {
        final created = await repo.addItem(
          name: name,
          categoryId: _categoryId!,
          brand: _brand.text,
          model: _model.text,
          openingQuantity: int.tryParse(_opening.text.trim()) ?? 0,
          minStock: minStock,
          photoPath: _photoCleared ? null : _photoPath,
          location: _location.text,
          note: _note.text,
        );
        if (mounted) {
          showSnack(context, s.saved);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ItemDetailScreen(itemId: created.id),
            ),
          );
        }
      }
    } on DuplicateItem catch (e) {
      if (mounted) setState(() => _duplicate = e.existing);
    } catch (_) {
      if (mounted) showSnack(context, s.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _NumField extends StatelessWidget {
  const _NumField({
    required this.label,
    required this.icon,
    required this.controller,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;

  void _bump(int by) {
    final value = (int.tryParse(controller.text.trim()) ?? 0) + by;
    controller.text = '${value < 0 ? 0 : value}';
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(AppIcons.minus, size: 18),
              onPressed: () => _bump(-1),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(AppIcons.add, size: 18),
              onPressed: () => _bump(1),
            ),
          ],
        ),
      ),
    );
  }
}

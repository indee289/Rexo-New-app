import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_info.dart';
import '../core/formatters.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../data/backup_service.dart';
import '../data/repository.dart';
import '../services/exports.dart';
import '../services/notifications.dart';
import '../services/sheets_sync.dart';
import 'widgets/common.dart';
import 'widgets/sync_chip.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _shop = TextEditingController();
  Timer? _shopDebounce;
  bool _busy = false;
  bool _initialised = false;

  @override
  void dispose() {
    _shopDebounce?.cancel();
    _shop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepo>();
    final sync = context.read<SheetsSync>();
    final s = repo.s;
    if (!_initialised) {
      _shop.text = repo.shopName;
      _initialised = true;
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 40),
        children: [
          _card([
            TextField(
              controller: _shop,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: s.shopName,
                prefixIcon: const Icon(AppIcons.shop, size: 20),
              ),
              onChanged: (v) {
                _shopDebounce?.cancel();
                _shopDebounce = Timer(
                  const Duration(milliseconds: 500),
                  () => repo.setSetting('shop_name', v.trim()),
                );
              },
            ),
          ]),
          const SizedBox(height: 14),
          SectionTitle(icon: AppIcons.language, text: s.language),
          _card([
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'hi', label: Text('हिंदी')),
                ButtonSegment(value: 'en', label: Text('English')),
              ],
              selected: {repo.languageCode},
              onSelectionChanged: (v) => repo.setLanguage(v.first),
            ),
          ]),
          const SizedBox(height: 14),
          SectionTitle(icon: AppIcons.lowStock, text: s.defaultMin),
          _card([
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${repo.defaultMinStock}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton.outlined(
                  icon: const Icon(AppIcons.minus),
                  onPressed: repo.defaultMinStock > 0
                      ? () => repo.setSetting(
                            'default_min_stock',
                            '${repo.defaultMinStock - 1}',
                          )
                      : null,
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  icon: const Icon(AppIcons.add),
                  onPressed: () => repo.setSetting(
                    'default_min_stock',
                    '${repo.defaultMinStock + 1}',
                  ),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 14),
          SectionTitle(icon: AppIcons.reminder, text: s.reminder),
          _card([
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: repo.reminderEnabled,
              title: Text(s.reminder),
              onChanged: (on) => _toggleReminder(repo, on),
            ),
            if (repo.reminderEnabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(AppIcons.history),
                title: Text(s.time),
                trailing: Text(
                  _timeText(repo.reminderHour, repo.reminderMinute),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onTap: () => _pickTime(repo),
              ),
          ]),
          const SizedBox(height: 14),
          SectionTitle(icon: AppIcons.cloud, text: s.sheetSync),
          _card(_syncSection(repo, sync)),
          const SizedBox(height: 14),
          SectionTitle(icon: AppIcons.backup, text: s.backup),
          _card([
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.backup),
              title: Text(s.backup),
              trailing: const Icon(AppIcons.share, size: 18),
              onTap: _busy ? null : () => _backup(repo),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.restore),
              title: Text(s.restore),
              subtitle: Text(
                s.restoreConfirm,
                style: const TextStyle(fontSize: 13),
              ),
              onTap: _busy ? null : () => _restore(repo),
            ),
          ]),
          const SizedBox(height: 14),
          SectionTitle(icon: AppIcons.info, text: s.about),
          _card([
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.info),
              title: Text(s.version),
              trailing: const Text(
                appVersion,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.quantity),
              title: Text(s.qtyOnly),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(AppIcons.sync),
              title: Text(s.fixCounts),
              onTap: () async {
                final fixed = await repo.recomputeQuantities();
                if (context.mounted) {
                  showSnack(context, '${s.done}  $fixed');
                }
              },
            ),
          ]),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      );

  String _timeText(int hour, int minute) {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour < 12 ? 'AM' : 'PM';
    return '$h:${minute.toString().padLeft(2, '0')} $suffix';
  }

  List<Widget> _syncSection(AppRepo repo, SheetsSync sync) {
    final s = repo.s;
    final state = repo.sync;

    if (!state.connected) {
      return [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            s.syncNote,
            style: const TextStyle(fontSize: 13.5, color: AppTheme.muted),
          ),
        ),
        FilledButton.icon(
          onPressed: _busy ? null : () => _connect(repo, sync),
          icon: const Icon(AppIcons.connect),
          label: Text(s.connect),
        ),
      ];
    }

    return [
      const Align(alignment: Alignment.centerLeft, child: SyncChip()),
      const SizedBox(height: 10),
      if ((state.accountEmail ?? '').isNotEmpty)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(AppIcons.cloud),
          title: Text(
            state.accountEmail!,
            style: const TextStyle(fontSize: 15),
          ),
          subtitle: Text(
            '${s.synced}: ${Fmt.ago(state.lastSuccessAt, s)}',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      const Divider(height: 1),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(AppIcons.open),
        title: Text(s.openSheet),
        onTap: () => _openSheet(repo),
      ),
      const Divider(height: 1),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(AppIcons.sync),
        title: Text(s.syncNow),
        onTap: () {
          sync.pushNow(manual: true);
          showSnack(context, s.making);
        },
      ),
      const Divider(height: 1),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(AppIcons.disconnect, color: AppTheme.low),
        title: Text(
          s.disconnect,
          style: const TextStyle(color: AppTheme.low),
        ),
        onTap: () async {
          final yes = await confirm(
            context,
            title: s.disconnect,
            detail: s.sheetSync,
            yes: s.disconnect,
            cancel: s.cancel,
          );
          if (!yes) return;
          await sync.disconnect();
          if (context.mounted) showSnack(context, s.done);
        },
      ),
    ];
  }

  Future<void> _connect(AppRepo repo, SheetsSync sync) async {
    final s = repo.s;
    setState(() => _busy = true);
    final error = await sync.connect();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error == null) {
      showSnack(context, s.done);
    } else {
      showSnack(context, syncErrorMessage(error, s));
    }
  }

  Future<void> _openSheet(AppRepo repo) async {
    final url = repo.sync.spreadsheetUrl;
    final s = repo.s;
    if (url == null || url.isEmpty) return;
    try {
      final ok = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!ok) throw Exception('no handler');
    } catch (_) {
      // No browser available: leave the owner with the link in hand.
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) showSnack(context, s.done);
    }
  }

  Future<void> _toggleReminder(AppRepo repo, bool on) async {
    final s = repo.s;
    if (!on) {
      await Reminders.cancel();
      await repo.setSetting('reminder_enabled', '0');
      return;
    }
    final granted = await Reminders.requestPermission();
    if (!granted) {
      if (mounted) showSnack(context, s.error);
      return;
    }
    final ok = await Reminders.scheduleDaily(
      hour: repo.reminderHour,
      minute: repo.reminderMinute,
      lowCount: repo.totals.lowCount,
      outCount: repo.totals.outCount,
      s: s,
    );
    await repo.setSetting('reminder_enabled', ok ? '1' : '0');
    if (!ok && mounted) showSnack(context, s.error);
  }

  Future<void> _pickTime(AppRepo repo) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: repo.reminderHour,
        minute: repo.reminderMinute,
      ),
    );
    if (picked == null) return;
    await repo.setSetting('reminder_hour', '${picked.hour}');
    await repo.setSetting('reminder_minute', '${picked.minute}');
    await Reminders.scheduleDaily(
      hour: picked.hour,
      minute: picked.minute,
      lowCount: repo.totals.lowCount,
      outCount: repo.totals.outCount,
      s: repo.s,
    );
  }

  Future<void> _backup(AppRepo repo) async {
    final s = repo.s;
    setState(() => _busy = true);
    try {
      final file = await BackupService.create(repo);
      await ExportFiles.share(file, subject: s.backup);
    } catch (_) {
      if (mounted) showSnack(context, s.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(AppRepo repo) async {
    final s = repo.s;
    final yes = await confirm(
      context,
      title: s.restore,
      detail: s.restoreConfirm,
      yes: s.restore,
      cancel: s.cancel,
    );
    if (!yes) return;

    setState(() => _busy = true);
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false,
      );
      final path = picked?.files.single.path;
      if (path == null) return;
      final result = await BackupService.restore(repo, File(path));
      if (!mounted) return;
      showSnack(
        context,
        result.ok ? '${s.done}  ${result.itemCount}' : s.error,
      );
    } catch (_) {
      if (mounted) showSnack(context, s.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

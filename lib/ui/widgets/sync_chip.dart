import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/icons.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/repository.dart';
import '../../services/sheets_sync.dart';

/// Plain-language message for a stored sync error code.
String syncErrorMessage(String? code, S repoStrings) {
  switch (code) {
    case SyncErrorCode.offline:
      return repoStrings.syncOffline;
    case SyncErrorCode.auth:
      return repoStrings.tokenExpired;
    case SyncErrorCode.notFound:
      return repoStrings.sheetMissing;
    case SyncErrorCode.busy:
      return repoStrings.googleBusy;
    default:
      return repoStrings.syncError;
  }
}

/// Sync status. Never blocks anything, and only appears once sync is set up.
class SyncChip extends StatelessWidget {
  const SyncChip({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<AppRepo>();
    final sync = context.read<SheetsSync>();
    final state = repo.sync;
    final s = repo.s;
    if (!state.connected) return const SizedBox.shrink();

    final hasError = (state.lastErrorCode ?? '').isNotEmpty;
    final pending = state.pendingCount > 0;

    late final Color fg;
    late final Color bg;
    late final IconData icon;
    late final String text;

    if (hasError) {
      fg = AppTheme.low;
      bg = AppTheme.lowBg;
      icon = AppIcons.lowStock;
      text = syncErrorMessage(state.lastErrorCode, s);
    } else if (pending) {
      fg = const Color(0xFFB45309);
      bg = const Color(0xFFFEF3C7);
      icon = AppIcons.sync;
      text = '${s.pending} ${state.pendingCount}';
    } else {
      fg = AppTheme.ok;
      bg = AppTheme.okBg;
      icon = AppIcons.cloud;
      text = '${s.synced} · ${Fmt.ago(state.lastSuccessAt, s)}';
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => sync.pushNow(manual: true),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
              if (hasError) ...[
                const SizedBox(width: 6),
                Icon(AppIcons.sync, size: 15, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

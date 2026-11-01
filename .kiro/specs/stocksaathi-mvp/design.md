# StockSaathi - Design (Phase 1 / MVP)

Companion to `requirements.md`. This document covers the locked decisions, architecture, data model, sync mechanism, screen designs, and export layouts.

## 1. Architecture at a glance

```
┌──────────────────────────────────────────────┐
│ UI layer (Flutter widgets, per screen)       │
│ Hindi/English via localisation layer         │
├──────────────────────────────────────────────┤
│ State layer (Riverpod providers)             │
│ Reactive streams from the database           │
├──────────────────────────────────────────────┤
│ Domain layer                                 │
│ ItemService · MovementService ·              │
│ ExportService · SyncService                  │
├──────────────────────────────────────────────┤
│ Data layer                                   │
│ Drift (SQLite) = single source of truth      │
│ secure storage (tokens) · file store (photos)│
├──────────────────────────────────────────────┤
│ Outbound only: Google Sheets API             │
│ (never reads stock values back)              │
└──────────────────────────────────────────────┘
```

The local SQLite database is the single source of truth. The UI reads from it through reactive streams, so a write updates every screen without manual refresh. Sync is a background consumer of the database; it is never in the path of a user action.

## 2. Locked decisions

Five open questions were resolved in favour of the lowest-risk option. Each entry records what was rejected and why, so the trade-off is visible later.

### 2.1 Sync direction: one-way (app to Sheet)

The Sheet is a read-only mirror. Rejected: two-way sync, because the same item edited both on the phone and in the Sheet requires a conflict-resolution policy, per-field change tracking, and a merge UI. That is the single largest source of data-loss bugs in this kind of app, and it would dominate the MVP schedule.

Consequence to communicate in the UI: a banner on every tab, and a line in Settings stating that Sheet edits get overwritten.

### 2.2 Google scope: non-sensitive per-file access, app creates the spreadsheet

The app requests `https://www.googleapis.com/auth/drive.file` only, and creates the spreadsheet itself. This scope grants access on a per-file basis, limited to files the app created or the user explicitly picked, and Google classifies it as non-sensitive, so it does not trigger the sensitive-scope verification process.

Rejected: the broad `spreadsheets` scope with a "paste your Sheet link" flow. That scope is classified as sensitive, and a public app requesting sensitive scopes has to complete Google's verification review before release, which can add weeks of unpredictable delay to launch. That is exactly the launch risk we are avoiding.

Product consequence, and it is a real one: the "paste a link to my existing Sheet" flow from the original plan is dropped. The app creates a fresh spreadsheet instead. Owners who want their own sheet can still use Excel export.

Sources: [Google Sheets API scopes](https://developers.google.com/sheets/api/scopes), [Google Drive API scopes](https://developers.google.com/workspace/drive/api/guides/api-specific-auth), [OAuth app verification overview](https://developers.google.com/identity/protocols/oauth2/production-readiness/overview). Content was rephrased for compliance with licensing restrictions.

### 2.3 No backend in Phase 1, but a sync-ready schema

Phase 1 ships with local SQLite only. No Firebase, no Supabase, no servers, no accounts of ours. That removes hosting cost, auth complexity, a privacy-policy surface, and an outage class.

The rewrite risk this normally creates is defused in the schema rather than in infrastructure. Every table uses a UUID primary key (not an autoincrement int), carries `updated_at` and `deleted_at`, and records the originating `device_id`. The movement ledger is append-only. Adding a backend in Phase 2 for staff logins and multi-shop therefore becomes additive work (a new sync target consuming the same ledger) rather than a schema migration across live user data.

Rejected: adding Supabase in Phase 1. It is the right call if staff logins were in Phase 1, but they are not, and it would widen the MVP for a Phase 2 benefit.

### 2.4 Reason codes on every movement, from the first version

Adding `reason` later would mean a migration over existing movement rows with no way to backfill the truth. It costs one dropdown now, so it ships now. Without it, history cannot distinguish a sale from a breakage, which is most of history's value in a no-price app.

### 2.5 OneDrive / Excel Online sync moved to Phase 2

A second OAuth stack (Microsoft Entra app registration, Graph permissions, separate consent and token handling) for a minority of users. Excel export already serves them in Phase 1.

### 2.6 Supporting low-risk choices

| Choice | Why |
|---|---|
| Sync pushes a **full snapshot** of the `Stock` tab, not incremental row patches | Idempotent and self-healing. A partial failure cannot leave the Sheet with mismatched rows, and there is no row-index mapping to drift out of sync. |
| `History` tab appends only, driven by a monotonic local cursor | Append is the only operation, so a retry can at worst duplicate nothing: the cursor advances only after a confirmed write. |
| Quantity stored as a cached column, derived from the movement ledger | Fast list queries, with a ledger that can always recompute the truth. A debug action recomputes all cached quantities. |
| Photos stay on-device, never uploaded | No Drive storage quota handling, no upload failure states, no image-privacy surface. The Sheet gets no photo column. |
| Undo appends a reversing movement | The ledger stays immutable, so history is always auditable and sync never has to delete a row. |
| PDF and Excel generated fully on-device | Works offline, no server, no document leaving the device unless shared. |
| No analytics or ad SDK | Keeps the Play Data Safety declaration honest and minimal. |

## 3. Tech stack

Pin exact versions with `flutter pub add` at setup time; the latest Flutter stable as of October 2026 is the 3.47.x line.

| Concern | Choice | Notes |
|---|---|---|
| Framework | Flutter (stable channel), Dart | Android first, iOS from the same codebase later |
| Local database | `drift` on SQLite | Type-safe queries, reactive streams, first-class migrations |
| State management | `riverpod` | Composes cleanly with Drift streams |
| Localisation | `flutter_localizations` + `intl` with ARB files | `app_en.arb`, `app_hi.arb` from the first commit |
| PDF | `pdf` + `printing` | Bundle a Devanagari-capable font; the built-in font does not cover Devanagari |
| Excel | a maintained `xlsx` writer package | Must support bold headers, frozen panes, numeric cells |
| Google auth | `google_sign_in` | `drive.file` scope only |
| Google Sheets | `googleapis` (Sheets v4 + Drive v3) | Create, then `values.update` and `values.append` |
| Secure storage | `flutter_secure_storage` | Refresh tokens, never in SharedPreferences |
| Connectivity | `connectivity_plus` | Trigger a sync attempt when the network returns |
| Share / files | `share_plus`, `path_provider` | Export and backup targets |
| Notifications | `flutter_local_notifications` | On-device scheduling only |
| Images | `image_picker` + on-device downscale | Cap stored photos at roughly 1024 px on the long edge |

Project layout:

```
lib/
  main.dart
  l10n/            app_en.arb, app_hi.arb
  data/
    db/            database.dart, tables/, migrations/
    repositories/
    files/         photo_store.dart, export_store.dart
  domain/
    models/
    services/      item_service.dart, movement_service.dart,
                   export_service.dart, sync_service.dart
  ui/
    dashboard/ stock_list/ add_item/ item_detail/
    low_stock/ reports/ settings/
    common/        widgets, theme, formatters
```

## 4. Data model

SQLite types shown as declared. All timestamps are UTC epoch milliseconds. All primary keys are UUID v4 strings.

### categories

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | UUID |
| name_en | TEXT NOT NULL | |
| name_hi | TEXT NOT NULL | |
| is_builtin | INTEGER NOT NULL DEFAULT 0 | Built-ins cannot be deleted |
| sort_order | INTEGER NOT NULL DEFAULT 100 | |
| created_at / updated_at | INTEGER NOT NULL | |
| deleted_at | INTEGER NULL | Soft delete |

Seeded built-ins: Cover / कवर, Tempered Glass / टेम्पर्ड ग्लास, Charger / चार्जर, Cable / केबल, Earphone / ईयरफोन, Power Bank / पावर बैंक, Memory Card / मेमोरी कार्ड, Other / अन्य.

A custom category stores the owner's single entered string in both name columns.

### items

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | UUID |
| name | TEXT NOT NULL | |
| category_id | TEXT NOT NULL | FK categories.id |
| brand | TEXT NULL | |
| model | TEXT NULL | e.g. "Samsung A55" |
| quantity | INTEGER NOT NULL DEFAULT 0 | Cached; equals SUM(movements.delta). Never written directly by the UI. |
| min_stock | INTEGER NOT NULL DEFAULT 5 | |
| photo_path | TEXT NULL | Relative path inside app documents |
| location | TEXT NULL | e.g. "Rack 2" |
| note | TEXT NULL | |
| created_at / updated_at | INTEGER NOT NULL | |
| deleted_at | INTEGER NULL | Soft delete |
| device_id | TEXT NOT NULL | Origin device, for future multi-device sync |

Constraints and indexes:

- `CHECK (quantity >= 0)`
- `CHECK (min_stock >= 0)`
- Unique index on `lower(trim(name)), lower(coalesce(trim(brand),'')), lower(coalesce(trim(model),''))` where `deleted_at IS NULL` - enforces FR1.3
- Index on `category_id`, on `deleted_at`, and on `(quantity, min_stock)` for the low-stock query

There is no price column, and there must never be one.

### stock_movements

Append-only ledger. Rows are never updated or deleted.

| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | UUID |
| seq | INTEGER | Local autoincrement, monotonic. Used as the sync cursor for the History tab. |
| item_id | TEXT NOT NULL | FK items.id |
| delta | INTEGER NOT NULL | Positive = stock in, negative = stock out. `CHECK (delta <> 0)` |
| reason | TEXT NOT NULL | One of `opening`, `purchase`, `sale`, `return_in`, `damage`, `correction` |
| note | TEXT NULL | |
| resulting_quantity | INTEGER NOT NULL | Item quantity after this movement; makes history readable without replaying the ledger |
| reverses_movement_id | TEXT NULL | Set when this row is an undo of another movement |
| occurred_at | INTEGER NOT NULL | |
| created_at | INTEGER NOT NULL | |
| device_id | TEXT NOT NULL | |

Indexes: `(item_id, occurred_at DESC)`, `(occurred_at)`, `(seq)`.

Reason labels:

| Code | English | Hindi | Sign |
|---|---|---|---|
| `opening` | Opening stock | शुरुआती स्टॉक | + |
| `purchase` | New stock in | नया माल आया | + |
| `sale` | Sold | बेचा | - |
| `return_in` | Customer return | वापस आया | + |
| `damage` | Damaged | टूटा / खराब | - |
| `correction` | Count correction | गिनती सुधारी | either |

### sync_state

Single row. Replaces a queue, because a full-snapshot push only needs a dirty flag plus a cursor.

| Column | Type | Notes |
|---|---|---|
| id | INTEGER PK | Always 1 |
| enabled | INTEGER NOT NULL DEFAULT 0 | |
| spreadsheet_id | TEXT NULL | |
| spreadsheet_url | TEXT NULL | |
| google_account_email | TEXT NULL | Shown in Settings |
| dirty | INTEGER NOT NULL DEFAULT 0 | Set by any item/movement write |
| pending_change_count | INTEGER NOT NULL DEFAULT 0 | Shown on the Pending chip |
| last_history_seq | INTEGER NOT NULL DEFAULT 0 | Advanced only after a confirmed append |
| last_success_at | INTEGER NULL | |
| last_attempt_at | INTEGER NULL | |
| consecutive_failures | INTEGER NOT NULL DEFAULT 0 | Drives backoff |
| last_error_code | TEXT NULL | Mapped to a plain-language message |

### settings

Key/value table. Keys: `shop_name`, `language` (`hi`/`en`), `default_min_stock`, `low_stock_notification_enabled`, `low_stock_notification_time`, `device_id`, `schema_version`.

### Write transaction for a stock change

Each stock change is one SQLite transaction, so a kill mid-write cannot desynchronise the ledger from the cached quantity:

1. Read the item's current quantity `FOR UPDATE` semantics within the transaction.
2. Reject if `quantity + delta < 0`.
3. Insert the movement row with `resulting_quantity = quantity + delta`.
4. Update `items.quantity` and `items.updated_at`.
5. Set `sync_state.dirty = 1` and increment `pending_change_count`.
6. Commit, then confirm in the UI.

## 5. Sync design

### Spreadsheet structure

Created by the app as `StockSaathi - {shop name}` with three tabs.

**Row 1 on every tab** is a banner, merged across the used columns, in a muted fill:
`Ye sheet app se auto-update hoti hai, yahan edit na karein | This sheet is auto-updated by the app, do not edit here`

**`Stock` tab** - header on row 2, frozen rows 1-2:

`S.No | Item Name | Category | Brand | Model | Quantity | Minimum Stock | Status | Last Updated`

**`History` tab** - header on row 2:

`Date | Time | Item Name | Category | Brand | Model | Change | Reason | Resulting Quantity | Note`

**`Summary` tab** - label/value pairs: Shop Name, Last Synced, Total Items, Total Quantity, Low Stock Items, Out of Stock Items.

No tab has a price column.

### Push algorithm

```
on database write (item or movement):
    sync_state.dirty = 1; pending_change_count += 1
    schedule push, debounced 15 s from the last write

also trigger a push on:
    app moving to background
    connectivity regained
    manual "Sync now"

push():
    if not enabled or offline: return
    if a push is already running: mark re-run needed and return

    1. read all non-deleted items, ordered by name
    2. Stock tab: values.update over the full data range,
       then clear any rows below the new last row
       (full snapshot, so the tab always matches the database exactly)
    3. Summary tab: values.update
    4. History tab: select movements where seq > last_history_seq
       ordered by seq; values.append them;
       on confirmed response, set last_history_seq = max(seq) pushed
    5. on success: dirty = 0, pending_change_count = 0,
       consecutive_failures = 0, last_success_at = now
    6. on failure: consecutive_failures += 1, record error code,
       retry with exponential backoff
          30 s, 2 min, 10 min, 30 min, capped at 2 h
       dirty stays 1, so nothing is lost
```

Because step 2 writes a complete snapshot, a failed or half-applied push is corrected by the next successful one. No reconciliation logic is needed.

### Error handling

| Condition | Owner-facing message (Hindi primary) | Recovery |
|---|---|---|
| Offline | "Net nahi hai. Net aane par khud sync ho jayega." | Automatic on reconnect |
| Token expired / revoked | "Google login khatam ho gaya. Dubara connect karein." | Settings shows a Reconnect action |
| Spreadsheet deleted or inaccessible (404) | "Sheet nahi mili. Nayi sheet banayein?" | Offer to create a fresh spreadsheet |
| Rate limited (429) | "Google thoda busy hai, thodi der me dubara koshish hogi." | Backoff, silent |
| Any other API error | "Sync me dikkat aayi. Dubara koshish karein." | Retry action, error code in Settings for support |

Sync failure never blocks a stock change and never shows a modal dialog. It surfaces only in the sync chip.

## 6. Screens

Navigation: a bottom bar with four destinations (Dashboard, Stock, Low Stock, Reports); Settings from the Dashboard app bar; Add Item as a floating action button on Dashboard and Stock; Item Detail pushed from any list.

### 6.1 Dashboard

- App bar: "StockSaathi", shop name as subtitle, Settings icon.
- Sync chip directly under the app bar when sync is connected.
- Four stat tiles, two per row, each tappable: Total Items, Total Quantity, Low Stock (red when above zero), Out of Stock (grey).
- "Aaj ka hisaab" card: quantity in today, quantity out today.
- Low Stock section: up to five most urgent items, each row showing name, model, current quantity vs minimum, with a "Sabhi dekhein" link.
- Floating action button: "Item Add Karein".
- Empty state: illustration plus a single primary button.

### 6.2 Stock List

- Persistent search field at the top, with a clear button.
- Filter row: Category, Brand, Model, Status chips; active filters shown as removable chips; a Clear action.
- Sort control: name, quantity ascending, recently updated.
- Rows: 72 dp tall, photo thumbnail or category icon, item name as the primary line, `brand · model · location` as the secondary line, quantity as a large right-aligned figure with a status dot and label.
- Inline `+` and `-` buttons on each row for a fast single-unit change with the default reason, so routine updates need no navigation. A long press opens the quantity keypad.
- Lazy-loaded list to hold scrolling smooth at 2,000 items.

### 6.3 Add / Edit Item

Single scrolling form, fields in this order: Photo (optional, camera or gallery), Item Name, Category (chips plus "+ Nayi category"), Brand (autocomplete), Model (autocomplete), Opening Quantity (stepper plus keypad; hidden when editing), Minimum Stock (stepper, prefilled from Settings), Shelf/Location, Note.

- Save is a full-width button pinned to the bottom.
- Validation is inline, under the offending field, never in a dialog.
- Duplicate detection runs on blur of the name field and offers "Wahi item kholein".

### 6.4 Item Detail

- Header: photo, item name, `brand · model`, category, location.
- Quantity block: current quantity in a large figure, status label, minimum stock.
- Two large controls side by side: `+ Stock Aaya` and `- Stock Gaya`, each at least 64 dp tall. Tapping opens a bottom sheet with a quantity keypad, a prefilled default reason, a reason selector, and an optional note.
- History list below: newest first, each row showing date and time, signed quantity, reason label, resulting quantity, note. An overflow action on each row offers Undo, which asks for confirmation and then appends a reversing movement.
- App bar actions: Edit, Delete.

### 6.5 Low Stock

Two sections: Out of Stock first, then Low Stock, each sorted by how far below minimum the item is. Rows match the Stock List row design and support the same inline `+`. A "Sheet me dekhein" link appears when sync is connected. Empty state: "Sab theek hai, koi item kam nahi hai."

### 6.6 Reports / Export

- Date range selector for history-based views: Today, This Week, This Month, Custom.
- Movement summary for the chosen range: quantity in, quantity out, split by reason.
- Day-wise and month-wise grouped lists.
- Two large export buttons: "PDF Banayein" and "Excel Banayein", each showing progress and then a share sheet.
- A note stating that exports contain no price information.

### 6.7 Settings / Sync

- Shop Name (used in PDF and spreadsheet titles).
- Language: Hindi / English toggle, applied immediately.
- Default Minimum Stock for new items.
- Low Stock notification toggle plus time picker.
- **Google Sheet Sync** section: when disconnected, an explanation and a "Google se Connect Karein" button, with a plain-language line that the app will create a new sheet and that editing the sheet will not change the app. When connected: account email, spreadsheet name with an Open link, last synced time, "Sync Now", and "Disconnect" (confirmation required).
- Backup section: "Backup Banayein" and "Backup se Wapas Layein" (confirmation required).
- About: version, privacy policy link, a line stating the app stores no prices.

### 6.8 Visual and interaction rules

| Rule | Value |
|---|---|
| Primary button height | 56 dp minimum; quantity controls 64 dp |
| Body text | 16 sp minimum; quantity figures 20 sp or larger |
| Status colours | Available green, Low Stock red, Out of Stock grey, each always paired with an icon and a text label |
| Font scale | Layouts must survive the system maximum text scale without clipping |
| Icons | Every primary action has an icon plus a text label |
| Feedback | Confirmations as a snackbar, not a dialog; dialogs reserved for destructive actions |
| Default language | Hindi when the device is set to Hindi, otherwise English |

## 7. Export layouts

### PDF

- Page: A4 portrait, 15 mm margins, Devanagari-capable bundled font.
- Header: shop name, "Stock Report", generated date and time, page numbers.
- Summary block: Total Items, Total Quantity, Low Stock, Out of Stock.
- Main table: S.No, Item Name, Category, Brand, Model, Quantity, Status. Repeating header on each page, zebra striping, Low Stock rows tinted.
- Second section: "Low Stock / Out of Stock" list.
- Footer: "Generated by StockSaathi".
- No price column, no monetary figure anywhere.

### Excel

Single sheet named `Stock`. Columns: S.No, Item Name, Category, Brand, Model, Quantity, Minimum Stock, Status, Last Updated. Header bold and frozen, column widths sized to content, Quantity and Minimum Stock written as numbers, Last Updated as a date-time cell. No price column.

## 8. Testing focus

Unit tests concentrate on the parts where a bug costs the owner real data:

1. Movement transaction: cached quantity always equals the ledger sum; negative stock is rejected; undo produces the correct reversing row.
2. Status derivation across the boundary cases (quantity 0, quantity equal to minimum, minimum of 0).
3. Duplicate detection with case, whitespace, and null brand/model variations.
4. Sync cursor: a failed append does not advance `last_history_seq`; a retry does not duplicate rows.
5. Snapshot push: a shrinking item list clears the trailing rows in the Sheet.
6. Offline queueing survives app restart.
7. Export generators: no price column present, Devanagari renders, row counts match the database.

A regression guard worth adding to CI: a test that fails if any column name or exported header in the codebase matches `price|cost|rate|amount|mrp`, so the no-price rule cannot be broken by accident.

## 9. Phase 2 and 3

**Phase 2:** barcode scanning for item entry, two-way Google Sheets sync with explicit conflict handling, staff logins and a backend sync target, Microsoft OneDrive / Excel Online sync, automatic cloud backup.

**Phase 3:** multiple shops, monthly reports, WhatsApp low-stock alerts, premium tier (unlimited items, priority support).

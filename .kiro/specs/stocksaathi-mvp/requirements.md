# StockSaathi - Requirements (Phase 1 / MVP)

**App name:** StockSaathi - Mobile Accessories
**Platform:** Android first (Flutter, iOS later)
**Audience:** Single-owner mobile accessory shops in India. Owner may have low digital literacy and reads Hindi more comfortably than English.

## 1. Problem

The shop owner tracks accessory stock (covers, tempered glass, chargers, cables, earphones, power banks, memory cards) in a paper register or from memory. Items run out without warning, and there is no reliable way to answer "kitna bacha hai?" for a specific model.

## 2. Product principles

These are binding constraints, not preferences.

1. **No prices, anywhere.** No purchase price, no selling price, no margin, no total value. Not in the database schema, not in the UI, not in PDF/Excel exports, not in the synced Google Sheet. Adding a price field is a Phase 3 decision, not a Phase 1 shortcut.
2. **The app works with no internet.** Every read and write operation must succeed offline. Network is only ever needed for Google Sheets sync, which is optional.
3. **Hindi is a first-class language, not a translation afterthought.** Language switching ships in Phase 1.
4. **Low-risk over feature-rich.** Where a feature has a launch-blocking or rewrite risk, it moves to a later phase. See `design.md` section 2 for the decisions this produced.

## 3. Non-goals for Phase 1

Explicitly out of scope. Each is listed with the reason, so nobody re-litigates it mid-sprint.

| Out of scope | Reason |
|---|---|
| Any price, cost, or value field | Product principle 1 |
| Two-way Google Sheets sync (Sheet edits flowing back into the app) | Needs conflict resolution; the most expensive and bug-prone part of sync. Phase 2. |
| Microsoft Excel Online / OneDrive sync | Second OAuth stack and app registration. Doubles auth work and delays launch. Excel export covers these users. Phase 2. |
| Staff logins, multiple shops | Needs a real backend and an auth model. Phase 2/3. The Phase 1 schema is built so this is additive. |
| Barcode scanning | Most accessory stock in this segment has no usable printed barcode. Phase 2. |
| Server-side anything, user accounts of our own | No backend in Phase 1. |
| Third-party analytics or ad SDKs | Keeps the privacy policy and Play Data Safety declaration minimal. |
| WhatsApp push alerts for low stock | Needs WhatsApp Business API. Phase 3. In-app + local notification covers Phase 1. |

## 4. Functional requirements

### FR1 - Item management

**User story:** As the shop owner, I want to add an accessory to my stock list, so I can track how many I have.

Acceptance criteria:
1. The Add Item form has these fields: Item name (required), Category (required, default "Other"), Brand (optional), Model (optional), Opening quantity (required, default 0), Minimum stock (required, defaults to the value set in Settings), Photo (optional), Shelf/Location (optional), Note (optional).
2. Saving an item with an empty name is blocked with an inline message; no other field blocks saving.
3. If an item with the same name + brand + model already exists (case-insensitive, trimmed), the app warns "Ye item pehle se hai" and offers to open the existing item instead of creating a duplicate.
4. Category list ships with: Cover, Tempered Glass, Charger, Cable, Earphone, Power Bank, Memory Card, Other. The owner can add a custom category from the same form without leaving it.
5. Brand and Model fields autocomplete from values the owner has already entered.
6. An item can be edited. Editing name/brand/model/category/min-stock/photo/location/note does **not** create a stock movement.
7. An item can be deleted. Delete is a soft delete: the item disappears from all lists and exports, and its history is retained. Delete asks for confirmation showing the item name.
8. Opening quantity, when non-zero, is recorded as a movement with reason `opening`, so the ledger always explains the current quantity.

### FR2 - Stock in / out

**User story:** As the shop owner, I want to raise or lower an item's quantity in two taps, so updating stock is faster than writing in the register.

Acceptance criteria:
1. The Item Detail screen has a large `+` (stock in) and `-` (stock out) control. Default step is 1; the owner can type any quantity.
2. Every quantity change requires a reason, picked from: `purchase` (naya maal aaya), `sale` (becha), `return_in` (customer ne wapas kiya), `damage` (toot gaya / kharab), `correction` (ginti sudhari). The reason defaults to `purchase` for `+` and `sale` for `-`, so the common case stays one extra tap at most.
3. Each change is stored as an immutable movement row with delta, reason, optional note, and a UTC timestamp. The item's quantity is never edited directly; it is always the sum of its movements.
4. Stock out that would take quantity below zero is blocked with the message "Itna stock nahi hai. Abhi {n} bacha hai." Negative stock is never stored.
5. A movement can be undone from the item's history. Undo appends a reversing movement with reason `correction` and a reference to the undone movement. Movements are never deleted or mutated.
6. After a change, the screen shows the new quantity prominently and a brief confirmation.

### FR3 - Search and filter

Acceptance criteria:
1. Stock List has a search box that matches against name, brand, and model, case-insensitively, on partial words.
2. Search results update as the owner types, with results visible within 300 ms for a catalogue of 2,000 items.
3. Filters available: Category (multi-select), Brand, Model, and stock status (All / Low Stock / Out of Stock / Available).
4. Active filters are shown as removable chips, and a single "Clear" action resets all of them.
5. Sort options: name A-Z, quantity low to high, recently updated.

### FR4 - Low stock alerts

Acceptance criteria:
1. An item is **Out of Stock** when quantity is 0, **Low Stock** when quantity is above 0 and at or below its minimum stock, otherwise **Available**.
2. In every list, Low Stock rows carry a red indicator and Out of Stock rows a grey/strike indicator. Status is conveyed by an icon and a text label as well as colour, never colour alone.
3. The Dashboard shows a Low Stock section listing affected items, most urgent first.
4. If the owner enables it in Settings, a local notification fires at a chosen time of day summarising how many items are low or out. This uses on-device scheduling only; no server, no push infrastructure.

### FR5 - Dashboard

Acceptance criteria:
1. Shows: total distinct items, total quantity across all items, count of low stock items, count of out of stock items.
2. Shows today's movement: total quantity in and total quantity out since local midnight.
3. Shows the sync status chip (see FR9) when sync is connected.
4. Tapping any figure opens the corresponding filtered list.
5. On a fresh install, shows an empty state with a single clear action: "Pehla item add karein".

### FR6 - History

Acceptance criteria:
1. Each item's detail screen lists its movements newest-first: date, time, +/- quantity, reason, note, and resulting quantity.
2. A global history screen lists movements across all items, filterable by date range, item, category, and reason.
3. History can be grouped by day and by month, showing quantity in and out per bucket.
4. History rows for soft-deleted items remain visible in the global history, marked as deleted.

### FR7 - PDF export

Acceptance criteria:
1. One action produces a PDF generated entirely on-device.
2. Contents, in order: shop name and generation date/time; summary block (total items, total quantity, low stock count, out of stock count); main table with columns S.No, Item Name, Category, Brand, Model, Quantity, Status; a separate Low Stock / Out of Stock section.
3. The PDF contains no price column and no monetary figure.
4. The PDF respects the app's current language for labels, and renders Devanagari correctly (a font with Devanagari coverage must be bundled; the default PDF font does not cover it).
5. The file can be shared (WhatsApp and any other share target), saved, or printed.
6. Filename pattern: `StockSaathi_Stock_YYYY-MM-DD.pdf`.

### FR8 - Excel export

Acceptance criteria:
1. One action produces an `.xlsx` file generated entirely on-device.
2. Columns, exactly: S.No, Item Name, Category, Brand, Model, Quantity, Minimum Stock, Status, Last Updated. No price column.
3. Header row is bold and frozen; Quantity and Minimum Stock are numeric cells, not text.
4. The file can be shared or saved.
5. Filename pattern: `StockSaathi_Stock_YYYY-MM-DD.xlsx`.

### FR9 - Google Sheets sync (one-way, app to Sheet)

**User story:** As the shop owner, I want my stock to appear in a Google Sheet automatically, so I can see it on a computer and share it without exporting anything.

Acceptance criteria:
1. Sync is opt-in. The app is fully usable without ever signing in to Google.
2. On connecting, the owner signs in with Google and the app **creates a new spreadsheet** named `StockSaathi - {shop name}`. The app requests only the non-sensitive per-file Drive scope, which avoids the OAuth verification process that broader scopes trigger (see `design.md` section 2.2). Pasting a link to an arbitrary existing sheet is **not** supported in Phase 1, because that scope cannot reach files the app did not create or the user did not explicitly pick.
3. The spreadsheet has three tabs: `Stock` (current state), `History` (append-only movement log), `Summary` (totals). Each tab carries a banner row in Hindi and English: "Ye sheet app se auto-update hoti hai, yahan edit na karein / This sheet is auto-updated by the app, do not edit here."
4. The `Stock` tab columns match FR8 exactly, with no price column.
5. After any stock change, the app pushes an update within 30 seconds of the last change while the device is online, and also on app background and on manual "Sync now".
6. Sync is one-way. The app never reads stock values back from the Sheet. Edits made in the Sheet are overwritten on the next sync, which the banner warns about.
7. Offline changes are retained locally and pushed automatically once connectivity returns, without the owner doing anything.
8. The sync chip shows one of: **Synced** (with relative time, e.g. "2 min pehle"), **Pending** (with count of unsynced changes), **Error** (with a plain-language cause and a Retry action). Errors never block app usage.
9. The owner can disconnect sync. Disconnecting revokes the stored token locally and leaves the existing spreadsheet untouched.
10. A link to open the spreadsheet in a browser is shown in Settings once connected.

### FR10 - Offline behaviour

Acceptance criteria:
1. All item, movement, search, filter, history, PDF, and Excel features work with networking fully disabled.
2. The app shows no blocking spinner or error dialog on cold start when offline.
3. Pending sync state survives app kill and device restart.

### FR11 - Language and usability

Acceptance criteria:
1. Hindi and English are both available; the app defaults to the device language if it is Hindi, else English, and the choice is changeable in Settings and applied without restart.
2. All user-facing strings go through the localisation layer from the first commit. No hardcoded display strings.
3. Primary action targets are at least 56 dp tall; the `+`/`-` quantity controls at least 64 dp.
4. Body text is at least 16 sp and quantity figures at least 20 sp; the layout must not break at the system's largest font scale.
5. Every primary action pairs an icon with a text label.
6. Destructive actions (delete item, disconnect sync, restore backup) require confirmation that names the affected item or data.

### FR12 - Local backup and restore

Acceptance criteria:
1. The owner can export a full backup file (items, categories, movements, settings) to share or save anywhere.
2. The owner can restore from a backup file. Restore replaces local data and asks for explicit confirmation first.
3. Item photos are included in the backup.
4. Backup and restore work entirely offline.

## 5. Non-functional requirements

| Area | Requirement |
|---|---|
| Target devices | Android 8.0 (API 26) and above, 2 GB RAM, 720x1280 and larger |
| Catalogue scale | 2,000 items and 50,000 movements with no perceptible lag in list scroll or search |
| Cold start | Usable Dashboard within 2 seconds on a 2 GB device |
| Data durability | A confirmed stock change must survive immediate app kill. Writes are committed to SQLite before the UI confirms. |
| Timestamps | Stored as UTC epoch milliseconds; displayed in device local time |
| Permissions | Camera/photo access only when adding a photo; notification permission only when alerts are enabled. No contacts, no location, no SMS. |
| Privacy | Stock data stays on-device unless the owner connects sync. Google tokens stored in platform secure storage. No third-party analytics. |
| Crash budget | Crash-free sessions above 99.5% before public launch |
| App size | Under 30 MB as delivered by Play. The universal sideload APK is larger (roughly 65 MB) because it carries every ABI; Play splits the app bundle per device. A split-per-ABI APK was rejected for sideloading because installing the wrong ABI fails with an unhelpful error. |

## 6. Pre-launch checklist (non-code)

1. **Name clearance.** "Saathi" appears in many Indian app names. Check Play Store listings and the Indian trademark register for "StockSaathi" before locking the store listing and icon. If there is a conflict, the fallback name is decided before, not after, store submission.
2. Privacy policy published at a public URL (required for Play, and for Google sign-in).
3. Play Data Safety form filled consistent with "data stays on device unless sync is enabled".
4. Google Cloud project with OAuth client configured for the release signing certificate, and the consent screen set to the non-sensitive scope only.
5. Devanagari-capable font licensed for bundling and redistribution in the PDF output.

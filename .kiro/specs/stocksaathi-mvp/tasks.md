# StockSaathi - Phase 1 Implementation Plan

Ordered so that each group leaves the app in a runnable state. Requirement references point at `requirements.md`.

- [ ] 1. Project foundation
- [ ] 1.1 Create the Flutter project, set the application id, app name, and minimum SDK to Android API 26, and commit the `lib/` folder structure from `design.md` section 3
- [ ] 1.2 Add and pin dependencies: drift, riverpod, intl, flutter_localizations, pdf, printing, an xlsx writer, google_sign_in, googleapis, flutter_secure_storage, connectivity_plus, share_plus, path_provider, image_picker, flutter_local_notifications
- [ ] 1.3 Set up the localisation pipeline with `app_en.arb` and `app_hi.arb`, wire the locale into the app, and add a lint or review rule against hardcoded display strings
  - _Requirements: FR11.1, FR11.2_
- [ ] 1.4 Build the theme: colour roles for Available / Low Stock / Out of Stock, minimum touch target sizes, and text styles honouring system font scale
  - _Requirements: FR11.3, FR11.4_

- [ ] 2. Data layer
- [ ] 2.1 Define the Drift tables for `categories`, `items`, `stock_movements`, `sync_state`, and `settings` exactly as specified, including check constraints, the duplicate-prevention unique index, and the listed indexes
  - _Requirements: FR1.3, FR2.4_
- [ ] 2.2 Write the initial migration and seed the eight built-in categories with Hindi and English names; generate and persist a `device_id` on first run
- [ ] 2.3 Implement `ItemRepository`: create, edit, soft delete, reactive queries for list, search, filter, sort, and the low-stock query
  - _Requirements: FR1.1, FR1.2, FR1.6, FR1.7, FR3.1, FR3.3, FR3.5, FR4.1_
- [ ] 2.4 Implement `MovementRepository` with the single-transaction stock change from `design.md` section 4: validate against negative stock, insert the movement with `resulting_quantity`, update the cached quantity, mark sync dirty
  - _Requirements: FR2.3, FR2.4, NFR data durability_
- [ ] 2.5 Implement undo as an appended reversing movement with `reverses_movement_id` set, and a debug-only action that recomputes all cached quantities from the ledger
  - _Requirements: FR2.5_
- [ ] 2.6 Implement `PhotoStore`: pick from camera or gallery, downscale to roughly 1024 px on the long edge, store under app documents, return a relative path
- [ ] 2.7 Unit tests for the movement transaction, status derivation boundaries, and duplicate detection
  - _Requirements: FR2.4, FR4.1, FR1.3_

- [ ] 3. Core screens
- [ ] 3.1 Build the Dashboard: four stat tiles, today's in/out card, low-stock preview, empty state, navigation into filtered lists
  - _Requirements: FR5_
- [ ] 3.2 Build the Stock List: search field, filter chips, sort control, 72 dp rows with status indicator, inline +/- for single-unit changes, lazy loading
  - _Requirements: FR3, FR4.2_
- [ ] 3.3 Build Add / Edit Item: full form, brand and model autocomplete, inline category creation, inline validation, duplicate warning on name blur, opening-quantity movement with reason `opening`
  - _Requirements: FR1.1 - FR1.8_
- [ ] 3.4 Build Item Detail: quantity block, the two large stock-in / stock-out controls, the quantity keypad bottom sheet with reason selector and note, item history list with per-row undo
  - _Requirements: FR2.1, FR2.2, FR2.6, FR6.1_
- [ ] 3.5 Build the Low Stock screen with Out of Stock and Low Stock sections and an empty state
  - _Requirements: FR4.3_
- [ ] 3.6 Build the global History view with date range, item, category, and reason filters, plus day-wise and month-wise grouping
  - _Requirements: FR6.2, FR6.3, FR6.4_
- [ ] 3.7 Build Settings: shop name, language toggle applied without restart, default minimum stock, notification toggle and time
  - _Requirements: FR11.1, FR4.4, FR1.1_
- [ ] 3.8 Add confirmation flows for all destructive actions, naming the affected item
  - _Requirements: FR11.6_

- [ ] 4. Exports
- [ ] 4.1 Bundle a Devanagari-capable font for PDF output and verify Hindi labels render in a generated file
  - _Requirements: FR7.4_
- [ ] 4.2 Implement the PDF generator per `design.md` section 7: header, summary block, paginated main table with repeating header, separate low-stock section, footer
  - _Requirements: FR7.1, FR7.2, FR7.3_
- [ ] 4.3 Implement the Excel generator with the nine specified columns, bold frozen header, and numeric quantity cells
  - _Requirements: FR8_
- [ ] 4.4 Build the Reports screen: date range, movement summary by reason, grouped lists, and the two export buttons with progress and share sheet
  - _Requirements: FR6.3, FR7.5, FR8.4_
- [ ] 4.5 Tests asserting that neither export contains a price column and that row counts match the database
  - _Requirements: FR7.3, FR8.2_

- [ ] 5. Google Sheets sync
- [ ] 5.1 Create the Google Cloud project and OAuth client for both debug and release signing certificates, configure the consent screen with `drive.file` only, and document the setup steps in the repository
  - _Requirements: FR9.2_
- [ ] 5.2 Implement Google sign-in with the `drive.file` scope, storing tokens in secure storage, and handle the sign-in cancelled and revoked cases
  - _Requirements: FR9.1, FR9.2_
- [ ] 5.3 Implement spreadsheet creation: three tabs, banner row on each, headers, frozen panes, persisted `spreadsheet_id` and URL
  - _Requirements: FR9.2, FR9.3, FR9.4_
- [ ] 5.4 Implement the snapshot push for the `Stock` and `Summary` tabs, including clearing trailing rows when the item list shrinks
  - _Requirements: FR9.5, FR9.6_
- [ ] 5.5 Implement the append-only `History` push driven by `last_history_seq`, advancing the cursor only after a confirmed write
  - _Requirements: FR9.5_
- [ ] 5.6 Implement the sync scheduler: 15 second debounce, triggers on app background, connectivity regained, and manual sync, with the specified exponential backoff
  - _Requirements: FR9.5, FR9.7, FR10.3_
- [ ] 5.7 Build the sync status chip and the Settings sync section, mapping each error code to its plain-language message, plus Reconnect, Sync Now, and Disconnect
  - _Requirements: FR9.8, FR9.9, FR9.10_
- [ ] 5.8 Tests for cursor behaviour on failure and retry, and for snapshot push with a shrinking item list
  - _Requirements: FR9.5, FR9.7_

- [ ] 6. Offline, notifications, backup
- [ ] 6.1 Verify every feature in FR10.1 with networking disabled, and confirm no blocking spinner or error dialog on offline cold start
  - _Requirements: FR10.1, FR10.2_
- [ ] 6.2 Verify pending sync state survives app kill and device restart
  - _Requirements: FR10.3_
- [ ] 6.3 Implement the scheduled local low-stock notification with runtime permission handling
  - _Requirements: FR4.4_
- [ ] 6.4 Implement backup export and restore covering items, categories, movements, settings, and photos, with confirmation before restore
  - _Requirements: FR12_

- [ ] 7. Hardening and release readiness
- [ ] 7.1 Seed 2,000 items and 50,000 movements, then profile list scroll, search latency, and cold start against the non-functional targets
  - _Requirements: NFR catalogue scale, NFR cold start_
- [ ] 7.2 Audit every screen at the system's largest font scale and on a 720x1280 display
  - _Requirements: FR11.4_
- [ ] 7.3 Add the CI guard that fails the build if any schema column or export header matches `price|cost|rate|amount|mrp`
  - _Requirements: Product principle 1_
- [ ] 7.4 Review requested permissions against the allowed list and fill the Play Data Safety declaration consistently
  - _Requirements: NFR permissions, NFR privacy_
- [ ] 7.5 Complete the non-code pre-launch checklist in `requirements.md` section 6, starting with the "StockSaathi" name clearance check
  - _Requirements: Pre-launch checklist_

## Launch plan

1. Install the build on 5 to 10 mobile shops personally and watch the owner add their first item without help. Note every point where they hesitate; those are the real bugs.
2. Simplify the Add Item form and button labels based on what you watched, not on what they said.
3. Record a one-minute demo: add an item, reduce stock after a sale, generate a PDF, show the Google Sheet updating.
4. Share the demo in local mobile-market WhatsApp groups and shop associations.
5. Keep all Phase 1 features free so owners install and form the habit. Premium belongs in Phase 3, after retention is proven.

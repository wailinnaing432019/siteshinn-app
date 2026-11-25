# Group Expense & Settlement App (Version 1) — Implementation Plan

## 1. Project Overview
A lightweight, offline-first **Android Flutter application** designed for roommates / shared-living groups (e.g., 5 people living together, pooling money for groceries, cooking, and shared bills) to record who paid for what and automatically calculate **"who pays whom"** at settlement time (e.g., every 6–7 days), with **PDF** and **Excel (.xlsx)** export.

- **Target Platform (V1):** Android (offline-first, local SQLite storage, no login/logout required).
- **Future Vision (V2 Roadmap):** Free cloud backend (e.g., Supabase / Firebase free tier) with Login/Logout, multi-device group sync, and individual member self-entry. *(V1's schema and repository pattern will use UUIDs and clean interfaces so V2 migration is straightforward.)*

---

## 2. Version 1 Core Features

### 2.1 Accounts & Member Management (စာရင်းအကောင့်နှင့် အဖွဲ့ဝင်များ)
- **Create / Manage Accounts (Groups):** Create one or more shared accounts (e.g., `"အိမ်စရိတ် (Room 5)"`, `"ခရီးစဉ်"`), set default currency (default: `MMK` / `Ks`).
- **Member Management:** Add, rename, or deactivate/archive members inside an account (e.g., 5 roommates). Deactivated members remain preserved in past expense history without breaking old records.

### 2.2 Expense Recording (စာရင်းမှတ်တမ်း)
- **Add / Edit / Delete Expense:**
  - **Amount** (numeric input, integer/decimal support for MMK or other currencies)
  - **Title / Note** (e.g., ဈေးဖိုး, ဟင်းချက်စရာ, ရေဖိုး/မီးဖိုး)
  - **Paid By ("ဘယ်သူစိုက်ထားလဲ"):** Select which member paid upfront
  - **Split Among:** Default to **all active members** equally, with an optional toggle to select only specific members (e.g., if 1 person didn't join a meal)
  - **Category:** Groceries/Food, Cooking/Gas, Utilities, Household, Other
  - **Date & Time**
- **Expense Feed & Filters:** View current cycle expenses, filter by payer or category, and search by keyword.

### 2.3 Settlement Calculation & Cycle Closing ("စာရင်းချုပ် / စာရင်းရှင်းမယ်")
- **Live Settlement Preview:** Anytime (or every 6–7 days), open the Settlement screen to view:
  - **Total Group Spending** & **Cost per Person**
  - **Per-Member Breakdown:**
    - Total Paid (`စိုက်ထားငွေ`)
    - Total Share (`ကျသင့်ငွေ`)
    - Net Balance (`+ ရရန်` if positive / `- ပေးရန်` if negative)
  - **Optimized Transfer Plan ("ဘယ်သူက ဘယ်သူ့ကို ဘယ်လောက်ပေးရမလဲ"):**
    - Uses a greedy minimum-cash-flow algorithm to minimize the total number of payments needed to settle everyone's balance (e.g., `Mg Mg -> Ko Ko: 12,500 Ks`).
- **Close Cycle & Save to History ("စာရင်းရှင်းပြီးကြောင်း မှတ်မည်"):**
  - Locks the current unsettled expenses into a **Settled Cycle** snapshot (e.g., `Nov 18 – Nov 25`) and opens a clean new cycle with the same account and members.
  - **Settlement History:** Browse past cycles anytime and re-export their reports.

### 2.4 Export to PDF & Excel (PDF / Excel ထုတ်ယူခြင်း)
- **PDF Export (`.pdf`):**
  - Formatted A4 report containing Account Name, Cycle Date Range, Total Spent, Member Balance Table, **"Who Pays Whom" Settlement Instructions**, and an itemized **Expense List**.
  - **Myanmar Unicode Support:** Embed a Myanmar font (e.g., `NotoSansMyanmar`) in app assets so Burmese titles/names render cleanly in PDFs (built-in PDF fonts do not support Myanmar script).
- **Excel Export (`.xlsx`):**
  - Multi-sheet Excel workbook:
    - **Sheet 1 (`Summary & Settlement`):** Account info, Member Paid/Share/Balance table, and Who-Pays-Whom transfer table.
    - **Sheet 2 (`Expenses`):** Full itemized list (Date, Title, Category, Paid By, Amount, Split Members).
- **Share & Save:** Share directly via Android Share Sheet (Viber, Messenger, Telegram, Gmail, Drive) or save to device storage.

### 2.5 Usability & Theme
- **Language Support:** Burmese (`မြန်မာ`) and English language toggle.
- **Material 3 UI:** Clean, fast mobile UI with Light & Dark mode support.

---

## 3. Technical Architecture & Packages

| Layer | Choice | Reason |
| :--- | :--- | :--- |
| **Framework** | Flutter (Android minSdk 24+) | Native Android performance & fast UI |
| **State Management** | `flutter_riverpod` | Clean reactive state, easy testing & V2 scalability |
| **Local Database** | `sqflite` + `path` | Reliable relational local DB for accounts, splits, cycles |
| **PDF Generation** | `pdf` + `printing` | Custom PDF layout with embedded Myanmar TTF font |
| **Excel Generation** | `excel` | Native `.xlsx` multi-sheet file creation |
| **File & Sharing** | `path_provider` + `share_plus` | Save temp/exported files and open Android Share Sheet |
| **Utilities** | `intl`, `uuid` | Currency/date formatting & V2-ready UUID primary keys |

### Folder Structure (`lib/`)
```text
lib/
├── main.dart
├── app.dart
├── core/
│   ├── theme/              # Material 3 light & dark themes
│   ├── l10n/               # Burmese & English strings
│   ├── utils/              # Currency & date formatters, settlement algorithm
│   └── database/           # SQLite helper & schema migrations
├── data/
│   ├── models/             # Account, Member, Cycle, Expense, Split, Transfer
│   └── repositories/       # Local SQLite CRUD & cycle queries
├── providers/              # Riverpod state notifiers & derived settlement providers
├── services/
│   ├── settlement_service.dart  # Balance & min-cash-flow calculation logic
│   ├── pdf_export_service.dart  # PDF builder with Myanmar font
│   └── excel_export_service.dart # .xlsx workbook builder
└── presentation/
    ├── screens/
    │   ├── home_screen.dart          # Dashboard, current cycle totals, recent expenses
    │   ├── add_expense_screen.dart   # Fast expense entry & payer/split selection
    │   ├── settlement_screen.dart    # Balances, "Who pays whom", close cycle, export
    │   ├── history_screen.dart       # Past settled cycles & details
    │   └── accounts_screen.dart      # Manage accounts, members, language & theme
    └── widgets/                      # Reusable cards, member chips, summary tiles
```

---

## 4. Database Schema (SQLite)

1. **`accounts`**: `id (TEXT PK)`, `name`, `currency_code`, `created_at`
2. **`members`**: `id (TEXT PK)`, `account_id (FK)`, `name`, `is_active (INT)`, `created_at`
3. **`cycles`**: `id (TEXT PK)`, `account_id (FK)`, `title`, `start_date`, `end_date`, `is_settled (INT)`
4. **`expenses`**: `id (TEXT PK)`, `account_id (FK)`, `cycle_id (FK)`, `paid_by_member_id (FK)`, `title`, `category`, `amount (REAL)`, `expense_date`, `created_at`
5. **`expense_splits`**: `id (TEXT PK)`, `expense_id (FK)`, `member_id (FK)`, `share_amount (REAL)`
6. **`settlement_transfers`**: `id (TEXT PK)`, `cycle_id (FK)`, `from_member_id (FK)`, `to_member_id (FK)`, `amount (REAL)` *(recorded snapshot when a cycle is closed)*

---

## 5. Settlement Algorithm Design
For an open or closed cycle:
1. For each member $m$:
   - $\text{paid}[m] = \sum \text{expenses paid by } m$
   - $\text{share}[m] = \sum \text{expense\_splits for } m$
   - $\text{net}[m] = \text{paid}[m] - \text{share}[m]$
2. Handle rounding remainders fairly (e.g., rounding to nearest `1 Ks` / `100 Ks` or keeping exact integer division with remainder distributed 1 unit at a time so total net sum is strictly `0`).
3. Split members into **Creditors** ($\text{net} > 0$) and **Debtors** ($\text{net} < 0$), sort descending by absolute value, and greedily match the largest debtor with the largest creditor until all balances are settled.

---

## 6. Implementation Phases

- **Phase 1 — Project Initialization:** Create Flutter project (`android` enabled), configure `pubspec.yaml` dependencies, add Myanmar font asset (`NotoSansMyanmar`), configure Material 3 theme & Burmese/English localization.
- **Phase 2 — Data Layer:** Implement SQLite database schema, models, and repositories for Accounts, Members, Cycles, and Expenses.
- **Phase 3 — Settlement Engine & Unit Tests:** Implement `SettlementService` (equal split, custom split, rounding safety, min-cash-flow transfers) and write thorough Dart unit tests.
- **Phase 4 — Core UI Screens:** Build Onboarding/Account Setup, Home Dashboard, Member Management, and Add/Edit Expense flow.
- **Phase 5 — Settlement & History UI:** Build the "စာရင်းချုပ်" Settlement screen, Cycle Closing flow, and Settlement History screen.
- **Phase 6 — PDF & Excel Export:** Build `PdfExportService` (with Myanmar font) and `ExcelExportService`, wire up Share/Save buttons on both live and historical cycles.
- **Phase 7 — Verification:** Run `flutter analyze`, `flutter test`, and verify Android APK compilation (`flutter build apk --debug`).

---

## 7. Version 2 Roadmap (Future Phase — Not in V1)
- Authentication (Login / Logout / Forgot Password) using a free cloud tier (e.g., Supabase Auth + PostgreSQL or Firebase Auth + Firestore).
- Group Invite Code / Link so all 5 roommates join the same cloud account on their own phones.
- Real-time sync + push notifications when a member adds an expense or initiates settlement.
- Migration helper to upload existing V1 local SQLite data into a V2 cloud account.

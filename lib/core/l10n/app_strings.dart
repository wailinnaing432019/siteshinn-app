import '../../data/models/expense.dart';
import '../../data/models/settlement_cycle.dart';

enum AppLanguage { en, my }

class AppStrings {
  final AppLanguage language;

  const AppStrings(this.language);

  bool get isBurmese => language == AppLanguage.my;

  static AppStrings of(AppLanguage lang) => AppStrings(lang);

  String get appTitle => 'SiteShinn';
  String get appSubtitle => isBurmese ? 'စိုက်ရှင်း • အဖွဲ့လိုက် အသုံးစရိတ်' : 'စိုက်ရှင်း • Group Expense Splitter';

  // Navigation
  String get navExpenses => isBurmese ? 'စာရင်း' : 'Expenses';
  String get navSettle => isBurmese ? 'စာရင်းချုပ်' : 'Settle Up';
  String get navHistory => isBurmese ? 'မှတ်တမ်း' : 'History';
  String get navAccounts => isBurmese ? 'အကောင့်' : 'Accounts';

  // Common
  String get save => isBurmese ? 'သိမ်းမည်' : 'Save';
  String get cancel => isBurmese ? 'မလုပ်တော့ပါ' : 'Cancel';
  String get delete => isBurmese ? 'ဖျက်မည်' : 'Delete';
  String get edit => isBurmese ? 'ပြင်မည်' : 'Edit';
  String get add => isBurmese ? 'ထည့်မည်' : 'Add';
  String get close => isBurmese ? 'ပိတ်မည်' : 'Close';
  String get confirm => isBurmese ? 'အတည်ပြုမည်' : 'Confirm';
  String get searchHint => isBurmese ? 'ခေါင်းစဉ် သို့မဟုတ် စိုက်သူ ရှာရန်...' : 'Search item or payer...';
  String get all => isBurmese ? 'အားလုံး' : 'All';

  // Dashboard / Expenses
  String get currentCycle => isBurmese ? 'လက်ရှိစာရင်းကာလ' : 'Current Cycle';
  String get totalSpent => isBurmese ? 'စုစုပေါင်းသုံးငွေ' : 'Total Spent';
  String get perPerson => isBurmese ? 'တစ်ဦးကျ' : 'Per Person';
  String get expensesCount => isBurmese ? 'အကြိမ်ရေ' : 'Expenses';
  String get addExpense => isBurmese ? 'စာရင်းထည့်မည်' : 'Add Expense';
  String get editExpense => isBurmese ? 'စာရင်းပြင်မည်' : 'Edit Expense';
  String get noExpensesYet => isBurmese
      ? 'လက်ရှိစာရင်းကာလတွင် အသုံးစရိတ် မရှိသေးပါ။\nအောက်ပါ + ခလုတ်ဖြင့် စတင်မှတ်သားပါ။'
      : 'No expenses in this cycle yet.\nTap + Add Expense to record who paid.';
  String get paidByLabel => isBurmese ? 'စိုက်ထားသူ' : 'Paid by';
  String get splitAmongLabel => isBurmese ? 'ခွဲဝေမည့်သူများ' : 'Split among';
  String get selectAllMembers => isBurmese ? 'အားလုံးရွေးမည်' : 'Select All';
  String get amountLabel => isBurmese ? 'ငွေပမာဏ' : 'Amount';
  String get titleLabel => isBurmese ? 'အကြောင်းအရာ (ဥပမာ - ဈေးဖိုး)' : 'Description (e.g. Groceries)';
  String get categoryLabel => isBurmese ? 'အမျိုးအစား' : 'Category';
  String get dateLabel => isBurmese ? 'နေ့စွဲ' : 'Date';
  String get deleteExpenseTitle => isBurmese ? 'စာရင်းဖျက်မည်လား?' : 'Delete Expense?';
  String get deleteExpenseConfirm => isBurmese
      ? 'ဤအသုံးစရိတ်ကို ဖျက်လိုက်ပါက စာရင်းချုပ်တွက်ချက်မှု ပြောင်းလဲသွားပါမည်။'
      : 'Removing this expense will update the current cycle settlement.';

  String splitSummary(int count, int totalActive) {
    if (count == totalActive) {
      return isBurmese ? 'အားလုံး ($count ဦး)' : 'All ($count)';
    }
    return isBurmese ? '$count ဦးခွဲ' : 'Split $count';
  }

  // Categories
  String categoryName(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return isBurmese ? 'အစားအသောက် / ဈေးဖိုး' : 'Food & Groceries';
      case ExpenseCategory.cooking:
        return isBurmese ? 'ချက်ပြုတ် / ဂတ်စ်' : 'Cooking & Gas';
      case ExpenseCategory.utilities:
        return isBurmese ? 'မီး / ရေ / အင်တာနက်' : 'Utilities';
      case ExpenseCategory.household:
        return isBurmese ? 'အိမ်သုံးပစ္စည်း' : 'Household';
      case ExpenseCategory.other:
        return isBurmese ? 'အခြား' : 'Other';
    }
  }

  // Settlement
  String get settlementTitle => isBurmese ? 'စာရင်းချုပ် / ရှင်းတမ်း' : 'Cycle Settlement';
  String get whoPaysWhom => isBurmese ? 'ဘယ်သူက ဘယ်သူ့ကို ဘယ်လောက်ပေးရမလဲ' : 'Who Pays Whom';
  String get memberBalances => isBurmese ? 'အဖွဲ့ဝင်တစ်ဦးချင်း စာရင်း' : 'Member Breakdown';
  String get totalPaid => isBurmese ? 'စိုက်ထားငွေ' : 'Paid';
  String get fairShare => isBurmese ? 'ကျသင့်ငွေ' : 'Share';
  String get netBalance => isBurmese ? 'လက်ကျန်' : 'Net';
  String get allSettledMsg => isBurmese
      ? 'အားလုံး စာရင်းညီမျှနေပါပြီ (ပေးစရာ/ရစရာ မရှိပါ)။'
      : 'All balances are even! No transfers needed.';
  String get closeCycleBtn => isBurmese ? 'စာရင်းရှင်းပြီးကြောင်း မှတ်မည်' : 'Settle & Close Cycle';
  String get closeCycleTitle => isBurmese ? 'စာရင်းကာလ ပိတ်မည်လား?' : 'Close & Settle This Cycle?';
  String get closeCycleBody => isBurmese
      ? 'ဤစာရင်းရှင်းမှတ်တမ်းအတွက် အမည်ပေးပါ။ မှတ်တမ်းထဲသို့ သိမ်းဆည်းပြီး စာရင်းကာလအသစ် စတင်ပါမည်။'
      : 'Enter a name for this settlement. It will be saved to History and a fresh cycle will start.';
  String get cycleNameLabel => isBurmese ? 'စာရင်းရှင်း ခေါင်းစဉ် / အမည်' : 'Settlement / Cycle Name';
  String get cycleNameHint => isBurmese
      ? 'ဥပမာ - ပထမအပတ် (Nov 18 - Nov 25)'
      : 'e.g. Week 1 (Nov 18 - Nov 25)';
  String displayCycleTitle(SettlementCycle cycle) =>
      cycle.title.trim().isEmpty ? currentCycle : cycle.title;
  String get cycleSettledToast => isBurmese
      ? 'စာရင်းရှင်းပြီး မှတ်တမ်းသိမ်းဆည်းပြီးပါပြီ။'
      : 'Cycle settled and archived to History.';
  String get receivesLabel => isBurmese ? 'ရရန်' : 'Gets back';
  String get owesLabel => isBurmese ? 'ပေးရန်' : 'Owes';
  String get evenLabel => isBurmese ? 'ညီမျှ' : 'Settled';

  // Export
  String get exportPdf => isBurmese ? 'PDF ထုတ်မည်' : 'Export PDF';
  String get exportExcel => isBurmese ? 'Excel ထုတ်မည်' : 'Export Excel';
  String get exporting => isBurmese ? 'ဖိုင်ထုတ်နေပါသည်...' : 'Generating file...';
  String get exportFailed => isBurmese ? 'ဖိုင်ထုတ်ယူမှု မအောင်မြင်ပါ' : 'Export failed';

  // History
  String get historyTitle => isBurmese ? 'စာရင်းရှင်းပြီး မှတ်တမ်းများ' : 'Settlement History';
  String get noHistoryYet => isBurmese
      ? 'စာရင်းရှင်းပြီးသား မှတ်တမ်း မရှိသေးပါ။\nစာရင်းချုပ် စာမျက်နှာမှ "စာရင်းရှင်းပြီးကြောင်း မှတ်မည်" ကို နှိပ်၍ သိမ်းနိုင်ပါသည်။'
      : 'No settled cycles yet.\nOnce you settle a cycle, its full report will appear here.';
  String get settledBadge => isBurmese ? 'ရှင်းပြီး' : 'Settled';

  // Accounts & Members
  String get accountsTitle => isBurmese ? 'အကောင့်နှင့် အဖွဲ့ဝင်များ' : 'Accounts & Members';
  String get switchAccount => isBurmese ? 'အကောင့်ရွေးရန်' : 'Switch Account';
  String get createAccount => isBurmese ? 'အကောင့်အသစ် ဖန်တီးမည်' : 'Create New Account';
  String get editAccount => isBurmese ? 'အကောင့်အမည် ပြင်မည်' : 'Edit Account';
  String get accountNameLabel => isBurmese ? 'အကောင့် / အဖွဲ့အမည်' : 'Account / Group Name';
  String get currencyLabel => isBurmese ? 'ငွေကြေး' : 'Currency';
  String get membersSection => isBurmese ? 'အဖွဲ့ဝင်များ' : 'Members';
  String get addMember => isBurmese ? 'အဖွဲ့ဝင် ထည့်မည်' : 'Add Member';
  String get memberNameLabel => isBurmese ? 'အဖွဲ့ဝင် အမည်' : 'Member Name';
  String get deactivateMember => isBurmese ? 'နုတ်ထွက် / ပိတ်မည်' : 'Deactivate';
  String get reactivateMember => isBurmese ? 'ပြန်ဖွင့်မည်' : 'Reactivate';
  String get inactiveBadge => isBurmese ? 'ပိတ်ထား' : 'Inactive';
  String get settingsSection => isBurmese ? 'ဆက်တင်များ' : 'App Settings';
  String get languageLabel => isBurmese ? 'ဘာသာစကား' : 'Language';
  String get themeLabel => isBurmese ? 'အရောင်ပုံစံ' : 'Appearance';
  String get themeSystem => isBurmese ? 'စနစ်အတိုင်း' : 'System';
  String get themeLight => isBurmese ? 'အလင်း' : 'Light';
  String get themeDark => isBurmese ? 'အမှောင်' : 'Dark';

  // Onboarding
  String get welcomeTitle => isBurmese ? 'စိုက်ရှင်း (SiteShinn) မှ ကြိုဆိုပါတယ်' : 'Welcome to SiteShinn (စိုက်ရှင်း)';
  String get welcomeSubtitle => isBurmese
      ? 'အိမ်/အခန်းတူနေသူများ စုပေါင်းအသုံးစရိတ် မှတ်သားပြီး တစ်ချက်တည်း စာရင်းရှင်းနိုင်ပါပြီ။'
      : 'Track shared roommate expenses and settle who owes whom in one tap — 100% offline.';
  String get setupAccountBtn => isBurmese ? 'အကောင့်နှင့် အဖွဲ့ဝင် စတင်သတ်မှတ်မည်' : 'Create Group & Start';
  String get initialMembersHint => isBurmese
      ? 'အဖွဲ့ဝင်အမည်များ ထည့်ပါ (ဥပမာ - ၅ ဦး)'
      : 'Add members in your group (e.g. 5 roommates)';

  // Validation
  String get requiredField => isBurmese ? 'ဖြည့်စွက်ရန် လိုအပ်ပါသည်' : 'Required';
  String get invalidAmount => isBurmese ? 'မှန်ကန်သော ငွေပမာဏ ထည့်ပါ' : 'Enter a valid amount > 0';
  String get needOneMember => isBurmese ? 'အနည်းဆုံး အဖွဲ့ဝင် ၁ ဦး လိုအပ်ပါသည်' : 'Select at least 1 member';
  String get needTwoMembers => isBurmese ? 'အနည်းဆုံး အဖွဲ့ဝင် ၂ ဦး ထည့်ပါ' : 'Add at least 2 members to share expenses';
}

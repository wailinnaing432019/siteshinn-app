import '../../data/models/expense.dart';
import '../../data/models/settlement_cycle.dart';

enum AppLanguage { en, my }

class AppStrings {
  final AppLanguage language;

  const AppStrings(this.language);

  bool get isBurmese => language == AppLanguage.my;

  static AppStrings of(AppLanguage lang) => AppStrings(lang);

  String get appTitle => 'SiteShinn';
  String get appSubtitle =>
      isBurmese ? 'စိုက်ရှင်း • အဖွဲ့လိုက်နှင့် ကိုယ်ပိုင်စာရင်း' : 'စိုက်ရှင်း • Group & Personal Finance';

  // Navigation
  String get navExpenses => isBurmese ? 'စာရင်း' : 'Expenses';
  String get navLedger => isBurmese ? 'ဝင်/ထွက်ငွေ' : 'Ledger';
  String get navSettle => isBurmese ? 'စာရင်းချုပ်' : 'Settle Up';
  String get navSummary => isBurmese ? 'အချုပ်' : 'Summary';
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
  String get searchHint =>
      isBurmese ? 'ခေါင်းစဉ် သို့မဟုတ် စိုက်သူ ရှာရန်...' : 'Search item or payer...';
  String get personalSearchHint =>
      isBurmese ? 'အကြောင်းအရာ ရှာရန်...' : 'Search transactions...';
  String get all => isBurmese ? 'အားလုံး' : 'All';

  // Account Types & Personal Ledger
  String get accountTypeLabel => isBurmese ? 'အကောင့်အမျိုးအစား' : 'Account Type';
  String get groupAccountType => isBurmese ? 'အဖွဲ့လိုက် (Group Split)' : 'Group Split';
  String get groupAccountDesc => isBurmese
      ? 'အဖွဲ့ဝင်များ စိုက်ထားငွေနှင့် စာရင်းရှင်းရန်'
      : 'Track who paid & settle among members';
  String get personalAccountType =>
      isBurmese ? 'ကိုယ်ပိုင်စာရင်း (Personal)' : 'Personal Wallet';
  String get personalAccountDesc => isBurmese
      ? 'Member မပါဘဲ ဝင်ငွေ/ထွက်ငွေနှင့် လက်ကျန်မှတ်ရန်'
      : 'Income, expense & opening balance (no members)';
  String get openingBalanceLabel =>
      isBurmese ? 'စတင်လက်ကျန်ငွေ (Opening Balance)' : 'Opening Balance';
  String get editOpeningBalance =>
      isBurmese ? 'Opening Balance ပြင်မည်' : 'Edit Opening Balance';
  String get currentBalanceLabel =>
      isBurmese ? 'လက်ရှိလက်ကျန်ငွေ' : 'Current Balance';
  String get incomeLabel => isBurmese ? 'ဝင်ငွေ' : 'Income';
  String get expenseLabel => isBurmese ? 'ထွက်ငွေ' : 'Expense';
  String get totalIncomeLabel => isBurmese ? 'စုစုပေါင်း ဝင်ငွေ' : 'Total Income';
  String get totalExpenseLabel => isBurmese ? 'စုစုပေါင်း ထွက်ငွေ' : 'Total Expense';
  String get addTransaction => isBurmese ? 'စာရင်းထည့်မည်' : 'Add Entry';
  String get editTransaction => isBurmese ? 'စာရင်းပြင်မည်' : 'Edit Entry';
  String get noPersonalTxYet => isBurmese
      ? 'ဝင်ငွေ/ထွက်ငွေ စာရင်း မရှိသေးပါ။\nအောက်ပါ + ခလုတ်ဖြင့် စတင်မှတ်သားပါ။'
      : 'No income or expense entries yet.\nTap + Add Entry to record your first transaction.';
  String get allMonths => isBurmese ? 'အချိန်အားလုံး' : 'All Time';
  String get thisMonth => isBurmese ? 'ယခုလ' : 'This Month';
  String get last7Days => isBurmese ? '၇ ရက်အတွင်း' : 'Last 7 Days';
  String get startDateLabel => isBurmese ? 'စတင်ရက်' : 'Start Date';
  String get endDateLabel => isBurmese ? 'ပြီးဆုံးရက်' : 'End Date';
  String get pickDateRange => isBurmese ? 'ရက်စွဲရွေးရန်' : 'Date Range';
  String get personalSummaryTitle =>
      isBurmese ? 'ကိုယ်ပိုင်စာရင်း အချုပ်' : 'Wallet Summary';
  String get categoryBreakdown =>
      isBurmese ? 'အမျိုးအစားအလိုက် အသုံးစရိတ်' : 'Spending by Category';

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
  String get titleLabel =>
      isBurmese ? 'အကြောင်းအရာ (ဥပမာ - ဈေးဖိုး)' : 'Description (e.g. Groceries)';
  String get categoryLabel => isBurmese ? 'အမျိုးအစား' : 'Category';
  String get dateLabel => isBurmese ? 'နေ့စွဲ' : 'Date';
  String get deleteExpenseTitle => isBurmese ? 'စာရင်းဖျက်မည်လား?' : 'Delete Entry?';
  String get deleteExpenseConfirm => isBurmese
      ? 'ဤစာရင်းကို ဖျက်လိုက်ပါက စာရင်းအချုပ် တွက်ချက်မှု ပြောင်းလဲသွားပါမည်။'
      : 'Removing this entry will update the balance and summary.';

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
      case ExpenseCategory.transport:
        return isBurmese ? 'ခရီးသွား / ကားခ' : 'Transport';
      case ExpenseCategory.shopping:
        return isBurmese ? 'ဈေးဝယ်' : 'Shopping';
      case ExpenseCategory.health:
        return isBurmese ? 'ကျန်းမာရေး' : 'Health';
      case ExpenseCategory.salary:
        return isBurmese ? 'လစာ' : 'Salary';
      case ExpenseCategory.business:
        return isBurmese ? 'လုပ်ငန်း / အပိုဝင်ငွေ' : 'Business / Side Income';
      case ExpenseCategory.gift:
        return isBurmese ? 'လက်ဆောင် / ဘောနပ်စ်' : 'Gift / Bonus';
      case ExpenseCategory.refund:
        return isBurmese ? 'ပြန်အမ်းငွေ' : 'Refund';
      case ExpenseCategory.otherIncome:
        return isBurmese ? 'အခြားဝင်ငွေ' : 'Other Income';
      case ExpenseCategory.other:
        return isBurmese ? 'အခြား' : 'Other';
    }
  }

  // Settlement
  String get settlementTitle => isBurmese ? 'စာရင်းချုပ် / ရှင်းတမ်း' : 'Cycle Settlement';
  String get whoPaysWhom =>
      isBurmese ? 'ဘယ်သူက ဘယ်သူ့ကို ဘယ်လောက်ပေးရမလဲ' : 'Who Pays Whom';
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
  String get cycleNameLabel =>
      isBurmese ? 'စာရင်းရှင်း ခေါင်းစဉ် / အမည်' : 'Settlement / Cycle Name';
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
  String get chooseExportAction => isBurmese ? 'လုပ်ဆောင်ချက် ရွေးချယ်ပါ' : 'Export Options';
  String get shareFile => isBurmese ? 'တိုက်ရိုက် Share မည်' : 'Share File';
  String get shareFileSubtitle => isBurmese
      ? 'Viber, Messenger, Telegram စသည်ဖြင့် ပို့ရန်'
      : 'Send directly via Viber, Messenger, Telegram, etc.';
  String get saveToDevice =>
      isBurmese ? 'Save To Device (ဖုန်းထဲသိမ်းမည်)' : 'Save to Device';
  String get saveToDeviceSubtitle => isBurmese
      ? 'Downloads သို့မဟုတ် နှစ်သက်ရာ folder တွင် သိမ်းရန်'
      : 'Save file to Downloads or chosen folder';
  String get savedToDeviceToast =>
      isBurmese ? 'ဖုန်းထဲသို့ သိမ်းဆည်းပြီးပါပြီ။' : 'Saved to device successfully.';

  // History
  String get historyTitle => isBurmese ? 'စာရင်းရှင်းပြီး မှတ်တမ်းများ' : 'Settlement History';
  String get noHistoryYet => isBurmese
      ? 'စာရင်းရှင်းပြီးသား မှတ်တမ်း မရှိသေးပါ။\nစာရင်းချုပ် စာမျက်နှာမှ "စာရင်းရှင်းပြီးကြောင်း မှတ်မည်" ကို နှိပ်၍ သိမ်းနိုင်ပါသည်။'
      : 'No settled cycles yet.\nOnce you settle a cycle, its full report will appear here.';
  String get settledBadge => isBurmese ? 'ရှင်းပြီး' : 'Settled';

  // Accounts & Members
  String get accountsTitle => isBurmese ? 'အကောင့်နှင့် ဆက်တင်များ' : 'Accounts & Settings';
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

  // Daily Reminder & China ROM Alarm
  String get reminderSection =>
      isBurmese ? 'နေ့စဉ်သတိပေးချက် (Reminder / Alarm)' : 'Daily Reminder & Alarm';
  String get reminderToggle => isBurmese ? 'နေ့စဉ်သတိပေးမည်' : 'Enable Daily Reminder';
  String get addAlarmBtn => isBurmese ? 'Alarm ထည့်မည်' : 'Add Alarm';
  String get noAlarmsYet => isBurmese
      ? 'Alarm မရှိသေးပါ။ Add Alarm နှိပ်ပြီး ထည့်နိုင်ပါသည်။'
      : 'No alarms yet. Tap Add Alarm to create one.';
  String get reminderTimeLabel => isBurmese ? 'သတိပေးမည့် အချိန်' : 'Reminder Time';
  String get alarmModeToggle =>
      isBurmese ? 'Alarm Mode (China ROM အတွက်)' : 'Alarm Mode (China ROM)';
  String get alarmModeDesc => isBurmese
      ? 'Xiaomi/OPPO/Vivo တို့တွင် notification မပျောက်စေရန် Alarm Clock စနစ်ဖြင့် နှိုးပေးမည်'
      : 'Uses Android AlarmClock trigger & alarm sound so China ROMs do not kill it';
  String get testReminderBtn => isBurmese ? 'စမ်းသပ်ကြည့်မည်' : 'Test Sound Now';
  String get stopSoundBtn => isBurmese ? 'အသံပိတ်' : 'Stop';
  String get stopAlarmNotifLabel => isBurmese ? 'Alarm ပိတ်မည်' : 'Stop Alarm';
  String get alarmSoundLabel => isBurmese ? 'Alarm အသံ / သီချင်း' : 'Alarm Sound';
  String get defaultAlarmSound =>
      isBurmese ? 'ဖုန်း Alarm အသံ (Default)' : 'Default System Alarm';
  String get pickAlarmSongBtn => isBurmese ? 'သီချင်းရွေးမည်' : 'Choose Song';
  String get resetAlarmSongBtn => isBurmese ? 'Default ပြန်ထား' : 'Use Default';
  String get songSavedToast =>
      isBurmese ? 'Alarm သီချင်း သတ်မှတ်ပြီးပါပြီ။' : 'Custom alarm song saved.';
  String get batterySettingsBtn =>
      isBurmese ? 'Battery / Autostart ဖွင့်ရန်' : 'Battery & Autostart Setup';
  String get notifSettingsBtn =>
      isBurmese ? 'Notification ဆက်တင်' : 'Notification Settings';
  String get notifBlockedWarn => isBurmese
      ? 'Notification ခွင့်ပြုချက် ပိတ်ထားပါသည်။ ဖွင့်ရန် "Notification Settings" ကို နှိပ်ပါ။'
      : 'Notifications are blocked by the system. Tap Settings to enable them.';
  String get appInfoBtn => isBurmese ? 'App Info ဖွင့်မည်' : 'Open App Info';
  String get chinaRomTip => isBurmese
      ? 'China ROM ဖုန်းများ (Xiaomi/OPPO/Vivo) တွင် ညနေတိုင်း မပျက်မကွက်မြည်စေရန် App Info > Battery ကို "No restrictions" ထားပြီး "Autostart" ဖွင့်ပေးပါ။'
      : 'For China ROM phones (Xiaomi/OPPO/Vivo), set Battery to "No restrictions" and enable "Autostart" in App Info for 100% reliable daily alarms.';
  String get reminderScheduledToast =>
      isBurmese ? 'နေ့စဉ်သတိပေးချက် သတ်မှတ်ပြီးပါပြီ။' : 'Daily reminder updated.';
  String get reminderNotifTitle =>
      isBurmese ? 'စိုက်ရှင်း (SiteShinn) • စာရင်းမှတ်ချိန်' : 'SiteShinn • Daily Log Reminder';
  String get reminderNotifBody => isBurmese
      ? 'ယနေ့ ဝင်ငွေ/ထွက်ငွေများကို မှတ်သားဖို့ မမေ့ပါနဲ့နော်!'
      : 'Don\'t forget to record today\'s income & expenses!';
  String get notifChannelName =>
      isBurmese ? 'နေ့စဉ် သတိပေးချက်' : 'Daily Expense Reminder';
  String get notifChannelDesc =>
      isBurmese ? 'နေ့စဉ် ဝင်ငွေ/ထွက်ငွေ မှတ်သားရန် သတိပေးချက်' : 'Daily reminder to log income & expenses';
  String get alarmChannelName =>
      isBurmese ? 'နေ့စဉ် Alarm သတိပေးချက်' : 'Daily Alarm Reminder';
  String get alarmChannelDesc =>
      isBurmese ? 'China ROM ဖုန်းများအတွက် Alarm အသံဖြင့် သတိပေးချက်' : 'Alarm-priority daily reminder for China ROM devices';

  // Onboarding
  String get welcomeTitle =>
      isBurmese ? 'စိုက်ရှင်း (SiteShinn) မှ ကြိုဆိုပါတယ်' : 'Welcome to SiteShinn (စိုက်ရှင်း)';
  String get welcomeSubtitle => isBurmese
      ? 'အဖွဲ့လိုက် စိုက်ရှင်းစာရင်း (သို့မဟုတ်) ကိုယ်ပိုင် ဝင်/ထွက်ငွေစာရင်းကို ၁၀၀% offline ဖြင့် မှတ်သားနိုင်ပါပြီ။'
      : 'Track group roommate splits or personal income & expenses — 100% offline.';
  String get setupAccountBtn => isBurmese ? 'အကောင့်တည်ဆောက်ပြီး စတင်မည်' : 'Create Account & Start';
  String get initialMembersHint => isBurmese
      ? 'အဖွဲ့ဝင်အမည်များ ထည့်ပါ (ဥပမာ - ၅ ဦး)'
      : 'Add members in your group (e.g. 5 roommates)';

  // Validation
  String get requiredField => isBurmese ? 'ဖြည့်စွက်ရန် လိုအပ်ပါသည်' : 'Required';
  String get invalidAmount => isBurmese ? 'မှန်ကန်သော ငွေပမာဏ ထည့်ပါ' : 'Enter a valid amount > 0';
  String get invalidOpeningBalance =>
      isBurmese ? 'မှန်ကန်သော ငွေပမာဏ ထည့်ပါ (>= 0)' : 'Enter a valid balance (>= 0)';
  String get needOneMember => isBurmese ? 'အနည်းဆုံး အဖွဲ့ဝင် ၁ ဦး လိုအပ်ပါသည်' : 'Select at least 1 member';
  String get needTwoMembers =>
      isBurmese ? 'အနည်းဆုံး အဖွဲ့ဝင် ၂ ဦး ထည့်ပါ' : 'Add at least 2 members to share expenses';
}

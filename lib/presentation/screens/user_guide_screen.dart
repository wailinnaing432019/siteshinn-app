import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_strings.dart';
import '../../providers/app_providers.dart';
import '../widgets/brand_logo.dart';

class UserGuideScreen extends ConsumerWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final isMy = strings.isBurmese;
    final colorScheme = Theme.of(context).colorScheme;

    final sections = _buildSections(isMy);

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.userGuideTitle),
        actions: [
          TextButton(
            onPressed: () {
              ref
                  .read(appSettingsProvider.notifier)
                  .setLanguage(isMy ? AppLanguage.en : AppLanguage.my);
            },
            child: Text(isMy ? 'EN' : 'မြန်မာ'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            color: colorScheme.primaryContainer.withValues(alpha: 0.45),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const BrandLogo(size: 48, borderRadius: 12),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMy
                              ? 'စိုက်ရှင်း (SiteShinn) v2.2.1'
                              : 'SiteShinn (စိုက်ရှင်း) v2.2.1',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isMy
                              ? 'အခန်းဖော်စိုက်ရှင်းစာရင်းနှင့် ကိုယ်ပိုင်ဝင်/ထွက်ငွေစာရင်း အသုံးပြုနည်း လမ်းညွှန်'
                              : 'Complete guide for roommate expense splitting, personal ledger, cloud sync & exports.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...sections.asMap().entries.map((entry) {
            final idx = entry.key;
            final sec = entry.value;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                initiallyExpanded: idx == 0,
                leading: CircleAvatar(
                  backgroundColor: colorScheme.secondaryContainer,
                  foregroundColor: colorScheme.onSecondaryContainer,
                  child: Icon(sec.icon, size: 20),
                ),
                title: Text(
                  sec.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: sec.steps
                    .map(
                      (step) => Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '• ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                step,
                                style: const TextStyle(height: 1.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<({IconData icon, String title, List<String> steps})> _buildSections(
    bool isMy,
  ) {
    if (isMy) {
      return [
        (
          icon: Icons.group_outlined,
          title: '၁။ Group စိုက်ရှင်းစာရင်း & Invite Code',
          steps: [
            'Account အသစ်ဖွင့်ရာတွင် "Group Expense Split" ကို ရွေးပြီး အဖွဲ့ဝင်အမည်များ ထည့်ပါ (ပထမနေရာတွင် Login ဝင်ထားသူအမည် အလိုအလျောက် ဖြည့်ထားပေးပါသည်)။',
            'Accounts tab ထဲရှိ ၆ လုံးပါ Group Invite Code ကို Copy/Share လုပ်ပြီး အခန်းဖော်များကို ပေးနိုင်ပါသည်။',
            'သူငယ်ချင်းများက မိမိဖုန်းမှ Login ဝင်ပြီး "Join Group" -> Invite Code ရိုက်ထည့်၍ မိမိအမည်ကို ရွေးကာ ကိုယ်တိုင် Expense များ ဝင်ထည့်နိုင်ပါသည်။',
          ],
        ),
        (
          icon: Icons.receipt_long_outlined,
          title: '၂။ စာရင်းထည့်နည်း & ရှင်းတမ်းထုတ်နည်း (Settle Up)',
          steps: [
            '"+ Add Expense" နှိပ်ပြီး ခေါင်းစဉ်၊ ပမာဏ၊ Paid By (ပေးသူ) နှင့် Split Among (ပါဝင်ခွဲဝေမည့်သူများ) ကို ရွေးချယ်သိမ်းဆည်းပါ။',
            'လူအချို့သာ ပါဝင်သော စရိတ် (ဥပမာ - ၃ ဦးတည်း) ဖြစ်ပါက Split Among တွင် ထို ၃ ဦးကိုသာ ရွေးပေးနိုင်ပါသည်။',
            'အဖွဲ့ဝင်တစ်ဦးထံ ကြိုပေးငွေ / ဘုံငွေအိတ် (Advance) ထည့်လိုပါက Add ထဲတွင် "ကြိုပေးငွေ" ကို ရွေးပြီး ပေးသူ (From) နှင့် လက်ခံသူ (To) မှတ်ထားပါက Settle Up ရှင်းတမ်းတွင် အလိုအလျောက် ချိန်ညှိတွက်ချက်ပေးပါမည်။',
            'စာရင်းရှင်းလိုသည့်အခါ "Settle Up" tab တွင် ဘယ်သူက ဘယ်သူ့ကို ဘယ်လောက်ပြန်ပေးရမလဲ အနည်းဆုံးအကြိမ်ဖြင့် တွက်ချက်ပြပေးပါမည်။ နာမည်ရှည်များကို Card ပေါ် နှိပ်၍ အပြည့်ဖတ်နိုင်ပါသည်။',
            'စာရင်းပိတ်ပြီးနောက် "History" tab ထဲတွင် ငွေပေးပြီးသူများကို အမှန်ခြစ် (Paid / ပေးပြီး) မှတ်သားထားနိုင်ပါသည်။',
          ],
        ),
        (
          icon: Icons.account_balance_wallet_outlined,
          title: '၃။ Personal Wallet (ကိုယ်ပိုင်စာရင်း)',
          steps: [
            'Account ဖွင့်ရာတွင် "Personal Wallet" ကို ရွေးပါက မိမိတစ်ဦးတည်းသာ မြင်ရသော သီးသန့် ဝင်ငွေ/ထွက်ငွေ စာရင်းအဖြစ် အသုံးပြုနိုင်ပါသည် (အခြားသူများ မမြင်ရပါ)။',
            'Opening Balance သတ်မှတ်နိုင်ပြီး "Summary" tab တွင် Start Date / End Date အလိုက် ဝင်ငွေ၊ ထွက်ငွေနှင့် လက်ကျန်ငွေကို စစ်ဆေးနိုင်ပါသည်။',
          ],
        ),
        (
          icon: Icons.cloud_sync_outlined,
          title: '၄။ Login, Offline Mode & V1 Data Upload',
          steps: [
            'Google Login သို့မဟုတ် Email/Password နှစ်မျိုးလုံးဖြင့် Login ဝင်ပြီး ဖုန်းများအကြား Realtime Sync သုံးနိုင်ပါသည်။',
            'အင်တာနက်မရှိသည့်အခါ Offline Mode ဖြင့် ဆက်လက်မှတ်သားနိုင်ပြီး အင်တာနက်ပြန်ရချိန်တွင် "Retry Online" ဖြင့် ပြန်ချိတ်နိုင်ပါသည်။',
            'ယခင် Offline ဖြင့် ထည့်ထားပြီးသား စာရင်းဟောင်းများ ရှိပါက Accounts & Settings ထဲရှိ "Upload Now" နှိပ်ပြီး Cloud ထဲသို့ တစ်ခါတည်း တင်နိုင်ပါသည်။',
          ],
        ),
        (
          icon: Icons.picture_as_pdf_outlined,
          title: '၅။ PDF & Excel Export (Save + Open)',
          steps: [
            'Settle Up, History နှင့် Personal Summary တို့မှ "Export PDF" သို့မဟုတ် "Export Excel" နှိပ်၍ Share (သို့) Save to Device လုပ်နိုင်ပါသည်။',
            'Save to Device ပြီးသည်နှင့် အောက်ခြေတွင် ပေါ်လာသော "ဖွင့်မည် (Open)" ခလုတ်ကို နှိပ်၍ ဖိုင်ကို တိုက်ရိုက်ကြည့်ရှုနိုင်ပါသည်။',
          ],
        ),
        (
          icon: Icons.alarm_outlined,
          title: '၆။ နေ့စဉ်သတိပေး Alarm နှင့် App Update',
          steps: [
            'Accounts & Settings ထဲတွင် Alarm အချိန် ၁ ခုထက်မက ထည့်နိုင်ပြီး ဖုန်းထဲမှ ကြိုက်နှစ်သက်ရာ MP3 သီချင်းကို Alarm Sound အဖြစ် ရွေးနိုင်ပါသည်။',
            'Xiaomi / OPPO / Vivo ဖုန်းများတွင် နေ့စဉ် Alarm မပျက်စေရန် App Info > Battery ကို "No restrictions" ထား၍ "Autostart" ဖွင့်ပေးပါ။',
            'App Update အသစ်ထွက်ရှိပါက App ဖွင့်ချိန်တွင် အလိုအလျောက် အသိပေးမည်ဖြစ်ပြီး Accounts & Settings -> "Update စစ်ဆေးမည်" မှလည်း စစ်ဆေးတင်နိုင်ပါသည်။',
          ],
        ),
      ];
    }

    return [
      (
        icon: Icons.group_outlined,
        title: '1. Group Expense Splits & Invite Code',
        steps: [
          'Choose "Group Expense Split" when creating an account and add member names (Member 1 defaults to your signed-in name).',
          'Copy or Share the 6-character Group Invite Code in Accounts & Settings so roommates can join from their own phones.',
          'Friends sign in, tap "Join Group", enter the invite code, claim their name (or join as a new member), and log expenses directly.',
        ],
      ),
      (
        icon: Icons.receipt_long_outlined,
        title: '2. Recording Expenses & Settling Up',
        steps: [
          'Tap "+ Add Expense" to record title, amount, who paid (Paid By), and who shares the cost (Split Among).',
          'You can select all roommates or only specific participants for any item.',
          'Need to give money in advance to a buyer or common fund holder? Switch to "Advance" when adding an entry to set From (Giver) and To (Receiver) — Settle Up adjusts member balances automatically without inflating total group spending.',
          'In "Settle Up", SiteShinn calculates the minimum transfers ("Who Pays Whom"). Tap any transfer row to expand full member names on narrow screens.',
          'After closing a cycle, open it in "History" to mark transfers as Paid.',
        ],
      ),
      (
        icon: Icons.account_balance_wallet_outlined,
        title: '3. Personal Wallet Ledger',
        steps: [
          'Choose "Personal Wallet" for a completely private income & expense ledger visible only to your account.',
          'Set your Opening Balance and filter transactions by Start/End date, Current Month, Last 7 Days, or All Time in Summary.',
        ],
      ),
      (
        icon: Icons.cloud_sync_outlined,
        title: '4. Cloud Sync, Offline Mode & V1 Upload',
        steps: [
          'Sign in with Google or Email & Password for realtime multi-device cloud sync.',
          'If your device goes offline, SiteShinn switches smoothly to local offline mode; tap "Retry Online" in Accounts when connected again.',
          'Have existing local accounts? Tap "Upload Now" in Accounts & Settings to migrate local data safely to your cloud account.',
        ],
      ),
      (
        icon: Icons.picture_as_pdf_outlined,
        title: '5. PDF & Excel Export (Share / Save + Open)',
        steps: [
          'Export any open cycle, historical cycle, or personal wallet report as PDF (with full Myanmar Unicode rendering) or Excel.',
          'After using "Save to Device", tap the "Open" button on the confirmation bar to view your saved PDF or spreadsheet right away.',
        ],
      ),
      (
        icon: Icons.alarm_outlined,
        title: '6. Daily Reminder Alarms & In-App Updates',
        steps: [
          'Schedule multiple daily alarms and pick a custom audio/MP3 file from your device in Accounts & Settings.',
          'On Xiaomi/OPPO/Vivo devices, set Battery Saver to "No restrictions" and enable "Autostart" for reliable daily alarms.',
          'SiteShinn checks for new versions automatically without Play Store; you can also tap "Check for Updates" anytime in Accounts & Settings.',
        ],
      ),
    ];
  }
}

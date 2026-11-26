import 'package:flutter/material.dart';

import '../../data/models/expense.dart';

IconData iconForExpenseCategory(ExpenseCategory category) {
  switch (category) {
    case ExpenseCategory.food:
      return Icons.shopping_basket_outlined;
    case ExpenseCategory.cooking:
      return Icons.local_fire_department_outlined;
    case ExpenseCategory.utilities:
      return Icons.bolt_outlined;
    case ExpenseCategory.household:
      return Icons.cleaning_services_outlined;
    case ExpenseCategory.transport:
      return Icons.directions_bus_outlined;
    case ExpenseCategory.shopping:
      return Icons.shopping_bag_outlined;
    case ExpenseCategory.health:
      return Icons.medical_services_outlined;
    case ExpenseCategory.salary:
      return Icons.account_balance_wallet_outlined;
    case ExpenseCategory.business:
      return Icons.storefront_outlined;
    case ExpenseCategory.gift:
      return Icons.card_giftcard_outlined;
    case ExpenseCategory.refund:
      return Icons.replay_outlined;
    case ExpenseCategory.otherIncome:
      return Icons.attach_money_outlined;
    case ExpenseCategory.other:
      return Icons.receipt_outlined;
  }
}

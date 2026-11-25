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
    case ExpenseCategory.other:
      return Icons.receipt_outlined;
  }
}

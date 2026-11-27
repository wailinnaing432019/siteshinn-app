import 'package:flutter/material.dart';

import '../data/models/expense.dart';
import '../data/models/settlement_cycle.dart';

class CategorySlice {
  final ExpenseCategory category;
  final double amount;
  final double ratio;
  final Color color;

  const CategorySlice({
    required this.category,
    required this.amount,
    required this.ratio,
    required this.color,
  });
}

class DailyTrendPoint {
  final DateTime day;
  final double income;
  final double expense;

  const DailyTrendPoint({
    required this.day,
    required this.income,
    required this.expense,
  });
}

class CycleTrendPoint {
  final SettlementCycle cycle;
  final double totalExpense;

  const CycleTrendPoint({
    required this.cycle,
    required this.totalExpense,
  });
}

class AnalyticsService {
  AnalyticsService._();

  static Color colorForCategory(ExpenseCategory category) {
    switch (category) {
      case ExpenseCategory.food:
        return const Color(0xFF0F766E);
      case ExpenseCategory.cooking:
        return const Color(0xFFEA580C);
      case ExpenseCategory.utilities:
        return const Color(0xFF2563EB);
      case ExpenseCategory.household:
        return const Color(0xFF7C3AED);
      case ExpenseCategory.transport:
        return const Color(0xFF0891B2);
      case ExpenseCategory.shopping:
        return const Color(0xFFDB2777);
      case ExpenseCategory.health:
        return const Color(0xFFDC2626);
      case ExpenseCategory.salary:
        return const Color(0xFF16A34A);
      case ExpenseCategory.business:
        return const Color(0xFF059669);
      case ExpenseCategory.gift:
        return const Color(0xFFD97706);
      case ExpenseCategory.refund:
        return const Color(0xFF4F46E5);
      case ExpenseCategory.otherIncome:
        return const Color(0xFF65A30D);
      case ExpenseCategory.other:
        return const Color(0xFF64748B);
    }
  }

  static List<CategorySlice> computeCategoryBreakdown(
    List<Expense> expenses, {
    bool expensesOnly = true,
  }) {
    final totals = <ExpenseCategory, double>{};
    var grandTotal = 0.0;

    for (final e in expenses) {
      if (expensesOnly && e.isIncome) continue;
      if (e.amount <= 0) continue;
      totals[e.category] = (totals[e.category] ?? 0) + e.amount;
      grandTotal += e.amount;
    }

    if (totals.isEmpty || grandTotal <= 0) return const [];

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries
        .map(
          (entry) => CategorySlice(
            category: entry.key,
            amount: entry.value,
            ratio: (entry.value / grandTotal).clamp(0.0, 1.0),
            color: colorForCategory(entry.key),
          ),
        )
        .toList();
  }

  static List<DailyTrendPoint> computeDailyTrend(List<Expense> expenses) {
    final incomeByDay = <DateTime, double>{};
    final expenseByDay = <DateTime, double>{};

    for (final e in expenses) {
      final day = DateTime(
        e.expenseDate.year,
        e.expenseDate.month,
        e.expenseDate.day,
      );
      if (e.isIncome) {
        incomeByDay[day] = (incomeByDay[day] ?? 0) + e.amount;
      } else {
        expenseByDay[day] = (expenseByDay[day] ?? 0) + e.amount;
      }
    }

    final days = {...incomeByDay.keys, ...expenseByDay.keys}.toList()..sort();
    return days
        .map(
          (day) => DailyTrendPoint(
            day: day,
            income: incomeByDay[day] ?? 0,
            expense: expenseByDay[day] ?? 0,
          ),
        )
        .toList();
  }

  static String formatCompactAxis(double value) {
    final abs = value.abs();
    if (abs >= 1000000) {
      final m = value / 1000000;
      return '${m.toStringAsFixed(m.truncateToDouble() == m ? 0 : 1)}M';
    }
    if (abs >= 1000) {
      final k = value / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}k';
    }
    return value.toStringAsFixed(0);
  }
}

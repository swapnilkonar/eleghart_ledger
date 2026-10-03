import '../models/splitwise_models.dart';

class SplitTransfer {
  final String fromMember;
  final String toMember;
  final double amount;

  SplitTransfer({
    required this.fromMember,
    required this.toMember,
    required this.amount,
  });
}

class MemberBalance {
  final String member;
  final double totalPaid;
  final double totalOwed;

  MemberBalance({
    required this.member,
    required this.totalPaid,
    required this.totalOwed,
  });

  double get netBalance => totalPaid - totalOwed;
  bool get isOwed => netBalance > 0.01;
  bool get owes => netBalance < -0.01;
  bool get isSettled => netBalance.abs() <= 0.01;
}

class SplitwiseService {
  /// Calculates member balances for a specific Splitwise group, converted to Group Base Currency
  static List<MemberBalance> calculateMemberBalances(
    SplitwiseGroupModel group,
    List<SplitwiseExpenseModel> groupExpenses,
  ) {
    final Map<String, double> paidMap = {};
    final Map<String, double> owedMap = {};

    final allMembers = group.members.isEmpty ? ['You'] : group.members;
    for (final m in allMembers) {
      paidMap[m] = 0.0;
      owedMap[m] = 0.0;
    }

    for (final expense in groupExpenses) {
      final rate = expense.exchangeRate > 0 ? expense.exchangeRate : 1.0;

      // 1. Paid By (converted to Group Base Currency)
      for (final entry in expense.paidBy.entries) {
        final payer = entry.key;
        final convertedPaid = entry.value * rate;
        paidMap[payer] = (paidMap[payer] ?? 0.0) + convertedPaid;
      }

      // 2. Owed / Share (converted to Group Base Currency)
      if (expense.distribution.isNotEmpty) {
        for (final entry in expense.distribution.entries) {
          final debtor = entry.key;
          final convertedOwed = entry.value * rate;
          owedMap[debtor] = (owedMap[debtor] ?? 0.0) + convertedOwed;
        }
      } else {
        // Exclude members specified in excludedMembers
        final activeMembers = allMembers.where((m) => !expense.excludedMembers.contains(m)).toList();
        final effectiveList = activeMembers.isEmpty ? allMembers : activeMembers;
        final shareInBase = (expense.amount * rate) / effectiveList.length;

        for (final m in effectiveList) {
          owedMap[m] = (owedMap[m] ?? 0.0) + shareInBase;
        }
      }
    }

    return allMembers.map((m) {
      return MemberBalance(
        member: m,
        totalPaid: paidMap[m] ?? 0.0,
        totalOwed: owedMap[m] ?? 0.0,
      );
    }).toList();
  }

  /// Min-Cash-Flow Debt Simplification Algorithm
  static List<SplitTransfer> simplifyDebts(List<MemberBalance> balances) {
    final List<_MemberNet> debtors = [];
    final List<_MemberNet> creditors = [];

    for (final b in balances) {
      if (b.owes) {
        debtors.add(_MemberNet(b.member, b.netBalance.abs()));
      } else if (b.isOwed) {
        creditors.add(_MemberNet(b.member, b.netBalance));
      }
    }

    debtors.sort((a, b) => b.amount.compareTo(a.amount));
    creditors.sort((a, b) => b.amount.compareTo(a.amount));

    final List<SplitTransfer> transfers = [];

    int i = 0;
    int j = 0;

    while (i < debtors.length && j < creditors.length) {
      final debtor = debtors[i];
      final creditor = creditors[j];

      final settleAmount = debtor.amount < creditor.amount
          ? debtor.amount
          : creditor.amount;

      if (settleAmount > 0.01) {
        transfers.add(SplitTransfer(
          fromMember: debtor.name,
          toMember: creditor.name,
          amount: settleAmount,
        ));
      }

      debtor.amount -= settleAmount;
      creditor.amount -= settleAmount;

      if (debtor.amount <= 0.01) i++;
      if (creditor.amount <= 0.01) j++;
    }

    return transfers;
  }

  /// Generates WhatsApp shareable summary report with join links & invite code
  static String generateWhatsAppSummary({
    required SplitwiseGroupModel group,
    required List<MemberBalance> balances,
    required List<SplitTransfer> transfers,
    required double totalGroupExpenses,
  }) {
    final symbol = group.currencySymbol;
    final buffer = StringBuffer();
    buffer.writeln("📊 *ELEGHART LEDGER - ${group.name.toUpperCase()}*");
    buffer.writeln("💰 Total Group Expenses: $symbol${totalGroupExpenses.toStringAsFixed(0)} (${group.currency})");
    buffer.writeln("");

    buffer.writeln("👥 *MEMBER BALANCES:*");
    for (final b in balances) {
      if (b.isOwed) {
        buffer.writeln("  • ${b.member}: Gets back $symbol${b.netBalance.toStringAsFixed(0)} 🟢");
      } else if (b.owes) {
        buffer.writeln("  • ${b.member}: Owes $symbol${b.netBalance.abs().toStringAsFixed(0)} 🔴");
      } else {
        buffer.writeln("  • ${b.member}: Settled (${symbol}0) ⚪");
      }
    }
    buffer.writeln("");

    buffer.writeln("🔄 *SIMPLIFIED SETTLEMENTS:*");
    if (transfers.isEmpty) {
      buffer.writeln("🎉 Everyone is fully settled!");
    } else {
      for (final t in transfers) {
        buffer.writeln("  👉 *${t.fromMember}* pays *${t.toMember}*: $symbol${t.amount.toStringAsFixed(0)}");
      }
    }

    if (group.inviteCode.isNotEmpty) {
      buffer.writeln("");
      buffer.writeln("📲 *JOIN GROUP ON ELEGHART LEDGER:*");
      buffer.writeln("👉 Join Link: https://eleghartledger.app/join?code=${group.inviteCode}");
      buffer.writeln("🔑 Invite Code: *${group.inviteCode}*");
    }

    buffer.writeln("");
    buffer.writeln("Sent via Eleghart Ledger 📱");
    return buffer.toString();
  }

  /// Generates WhatsApp reminder message for a debtor to settle up
  static String generateWhatsAppNudgeMessage({
    required String debtorName,
    required String creditorName,
    required double amount,
    required String currencySymbol,
    required String groupName,
    String? upiId,
  }) {
    final buffer = StringBuffer();
    buffer.writeln("👋 Hi $debtorName,");
    buffer.writeln("Quick reminder for our group '*$groupName*' on Eleghart Ledger.");
    buffer.writeln("You owe *$creditorName*: *$currencySymbol${amount.toStringAsFixed(0)}*.");
    if (upiId != null && upiId.isNotEmpty) {
      buffer.writeln("");
      buffer.writeln("💳 Pay instantly via UPI:");
      buffer.writeln("UPI ID: `$upiId`");
    }
    buffer.writeln("");
    buffer.writeln("Thanks! 🙏");
    return buffer.toString();
  }
}

class _MemberNet {
  final String name;
  double amount;
  _MemberNet(this.name, this.amount);
}


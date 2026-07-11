import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';

class BankDetailsPage extends StatefulWidget {
  const BankDetailsPage({super.key});

  @override
  State<BankDetailsPage> createState() => _BankDetailsPageState();
}

class _BankDetailsPageState extends State<BankDetailsPage> {
  String _defaultBankName = 'HDFC Bank';

  // Local list of active accounts to allow adding new ones
  final List<Map<String, dynamic>> _banks = [];

  @override
  void initState() {
    super.initState();
    _loadBankPreferences();
  }

  Future<void> _loadBankPreferences() async {
    try {
      final prefs = await settingsPreferencesService.load();
      final defaultBank = prefs['defaultBankName'];
      final savedBanks = prefs['linkedBanks'];
      if (!mounted) return;
      setState(() {
        if (defaultBank is String && defaultBank.isNotEmpty) {
          _defaultBankName = defaultBank;
        }
        if (savedBanks is List && savedBanks.isNotEmpty) {
          _banks
            ..clear()
            ..addAll(
              savedBanks.whereType<Map>().map((bank) {
                final map = Map<String, dynamic>.from(bank);
                return {
                  'name': map['name']?.toString() ?? 'Bank',
                  'accNum': map['accNum']?.toString() ?? '****',
                  'type': map['type']?.toString() ?? 'Savings Account',
                  'holder': map['holder']?.toString() ?? '',
                  'color1': const Color(0xFF6B7280),
                  'color2': const Color(0xFF374151),
                };
              }),
            );
        }
      });
    } catch (_) {}
  }

  Future<void> _saveBankPreferences() {
    return settingsPreferencesService.savePatch({
      'defaultBankName': _defaultBankName,
      'linkedBanks': _banks
          .map(
            (bank) => {
              'name': bank['name']?.toString() ?? '',
              'accNum': bank['accNum']?.toString() ?? '',
              'type': bank['type']?.toString() ?? '',
              'holder': bank['holder']?.toString() ?? '',
            },
          )
          .toList(),
    });
  }

  void _showBankOptionsSheet(String bankName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              bankName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select an option for this bank account.',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: primary.withOpacity(0.1),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.orange,
                  size: 24,
                ),
              ),
              title: const Text(
                'Set as Default for Payments',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: ink,
                ),
              ),
              subtitle: const Text(
                'Use this account for automatic deposits and payouts',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              trailing: _defaultBankName == bankName
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _defaultBankName = bankName;
                });
                _saveBankPreferences();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '$bankName is now set as your default account for payments.',
                    ),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: primary,
                  ),
                );
              },
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade50,
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.green,
                  size: 24,
                ),
              ),
              title: const Text(
                'See Account Balance',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: ink,
                ),
              ),
              subtitle: const Text(
                'View available funds (requires UPI PIN)',
                style: TextStyle(fontSize: 12, color: muted),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showBalanceSheet(bankName);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showBalanceSheet(String bankName) {
    String enteredPin = '';
    bool isProcessing = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void onKey(String val) {
            if (isProcessing) return;
            setModalState(() {
              if (val == '<') {
                if (enteredPin.isNotEmpty)
                  enteredPin = enteredPin.substring(0, enteredPin.length - 1);
              } else if (enteredPin.length < 4) {
                enteredPin += val;
                if (enteredPin.length == 4) {
                  isProcessing = true;
                  Future.delayed(const Duration(milliseconds: 1200), () {
                    isProcessing = false;
                    Navigator.pop(ctx); // Close PIN sheet
                    _showBalanceResult(bankName);
                  });
                }
              }
            });
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Enter UPI PIN for $bankName',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Required to view secure account balance.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (idx) {
                    final hasChar = idx < enteredPin.length;
                    return Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasChar ? primary : Colors.grey.shade300,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                if (isProcessing)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  )
                else
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    childAspectRatio: 1.8,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      for (int i = 1; i <= 9; i++)
                        TextButton(
                          onPressed: () => onKey(i.toString()),
                          child: Text(
                            i.toString(),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: ink,
                            ),
                          ),
                        ),
                      const SizedBox(),
                      TextButton(
                        onPressed: () => onKey('0'),
                        child: const Text(
                          '0',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: ink,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => onKey('<'),
                        icon: const Icon(
                          Icons.backspace_outlined,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showBalanceResult(String bankName) {
    final balanceVal = globalBankBalances.value[bankName] ?? 0.0;

    // Play a preview ping/chime when showing balance
    soundService.selectedTone.value = 'Success Ping';
    soundService.playSelectedTone();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: const CircleAvatar(
          radius: 28,
          backgroundColor: Color(0xFFDCFCE7),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            color: success,
            size: 28,
          ),
        ),
        title: Text('$bankName Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Available Account Balance:',
              style: TextStyle(color: muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              '₹${balanceVal.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: success,
              ),
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Okay'),
          ),
        ],
      ),
    );
  }

  void _showAddAccountSheet() {
    final bankCtrl = TextEditingController();
    final accCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Link Bank Account',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter account credentials to securely link via UPI.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: bankCtrl,
              decoration: InputDecoration(
                labelText: 'Bank Name (e.g. ICICI Bank)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Account Holder Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: accCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Last 4 Digits of Account Number',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (bankCtrl.text.isEmpty ||
                      nameCtrl.text.isEmpty ||
                      accCtrl.text.isEmpty)
                    return;
                  Navigator.pop(ctx);
                  setState(() {
                    _banks.add({
                      'name': bankCtrl.text,
                      'accNum': '**** ${accCtrl.text}',
                      'type': 'Savings Account',
                      'holder': nameCtrl.text,
                      'color1': const Color(0xFF6B7280),
                      'color2': const Color(0xFF374151),
                    });
                    // Initialize balance for new bank
                    final map = Map<String, double>.from(
                      globalBankBalances.value,
                    );
                    map[bankCtrl.text] = 10000.00; // default starting balance
                    globalBankBalances.value = map;
                  });
                  _saveBankPreferences();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${bankCtrl.text} linked successfully!'),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Verify & Link',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bank Accounts & Balance',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Kicker('LINKED CARDS'),
            const SizedBox(height: 12),

            // Render bank cards
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _banks.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, idx) {
                  final bank = _banks[idx];
                  return GestureDetector(
                    onTap: () => _showBankOptionsSheet(bank['name']),
                    child: Container(
                      width: 320,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            bank['color1'] as Color,
                            bank['color2'] as Color,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: (bank['color1'] as Color).withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    bank['name'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  if (bank['name'] == _defaultBankName) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check,
                                            size: 10,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'DEFAULT',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const Icon(
                                Icons.credit_card,
                                color: Colors.white70,
                                size: 28,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            bank['type'],
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            bank['accNum'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'CARD HOLDER',
                                      style: TextStyle(
                                        color: Colors.white30,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      bank['holder'],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _showBankOptionsSheet(bank['name']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(
                                    0.18,
                                  ),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                  size: 14,
                                ),
                                label: const Text(
                                  'Manage',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _showAddAccountSheet,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(color: primary.withOpacity(0.4), width: 1.5),
              ),
              icon: const Icon(Icons.add, color: primary),
              label: const Text(
                'Link Another Bank Account',
                style: TextStyle(color: primary, fontWeight: FontWeight.w800),
              ),
            ),

            const SizedBox(height: 40),
            const Kicker('RECENT BANK TRANSACTIONS'),
            const SizedBox(height: 16),

            ValueListenableBuilder<List<Map<String, dynamic>>>(
              valueListenable: globalPaymentHistory,
              builder: (context, txList, _) {
                if (txList.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Text(
                        'No recent statements',
                        style: TextStyle(
                          color: muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: txList.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (context, idx) {
                    final tx = txList[idx];
                    return Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.grey.shade100,
                          child: Icon(
                            tx['icon'] as IconData? ?? Icons.storefront,
                            color: primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx['merchant'] ?? 'Platform Transfer',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                tx['date'] ?? '',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          tx['amount'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: success,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

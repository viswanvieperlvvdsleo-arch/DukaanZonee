import 'package:flutter/material.dart';
import 'package:dukaan_zone_flutter/dukaan.dart';
// Financial models (SellerFinancialAccount, FinancialTx, etc.) come from here:
// ignore: implementation_imports
import 'package:dukaan_zone_flutter/ui/pages/admin/financials_page.dart'
    show SellerFinancialAccount, FinancialTx, FinancialTxCategory, FinancialTxType, FinancialTxCategoryX;

class SellerFinancialDetailsPage extends StatefulWidget {
  const SellerFinancialDetailsPage({super.key, required this.account});
  final SellerFinancialAccount account;

  @override
  State<SellerFinancialDetailsPage> createState() => _SellerFinancialDetailsPageState();
}

class _SellerFinancialDetailsPageState extends State<SellerFinancialDetailsPage> {
  String _txSearchQuery = '';
  FinancialTxCategory? _categoryFilter;

  List<FinancialTx> get _filteredTransactions {
    final query = _txSearchQuery.toLowerCase();
    return widget.account.transactions.where((tx) {
      // Filter by category if selected
      if (_categoryFilter != null && tx.category != _categoryFilter) {
        return false;
      }
      
      // Filter by search query (ID, amount, category label, or date)
      if (query.isEmpty) return true;

      final dateStr = '${tx.date.day}/${tx.date.month}/${tx.date.year}'.toLowerCase();
      final timeStr = '${tx.date.hour.toString().padLeft(2, '0')}:${tx.date.minute.toString().padLeft(2, '0')}';
      final amountStr = tx.amount.toStringAsFixed(2);
      final categoryStr = tx.category.label.toLowerCase();
      final idStr = tx.id.toLowerCase();

      return idStr.contains(query) ||
          amountStr.contains(query) ||
          categoryStr.contains(query) ||
          dateStr.contains(query) ||
          timeStr.contains(query);
    }).toList();
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year} • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCredits = widget.account.transactions
        .where((tx) => tx.type == FinancialTxType.credit)
        .fold(0.0, (sum, tx) => sum + tx.amount);
    final totalDebits = widget.account.transactions
        .where((tx) => tx.type == FinancialTxType.debit)
        .fold(0.0, (sum, tx) => sum + tx.amount);
    
    final filteredList = _filteredTransactions;

    return Scaffold(
      backgroundColor: isDark ? bgDark : bgLight,
      appBar: MainHeader(
        role: Role.admin,
        onExit: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Breadcrumbs & Back Navigation
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Back to Financials Hub', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Shop Header Profile Summary
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: muted.withOpacity(0.15)),
                    boxShadow: shadowSm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.storefront, color: success, size: 32),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.account.shopName,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Merchant Owner: ${widget.account.ownerName}',
                              style: const TextStyle(color: muted, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${widget.account.totalReceived.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 26, color: success),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'TOTAL NET RECEIVED',
                            style: TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Stats Dashboard (Credits / Debits / Count) - Responsive Layout
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 600;
                    final card1 = _buildStatMiniCard('Total Inflow (Credit)', '₹${totalCredits.toStringAsFixed(2)}', success, Icons.trending_up, isNarrow);
                    final card2 = _buildStatMiniCard('Total Outflow (Debit)', '₹${totalDebits.toStringAsFixed(2)}', Colors.redAccent, Icons.trending_down, isNarrow);
                    final card3 = _buildStatMiniCard('Transaction Volume', '${widget.account.transactions.length} txns', primary, Icons.analytics_outlined, isNarrow);

                    if (isNarrow) {
                      return Column(
                        children: [
                          card1,
                          const SizedBox(height: 12),
                          card2,
                          const SizedBox(height: 12),
                          card3,
                        ],
                      );
                    } else {
                      return Row(
                        children: [
                          Expanded(child: card1),
                          const SizedBox(width: 16),
                          Expanded(child: card2),
                          const SizedBox(width: 16),
                          Expanded(child: card3),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 32),

                // Transaction Feed Kicker
                const Kicker('LEDGER TRANSACTION HISTORY'),
                const SizedBox(height: 12),

                // Filter & Search Controls card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: muted.withOpacity(0.15)),
                    boxShadow: shadowSm,
                  ),
                  child: Column(
                    children: [
                      // Search Bar input
                      TextField(
                        onChanged: (v) => setState(() => _txSearchQuery = v),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, color: muted),
                          hintText: 'Search by amount (e.g. 60), date (e.g. 24/5), ID, or keyword...',
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF4F6F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Segmented Category Filter Pill list
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildFilterChip('All Types', null),
                            const SizedBox(width: 8),
                            _buildFilterChip(FinancialTxCategory.promotion.label, FinancialTxCategory.promotion),
                            const SizedBox(width: 8),
                            _buildFilterChip(FinancialTxCategory.payoutDeduction.label, FinancialTxCategory.payoutDeduction),
                            const SizedBox(width: 8),
                            _buildFilterChip(FinancialTxCategory.refund.label, FinancialTxCategory.refund),
                            const SizedBox(width: 8),
                            _buildFilterChip(FinancialTxCategory.platformFee.label, FinancialTxCategory.platformFee),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Dynamic Transaction list items
                if (filteredList.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 64),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: muted.withOpacity(0.15)),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 64, color: muted),
                          SizedBox(height: 16),
                          Text(
                            'No transactions match search criteria.',
                            style: TextStyle(color: muted, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final tx = filteredList[index];
                      final isCredit = tx.type == FinancialTxType.credit;
                      final txColor = tx.category == FinancialTxCategory.promotion 
                          ? primary 
                          : tx.category == FinancialTxCategory.payoutDeduction 
                              ? success 
                              : tx.category == FinancialTxCategory.refund 
                                  ? Colors.redAccent 
                                  : success;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: txColor.withOpacity(0.2)),
                          boxShadow: shadowSm,
                        ),
                        child: Row(
                          children: [
                            // Left Category icon container
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: txColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(tx.category.icon, color: txColor, size: 24),
                            ),
                            const SizedBox(width: 16),

                            // Transaction details and clear timestamps
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        tx.category.label,
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                      ),
                                      // Specific visual badge mapping payout origin
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: txColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          tx.category == FinancialTxCategory.promotion 
                                              ? 'PROMOTIONS ORIGIN' 
                                              : tx.category == FinancialTxCategory.payoutDeduction 
                                                  ? '3% platform pay deduction'.toUpperCase() 
                                                  : 'OTHER LEDGER',
                                          style: TextStyle(
                                            color: txColor, 
                                            fontSize: 8, 
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${tx.id} • ${_formatDate(tx.date)}',
                                    style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),

                            // Right Amount block
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${isCredit ? '+' : '-'}₹${tx.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17,
                                    color: isCredit ? success : Colors.redAccent,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isCredit ? success.withOpacity(0.12) : Colors.redAccent.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isCredit ? 'CREDIT' : 'DEBIT',
                                    style: TextStyle(
                                      color: isCredit ? success : Colors.redAccent, 
                                      fontSize: 9, 
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatMiniCard(String title, String value, Color color, IconData icon, bool isNarrow) {
    return Container(
      padding: EdgeInsets.all(isNarrow ? 16 : 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: shadowSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: TextStyle(
                    color: color, 
                    fontSize: isNarrow ? 18 : 20, 
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: EdgeInsets.all(isNarrow ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isNarrow ? 20 : 24),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, FinancialTxCategory? category) {
    final isSelected = _categoryFilter == category;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : ink),
        ),
      ),
      selected: isSelected,
      selectedColor: primary,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E293B) : const Color(0xFFF4F6F8),
      onSelected: (selected) {
        setState(() {
          _categoryFilter = selected ? category : null;
        });
      },
    );
  }
}

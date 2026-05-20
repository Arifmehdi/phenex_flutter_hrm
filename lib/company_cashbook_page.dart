import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'session_manager.dart';

class CompanyCashbookPage extends StatefulWidget {
  const CompanyCashbookPage({super.key});

  @override
  State<CompanyCashbookPage> createState() => _CompanyCashbookPageState();
}

class _CompanyCashbookPageState extends State<CompanyCashbookPage> {
  late DateTime _fromDate;
  late DateTime _toDate;
  bool _isLoading = true;
  
  double _openingBalance = 0.0;
  List<dynamic> _incomeList = [];
  List<dynamic> _expenseList = [];
  
  double get _totalIncome => _incomeList.fold(0.0, (sum, item) {
    final amt = (item['incomeAmount'] ?? item['amount'] ?? '0').toString();
    return sum + (double.tryParse(amt) ?? 0.0);
  });
  
  double get _totalExpense => _expenseList.fold(0.0, (sum, item) {
    final amt = (item['expenseAmount'] ?? item['amount'] ?? '0').toString();
    return sum + (double.tryParse(amt) ?? 0.0);
  });
  double get _cashInHand => (_totalIncome + _openingBalance) - _totalExpense;

  @override
  void initState() {
    super.initState();
    _toDate = DateTime.now();
    _fromDate = DateTime(_toDate.year, _toDate.month, 1);
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final orgId = await SessionManager.getOrgId() ?? 106;
      
      final startStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      final endStr = DateFormat('yyyy-MM-dd').format(_toDate);
      
      // Use the unified CashBook/list API
      final url = 'https://bs-org.com/index.php/api/CashBook/list?orgID=$orgId&start=$startStr&end=$endStr';
      debugPrint('Fetching Cashbook: $url');
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Cashbook Response: $data');
        
        if (data['status'] == true) {
          // Based on cashbooks.txt API sample:
          _openingBalance = double.tryParse(data['opening_balance']?.toString() ?? '0') ?? 0.0;
          _incomeList = data['income_summary'] as List<dynamic>? ?? [];
          _expenseList = data['expense_summary'] as List<dynamic>? ?? [];
          
          debugPrint('Parsed -> Opening: $_openingBalance, Income count: ${_incomeList.length}, Expense count: ${_expenseList.length}');
          
          // Fallback to previous logic if summary lists are empty but raw data exists
          if (_incomeList.isEmpty && _expenseList.isEmpty) {
            final rawData = data['data'] ?? data;
            final incomeData = rawData['income'] as List<dynamic>? ?? 
                              rawData['accIncome'] as List<dynamic>? ?? [];
            final expenseData = rawData['expense'] as List<dynamic>? ?? 
                               rawData['accExpense'] as List<dynamic>? ?? [];
            
            if (rawData['accOpenBalance'] != null) {
              _openingBalance = double.tryParse(rawData['accOpenBalance'].toString()) ?? 0.0;
              _incomeList = incomeData.where((item) => (item['iHead'] ?? item['head']) != 'Opening Balance').toList();
            } else {
              final opening = incomeData.firstWhere(
                (item) => (item['iHead'] ?? item['head']) == 'Opening Balance', 
                orElse: () => null
              );
              if (opening != null) {
                _openingBalance = double.tryParse((opening['incomeAmount'] ?? opening['amount'] ?? '0').toString()) ?? 0.0;
                _incomeList = incomeData.where((item) => (item['iHead'] ?? item['head']) != 'Opening Balance').toList();
              } else {
                _incomeList = incomeData;
              }
            }
            _expenseList = expenseData;
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching cashbook data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate : _toDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPageHeader(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFDDDDDD)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildListHeader(),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    _buildOpeningBalanceBar(),
                    _buildIncomeExpenseGrid(),
                    _buildCashInHandFooter(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.account_balance_wallet, size: 20, color: Color(0xFF666666)),
              SizedBox(width: 8),
              Text(
                'Company Cashbook',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildHeaderIcon(Icons.assignment),
              const SizedBox(width: 12),
              _buildHeaderIcon(Icons.refresh),
              const SizedBox(width: 12),
              _buildHeaderIcon(Icons.settings),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon) {
    return InkWell(
      onTap: icon == Icons.refresh ? _fetchData : null,
      child: Icon(icon, size: 18, color: Colors.grey[600]),
    );
  }

  Widget _buildListHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        border: Border(bottom: BorderSide(color: Color(0xFFDDDDDD))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Cashbook Report',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              Text(
                'From: ${DateFormat('dd/MM/yyyy').format(_fromDate)}  To: ${DateFormat('dd/MM/yyyy').format(_toDate)}',
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOpeningBalanceBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(12.0),
        constraints: const BoxConstraints(minWidth: 500), // Ensure search controls don't squash
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Opening Balance: ${NumberFormat('#,##0.00').format(_openingBalance)}/-',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(width: 20),
            Row(
              children: [
                _buildMiniDatePicker(_fromDate, true),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text('-', style: TextStyle(color: Colors.grey)),
                ),
                _buildMiniDatePicker(_toDate, false),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _fetchData,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBA6D6D),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: const Text('Search', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncomeExpenseGrid() {
    return Column(
      children: [
        const Divider(height: 1),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 350, // Minimum width for Income side
                  child: _buildSection('Income', _incomeList, _totalIncome),
                ),
                Container(width: 1, color: const Color(0xFFDDDDDD)),
                SizedBox(
                  width: 350, // Minimum width for Expense side
                  child: _buildSection('Expense', _expenseList, _totalExpense),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<dynamic> data, double total) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DataTable(
          columnSpacing: 16,
          headingRowHeight: 40,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 40,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F5F5)),
          border: const TableBorder(
            verticalInside: BorderSide(color: Color(0xFFDDDDDD), width: 1),
            horizontalInside: BorderSide(color: Color(0xFFDDDDDD), width: 1),
            bottom: BorderSide(color: Color(0xFFDDDDDD), width: 1),
          ),
          columns: [
            const DataColumn(label: Center(child: Text('SL#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
            DataColumn(label: Center(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
            const DataColumn(label: Center(child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
          ],
          rows: data.isEmpty 
            ? [
                const DataRow(cells: [
                  DataCell(Text('')),
                  DataCell(Text('No data found', style: TextStyle(fontSize: 12))),
                  DataCell(Text('')),
                ])
              ]
            : List.generate(data.length, (index) {
                final item = data[index];
                final head = item['iHead'] ?? item['eHead'] ?? item['head'] ?? 'Unknown';
                final amount = double.tryParse((item['incomeAmount'] ?? item['expenseAmount'] ?? item['amount'] ?? '0').toString()) ?? 0.0;
                return DataRow(cells: [
                  DataCell(Center(child: Text((index + 1).toString(), style: const TextStyle(fontSize: 12)))),
                  DataCell(Text(head, style: const TextStyle(fontSize: 12))),
                  DataCell(
                    Container(
                      alignment: Alignment.centerRight,
                      child: Text(NumberFormat('#,##0.00').format(amount), style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ]);
              }),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: const Color(0xFFF9F9F9),
          child: Text(
            'Total $title: ${NumberFormat('#,##0.00').format(total)}/-',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniDatePicker(DateTime date, bool isFrom) {
    return InkWell(
      onTap: () => _selectDate(context, isFrom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDDDDD)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          children: [
            Text(DateFormat('dd/MM/yyyy').format(date), style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 4),
            const Icon(Icons.calendar_today, size: 10, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildCashInHandFooter() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        border: Border(top: BorderSide(color: Color(0xFFDDDDDD))),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text(
            'Cash in Hand : ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF333333)),
          ),
          const SizedBox(width: 8),
          Text(
            '${NumberFormat('#,##0.00').format(_cashInHand)}/-',
            style: const TextStyle(
              color: Colors.red, // Matching standard accounting emphasis
              fontWeight: FontWeight.bold, 
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

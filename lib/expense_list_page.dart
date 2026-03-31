import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'session_manager.dart';

class ExpenseListPage extends StatefulWidget {
  final VoidCallback? onAddNew;
  final Function(Map<String, dynamic>)? onEditExpense;

  const ExpenseListPage({
    super.key,
    this.onAddNew,
    this.onEditExpense,
  });

  @override
  State<ExpenseListPage> createState() => _ExpenseListPageState();
}

class _ExpenseListPageState extends State<ExpenseListPage> {
  List<dynamic> _expenseList = [];
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now().subtract(const Duration(days: 30));
    _toDate = DateTime.now();
    _fetchExpenseList();
  }

  Future<void> _fetchExpenseList() async {
    setState(() => _isLoading = true);
    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;
      debugPrint('ExpenseList: orgId = $orgId');

      String url = 'https://bs-org.com/index.php/api/Expense/list?orgID=$orgId';
      if (_fromDate != null && _toDate != null) {
        final startStr = DateFormat('yyyy-MM-dd').format(_fromDate!);
        final endStr = DateFormat('yyyy-MM-dd').format(_toDate!);
        url += '&dateFrom=$startStr&dateTo=$endStr';
      }
      debugPrint('ExpenseList: fetching from $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        debugPrint('ExpenseList: response status 200');
        final data = json.decode(response.body);
        List<dynamic> fetchedList = [];

        if (data is Map && data['data'] != null) {
          fetchedList = List.from(data['data']);
          debugPrint('ExpenseList: fetched ${fetchedList.length} items');
        } else if (data is List) {
          fetchedList = data;
          debugPrint('ExpenseList: fetched ${fetchedList.length} items (list)');
        }

        setState(() {
          _expenseList = fetchedList;
          _isLoading = false;
        });
      } else {
        debugPrint('ExpenseList: HTTP error ${response.statusCode}');
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to fetch expense data')),
        );
      }
    } catch (e) {
      debugPrint('Error fetching expense list: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _selectDateRange(BuildContext context, bool isFrom) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _fromDate ?? DateTime.now() : _toDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
          if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
            _toDate = _fromDate;
          }
        } else {
          _toDate = picked;
        }
      });
      _fetchExpenseList();
    }
  }

  void _viewExpenseDetails(Map<String, dynamic> expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Expense Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('ID', expense['id']?.toString() ?? 'N/A'),
              _buildDetailRow('Head', expense['eHead']?.toString() ?? 'N/A'),
              _buildDetailRow('Description', expense['comments']?.toString() ?? 'N/A'),
              _buildDetailRow('Amount', '৳ ${NumberFormat('#,##0.00').format(double.tryParse(expense['expenseAmount']?.toString() ?? '0') ?? 0)}'),
              _buildDetailRow('Date', expense['date']?.toString() ?? 'N/A'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _editExpense(Map<String, dynamic> expense) async {
    final id = expense['id']?.toString();
    if (id == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid expense ID')),
        );
      }
      return;
    }

    // Show loading dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Material(
            color: Colors.transparent,
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;
      final token = await SessionManager.getToken();

      final response = await http.get(
        Uri.parse('https://bs-org.com/index.php/api/Expense/expenseView?expenseID=$id&orgID=$orgId'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      // Dismiss loading dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['data'] != null) {
          final fullExpense = Map<String, dynamic>.from(data['data']);
          if (widget.onEditExpense != null) {
            widget.onEditExpense!(fullExpense);
          }
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch expense details');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        // Dismiss loading if still showing
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading expense: $e')),
        );
      }
    }
  }

  void _deleteExpense(String? id) async {
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final session = await SessionManager.getSession();
        final token = await SessionManager.getToken();

        final response = await http.post(
          Uri.parse('https://bs-org.com/index.php/api/Expense/deleteExpense'),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: {
            'expenseID': id,
            'orgID': session['orgId']?.toString() ?? '106',
          },
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense deleted successfully!')),
          );
          await _fetchExpenseList();
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting expense: $e')),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Color(0xFF333333)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Icon(icon, size: 12, color: Colors.white),
      ),
    );
  }

  String _formatComment(dynamic comments) {
    if (comments == null) return '-';
    final str = comments.toString().trim();
    return str.isEmpty ? '-' : str;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildPageHeader(),
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
                  _buildSearchSection(),
                  _buildDataTable(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPageHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.table_chart, size: 20, color: Color(0xFF666666)),
              SizedBox(width: 8),
              Text(
                'Expense',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          const Row(
            children: [
              Icon(Icons.assignment, size: 18, color: Color(0xFF666666)),
              SizedBox(width: 12),
              Icon(Icons.refresh, size: 18, color: Color(0xFF666666)),
              SizedBox(width: 12),
              Icon(Icons.settings, size: 18, color: Color(0xFF666666)),
            ],
          ),
        ],
      ),
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
        children: [
          const Text(
            'Expense List (',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          InkWell(
            onTap: widget.onAddNew,
            child: const Text(
              ' + New ',
              style: TextStyle(
                color: Color(0xFFBA6D6D),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const Text(
            ')',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9F9),
        border: Border(bottom: BorderSide(color: Color(0xFFDDDDDD))),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          _buildDatePickerField('From:', _fromDate, true),
          _buildDatePickerField('To:', _toDate, false),
          ElevatedButton(
            onPressed: _fetchExpenseList,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Search', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePickerField(String label, DateTime? date, bool isFrom) {
    final dateStr = date != null ? DateFormat('dd-MMM-yyyy').format(date) : 'Select date';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => _selectDateRange(context, isFrom),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            width: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFCCCCCC)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              dateStr,
              style: TextStyle(
                fontSize: 12,
                color: date != null ? Colors.black87 : Colors.grey,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 20,
        headingRowHeight: 40,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 40,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F5F5)),
        border: const TableBorder(
          verticalInside: BorderSide(color: Color(0xFFDDDDDD), width: 1),
          horizontalInside: BorderSide(color: Color(0xFFDDDDDD), width: 1),
        ),
        columns: const [
          DataColumn(
            label: Text('SL#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          DataColumn(
            label: Text('Head', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          DataColumn(
            label: Text('Desc.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          DataColumn(
            numeric: true,
            label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          DataColumn(
            label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          DataColumn(
            label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
        rows: [
          ..._expenseList.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final expense = entry.value;
            final amount = double.tryParse(expense['expenseAmount']?.toString() ?? '0') ?? 0.0;

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    '$index',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  Text(
                    expense['eHead']?.toString() ?? 'N/A',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 200,
                    child: Text(
                      _formatComment(expense['comments']),
                      style: const TextStyle(fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      NumberFormat('#,##0.00').format(amount),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    expense['date']?.toString() ?? 'N/A',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildActionButton(Icons.search, const Color(0xFF2299CC), () => _viewExpenseDetails(expense)),
                      const SizedBox(width: 4),
                      _buildActionButton(Icons.edit, const Color(0xFFFFC107), () => _editExpense(expense)),
                      const SizedBox(width: 4),
                      _buildActionButton(Icons.delete, Colors.red, () => _deleteExpense(expense['id']?.toString())),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
          // Total row
          DataRow(
            cells: [
              const DataCell(
                Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              const DataCell(Text('')),
              const DataCell(Text('')),
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    NumberFormat('#,##0.00').format(_expenseList.fold(0.0, (sum, item) => sum + (double.tryParse(item['expenseAmount']?.toString() ?? '0') ?? 0.0))),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ),
              const DataCell(Text('')),
              const DataCell(Text('')),
            ],
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'dart:convert';
import 'session_manager.dart';

class AccountsPayablePage extends StatefulWidget {
  const AccountsPayablePage({super.key});

  @override
  State<AccountsPayablePage> createState() => _AccountsPayablePageState();
}

class _AccountsPayablePageState extends State<AccountsPayablePage> {
  bool _showForm = false;
  bool _isLoadingList = true;
  List<dynamic> _payableList = [];
  
  // Form State
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _otherController = TextEditingController();
  
  String? _selectedSupplier;
  DateTime? _selectedDate;
  
  List<dynamic> _suppliers = [];
  bool _isLoadingSuppliers = false;
  bool _isSubmitting = false;

  late DateTime _fromDate;
  late DateTime _toDate;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now().subtract(const Duration(days: 30));
    _toDate = DateTime.now();
    _fetchPayableList();
  }

  Future<void> _fetchPayableList() async {
    setState(() => _isLoadingList = true);
    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;
      
      // In a real app, this would be an http call
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _payableList = [
          {
            'sl': 1,
            'head': 'Office Rent',
            'amount': 5000.00,
            'date': '2026-03-01',
          },
          {
            'sl': 2,
            'head': 'Electricity Bill',
            'amount': 1200.50,
            'date': '2026-03-05',
          },
        ];
        _isLoadingList = false;
      });
    } catch (e) {
      debugPrint('Error fetching payable list: $e');
      setState(() => _isLoadingList = false);
    }
  }

  Future<void> _fetchSuppliers() async {
    setState(() => _isLoadingSuppliers = true);
    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;
      
      final response = await http.get(
        Uri.parse('https://bs-org.com/index.php/api/Supplier/list?orgID=$orgId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> fetchedSuppliers = [];
        if (data is List) {
          fetchedSuppliers = data.where((item) => item != null).toList();
        } else if (data is Map && data['data'] != null) {
          final list = data['data'];
          if (list is List) {
            fetchedSuppliers = list.where((item) => item != null).toList();
          }
        }
        setState(() {
          _suppliers = fetchedSuppliers;
        });
      }
    } catch (e) {
      debugPrint('Error fetching suppliers: $e');
    } finally {
      setState(() => _isLoadingSuppliers = false);
    }
  }

  void _toggleForm(bool show) {
    setState(() {
      _showForm = show;
      if (show && _suppliers.isEmpty) {
        _fetchSuppliers();
      }
    });
  }

  Future<void> _selectDateRange(BuildContext context, bool isFrom) async {
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
    }
  }

  Future<void> _selectFormDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      
      // Simulate submission
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
            _showForm = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Accounts Payable entry saved successfully!')),
          );
          _fetchPayableList(); // Refresh list
          
          // Clear form
          _amountController.clear();
          _dateController.clear();
          _noteController.clear();
          _selectedSupplier = null;
          _selectedDate = null;
        }
      });
    }
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
                  if (!_showForm) ...[
                    _buildListHeader(),
                    _buildSearchSection(),
                    _buildDataTable(),
                  ] else ...[
                    _buildFormHeader(),
                    _buildFormSection(),
                  ],
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
            children: [
              const Icon(Icons.table_chart, size: 20, color: Color(0xFF666666)),
              const SizedBox(width: 8),
              Text(
                _showForm ? 'Payable Form' : 'Payable',
                style: const TextStyle(
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
            'Payable List (',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          InkWell(
            onTap: () => _toggleForm(true),
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

  Widget _buildFormHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        border: Border(bottom: BorderSide(color: Color(0xFFDDDDDD))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Text(
                'New Payable',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _toggleForm(false),
                child: const Icon(Icons.list, size: 16, color: Color(0xFFBA6D6D)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: const BoxDecoration(
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
            onPressed: _fetchPayableList,
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

  Widget _buildDatePickerField(String label, DateTime date, bool isFrom) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () => _selectDateRange(context, isFrom),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            width: 110,
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              border: Border.all(color: const Color(0xFFDDDDDD)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd-MMM-yyyy').format(date),
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                ),
                const Icon(Icons.calendar_today, size: 10, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDataTable() {
    if (_isLoadingList) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    double total = 0;
    for (var item in _payableList) {
      total += (item['amount'] as num).toDouble();
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
          DataColumn(label: Text('SL#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          DataColumn(label: Text('Head', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
        ],
        rows: [
          ..._payableList.map((item) => DataRow(cells: [
                DataCell(Text(item['sl'].toString(), style: const TextStyle(fontSize: 12))),
                DataCell(Text(item['head'].toString(), style: const TextStyle(fontSize: 12))),
                DataCell(Align(
                  alignment: Alignment.centerRight,
                  child: Text(NumberFormat('#,##0.00').format(item['amount']), style: const TextStyle(fontSize: 12)),
                )),
                DataCell(Text(item['date'].toString(), style: const TextStyle(fontSize: 12))),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionButton(Icons.search, Colors.blue),
                    const SizedBox(width: 4),
                    _buildActionButton(Icons.edit, Colors.orange),
                    const SizedBox(width: 4),
                    _buildActionButton(Icons.delete, Colors.red),
                  ],
                )),
              ])),
          DataRow(cells: [
            const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            const DataCell(Text('')),
            DataCell(Align(
              alignment: Alignment.centerRight,
              child: Text(NumberFormat('#,##0.00').format(total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            )),
            const DataCell(Text('')),
            const DataCell(Text('')),
          ]),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Icon(icon, size: 12, color: Colors.white),
    );
  }

  Widget _buildFormSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Supplier / Vendor *'),
            _isLoadingSuppliers
                ? const CircularProgressIndicator()
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF566D7E),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: DropdownSearch<String>(
                      selectedItem: _selectedSupplier,
                      items: _suppliers
                          .where((s) => s != null && (s['id']?.toString() ?? s['supplier_id']?.toString()) != null)
                          .map((s) => (s['id']?.toString() ?? s['supplier_id']?.toString())!)
                          .toList(),
                      itemAsString: (item) {
                        if (item == null) return '( Select One )';
                        final supplier = _suppliers.firstWhere(
                          (s) => s != null && (s['id']?.toString() ?? s['supplier_id']?.toString()) == item,
                          orElse: () => {},
                        );
                        return supplier['name'] ?? supplier['supplier_name'] ?? 'Unknown';
                      },
                      onChanged: (val) => setState(() => _selectedSupplier = val),
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          hintText: '( Select One )',
                          hintStyle: TextStyle(color: Colors.white70, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      popupProps: const PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          decoration: InputDecoration(
                            hintText: 'Search suppliers...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      dropdownBuilder: (context, selectedItem) {
                        if (selectedItem == null) {
                          return Text(
                            '( Select One )',
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          );
                        }
                        final supplier = _suppliers.firstWhere(
                          (s) => s != null && (s['id']?.toString() ?? s['supplier_id']?.toString()) == selectedItem,
                          orElse: () => {},
                        );
                        return Text(
                          supplier['name'] ?? supplier['supplier_name'] ?? 'Unknown',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        );
                      },
                    ),
                  ),
            const SizedBox(height: 16),
            _buildLabel('Payable Amount *'),
            _buildTextField(_amountController, 'Payable Amount', isNumber: true),
            const SizedBox(height: 16),
            _buildLabel('Payable Date *'),
            _buildDateField(),
            const SizedBox(height: 16),
            _buildLabel('Site Note'),
            _buildTextField(_noteController, 'Enter notes here...', maxLines: 3),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0066CC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  ),
                  child: _isSubmitting ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Submit'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _toggleForm(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _formKey.currentState!.reset();
                    setState(() {
                      _selectedSupplier = null;
                      _selectedDate = null;
                      _amountController.clear();
                      _dateController.clear();
                      _noteController.clear();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  ),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(3),
          borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
        ),
        filled: true,
        fillColor: const Color(0xFFF9F9F9),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter $hint';
        }
        return null;
      },
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: () => _selectFormDate(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F9F9),
          border: Border.all(color: const Color(0xFFDDDDDD)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _dateController.text.isEmpty ? 'Select Date' : _dateController.text,
              style: const TextStyle(fontSize: 13),
            ),
            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

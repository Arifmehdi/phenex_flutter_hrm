import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'dart:convert';
import 'session_manager.dart';

class FinanceTablePage extends StatefulWidget {
  final String title;

  const FinanceTablePage({super.key, required this.title});

  @override
  State<FinanceTablePage> createState() => _FinanceTablePageState();
}

class _FinanceTablePageState extends State<FinanceTablePage> {
  late DateTime _fromDate;
  late DateTime _toDate;
  bool _showForm = false;
  Map<String, dynamic>? _editingData;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now();
    _toDate = DateTime.now();
  }

  @override
  void didUpdateWidget(FinanceTablePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      setState(() {
        _fromDate = DateTime.now();
        _toDate = DateTime.now();
        _showForm = false;
        _editingData = null;
      });
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
                  if (!_showForm) ...[
                    _buildListHeader(),
                    _buildSearchSection(context),
                    _buildResponsiveTable(context),
                  ] else ...[
                    _buildFormHeader(),
                    _FinanceFormSection(
                      title: widget.title,
                      initialData: _editingData,
                      onCancel: () {
                        setState(() {
                          _showForm = false;
                          _editingData = null;
                        });
                      },
                    ),
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
            children: [
              const Icon(Icons.table_chart, size: 20, color: Color(0xFF666666)),
              const SizedBox(width: 8),
              Text(
                _showForm ? '${widget.title} Form' : widget.title,
                style: const TextStyle(
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
    return Icon(icon, size: 18, color: Colors.grey[600]);
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
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 13),
              children: [
                TextSpan(text: '${widget.title} List ('),
                WidgetSpan(
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showForm = true;
                        _editingData = null;
                      });
                    },
                    child: const Text(
                      ' + New ',
                      style: TextStyle(
                        color: Color(0xFFBA6D6D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: ')'),
              ],
            ),
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
              Text(
                '${_editingData != null ? "Edit" : "New"} ${widget.title}',
                style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  setState(() {
                    _showForm = false;
                    _editingData = null;
                  });
                },
                child: const Icon(Icons.list, size: 16, color: Color(0xFFBA6D6D)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFDDDDDD))),
      ),
      child: Container(
        padding: const EdgeInsets.all(8.0),
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 100,
              child: _buildDatePickerField('From:', _fromDate, true),
            ),
            SizedBox(
              width: 100,
              child: _buildDatePickerField('To:', _toDate, false),
            ),
            ElevatedButton(
              onPressed: () {},
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
          onTap: () => _selectDate(context, isFrom),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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

  Widget _buildResponsiveTable(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          headingRowHeight: 40,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 40,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F5F5)),
          border: const TableBorder(
            verticalInside: BorderSide(color: Color(0xFFDDDDDD), width: 1),
            horizontalInside: BorderSide(color: Color(0xFFDDDDDD), width: 1),
          ),
          columns: [
            const DataColumn(label: Center(child: Text('SL#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
            DataColumn(label: Center(child: Text(widget.title.toLowerCase() == 'receivable' ? 'Dealer' : 'Head', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
            const DataColumn(label: Center(child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
            const DataColumn(label: Center(child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
            const DataColumn(label: Center(child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
          ],
          rows: [
            ...List.generate(3, (index) => _buildDataRow(index + 1)),
            _buildTotalRow(),
          ],
        ),
      ),
    );
  }

  DataRow _buildDataRow(int sl) {
    final isReceivable = widget.title.toLowerCase() == 'receivable';
    final String head = isReceivable ? 'Dealer A' : 'Office Rent';
    const double amount = 5000.00;
    const String date = '2026-03-01';

    return DataRow(
      cells: [
        DataCell(Center(child: Text(sl.toString(), style: const TextStyle(fontSize: 12)))),
        DataCell(Text(head, style: const TextStyle(fontSize: 12))),
        const DataCell(Align(alignment: Alignment.centerRight, child: Text('5,000.00', style: TextStyle(fontSize: 12)))),
        DataCell(Center(child: Text(date, style: const TextStyle(fontSize: 12)))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(Icons.search, Colors.blue, () {}),
              const SizedBox(width: 4),
              _buildActionButton(Icons.edit, Colors.orange, () {
                setState(() {
                  _showForm = true;
                  _editingData = {
                    'head': head,
                    'amount': amount,
                    'date': date,
                  };
                });
              }),
              const SizedBox(width: 4),
              _buildActionButton(Icons.delete, Colors.red, () {}),
            ],
          ),
        ),
      ],
    );
  }

  DataRow _buildTotalRow() {
    return DataRow(
      cells: [
        const DataCell(Center(child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
        const DataCell(Text('')),
        const DataCell(Align(alignment: Alignment.centerRight, child: Text('15,000.00', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
        const DataCell(Text('')),
        const DataCell(Text('')),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
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
}

class _FinanceFormSection extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? initialData;
  final VoidCallback onCancel;

  const _FinanceFormSection({
    required this.title,
    this.initialData,
    required this.onCancel,
  });

  @override
  State<_FinanceFormSection> createState() => _FinanceFormSectionState();
}

class _FinanceFormSectionState extends State<_FinanceFormSection> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _transactionDate;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String? _selectedHead;
  String? _selectedDealer;
  bool _isEdit = false;

  List<dynamic> _dealers = [];
  bool _isLoadingDealers = false;

  final List<String> _heads = ['Office Rent', 'Salary', 'Electricity Bill', 'Internet Bill', 'Miscellaneous'];

  @override
  void initState() {
    super.initState();
    _isEdit = widget.initialData != null;
    _transactionDate = DateTime.now();

    if (widget.title.toLowerCase() == 'receivable') {
      _fetchDealers();
    }

    if (_isEdit) {
      _selectedHead = widget.initialData!['head'];
      _selectedDealer = widget.initialData!['dealer'];
      _amountController.text = widget.initialData!['amount'].toString().replaceAll(',', '');
      _commentController.text = widget.initialData!['comment'] ?? '';
      if (widget.initialData!['date'] != null) {
        try {
          _transactionDate = DateTime.parse(widget.initialData!['date']);
        } catch (_) {}
      }
    }
  }

  Future<void> _fetchDealers() async {
    setState(() => _isLoadingDealers = true);
    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 98;
      final url = 'https://bs-org.com/index.php/api/Dealer/list?orgID=$orgId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> fetchedDealers = [];
        if (data is List) {
          fetchedDealers = data.where((item) => item != null).toList();
        } else if (data is Map && data['data'] != null) {
          final list = data['data'];
          if (list is List) {
            fetchedDealers = list.where((item) => item != null).toList();
          }
        }
        setState(() {
          _dealers = fetchedDealers;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dealers: $e');
    } finally {
      setState(() => _isLoadingDealers = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _transactionDate) {
      setState(() {
        _transactionDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title.toLowerCase() == 'receivable') ...[
              _buildLabel('Dealer / Customer *'),
            ] else ...[
              _buildLabel('${widget.title} Head'),
            ],
            _buildDropdownField(),
            const SizedBox(height: 16),
            _buildLabel('${widget.title} Amount'),
            _buildTextField(_amountController, '${widget.title} Amount', isNumber: true),
            const SizedBox(height: 16),
            _buildLabel(widget.title.toLowerCase() == 'receivable' ? 'Receivable Date' : 'Transaction Date'),
            _buildDateField(),
            const SizedBox(height: 16),
            _buildLabel('Site Note'),
            _buildTextField(_commentController, 'Site Note', maxLines: 3, isRequired: false),
            const SizedBox(height: 24),
            _buildFormActions(),
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
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDropdownField() {
    if (widget.title.toLowerCase() == 'receivable') {
      if (_isLoadingDealers) {
        return const Center(child: CircularProgressIndicator());
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF566D7E),
          borderRadius: BorderRadius.circular(3),
        ),
        child: DropdownSearch<String>(
          selectedItem: _selectedDealer,
          items: _dealers
              .where((d) => d != null)
              .map((dealer) => dealer['id']?.toString() ?? dealer['dealer_id']?.toString())
              .where((id) => id != null)
              .map((id) => id!)
              .toList(),
          itemAsString: (item) {
            if (item == null) return '( Select Dealer )';
            final dealer = _dealers.firstWhere(
              (d) => d != null && (d['id']?.toString() ?? d['dealer_id']?.toString()) == item,
              orElse: () => {'name': null, 'dealer_name': null, 'company': null},
            );
            return dealer['name'] ?? dealer['dealer_name'] ?? dealer['company'] ?? 'Unknown';
          },
          onChanged: (newValue) {
            setState(() {
              _selectedDealer = newValue;
            });
          },
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              hintText: '( Select Dealer )',
              hintStyle: TextStyle(color: Colors.white70, fontSize: 13),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          popupProps: const PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: 'Search dealers...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
          dropdownBuilder: (context, selectedItem) {
            if (selectedItem == null) {
              return Text(
                '( Select Dealer )',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              );
            }
            final dealer = _dealers.firstWhere(
              (d) => d != null && (d['id']?.toString() ?? d['dealer_id']?.toString()) == selectedItem,
              orElse: () => {},
            );
            return Text(
              dealer['name'] ?? dealer['dealer_name'] ?? dealer['company'] ?? 'Unknown',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            );
          },
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF566D7E),
        borderRadius: BorderRadius.circular(3),
      ),
      child: DropdownSearch<String>(
        selectedItem: _selectedHead,
        items: _heads,
        itemAsString: (item) => item,
        onChanged: (newValue) {
          setState(() {
            _selectedHead = newValue;
          });
        },
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
              hintText: 'Search heads...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        dropdownBuilder: (context, selectedItem) {
          return Text(
            selectedItem ?? '( Select One )',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          );
        },
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool isNumber = false, int maxLines = 1, bool isRequired = true}) {
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
        if (!isRequired) return null;
        if (value == null || value.isEmpty) {
          return 'Please enter $hint';
        }
        return null;
      },
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: () => _selectDate(context),
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
              DateFormat('yyyy-MM-dd').format(_transactionDate),
              style: const TextStyle(fontSize: 13),
            ),
            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildFormActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: () {
            final isReceivable = widget.title.toLowerCase() == 'receivable';
            if (isReceivable && (_selectedDealer == null || _selectedDealer!.isEmpty)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please select Dealer / Customer')),
              );
              return;
            }

            if (_formKey.currentState!.validate()) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${_isEdit ? "Updating" : "Saving"} data...')),
              );
              widget.onCancel();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _isEdit ? Colors.orange : const Color(0xFF0066CC),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          ),
          child: Text(_isEdit ? 'Update' : 'Submit'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: widget.onCancel,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          ),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        if (!_isEdit)
          ElevatedButton(
            onPressed: () {
              _formKey.currentState!.reset();
              setState(() {
                _selectedHead = null;
                _selectedDealer = null;
                _transactionDate = DateTime.now();
                _amountController.clear();
                _commentController.clear();
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
    );
  }
}

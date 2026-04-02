import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'session_manager.dart';

class FinanceTablePage extends StatefulWidget {
  final String title;
  final bool showFormInitially;

  const FinanceTablePage({super.key, required this.title, this.showFormInitially = false});

  @override
  State<FinanceTablePage> createState() => _FinanceTablePageState();
}

class _FinanceTablePageState extends State<FinanceTablePage> {
  late DateTime _fromDate;
  late DateTime _toDate;
  bool _showForm = false;
  Map<String, dynamic>? _editingData;

  // List state
  List<Map<String, dynamic>> _receivableList = [];
  bool _isLoadingList = false;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now();
    _toDate = DateTime.now();
    _showForm = widget.showFormInitially;

    // Fetch data only if showing the list (not the form)
    if (!_showForm) {
      _fetchReceivableList();
    }
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

  Future<void> _fetchReceivableList() async {
    setState(() => _isLoadingList = true);
    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;
      final token = await SessionManager.getToken();

      debugPrint('Fetching receivable list with orgId: $orgId');

      // Build URL with date range if needed (API expects 'start' and 'end')
      final fromDateStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      final toDateStr = DateFormat('yyyy-MM-dd').format(_toDate);
      final url = 'https://bs-org.com/index.php/api/receivable/receivable?orgID=$orgId&start=$fromDateStr&end=$toDateStr';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Receivable list response status: ${response.statusCode}');
      debugPrint('Receivable list response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<Map<String, dynamic>> fetchedList = [];

        if (data is Map && data['data'] != null) {
          final list = data['data'];
          if (list is List) {
            fetchedList = list.where((item) => item != null).cast<Map<String, dynamic>>().toList();
          }
        } else if (data is List) {
          fetchedList = data.where((item) => item != null).cast<Map<String, dynamic>>().toList();
        }

        setState(() {
          _receivableList = fetchedList;
          _isLoadingList = false;
        });
      } else {
        setState(() => _isLoadingList = false);
      }
    } catch (e) {
      debugPrint('Error fetching receivable list: $e');
      setState(() => _isLoadingList = false);
    }
  }

  Future<void> _deleteReceivable(dynamic id) async {
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete: Invalid ID')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this receivable?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final session = await SessionManager.getSession();
      final token = await SessionManager.getToken();
      final orgId = session['orgId'];

      if (orgId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please login again.')),
        );
        return;
      }

      final response = await http.post(
        Uri.parse('https://bs-org.com/index.php/api/receivable/delete'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'id': id,
          'orgID': orgId,
        }),
      );

      debugPrint('Delete receivable response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receivable deleted successfully')),
          );
          // Refresh the list
          _fetchReceivableList();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to delete receivable')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting receivable: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
                      onSuccess: () {
                        // Refresh the list after successful submission
                        _fetchReceivableList();
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
              onPressed: _fetchReceivableList,
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
    if (_isLoadingList) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_receivableList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: Text('No data available', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    // Calculate total
    double total = 0;
    for (var item in _receivableList) {
      final amount = item['incomeAmount'] ?? item['amount'];
      if (amount != null && amount != '') {
        total += double.tryParse(amount.toString()) ?? 0;
      }
    }

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
            ..._receivableList.asMap().entries.map((entry) => _buildDataRow(entry.key + 1, entry.value)),
            _buildTotalRow(total),
          ],
        ),
      ),
    );
  }

  DataRow _buildDataRow(int sl, Map<String, dynamic> item) {
    // Extract dealer name - might be from incomeHead relation or directly
    String? dealerName;
    if (item['iHead'] != null) {
      dealerName = item['iHead'].toString();
    } else if (item['incomeHead'] != null) {
      // incomeHead might be an ID, we could look it up from _dealers but for now show as is
      dealerName = item['incomeHead'].toString();
    } else if (item['dealer_name'] != null) {
      dealerName = item['dealer_name'];
    } else if (item['name'] != null) {
      dealerName = item['name'];
    } else {
      dealerName = 'N/A';
    }

    final amount = item['incomeAmount'] ?? item['amount'] ?? 0;
    final date = item['incomeDate'] ?? item['date'] ?? '';
    final id = item['id']; // Keep for edit/delete if needed

    final amountFormatted = NumberFormat('#,##0.00').format(amount is num ? amount : double.tryParse(amount?.toString() ?? '0') ?? 0);

    return DataRow(
      cells: [
        DataCell(Center(child: Text(sl.toString(), style: const TextStyle(fontSize: 12)))),
        DataCell(Text(dealerName ?? 'N/A', style: const TextStyle(fontSize: 12))),
        DataCell(Align(alignment: Alignment.centerRight, child: Text(amountFormatted, style: const TextStyle(fontSize: 12)))),
        DataCell(Center(child: Text(date?.toString() ?? '', style: const TextStyle(fontSize: 12)))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(Icons.search, Colors.blue, () {
                // View details - could show a dialog
              }),
              const SizedBox(width: 4),
              _buildActionButton(Icons.edit, Colors.orange, () {
                setState(() {
                  _showForm = true;
                  _editingData = {
                    'id': id,
                    'dealer': dealerName,
                    'dealerId': item['incomeHead'] ?? item['dealer_id'],
                    'amount': amount,
                    'date': date,
                  };
                });
              }),
              const SizedBox(width: 4),
              _buildActionButton(Icons.delete, Colors.red, () {
                _deleteReceivable(id);
              }),
            ],
          ),
        ),
      ],
    );
  }

  DataRow _buildTotalRow(double total) {
    final totalFormatted = NumberFormat('#,##0.00').format(total);
    return DataRow(
      cells: [
        const DataCell(Center(child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
        const DataCell(Text('')),
        DataCell(Align(alignment: Alignment.centerRight, child: Text(totalFormatted, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
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
  final VoidCallback? onSuccess; // Callback when form is submitted successfully

  const _FinanceFormSection({
    required this.title,
    this.initialData,
    required this.onCancel,
    this.onSuccess,
  });

  @override
  State<_FinanceFormSection> createState() => _FinanceFormSectionState();
}

class _FinanceFormSectionState extends State<_FinanceFormSection> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _transactionDate;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _referenceNoController = TextEditingController();
  String? _selectedHead;
  String? _selectedDealerId; // Store the actual dealer ID
  String? _selectedDealerName; // Store the dealer name for display
  bool _isEdit = false;
  bool _isSubmitting = false;
  XFile? _selectedFile;
  String? _fileName;

  List<Map<String, dynamic>> _dealers = [];
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
      // For Payable/other types, 'head' is used; for Receivable, 'dealer' is used
      _selectedHead = widget.initialData!.containsKey('head') ? widget.initialData!['head'] : null;
      _selectedDealerName = widget.initialData!.containsKey('dealer') ? widget.initialData!['dealer'] : null;
      _selectedDealerId = widget.initialData!.containsKey('dealerId') ? widget.initialData!['dealerId']?.toString() : null;
      _amountController.text = widget.initialData!['amount'].toString().replaceAll(',', '');
      _commentController.text = widget.initialData!['comment'] ?? '';
      _referenceNoController.text = widget.initialData!['reference_no'] ?? widget.initialData!['invoice_no'] ?? '';
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
        List<Map<String, dynamic>> fetchedDealers = [];
        if (data is List) {
          fetchedDealers = data.where((item) => item != null).cast<Map<String, dynamic>>().toList();
        } else if (data is Map && data['data'] != null) {
          final list = data['data'];
          if (list is List) {
            fetchedDealers = list.where((item) => item != null).cast<Map<String, dynamic>>().toList();
          }
        }
        setState(() {
          _dealers = fetchedDealers;

          // If editing and _selectedDealerName is set but _selectedDealerId is not, find the dealer ID
          if (_isEdit && _selectedDealerName != null && _selectedDealerId == null) {
            final dealer = _dealers.firstWhere(
              (d) => (d['name']?.toString() ?? d['dealer_name']?.toString() ?? d['company']?.toString()) == _selectedDealerName,
              orElse: () => {},
            );
            if (dealer.isNotEmpty) {
              _selectedDealerId = dealer['id']?.toString() ?? dealer['dealer_id']?.toString();
              // Optionally update name to match exact formatting from dealer list
              _selectedDealerName = dealer['name'] ?? dealer['dealer_name'] ?? dealer['company']?.toString();
            }
          }
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

  Future<void> _pickFile() async {
    final ImagePicker picker = ImagePicker();
    try {
      // For documents, we can use gallery or file picker
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        // You can also add other options like imageQuality for compression
      );
      if (file != null) {
        setState(() {
          _selectedFile = file;
          _fileName = file.name;
        });
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting file: $e')),
        );
      }
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
            _buildLabel('${widget.title} Amount *'),
            _buildTextField(
              _amountController,
              '${widget.title} Amount',
              isNumber: true,
              customValidator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter ${widget.title} Amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid amount';
                }
                if (double.tryParse(value)! <= 0) {
                  return 'Amount must be greater than zero';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildLabel(widget.title.toLowerCase() == 'receivable' ? 'Receivable Date' : 'Transaction Date'),
            _buildDateField(),
            const SizedBox(height: 16),
            _buildLabel('Reference No. / Invoice No. (Optional)'),
            _buildTextField(_referenceNoController, 'Enter reference number', isRequired: false),
            const SizedBox(height: 16),
            _buildLabel('Reference Doc. (Optional)'),
            _buildFileUploadField(),
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
          gradient: const LinearGradient(
            colors: [Color(0xFF6A5AE0), Color(0xFF7C73E6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: DropdownSearch<Map<String, dynamic>>(
          selectedItem: _selectedDealerId != null
              ? _dealers.firstWhere(
                  (d) => (d['id']?.toString() ?? d['dealer_id']?.toString()) == _selectedDealerId,
                  orElse: () => {},
                )
              : null,
          items: _dealers.where((d) => d != null).toList(),
          itemAsString: (item) => item['name'] ?? item['dealer_name'] ?? item['company'] ?? 'Unknown',
          onChanged: (selectedDealer) {
            setState(() {
              if (selectedDealer != null) {
                _selectedDealerId = selectedDealer['id']?.toString() ?? selectedDealer['dealer_id']?.toString();
                _selectedDealerName = selectedDealer['name'] ?? selectedDealer['dealer_name'] ?? selectedDealer['company']?.toString();
              } else {
                _selectedDealerId = null;
                _selectedDealerName = null;
              }
            });
          },
          dropdownDecoratorProps: const DropDownDecoratorProps(
            dropdownSearchDecoration: InputDecoration(
              hintText: '( Select Dealer )',
              hintStyle: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            ),
          ),
          popupProps: PopupProps.menu(
            showSearchBox: true,
            searchFieldProps: TextFieldProps(
              decoration: InputDecoration(
                hintText: 'Search dealers...',
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF6A5AE0)),
                suffixIcon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(width: 0),
                ),
                enabledBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(width: 0),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Color(0xFF6A5AE0), width: 2),
                ),
              ),
            ),
            constraints: const BoxConstraints(maxHeight: 350),
            itemBuilder: (context, item, isSelected) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFF0F0FF) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? const Color(0xFF6A5AE0) : Colors.grey[400],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item['name'] ?? item['dealer_name'] ?? item['company'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? const Color(0xFF6A5AE0) : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          dropdownBuilder: (context, selectedItem) {
            if (selectedItem == null || _selectedDealerName == null) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.centerLeft,
                child: const Text(
                  '( Select Dealer )',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedDealerName!,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: Colors.white70, size: 18),
                ],
              ),
            );
          },
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6A5AE0), Color(0xFF7C73E6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
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
            hintStyle: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          ),
        ),
        popupProps: PopupProps.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              hintText: 'Search heads...',
              prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF6A5AE0)),
              suffixIcon: const Icon(Icons.clear, size: 18, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(width: 0),
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(width: 0),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
                borderSide: BorderSide(color: Color(0xFF6A5AE0), width: 2),
              ),
            ),
          ),
          constraints: const BoxConstraints(maxHeight: 300),
          itemBuilder: (context, item, isSelected) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF0F0FF) : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? const Color(0xFF6A5AE0) : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? const Color(0xFF6A5AE0) : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        dropdownBuilder: (context, selectedItem) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedItem ?? '( Select One )',
                    style: TextStyle(
                      color: selectedItem == null ? Colors.white70 : Colors.white,
                      fontSize: selectedItem == null ? 13 : 14,
                      fontWeight: selectedItem == null ? FontWeight.w400 : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (selectedItem != null)
                  const Icon(Icons.check_circle, color: Colors.white70, size: 18),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool isNumber = false, int maxLines = 1, bool isRequired = true, String? Function(String?)? customValidator}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
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
        if (customValidator != null) {
          return customValidator(value);
        }
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

  Widget _buildFileUploadField() {
    return InkWell(
      onTap: _pickFile,
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
            Expanded(
              child: Text(
                _fileName != null
                    ? _fileName!
                    : _selectedFile != null
                        ? _selectedFile!.name
                        : 'Tap to upload document (PDF, Image)',
                style: TextStyle(
                  fontSize: 13,
                  color: (_fileName != null || _selectedFile != null) ? Colors.black87 : Colors.grey,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              _selectedFile != null ? Icons.check_circle : Icons.upload_file,
              size: 18,
              color: _selectedFile != null ? Colors.green : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    debugPrint('ReceivableForm: _submitForm() called');

    setState(() => _isSubmitting = true);

    // Validate form fields
    if (_formKey.currentState!.validate()) {
      // Additional custom validation for dealer/customer
      if (_selectedDealerId == null || _selectedDealerId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select Dealer / Customer')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      final amountText = _amountController.text.trim();
      final amount = double.tryParse(amountText);

      if (amount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid amount')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // Get session data
      final session = await SessionManager.getSession();
      final token = await SessionManager.getToken();
      final orgId = session['orgId'];
      final userId = session['userId'];

      debugPrint('ReceivableForm: orgId=$orgId, userId=$userId, dealerId=$_selectedDealerId, amount=$amount');

      if (orgId == null || userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session expired. Please login again.')),
        );
        setState(() => _isSubmitting = false);
        return;
      }

      // Format date as YYYY-MM-DD
      final payDate = DateFormat('yyyy-MM-dd').format(_transactionDate);

      debugPrint('ReceivableForm: Submitting - incomeHead=$_selectedDealerId, amount=$amount, date=$payDate, content=${_commentController.text}, orgID=$orgId, userID=$userId');

      try {
        // Show loading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Submitting...')),
          );
        }

        // Prepare request data with ONLY required fields as per Receivable.txt
        final Map<String, String> requestData = {
          'incomeHead': _selectedDealerId!, // Already a string
          'incomeAmount': amount.toString(),
          'incomeDate': payDate,
          'orgID': orgId.toString(),
        };

        // Add optional fields if present
        final comment = _commentController.text.trim();
        if (comment.isNotEmpty) {
          requestData['content'] = comment;
        }

        // Reference number (optional)
        final referenceNo = _referenceNoController.text.trim();
        if (referenceNo.isNotEmpty) {
          requestData['reference_no'] = referenceNo;
        }

        // Optional userID
        if (userId != null) {
          requestData['userID'] = userId.toString();
        }

        final http.Response response;

        // If a file is selected, use multipart request
        if (_selectedFile != null) {
          debugPrint('ReceivableForm: Uploading with file: ${_selectedFile!.name}');
          final uri = Uri.parse('https://bs-org.com/index.php/api/receivable/insert');
          final request = http.MultipartRequest('POST', uri);

          // Add headers
          if (token != null) {
            request.headers['Authorization'] = 'Bearer $token';
          }

          // Add all fields to the multipart request
          requestData.forEach((key, value) {
            request.fields[key] = value;
          });

          // Add file
          final bytes = await _selectedFile!.readAsBytes();
          final fileName = _selectedFile!.name;
          request.files.add(
            http.MultipartFile.fromBytes(
              'reference_doc', // field name
              bytes,
              filename: fileName,
            ),
          );

          final streamedResponse = await request.send();
          response = await http.Response.fromStream(streamedResponse);
        } else {
          debugPrint('ReceivableForm: Sending JSON without file');
          response = await http.post(
            Uri.parse('https://bs-org.com/index.php/api/receivable/insert'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: json.encode(requestData),
          );
        }

        debugPrint('ReceivableForm: API response status=${response.statusCode}, body=${response.body}');
        debugPrint('ReceivableForm: response.body length=${response.body.length}');

        if (response.statusCode == 200) {
          if (response.body.isEmpty) {
            debugPrint('ReceivableForm: Response body is empty!');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Server returned empty response. Contact support.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            setState(() => _isSubmitting = false);
            return;
          }

          try {
            final data = json.decode(response.body);
            debugPrint('ReceivableForm: API response data=$data');

            if (data['status'] == true) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(data['message'] ?? 'Receivable added successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                // Call success callback if provided
                if (widget.onSuccess != null) {
                  widget.onSuccess!();
                }
                // Clear form fields before closing
                _referenceNoController.clear();
                _selectedFile = null;
                _fileName = null;
                widget.onCancel(); // Close form
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(data['message'] ?? 'Failed to add receivable'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } catch (e) {
            debugPrint('ReceivableForm: JSON decode error - $e');
            final previewLength = response.body.length > 500 ? 500 : response.body.length;
            debugPrint('ReceivableForm: Response was NOT JSON. Body preview: ${response.body.substring(0, previewLength)}');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Server returned HTML/invalid response. Check logs.'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          debugPrint('ReceivableForm: Server error - Status: ${response.statusCode}, Body: ${response.body}');
          if (mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Server Error ${response.statusCode}'),
                content: SingleChildScrollView(
                  child: Text(
                    response.body,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('ReceivableForm: Exception - $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildFormActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isEdit ? Colors.orange : const Color(0xFF0066CC),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
          ),
          child: _isSubmitting
              ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(_isEdit ? 'Update' : 'Submit'),
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
                _selectedDealerId = null;
                _selectedDealerName = null;
                _transactionDate = DateTime.now();
                _amountController.clear();
                _commentController.clear();
                _referenceNoController.clear();
                _selectedFile = null;
                _fileName = null;
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

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    _referenceNoController.dispose();
    super.dispose();
  }
}

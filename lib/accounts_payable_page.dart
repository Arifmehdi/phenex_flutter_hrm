import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:math';
import 'session_manager.dart';

class AccountsPayablePage extends StatefulWidget {
  const AccountsPayablePage({super.key});

  @override
  State<AccountsPayablePage> createState() => _AccountsPayablePageState();
}

class _AccountsPayablePageState extends State<AccountsPayablePage> {
  bool _showForm = false;
  bool _isLoadingList = true;
  bool _isEditMode = false;
  Map<String, dynamic>? _editingPayable;
  List<dynamic> _payableList = [];
  
  // Form State
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _otherController = TextEditingController();
  final TextEditingController _referenceNoController = TextEditingController();

  String? _selectedSupplier;
  DateTime? _selectedDate;

  XFile? _selectedFile;
  String? _fileName;

  List<dynamic> _suppliers = [];
  bool _isLoadingSuppliers = false;
  bool _isSubmitting = false;

  late DateTime _fromDate;
  late DateTime _toDate;

  // Pagination variables
  int _currentPage = 1;
  int _itemsPerPage = 10;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now();
    _toDate = DateTime.now();
    _fetchPayableList();
  }

  Future<void> _fetchPayableList() async {
    setState(() => _isLoadingList = true);
    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;
      final token = await SessionManager.getToken();

      debugPrint('Fetching payable list with orgId: $orgId');

      // Build date range from _fromDate and _toDate
      final fromDateStr = DateFormat('yyyy-MM-dd').format(_fromDate);
      final toDateStr = DateFormat('yyyy-MM-dd').format(_toDate);
      final url = 'https://bs-org.com/index.php/api/payable/payable?orgID=$orgId&start=$fromDateStr&end=$toDateStr';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Payable list response status: ${response.statusCode}');
      debugPrint('Payable list response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> fetchedList = [];

        // Handle different response formats
        if (data is Map) {
          if (data['payableList'] != null) {
            // Correct format: { "payableList": [...] }
            fetchedList = List.from(data['payableList']);
          } else if (data['data'] != null) {
            // Alternative format: { "data": [...] }
            fetchedList = List.from(data['data']);
          } else if (data['incomeList'] != null) {
            // Old format (income data) - for backwards compatibility
            fetchedList = List.from(data['incomeList']);
            debugPrint('Warning: API returning incomeList instead of payable data');
          }
        } else if (data is List) {
          fetchedList = data;
        }

        setState(() {
          _payableList = fetchedList;
          _totalItems = fetchedList.length;
          _currentPage = 1; // Reset to first page when new data loads
          _isLoadingList = false;
        });
      } else {
        setState(() => _isLoadingList = false);
      }
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
        if (data is Map && data['status'] == true && data['data'] != null) {
          // Expected format: { "status": true, "data": [...] }
          final list = data['data'];
          if (list is List) {
            fetchedSuppliers = list.where((item) => item != null).toList();
          }
        } else if (data is List) {
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
        debugPrint('Fetched ${_suppliers.length} suppliers');
      }
    } catch (e) {
      debugPrint('Error fetching suppliers: $e');
    } finally {
      setState(() => _isLoadingSuppliers = false);
    }
  }

  Future<void> _toggleForm(bool show, {bool isEdit = false, Map<String, dynamic>? payable}) async {
    setState(() {
      _showForm = show;
      _isEditMode = isEdit;
      _editingPayable = isEdit ? payable : null;
    });

    // Ensure suppliers are loaded before populating form
    if (show && _suppliers.isEmpty) {
      await _fetchSuppliers();
    }

    // If editing, ensure the current supplier exists in the list
    if (show && isEdit && payable != null) {
      final supplierId = payable['vendor_id']?.toString() ?? payable['dealer_id']?.toString();
      if (supplierId != null && supplierId.isNotEmpty) {
        final exists = _suppliers.any((s) => s != null && s['id']?.toString() == supplierId);
        if (!exists) {
          setState(() {
            _suppliers.add({
              'id': supplierId,
              'supplier_name': payable['supplier_name'] ?? payable['vendor_name'] ?? 'Unknown Supplier',
            });
          });
          debugPrint('Added missing supplier to list: ID=$supplierId, Name=${payable['supplier_name'] ?? payable['vendor_name']}');
        }
      }
    }

    if (show) {
      setState(() {
        if (isEdit && payable != null) {
          _populateFormForEdit(payable);
        } else {
          _clearForm();
        }
      });
    }
  }

  void _populateFormForEdit(Map<String, dynamic> payable) {
    debugPrint('_populateFormForEdit called for payable ID: ${payable['id']}');
    debugPrint('Payable keys: ${payable.keys.toList()}');

    // Set vendor ID
    final vendorId = payable['vendor_id']?.toString() ?? payable['dealer_id']?.toString() ?? '';
    debugPrint('Setting vendorId: $vendorId');
    _selectedSupplier = vendorId.isNotEmpty ? vendorId : null;

    // Set amount
    final amount = payable['amount'] ?? payable['due_amount'] ?? payable['incomeAmount'] ?? 0;
    _amountController.text = amount.toString();
    debugPrint('Setting amount: $amount');

    // Set schedule date
    final scheduleDate = payable['schedule_date'] ?? payable['due_date'] ?? payable['date'] ?? '';
    if (scheduleDate.isNotEmpty) {
      try {
        _selectedDate = DateTime.tryParse(scheduleDate);
        _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      } catch (e) {
        _dateController.text = scheduleDate;
      }
    }
    debugPrint('Setting scheduleDate: $scheduleDate');

    // Set reference number
    final refNo = payable['reference_no'] ?? '';
    _referenceNoController.text = refNo;
    debugPrint('Setting referenceNo: $refNo');

    // Set notes/comments - check all possible field names
    final notes = payable['comments'] ?? payable['comment'] ?? payable['note'] ?? payable['comments_text'] ?? '';
    debugPrint('Setting notes: "$notes" (from field: ${payable.containsKey('comments') ? 'comments' : payable.containsKey('comment') ? 'comment' : payable.containsKey('note') ? 'note' : 'none'})');
    _noteController.text = notes;
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedSupplier = null;
      _selectedDate = null;
      _amountController.clear();
      _dateController.clear();
      _noteController.clear();
      _referenceNoController.clear();
      _selectedFile = null;
      _fileName = null;
      _isEditMode = false;
      _editingPayable = null;
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

  Future<void> _pickFile() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
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

  Future<void> _submitForm() async {
    // Validate form fields
    if (_formKey.currentState!.validate()) {
      // Validate supplier selection
      if (_selectedSupplier == null || _selectedSupplier!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a Vendor')),
        );
        return;
      }

      // Validate amount
      final amountText = _amountController.text.trim();
      if (amountText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter Amount')),
        );
        return;
      }

      // Validate schedule date
      if (_dateController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a Schedule Date')),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      try {
        final session = await SessionManager.getSession();
        final token = await SessionManager.getToken();
        final orgId = session['orgId'];
        final userId = session['userId'];

        if (orgId == null || userId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expired. Please login again.')),
          );
          setState(() => _isSubmitting = false);
          return;
        }

        // Prepare base data
        final Map<String, String> requestData = {
          'vendor_id': _selectedSupplier ?? '',
          'amount': _amountController.text.trim(),
          'schedule_date': _dateController.text.trim(),
          'orgID': orgId.toString(),
        };

        // For update, add the payable ID
        if (_isEditMode && _editingPayable != null) {
          final payableId = _editingPayable!['id']?.toString() ?? '';
          if (payableId.isNotEmpty) {
            requestData['id'] = payableId;
          }
        }

        // Optional fields
        final note = _noteController.text.trim();
        if (note.isNotEmpty) {
          requestData['comments'] = note;
        }

        final referenceNo = _referenceNoController.text.trim();
        if (referenceNo.isNotEmpty) {
          requestData['reference_no'] = referenceNo;
        }

        requestData['user_id'] = userId.toString();

        debugPrint('PayableForm: ${_isEditMode ? 'Updating' : 'Submitting'} data: ${json.encode(requestData)}');

        final http.Response response;
        final String apiUrl = _isEditMode
          ? 'https://bs-org.com/index.php/api/payable/update'
          : 'https://bs-org.com/index.php/api/payable/insert';

        // If file selected, use multipart
        if (_selectedFile != null) {
          debugPrint('PayableForm: Uploading with file: ${_selectedFile!.name}');
          final uri = Uri.parse(apiUrl);
          final request = http.MultipartRequest('POST', uri);

          if (token != null) {
            request.headers['Authorization'] = 'Bearer $token';
          }

          requestData.forEach((key, value) {
            request.fields[key] = value;
          });

          final bytes = await _selectedFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'doc',
              bytes,
              filename: _selectedFile!.name,
            ),
          );

          final streamedResponse = await request.send();
          response = await http.Response.fromStream(streamedResponse);
        } else {
          debugPrint('PayableForm: Sending JSON without file');
          response = await http.post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: json.encode(requestData),
          );
        }

        debugPrint('PayableForm: Response status=${response.statusCode}, body=${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(data['message'] ?? (_isEditMode ? 'Payable updated successfully' : 'Payable added successfully')),
                  backgroundColor: Colors.green,
                ),
              );
              // Clear form and return to list
              _clearForm();
              setState(() {
                _showForm = false;
              });
              _fetchPayableList();
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(data['message'] ?? 'Failed to save payable'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Server error: ${response.statusCode}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('PayableForm: Exception - $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
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
              Text(
                _isEditMode ? 'Edit Payable' : 'New Payable',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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

  void _changePage(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _changeItemsPerPage(int itemsPerPage) {
    setState(() {
      _itemsPerPage = itemsPerPage;
      _currentPage = 1; // Reset to first page
    });
  }

  List<dynamic> _getCurrentPageData() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _payableList.length) {
      return [];
    }
    return _payableList.sublist(startIndex, endIndex > _payableList.length ? _payableList.length : endIndex);
  }

  int get _totalPages => (_totalItems / _itemsPerPage).ceil();

  List<Widget> _buildPageNumbers() {
    List<Widget> pageNumbers = [];
    int maxPagesToShow = 5;
    int startPage = max(1, _currentPage - maxPagesToShow ~/ 2);
    int endPage = min(_totalPages, startPage + maxPagesToShow - 1);

    if (endPage - startPage + 1 < maxPagesToShow) {
      startPage = max(1, endPage - maxPagesToShow + 1);
    }

    if (startPage > 1) {
      pageNumbers.add(
        InkWell(
          onTap: () => _changePage(1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFDDDDDD)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text('1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ),
      );
      if (startPage > 2) {
        pageNumbers.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('...', style: TextStyle(fontSize: 12)),
          ),
        );
      }
    }

    for (int i = startPage; i <= endPage; i++) {
      pageNumbers.add(
        InkWell(
          onTap: () => _changePage(i),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: i == _currentPage ? const Color(0xFF0066CC) : Colors.white,
              border: Border.all(color: i == _currentPage ? const Color(0xFF0066CC) : const Color(0xFFDDDDDD)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              i.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: i == _currentPage ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      );
    }

    if (endPage < _totalPages) {
      if (endPage < _totalPages - 1) {
        pageNumbers.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('...', style: TextStyle(fontSize: 12)),
          ),
        );
      }
      pageNumbers.add(
        InkWell(
          onTap: () => _changePage(_totalPages),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFDDDDDD)),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(_totalPages.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ),
      );
    }

    return pageNumbers;
  }

  Widget _buildDataTable() {
    if (_isLoadingList) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final currentPageData = _getCurrentPageData();
    if (_payableList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: Text('No data available', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    double total = 0;
    for (var item in _payableList) {
      final amount = item['amount'];
      if (amount != null && amount != '') {
        total += double.tryParse(amount.toString()) ?? 0;
      }
    }

    return Column(
      children: [
        SingleChildScrollView(
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
              DataColumn(label: Text('Vendor', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              DataColumn(label: Text('Ref No.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              DataColumn(label: Text('Schedule Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            ],
            rows: [
              ...currentPageData.asMap().entries.map((entry) {
                final globalIndex = (_currentPage - 1) * _itemsPerPage + entry.key + 1;
                return _buildDataRow(globalIndex, entry.value);
              }),
              DataRow(cells: [
                const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                const DataCell(Text('')),
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
        ),
        const SizedBox(height: 12),
        _buildPaginationControls(),
        const SizedBox(height: 80), // Bottom spacer to keep pagination above bottom navbar
      ],
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9F9),
        border: Border(top: BorderSide(color: Color(0xFFDDDDDD))),
      ),
      child: Column(
        children: [
          // Top row: Items per page selector and info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Items per page selector
              Row(
                children: [
                  const Text('Show: ', style: TextStyle(fontSize: 12, color: Colors.black87)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFDDDDDD)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: DropdownButton<int>(
                      value: _itemsPerPage,
                      items: [5, 10, 25, 50, 100].map((int value) {
                        return DropdownMenuItem<int>(
                          value: value,
                          child: Text(value.toString(), style: const TextStyle(fontSize: 12)),
                        );
                      }).toList(),
                      onChanged: (int? newValue) {
                        if (newValue != null) {
                          _changeItemsPerPage(newValue);
                        }
                      },
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, size: 16),
                    ),
                  ),
                ],
              ),

              // Info text
              Text(
                'Showing ${(_currentPage - 1) * _itemsPerPage + 1} to ${(_currentPage * _itemsPerPage).clamp(0, _totalItems)} of $_totalItems entries',
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Bottom row: Pagination buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous button
              InkWell(
                onTap: _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _currentPage > 1 ? Colors.white : const Color(0xFFF5F5F5),
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'Previous',
                    style: TextStyle(
                      fontSize: 12,
                      color: _currentPage > 1 ? Colors.black87 : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Page numbers container
              Container(
                constraints: const BoxConstraints(maxWidth: 300),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildPageNumbers(),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Next button
              InkWell(
                onTap: _currentPage < _totalPages ? () => _changePage(_currentPage + 1) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _currentPage < _totalPages ? Colors.white : const Color(0xFFF5F5F5),
                    border: Border.all(color: const Color(0xFFDDDDDD)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'Next',
                    style: TextStyle(
                      fontSize: 12,
                      color: _currentPage < _totalPages ? Colors.black87 : Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(int sl, Map<String, dynamic> item) {
    // Handle payable API response format
    final vendorName = item['supplier_name'] ?? item['vendor_name'] ?? item['head'] ?? item['iHead'] ?? 'N/A';
    final referenceNo = item['reference_no'] ?? '';
    final amount = item['amount'] ?? 0;
    final scheduleDate = item['schedule_date'] ?? '';
    final id = item['id'];

    final amountFormatted = NumberFormat('#,##0.00').format(amount is num ? amount : double.tryParse(amount.toString()) ?? 0);

    return DataRow(
      cells: [
        DataCell(Text(sl.toString(), style: const TextStyle(fontSize: 12))),
        DataCell(Text(vendorName.toString(), style: const TextStyle(fontSize: 12))),
        DataCell(Text(referenceNo.toString(), style: const TextStyle(fontSize: 12))),
        DataCell(Align(alignment: Alignment.centerRight, child: Text(amountFormatted, style: const TextStyle(fontSize: 12)))),
        DataCell(Text(scheduleDate.toString(), style: const TextStyle(fontSize: 12))),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionButton(Icons.search, Colors.blue, () {
              debugPrint('View icon tapped for payable id: $id');
              _viewPayable(item);
            }),
            const SizedBox(width: 4),
            _buildActionButton(Icons.edit, Colors.orange, () {
              _toggleForm(true, isEdit: true, payable: item);
            }),
            const SizedBox(width: 4),
            _buildActionButton(Icons.delete, Colors.red, () {
              _deletePayable(id);
            }),
          ],
        )),
      ],
    );
  }

  Future<void> _viewPayable(Map<String, dynamic> payable) async {
    debugPrint('_viewPayable called with payable ID: ${payable['id']}');
    debugPrint('All payable keys: ${payable.keys.toList()}');
    debugPrint('Raw payable data: ${json.encode(payable)}');
    try {
      final vendorName = payable['supplier_name'] ?? payable['vendor_name'] ?? payable['head'] ?? payable['iHead'] ?? 'N/A';
      final amount = payable['amount'] ?? 0;
      final scheduleDate = payable['schedule_date'] ?? '';
      final referenceNo = payable['reference_no'] ?? 'N/A';
      // Try all possible comment field names
      final comments = payable['comments'] ?? payable['comment'] ?? payable['note'] ?? payable['comments_text'] ?? payable['comment_text'] ?? 'N/A';
      debugPrint('Parsed values: vendor=$vendorName, amount=$amount, date=$scheduleDate, ref=$referenceNo, notes=$comments');

      final amountFormatted = NumberFormat('#,##0.00').format(amount is num ? amount : double.tryParse(amount.toString()) ?? 0);

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Payable Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Vendor:', vendorName),
                _buildDetailRow('Amount:', '\৳ $amountFormatted'),
                _buildDetailRow('Schedule Date:', scheduleDate),
                _buildDetailRow('Reference No.:', referenceNo),
                const SizedBox(height: 8),
                const Text(
                  'Notes:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    comments,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e, stack) {
      debugPrint('Error in _viewPayable: $e\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error viewing payable: $e')),
        );
      }
    }
  }

  Future<void> _deletePayable(dynamic id) async {
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete: Invalid ID')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this payable?'),
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
        Uri.parse('https://bs-org.com/index.php/api/payable/delete'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'id': id,
          'orgID': orgId,
        }),
      );

      debugPrint('Delete payable response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payable deleted successfully')),
          );
          _fetchPayableList();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to delete payable')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Error deleting payable: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _buildActionButton(IconData icon, Color color, [VoidCallback? onTap]) {
    final widget = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Icon(icon, size: 12, color: Colors.white),
    );
    if (onTap != null) {
      return InkWell(onTap: onTap, child: widget);
    }
    return widget;
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: valueColor ?? Colors.black87,
                fontWeight: valueColor != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
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
            _buildLabel('Vendor *'),
            _isLoadingSuppliers
                ? const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6A5AE0)),
                      ),
                    ),
                  )
                : Container(
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
                      selectedItem: _selectedSupplier,
                      items: _suppliers
                          .where((s) => s != null && s['id'] != null)
                          .map((s) => s['id'].toString())
                          .toList(),
                      itemAsString: (item) {
                        final supplier = _suppliers.firstWhere(
                          (s) => s != null && s['id']?.toString() == item,
                          orElse: () => {},
                        );
                        return supplier['supplier_name'] ?? supplier['name'] ?? 'Unknown';
                      },
                      onChanged: (val) => setState(() => _selectedSupplier = val),
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          hintText: '( Select Vendor )',
                          hintStyle: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        ),
                      ),
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          decoration: InputDecoration(
                            hintText: 'Search vendors...',
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
                          final supplier = _suppliers.firstWhere(
                            (s) => s != null && (s['id']?.toString() ?? s['supplier_id']?.toString()) == item,
                            orElse: () => {},
                          );
                          final supplierName = supplier['name'] ?? supplier['supplier_name'] ?? 'Unknown';

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
                                    supplierName,
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
                        if (selectedItem == null) {
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            alignment: Alignment.centerLeft,
                            child: const Text(
                              '( Select Vendor )',
                              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          );
                        }
                        final supplier = _suppliers.firstWhere(
                          (s) => s != null && s['id']?.toString() == selectedItem,
                          orElse: () => {},
                        );
                        final supplierName = supplier['name'] ?? supplier['supplier_name'] ?? 'Unknown';

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  supplierName,
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
                  ),
            const SizedBox(height: 16),
            _buildLabel('Payable Amount *'),
            _buildTextField(_amountController, 'Payable Amount', isNumber: true),
            const SizedBox(height: 16),
            _buildLabel('Schedule Date *'),
            _buildDateField(),
            const SizedBox(height: 16),
            _buildLabel('Reference No. / Invoice No. (Optional)'),
            _buildTextField(_referenceNoController, 'Enter reference number', isNumber: false, isRequired: false),
            const SizedBox(height: 16),
            _buildLabel('Reference Doc. (Optional)'),
            _buildFileUploadField(),
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
                  onPressed: () {
                    _clearForm();
                    _toggleForm(false);
                  },
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
        if (isRequired && (value == null || value.isEmpty)) {
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

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    _noteController.dispose();
    _referenceNoController.dispose();
    super.dispose();
  }
}

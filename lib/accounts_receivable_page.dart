import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:math';
import 'session_manager.dart';

class AccountsReceivablePage extends StatefulWidget {
  const AccountsReceivablePage({super.key});

  @override
  State<AccountsReceivablePage> createState() => _AccountsReceivablePageState();
}

class _AccountsReceivablePageState extends State<AccountsReceivablePage> {
  bool _showForm = false;
  bool _isLoadingList = true;
  bool _isEditMode = false;
  Map<String, dynamic>? _editingReceivable;
  List<dynamic> _receivableList = [];

  // Pagination variables
  int _currentPage = 1;
  int _itemsPerPage = 10;
  int _totalItems = 0;

  // Form State
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _referenceNoController = TextEditingController();

  String? _selectedDealer;
  DateTime? _selectedDate;

  XFile? _selectedFile;
  String? _fileName;

  List<dynamic> _dealers = [];
  bool _isLoadingDealers = false;
  bool _isSubmitting = false;

  late DateTime _fromDate;
  late DateTime _toDate;

  @override
  void initState() {
    super.initState();
    _fromDate = DateTime.now().subtract(const Duration(days: 30));
    _toDate = DateTime.now();
    _fetchReceivableList();
  }

  Future<void> _fetchReceivableList() async {
    setState(() => _isLoadingList = true);
    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;
      final token = await SessionManager.getToken();

      debugPrint('Fetching receivable list with orgId: $orgId');

      final url = 'https://bs-org.com/index.php/api/Receivable/list?orgID=$orgId';

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
        List<dynamic> fetchedList = [];

        if (data is Map) {
          if (data['data'] != null) {
            fetchedList = List.from(data['data']);
          }
        } else if (data is List) {
          fetchedList = data;
        }

        setState(() {
          _receivableList = fetchedList;
          _totalItems = fetchedList.length;
          _currentPage = 1; // Reset to first page when new data loads
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

  Future<void> _fetchDealers() async {
    setState(() => _isLoadingDealers = true);
    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;

      final response = await http.get(
        Uri.parse('https://bs-org.com/index.php/api/Receivable/dealer?orgID=$orgId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> fetchedDealers = [];
        if (data is Map && data['dealers'] != null) {
          fetchedDealers = List.from(data['dealers']);
        } else if (data is Map && data['data'] != null) {
          final list = data['data'];
          if (list is List) {
            fetchedDealers = list;
          }
        }
        setState(() {
          _dealers = fetchedDealers;
        });
        debugPrint('Fetched ${_dealers.length} dealers');
      }
    } catch (e) {
      debugPrint('Error fetching dealers: $e');
    } finally {
      setState(() => _isLoadingDealers = false);
    }
  }

  Future<void> _toggleForm(bool show, {bool isEdit = false, Map<String, dynamic>? receivable}) async {
    setState(() {
      _showForm = show;
      _isEditMode = isEdit;
      _editingReceivable = isEdit ? receivable : null;
    });

    if (show && _dealers.isEmpty) {
      await _fetchDealers();
    }

    // If editing, ensure the current dealer exists in the list
    if (show && isEdit && receivable != null) {
      final dealerId = receivable['dealer_id']?.toString();
      if (dealerId != null && dealerId.isNotEmpty) {
        final exists = _dealers.any((d) => d != null && d['id']?.toString() == dealerId);
        if (!exists) {
          setState(() {
            _dealers.add({
              'id': dealerId,
              'dealer_name': receivable['dealer_name'] ?? 'Unknown Dealer',
            });
          });
          debugPrint('Added missing dealer to list: ID=$dealerId, Name=${receivable['dealer_name']}');
        }
      }
    }

    if (show) {
      setState(() {
        if (isEdit && receivable != null) {
          _populateFormForEdit(receivable);
        } else {
          _clearForm();
        }
      });
    }
  }

  void _populateFormForEdit(Map<String, dynamic> receivable) {
    // Set dealer ID
    final dealerId = receivable['dealer_id']?.toString() ?? '';
    _selectedDealer = dealerId.isNotEmpty ? dealerId : null;

    // Set amount
    final amount = receivable['due_amount'] ?? receivable['amount'] ?? 0;
    _amountController.text = amount.toString();

    // Set due date
    final dueDate = receivable['due_date'] ?? '';
    if (dueDate.isNotEmpty) {
      try {
        _selectedDate = DateTime.tryParse(dueDate);
        _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      } catch (e) {
        _dateController.text = dueDate;
      }
    }

    // Set reference number (if exists)
    final refNo = receivable['reference_no'] ?? '';
    _referenceNoController.text = refNo;

    // Set notes/comments (if exists)
    final notes = receivable['comments'] ?? receivable['comment'] ?? receivable['note'] ?? '';
    _noteController.text = notes;
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    setState(() {
      _selectedDealer = null;
      _selectedDate = null;
      _amountController.clear();
      _dateController.clear();
      _noteController.clear();
      _referenceNoController.clear();
      _selectedFile = null;
      _fileName = null;
      _isEditMode = false;
      _editingReceivable = null;
    });
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
    if (_formKey.currentState!.validate()) {
      // Collect all validation errors
      List<String> errors = [];

      if (_selectedDealer == null || _selectedDealer!.isEmpty) {
        errors.add('Please select a Dealer/Customer');
      }

      final amountText = _amountController.text.trim();
      if (amountText.isEmpty) {
        errors.add('Please enter Amount');
      }

      if (_dateController.text.trim().isEmpty) {
        errors.add('Please select a Receivable Date');
      }

      // If there are any errors, show them all at once
      if (errors.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errors.join('\n'),
              style: const TextStyle(fontSize: 13),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
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

        // Prepare data according to Receivable API: uses amounts[] and dates[] arrays
        final Map<String, dynamic> requestData = {
          'dealer_id': _selectedDealer ?? '',
          'amounts': [amountText],
          'dates': [_dateController.text.trim()],
          'orgID': orgId.toString(),
          'user_id': userId.toString(),
        };

        // For update, add the receivable ID
        if (_isEditMode && _editingReceivable != null) {
          final receivableId = _editingReceivable!['id']?.toString() ?? '';
          if (receivableId.isNotEmpty) {
            requestData['id'] = receivableId;
          }
        }

        // Optional fields
        final referenceNo = _referenceNoController.text.trim();
        if (referenceNo.isNotEmpty) {
          requestData['reference_no'] = referenceNo;
        }

        final note = _noteController.text.trim();
        if (note.isNotEmpty) {
          requestData['comments'] = note;
        }

        debugPrint('ReceivableForm: ${_isEditMode ? 'Updating' : 'Submitting'} data: ${json.encode(requestData)}');

        final http.Response response;
        final String apiUrl = _isEditMode
          ? 'https://bs-org.com/index.php/api/Receivable/update'
          : 'https://bs-org.com/index.php/api/Receivable/insert';

        // If file selected, use multipart
        if (_selectedFile != null) {
          debugPrint('ReceivableForm: Uploading with file: ${_selectedFile!.name}');
          final uri = Uri.parse(apiUrl);
          final request = http.MultipartRequest('POST', uri);

          if (token != null) {
            request.headers['Authorization'] = 'Bearer $token';
          }

          requestData.forEach((key, value) {
            if (value is List) {
              for (var item in value) {
                request.fields[key] = item.toString();
              }
            } else {
              request.fields[key] = value.toString();
            }
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
          debugPrint('ReceivableForm: Sending JSON without file');
          response = await http.post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: json.encode(requestData),
          );
        }

        debugPrint('ReceivableForm: Response status=${response.statusCode}, body=${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(data['message'] ?? (_isEditMode ? 'Receivable updated successfully' : 'Receivable added successfully')),
                  backgroundColor: Colors.green,
                ),
              );
              _clearForm();
              setState(() {
                _showForm = false;
              });
              _fetchReceivableList();
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(data['message'] ?? 'Failed to save receivable'),
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
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  Future<void> _markAsPaid(dynamic id) async {
    if (id == null) return;

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
        Uri.parse('https://bs-org.com/index.php/api/Receivable/mark_paid'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'id': id,
          'orgID': orgId,
        }),
      );

      debugPrint('Mark paid response: ${response.statusCode}, ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Receivable marked as paid')),
          );
          _fetchReceivableList();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to mark as paid')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Error marking as paid: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _deleteReceivable(dynamic id) async {
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
        Uri.parse('https://bs-org.com/index.php/api/Receivable/delete'),
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
    if (startIndex >= _receivableList.length) {
      return [];
    }
    return _receivableList.sublist(startIndex, endIndex > _receivableList.length ? _receivableList.length : endIndex);
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
                _showForm ? 'Receivable Form' : 'Receivable',
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
            'Receivable List (',
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
                _isEditMode ? 'Edit Receivable' : 'New Receivable',
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
    );
  }

  Widget _buildDatePickerField(String label, DateTime date, bool isFrom) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
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
          },
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

    final currentPageData = _getCurrentPageData();
    if (_receivableList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: Text('No data available', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    double total = 0;
    for (var item in _receivableList) {
      final amount = item['due_amount'] ?? item['amount'];
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
              DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
              DataColumn(label: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
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
        Container(
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
        ),
        // Bottom spacer to keep pagination above bottom navbar
        const SizedBox(height: 80),
      ],
    );
  }

  DataRow _buildDataRow(int sl, Map<String, dynamic> item) {
    final customerName = item['dealer_name'] ?? 'N/A';
    final amount = item['due_amount'] ?? item['amount'] ?? 0;
    final dueDate = item['due_date'] ?? '';
    final id = item['id'];

    final amountFormatted = NumberFormat('#,##0.00').format(amount is num ? amount : double.tryParse(amount.toString()) ?? 0);

    return DataRow(
      cells: [
        DataCell(Text(sl.toString(), style: const TextStyle(fontSize: 12))),
        DataCell(Text(customerName.toString(), style: const TextStyle(fontSize: 12))),
        DataCell(Align(alignment: Alignment.centerRight, child: Text(amountFormatted, style: const TextStyle(fontSize: 12)))),
        DataCell(Text(dueDate.toString(), style: const TextStyle(fontSize: 12))),
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildActionButton(Icons.visibility, Colors.blue, () {
              _viewReceivable(item);
            }),
            const SizedBox(width: 4),
            _buildActionButton(Icons.edit, Colors.orange, () {
              _toggleForm(true, isEdit: true, receivable: item);
            }),
            const SizedBox(width: 4),
            _buildActionButton(Icons.delete, Colors.red, () {
              _deleteReceivable(id);
            }),
          ],
        )),
      ],
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
            _buildLabel('Dealer / Customer *'),
            _isLoadingDealers
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
                      selectedItem: _selectedDealer,
                      items: _dealers
                          .where((d) => d != null && d['id'] != null)
                          .map((d) => d['id'].toString())
                          .toList(),
                      itemAsString: (item) {
                        final dealer = _dealers.firstWhere(
                          (d) => d != null && d['id']?.toString() == item,
                          orElse: () => {},
                        );
                        return dealer['dealer_name'] ?? dealer['name'] ?? 'Unknown';
                      },
                      onChanged: (val) => setState(() => _selectedDealer = val),
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          hintText: '( Select Customer )',
                          hintStyle: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        ),
                      ),
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          decoration: InputDecoration(
                            hintText: 'Search customers...',
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
                          final dealer = _dealers.firstWhere(
                            (d) => d != null && d['id']?.toString() == item,
                            orElse: () => {},
                          );
                          final dealerName = dealer['dealer_name'] ?? dealer['name'] ?? 'Unknown';

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
                                    dealerName,
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
                              '( Select Customer )',
                              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          );
                        }
                        final dealer = _dealers.firstWhere(
                          (d) => d != null && d['id']?.toString() == selectedItem,
                          orElse: () => {},
                        );
                        final dealerName = dealer['dealer_name'] ?? dealer['name'] ?? 'Unknown';

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  dealerName,
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
            _buildLabel('Reference No. / Invoice No.'),
            _buildTextField(_referenceNoController, 'Enter reference number', isNumber: false, isRequired: false),
            const SizedBox(height: 16),
            _buildLabel('Receivable Amount *'),
            _buildTextField(_amountController, 'Receivable Amount', isNumber: true),
            const SizedBox(height: 16),
            _buildLabel('Receivable Date *'),
            _buildDateField(),
            const SizedBox(height: 16),
            _buildLabel('Reference Doc. (Optional)'),
            _buildFileUploadField(),
            const SizedBox(height: 16),
            _buildLabel('Site Note'),
            _buildTextField(_noteController, 'Enter notes here...', maxLines: 3, isRequired: false),
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
                      _selectedDealer = null;
                      _selectedDate = null;
                      _amountController.clear();
                      _dateController.clear();
                      _noteController.clear();
                      _referenceNoController.clear();
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

  Future<void> _viewReceivable(Map<String, dynamic> receivable) async {
    final dealerName = receivable['dealer_name'] ?? 'N/A';
    final amount = receivable['due_amount'] ?? receivable['amount'] ?? 0;
    final dueDate = receivable['due_date'] ?? '';
    final referenceNo = receivable['reference_no'] ?? 'N/A';
    final comments = receivable['comments'] ?? receivable['note'] ?? 'N/A';

    final amountFormatted = NumberFormat('#,##0.00').format(amount is num ? amount : double.tryParse(amount.toString()) ?? 0);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Receivable Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Customer:', dealerName),
              _buildDetailRow('Amount:', '\৳ $amountFormatted'),
              _buildDetailRow('Due Date:', dueDate),
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

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    _referenceNoController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}

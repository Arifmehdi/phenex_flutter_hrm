import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'dart:convert';
import 'session_manager.dart';

class ExpenseFormPage extends StatefulWidget {
  final VoidCallback? onListTap;
  final Map<String, dynamic>? expenseToEdit;

  const ExpenseFormPage({
    super.key,
    this.onListTap,
    this.expenseToEdit,
  });

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  bool _isLoadingHeads = false;
  List<dynamic> _expenseHeads = [];

  // Payable from expense feature
  bool _isExpenseFromPayable = false;
  bool _isLoadingPayables = false;
  List<dynamic> _payableList = [];
  String? _selectedPayableId;
  String? _selectedVendorId;

  // Form State
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _payeeNameController = TextEditingController();
  final TextEditingController _contactNoController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();

  String? _selectedExpenseHead;
  int? _editingExpenseId; // null for new, set for edit mode
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _fetchExpenseHeads();
    if (!mounted) return;
    if (widget.expenseToEdit != null) {
      _editExpense(widget.expenseToEdit!);
    }
  }

  Future<void> _fetchExpenseHeads() async {
    setState(() => _isLoadingHeads = true);
    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;

      debugPrint('Fetching expense heads with orgId: $orgId');

      final response = await http.get(
        Uri.parse('https://bs-org.com/index.php/api/Expense/expenseList?orgID=$orgId'),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> fetchedHeads = [];

        if (data is Map && data['data'] != null) {
          fetchedHeads = List.from(data['data']);
        } else if (data is List) {
          fetchedHeads = data;
        } else if (data is Map) {
          fetchedHeads = [data];
        }

        debugPrint('Fetched ${fetchedHeads.length} expense heads');

        setState(() {
          _expenseHeads = fetchedHeads;
          _isLoadingHeads = false;
        });
      } else {
        setState(() => _isLoadingHeads = false);
      }
    } catch (e) {
      debugPrint('Error fetching expense heads: $e');
      setState(() => _isLoadingHeads = false);
    }
  }

  Future<void> _fetchPayables() async {
    setState(() => _isLoadingPayables = true);
    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;

      debugPrint('Fetching payables for expense with orgId: $orgId');

      final response = await http.get(
        Uri.parse('https://bs-org.com/index.php/api/Expense/getPayables?orgID=$orgId'),
      );

      debugPrint('Payable list response status: ${response.statusCode}');
      debugPrint('Payable list response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> fetchedPayables = [];

        if (data is Map && data['payables'] != null) {
          fetchedPayables = List.from(data['payables']);
        } else if (data is Map && data['data'] != null) {
          fetchedPayables = List.from(data['data']);
        } else if (data is List) {
          fetchedPayables = data;
        }

        setState(() {
          _payableList = fetchedPayables;
          _isLoadingPayables = false;
        });
        debugPrint('Fetched ${_payableList.length} payables');
      } else {
        setState(() => _isLoadingPayables = false);
      }
    } catch (e) {
      debugPrint('Error fetching payables: $e');
      setState(() => _isLoadingPayables = false);
    }
  }


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _onExpenseFromPayableCheckboxChanged(bool? value) {
    setState(() {
      _isExpenseFromPayable = value ?? false;
      if (!_isExpenseFromPayable) {
        // Clear payable selection and related fields
        _selectedPayableId = null;
        _selectedVendorId = null;
        _payeeNameController.clear();
        _amountController.clear();
        _dateController.clear();
      }
    });

    if (_isExpenseFromPayable && _payableList.isEmpty) {
      _fetchPayables();
    }
  }

  void _onPayableSelected(String? value) {
    if (value == null || value.isEmpty) return;

    final selectedPayable = _payableList.firstWhere(
      (p) => p['id']?.toString() == value,
      orElse: () => {},
    );

    if (selectedPayable.isNotEmpty) {
      // Get values before setState for debugging
      final supplierName = selectedPayable['supplier_name'] ?? selectedPayable['vendor_name'] ?? '';
      final amount = selectedPayable['amount'] ?? selectedPayable['due_amount'] ?? '';
      final scheduleDate = selectedPayable['schedule_date'] ?? selectedPayable['due_date'] ?? '';
      final vendorId = selectedPayable['vendor_id']?.toString();

      setState(() {
        _selectedPayableId = value;
        _selectedVendorId = vendorId;
        // Auto-fill payee name, amount and date from payable
        _payeeNameController.text = supplierName;
        _amountController.text = amount.toString();
        if (scheduleDate.isNotEmpty) {
          _dateController.text = scheduleDate;
        }
      });
      debugPrint('Payable selected: ID=$value, vendorId=$vendorId, supplier=$supplierName, amount=$amount, date=$scheduleDate');
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        final session = await SessionManager.getSession();
        final token = await SessionManager.getToken();
        final orgId = session['orgId'] ?? 106;
        final userId = session['userId'];

        // Prepare form data
        Map<String, String> formData = {
          'orgID': orgId.toString(),
          'expenseAmount': _amountController.text.trim(),
          'expenseDate': _dateController.text.trim(),
          'content': _commentsController.text.trim(),
        };

        // Only add expenseHead if not using payable (or if selected manually alongside payable)
        if (_selectedExpenseHead != null && _selectedExpenseHead!.isNotEmpty) {
          formData['expenseHead'] = _selectedExpenseHead!;
        }

        // If expense from payable, add vendor_id AND payable_id
        if (_isExpenseFromPayable) {
          if (_selectedVendorId != null) {
            formData['vendor_id'] = _selectedVendorId!;
          }
          if (_selectedPayableId != null) {
            formData['payable_id'] = _selectedPayableId!;
          }
        }

        // Add optional fields if they have values
        if (_payeeNameController.text.trim().isNotEmpty) {
          formData['payeeName'] = _payeeNameController.text.trim();
        }
        if (_contactNoController.text.trim().isNotEmpty) {
          formData['contactNo'] = _contactNoController.text.trim();
        }
        if (userId != null) {
          formData['userID'] = userId.toString();
        }

        final url = _editingExpenseId == null
            ? 'https://bs-org.com/index.php/api/Expense/expenseInsert'
            : 'https://bs-org.com/index.php/api/Expense/expenseUpdate';

        if (_editingExpenseId != null) {
          formData['expenseID'] = _editingExpenseId.toString();
        }

        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: formData,
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          if (data['status'] == true) {
            if (mounted) {
              setState(() {
                _isSubmitting = false;
              });

              String message = _editingExpenseId == null
                  ? data['message'] ?? 'Expense added successfully!'
                  : data['message'] ?? 'Expense updated successfully!';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );

              _resetForm();
              // After successful submission, navigate back to list if callback provided
              if (_editingExpenseId != null && widget.onListTap != null) {
                widget.onListTap!();
              }
            }
          } else {
            throw Exception(data['message'] ?? 'Failed to save expense');
          }
        } else {
          throw Exception('HTTP error: ${response.statusCode}');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _editExpense(Map<String, dynamic> expense) async {
    setState(() {
      _editingExpenseId = expense['id'] is String
          ? int.tryParse(expense['id'].toString())
          : expense['id'] as int?;

      // Get expense head name from API response (eHead field)
      final headName = expense['eHead']?.toString() ??
                       expense['categoryName']?.toString() ??
                       '';

      // Find the expense head ID from the fetched heads list
      final head = _expenseHeads.isNotEmpty
          ? _expenseHeads.firstWhere(
              (h) => (h['categoryName']?.toString() ?? h['name']?.toString()) == headName,
              orElse: () => {},
            )
          : {};

      _selectedExpenseHead = head['id']?.toString() ?? headName;
      _payeeNameController.text = expense['payeeName']?.toString() ?? '';
      _contactNoController.text = expense['contactNo']?.toString() ?? '';
      _amountController.text = expense['expenseAmount']?.toString() ?? '';

      // Format date to yyyy-MM-dd for the date picker
      final dateStr = expense['date']?.toString() ?? '';
      if (dateStr.isNotEmpty) {
        try {
          final date = DateTime.parse(dateStr);
          _dateController.text = DateFormat('yyyy-MM-dd').format(date);
        } catch (e) {
          _dateController.text = dateStr;
        }
      } else {
        _dateController.clear();
      }

      _commentsController.text = expense['comments']?.toString() ?? '';

      // Handle expense from payable checkbox
      final payableId = expense['payable_id'];
      if (payableId != null && payableId != 0 && payableId != '') {
        _isExpenseFromPayable = true;
        _selectedPayableId = payableId.toString();
      } else {
        _isExpenseFromPayable = false;
        _selectedPayableId = null;
      }
    });

    // If expense from payable is checked, fetch payables
    if (_isExpenseFromPayable && _selectedPayableId != null) {
      if (_payableList.isEmpty) {
        await _fetchPayables();
      }
      // Amount and date are already set from the expense data
    }
  }

  void _deleteExpense(int id) async {
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
          'expenseID': id.toString(),
          'orgID': session['orgId']?.toString() ?? '106',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted successfully!')),
        );
        // After deletion, maybe go back to list if callback provided
        if (widget.onListTap != null) {
          widget.onListTap!();
        } else {
          _resetForm();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting expense: $e')),
      );
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    setState(() {
      _editingExpenseId = null;
      _selectedExpenseHead = null;
      _payeeNameController.clear();
      _contactNoController.clear();
      _amountController.clear();
      _dateController.clear();
      _commentsController.clear();
      _isExpenseFromPayable = false;
      _selectedPayableId = null;
      _selectedVendorId = null;
    });
  }

  @override
  void dispose() {
    _payeeNameController.dispose();
    _contactNoController.dispose();
    _amountController.dispose();
    _dateController.dispose();
    _commentsController.dispose();
    super.dispose();
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
                  _buildFormHeader(),
                  _buildFormSection(),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        border: Border(bottom: BorderSide(color: Color(0xFFDDDDDD))),
      ),
      child: Row(
        children: [
          const Icon(Icons.arrow_back, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          const Text(
            'Accounts',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const Text(' / ', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const Text(
            'Expense',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const Text(' / ', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const Text(
            'Add Expense',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
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
        children: [
          Text(
            _editingExpenseId == null ? 'Add Expense' : 'Update Expense',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (widget.onListTap != null)
            InkWell(
              onTap: widget.onListTap,
              child: const Icon(Icons.list, size: 16, color: Color(0xFFBA6D6D)),
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
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Expense Head *'),
            _isLoadingHeads
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
                      selectedItem: _selectedExpenseHead,
                      items: _expenseHeads
                          .where((h) => h != null && (h['id']?.toString() ?? h['head_id']?.toString()) != null)
                          .map((h) => (h['id']?.toString() ?? h['head_id']?.toString())!)
                          .toList(),
                      itemAsString: (item) {
                        if (item == null) return '( Select Expense Head )';
                        final head = _expenseHeads.firstWhere(
                          (h) => h != null && (h['id']?.toString() ?? h['head_id']?.toString()) == item,
                          orElse: () => {},
                        );
                        return head['categoryName'] ?? head['name'] ?? head['head_name'] ?? 'Unknown';
                      },
                      onChanged: (val) => setState(() => _selectedExpenseHead = val),
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          hintText: '( Select Expense Head )',
                          hintStyle: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        ),
                      ),
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          decoration: InputDecoration(
                            hintText: 'Search expense heads...',
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
                          final head = _expenseHeads.firstWhere(
                            (h) => h != null && (h['id']?.toString() ?? h['head_id']?.toString()) == item,
                            orElse: () => {},
                          );
                          final headName = head['categoryName'] ?? head['name'] ?? head['head_name'] ?? 'Unknown';

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
                                    headName,
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
                              '( Select Expense Head )',
                              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          );
                        }
                        final head = _expenseHeads.firstWhere(
                          (h) => h != null && (h['id']?.toString() ?? h['head_id']?.toString()) == selectedItem,
                          orElse: () => {},
                        );
                        final headName = head['categoryName'] ?? head['name'] ?? head['head_name'] ?? 'Unknown';

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  headName,
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
                      validator: (value) {
                        // If expense is from payable, expense head is optional (API will auto-create from vendor)
                        if (_isExpenseFromPayable && _selectedPayableId != null) {
                          return null;
                        }
                        return value == null || value.isEmpty ? 'Please select an expense head' : null;
                      },
                    ),
                  ),
            const SizedBox(height: 16),

            // Checkbox: Expense From Payable
            Row(
              children: [
                Checkbox(
                  value: _isExpenseFromPayable,
                  onChanged: _onExpenseFromPayableCheckboxChanged,
                  activeColor: const Color(0xFF0066CC),
                ),
                const Expanded(
                  child: Text(
                    'Expense From Payable',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),

            // Payable Dropdown (conditionally visible)
            _isExpenseFromPayable
                ? Container(
                    margin: const EdgeInsets.only(top: 8),
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
                    child: _isLoadingPayables
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
                        : DropdownSearch<String>(
                            selectedItem: _selectedPayableId,
                            items: _payableList
                                .where((p) => p != null && p['id'] != null)
                                .map((p) => p['id'].toString())
                                .toList(),
                            itemAsString: (item) {
                              final payable = _payableList.firstWhere(
                                (p) => p != null && p['id']?.toString() == item,
                                orElse: () => {},
                              );
                              final supplierName = payable['supplier_name'] ?? payable['vendor_name'] ?? 'Unknown Supplier';
                              final amount = payable['amount'] ?? 0;
                              final scheduleDate = payable['schedule_date'] ?? '';
                              return '$supplierName - Amount: ${NumberFormat('#,##0.00').format(amount is num ? amount : double.tryParse(amount.toString()) ?? 0)} - Schedule Date: $scheduleDate';
                            },
                            onChanged: _onPayableSelected,
                            dropdownDecoratorProps: const DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                hintText: '( Select Payable )',
                                hintStyle: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                              ),
                            ),
                            popupProps: PopupProps.menu(
                              showSearchBox: true,
                              searchFieldProps: TextFieldProps(
                                decoration: InputDecoration(
                                  hintText: 'Search payables...',
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
                                final payable = _payableList.firstWhere(
                                  (p) => p != null && p['id']?.toString() == item,
                                  orElse: () => {},
                                );
                                final supplierName = payable['supplier_name'] ?? payable['vendor_name'] ?? 'Unknown Supplier';
                                final amount = payable['amount'] ?? 0;
                                final scheduleDate = payable['schedule_date'] ?? '';

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
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              supplierName,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                color: isSelected ? const Color(0xFF6A5AE0) : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Amount: ${NumberFormat('#,##0.00').format(amount is num ? amount : double.tryParse(amount.toString()) ?? 0)} - Schedule: $scheduleDate',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
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
                                    '( Select Payable )',
                                    style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                );
                              }
                              final payable = _payableList.firstWhere(
                                (p) => p != null && p['id']?.toString() == selectedItem,
                                orElse: () => {},
                              );
                              final supplierName = payable['supplier_name'] ?? payable['vendor_name'] ?? 'Unknown Supplier';
                              final amount = payable['amount'] ?? 0;

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
                                    Text(
                                      NumberFormat('#,##0.00').format(amount is num ? amount : double.tryParse(amount.toString()) ?? 0),
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.check_circle, color: Colors.white70, size: 18),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                : const SizedBox.shrink(),

            const SizedBox(height: 16),
            _buildLabel('Pay To *'),
            _buildTextField(
              _payeeNameController,
              'Payee Name',
              validator: (value) => (value == null || value.isEmpty) ? 'Please enter payee name' : null,
            ),
            const SizedBox(height: 16),
            _buildLabel('Contact No. *'),
            _buildTextField(
              _contactNoController,
              'Contact No.',
              isNumber: true,
              validator: (value) => (value == null || value.isEmpty) ? 'Please enter contact number' : null,
            ),
            const SizedBox(height: 16),
            _buildLabel('Expense Amount *'),
            _buildTextField(
              _amountController,
              'Expense Amount',
              isNumber: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter expense amount';
                }
                if (double.tryParse(value) == null) {
                  return 'Please enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildLabel('Transaction Date *'),
            _buildDateField(
              validator: (value) => (value == null || value.isEmpty) ? 'Please select transaction date' : null,
            ),
            const SizedBox(height: 16),
            _buildLabel('Site Comments'),
            _buildTextField(_commentsController, 'Enter comments here...', maxLines: 3),
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
                  child: _isSubmitting
                      ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_editingExpenseId == null ? 'Submit' : 'Update'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: widget.onListTap ?? () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _resetForm,
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCCCCCC)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildDateField({String? Function(String?)? validator}) {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: AbsorbPointer(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCCCCCC)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextFormField(
            controller: _dateController,
            validator: validator,
            decoration: const InputDecoration(
              hintText: 'Select date',
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: InputBorder.none,
              suffixIcon: Icon(Icons.calendar_today, size: 16, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'dart:convert';
import 'session_manager.dart';

class IncomeFormPage extends StatefulWidget {
  final VoidCallback? onListTap;
  final Map<String, dynamic>? incomeToEdit;

  const IncomeFormPage({
    super.key,
    this.onListTap,
    this.incomeToEdit,
  });

  @override
  State<IncomeFormPage> createState() => _IncomeFormPageState();
}

class _IncomeFormPageState extends State<IncomeFormPage> {
  bool _isLoadingHeads = false;
  List<dynamic> _incomeHeads = [];

  // Receivable from income feature
  bool _isReceivableIncome = false;
  bool _isLoadingReceivables = false;
  List<dynamic> _receivableList = [];
  String? _selectedReceivableId;

  // Form State
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();

  String? _selectedIncomeHead;
  int? _editingIncomeId; // null for new, set for edit mode
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _fetchIncomeHeads();
    if (!mounted) return;
    if (widget.incomeToEdit != null) {
      _editIncome(widget.incomeToEdit!);
    }
  }

  Future<void> _fetchIncomeHeads() async {
    setState(() => _isLoadingHeads = true);
    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;

      debugPrint('Fetching income heads with orgId: $orgId');

      // Try the endpoint from income_form.txt
      final response = await http.get(
        Uri.parse('https://bs-org.com/index.php/api/Income/incomeList?orgID=$orgId'),
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
          // If it's a map with direct fields
          fetchedHeads = [data];
        }

        debugPrint('Fetched ${fetchedHeads.length} income heads');

        setState(() {
          _incomeHeads = fetchedHeads;
          _isLoadingHeads = false;
        });
      } else {
        setState(() => _isLoadingHeads = false);
      }
    } catch (e) {
      debugPrint('Error fetching income heads: $e');
      setState(() => _isLoadingHeads = false);
    }
  }

  Future<void> _fetchReceivables() async {
    setState(() => _isLoadingReceivables = true);
    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;

      debugPrint('Fetching receivables for income with orgId: $orgId');

      final response = await http.get(
        Uri.parse('https://bs-org.com/index.php/api/Income/receivableList?orgID=$orgId'),
      );

      debugPrint('Receivable list response status: ${response.statusCode}');
      debugPrint('Receivable list response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> fetchedReceivables = [];

        if (data is Map && data['data'] != null) {
          fetchedReceivables = List.from(data['data']);
        } else if (data is List) {
          fetchedReceivables = data;
        }

        setState(() {
          _receivableList = fetchedReceivables;
          _isLoadingReceivables = false;
        });
        debugPrint('Fetched ${_receivableList.length} receivables');
      } else {
        setState(() => _isLoadingReceivables = false);
      }
    } catch (e) {
      debugPrint('Error fetching receivables: $e');
      setState(() => _isLoadingReceivables = false);
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

  void _onReceivableCheckboxChanged(bool? value) {
    setState(() {
      _isReceivableIncome = value ?? false;
      if (!_isReceivableIncome) {
        // Clear receivable selection and related fields
        _selectedReceivableId = null;
        _amountController.clear();
        _dateController.clear();
      }
    });

    if (_isReceivableIncome && _receivableList.isEmpty) {
      _fetchReceivables();
    }
  }

  void _onReceivableSelected(String? value) {
    if (value == null || value.isEmpty) return;

    final selectedReceivable = _receivableList.firstWhere(
      (r) => r['id']?.toString() == value,
      orElse: () => {},
    );

    if (selectedReceivable.isNotEmpty) {
      // Get values before setState for debugging
      final amount = selectedReceivable['due_amount'] ?? selectedReceivable['amount'] ?? '';
      final dueDate = selectedReceivable['due_date'] ?? '';

      setState(() {
        _selectedReceivableId = value;
        // Auto-fill amount and date from receivable
        _amountController.text = amount.toString();
        if (dueDate.isNotEmpty) {
          _dateController.text = dueDate;
        }
      });
      debugPrint('Receivable selected: ID=$value, amount=$amount, date=$dueDate');
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
          'incomeHead': _selectedIncomeHead ?? '',
          'incomeAmount': _amountController.text.trim(),
          'incomeDate': _dateController.text.trim(),
          'content': _commentsController.text.trim(),
        };

        // If income from receivable, add receivable_id
        if (_isReceivableIncome && _selectedReceivableId != null) {
          formData['receivable_id'] = _selectedReceivableId!;
        }

        if (userId != null) {
          formData['userID'] = userId.toString();
        }

        final url = _editingIncomeId == null
            ? 'https://bs-org.com/index.php/api/Income/incomeInsert'
            : 'https://bs-org.com/index.php/api/Income/incomeUpdate';

        if (_editingIncomeId != null) {
          formData['incomeID'] = _editingIncomeId.toString();
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

              String message = _editingIncomeId == null
                  ? data['message'] ?? 'Income added successfully!'
                  : data['message'] ?? 'Income updated successfully!';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );

              _resetForm();
              // After successful submission, navigate back to list if callback provided
              if (_editingIncomeId != null && widget.onListTap != null) {
                widget.onListTap!();
              }
            }
          } else {
            throw Exception(data['message'] ?? 'Failed to save income');
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

  Future<void> _editIncome(Map<String, dynamic> income) async {
    setState(() {
      _editingIncomeId = income['id'] is String
          ? int.tryParse(income['id'].toString())
          : income['id'] as int?;

      // Get income head name from API response
      final headName = income['iHead']?.toString() ??
                       income['categoryName']?.toString() ??
                       '';

      // Find the income head ID from the fetched heads list
      final head = _incomeHeads.isNotEmpty
          ? _incomeHeads.firstWhere(
              (h) => (h['categoryName']?.toString() ?? h['name']?.toString()) == headName,
              orElse: () => {},
            )
          : {};

      _selectedIncomeHead = head['id']?.toString() ?? headName;
      _amountController.text = income['incomeAmount']?.toString() ?? '';
      _dateController.text = income['date']?.toString() ?? '';
      _commentsController.text = income['comments']?.toString() ?? '';

      // Handle receivable income checkbox
      final receivableId = income['receivable_id'];
      if (receivableId != null && receivableId != 0 && receivableId != '') {
        _isReceivableIncome = true;
        _selectedReceivableId = receivableId.toString();
        // Note: The receivable dropdown list should be loaded already or will be loaded when checkbox is toggled
        // The actual amount/date fields may have been manually edited, so we don't override them
        // unless we want to re-fetch from receivable API. For now, assume the form values are correct.
      } else {
        _isReceivableIncome = false;
        _selectedReceivableId = null;
      }
    });

    // If receivable income is checked, fetch receivables and set the selected value
    if (_isReceivableIncome && _selectedReceivableId != null) {
      if (_receivableList.isEmpty) {
        await _fetchReceivables();
      }
      // After fetching, ensure the selected receivable is applied (to get any fields not in the income record)
      // But the amount/date should already be in the form from the edit data
    }
  }

  void _deleteIncome(int id) async {
    try {
      final session = await SessionManager.getSession();
      final token = await SessionManager.getToken();

      final response = await http.post(
        Uri.parse('https://bs-org.com/index.php/api/Income/deleteIncome'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: {
          'incomeID': id.toString(),
          'orgID': session['orgId']?.toString() ?? '106',
        },
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Income deleted successfully!')),
        );
        // After deletion, go back to list if callback provided
        if (widget.onListTap != null) {
          widget.onListTap!();
        } else {
          _resetForm();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting income: $e')),
      );
    }
  }

  void _resetForm() {
    _formKey.currentState!.reset();
    setState(() {
      _editingIncomeId = null;
      _selectedIncomeHead = null;
      _amountController.clear();
      _dateController.clear();
      _commentsController.clear();
      _isReceivableIncome = false;
      _selectedReceivableId = null;
    });
  }

  @override
  void dispose() {
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
            'Income',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const Text(' / ', style: TextStyle(fontSize: 13, color: Colors.grey)),
          Text(
            _editingIncomeId == null ? 'Add Income' : 'Update Income',
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
            _editingIncomeId == null ? 'Add Income' : 'Update Income',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (widget.onListTap != null)
            InkWell(
              onTap: widget.onListTap!,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Income Head *'),
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
                      selectedItem: _selectedIncomeHead,
                      items: _incomeHeads
                          .where((h) => h != null && (h['id']?.toString() ?? h['head_id']?.toString()) != null)
                          .map((h) => (h['id']?.toString() ?? h['head_id']?.toString())!)
                          .toList(),
                      itemAsString: (item) {
                        if (item == null) return '( Select Income Head )';
                        final head = _incomeHeads.firstWhere(
                          (h) => h != null && (h['id']?.toString() ?? h['head_id']?.toString()) == item,
                          orElse: () => {},
                        );
                        return head['iHead'] ?? head['categoryName'] ?? head['name'] ?? head['head_name'] ?? 'Unknown';
                      },
                      onChanged: (val) => setState(() => _selectedIncomeHead = val),
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          hintText: '( Select Income Head )',
                          hintStyle: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                        ),
                      ),
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: TextFieldProps(
                          decoration: InputDecoration(
                            hintText: 'Search income heads...',
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
                          final head = _incomeHeads.firstWhere(
                            (h) => h != null && (h['id']?.toString() ?? h['head_id']?.toString()) == item,
                            orElse: () => {},
                          );
                          final headName = head['iHead'] ?? head['categoryName'] ?? head['name'] ?? head['head_name'] ?? 'Unknown';

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
                              '( Select Income Head )',
                              style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          );
                        }
                        final head = _incomeHeads.firstWhere(
                          (h) => h != null && (h['id']?.toString() ?? h['head_id']?.toString()) == selectedItem,
                          orElse: () => {},
                        );
                        final headName = head['iHead'] ?? head['categoryName'] ?? head['name'] ?? head['head_name'] ?? 'Unknown';

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
                    ),
                  ),
            const SizedBox(height: 16),

            // Checkbox: Income From Receivable
            Row(
              children: [
                Checkbox(
                  value: _isReceivableIncome,
                  onChanged: _onReceivableCheckboxChanged,
                  activeColor: const Color(0xFF0066CC),
                ),
                const Expanded(
                  child: Text(
                    'Income From Receivable',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),

            // Receivable Dropdown (conditionally visible)
            _isReceivableIncome
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
                    child: _isLoadingReceivables
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
                            selectedItem: _selectedReceivableId,
                            items: _receivableList
                                .where((r) => r != null && r['id'] != null)
                                .map((r) => r['id'].toString())
                                .toList(),
                            itemAsString: (item) {
                              final receivable = _receivableList.firstWhere(
                                (r) => r != null && r['id']?.toString() == item,
                                orElse: () => {},
                              );
                              final dealerName = receivable['dealer_name'] ?? 'Unknown Dealer';
                              final amount = receivable['due_amount'] ?? receivable['amount'] ?? 0;
                              final dueDate = receivable['due_date'] ?? '';
                              return '$dealerName - Amount: ${NumberFormat('#,##0.00').format(amount is num ? amount : double.tryParse(amount.toString()) ?? 0)} - Due Date: $dueDate';
                            },
                            onChanged: _onReceivableSelected,
                            dropdownDecoratorProps: const DropDownDecoratorProps(
                              dropdownSearchDecoration: InputDecoration(
                                hintText: '( Select Receivable )',
                                hintStyle: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                              ),
                            ),
                            popupProps: PopupProps.menu(
                              showSearchBox: true,
                              searchFieldProps: TextFieldProps(
                                decoration: InputDecoration(
                                  hintText: 'Search receivables...',
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
                                final receivable = _receivableList.firstWhere(
                                  (r) => r != null && r['id']?.toString() == item,
                                  orElse: () => {},
                                );
                                final dealerName = receivable['dealer_name'] ?? 'Unknown Dealer';
                                final amount = receivable['due_amount'] ?? receivable['amount'] ?? 0;
                                final dueDate = receivable['due_date'] ?? '';

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
                                              dealerName,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                                color: isSelected ? const Color(0xFF6A5AE0) : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Amount: ${NumberFormat('#,##0.00').format(amount is num ? amount : double.tryParse(amount.toString()) ?? 0)} - Due: $dueDate',
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
                                    '( Select Receivable )',
                                    style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                );
                              }
                              final receivable = _receivableList.firstWhere(
                                (r) => r != null && r['id']?.toString() == selectedItem,
                                orElse: () => {},
                              );
                              final dealerName = receivable['dealer_name'] ?? 'Unknown Dealer';
                              final amount = receivable['due_amount'] ?? receivable['amount'] ?? 0;

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
            _buildLabel('Income Amount *'),
            _buildTextField(_amountController, 'Income Amount', isNumber: true),
            const SizedBox(height: 16),
            _buildLabel('Transaction Date *'),
            _buildDateField(),
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
                      : Text(_editingIncomeId == null ? 'Submit' : 'Update'),
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
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCCCCCC)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: AbsorbPointer(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCCCCCC)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
            controller: _dateController,
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

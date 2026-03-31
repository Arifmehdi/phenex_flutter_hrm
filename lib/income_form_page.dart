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

  void _editIncome(Map<String, dynamic> income) {
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
    });
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

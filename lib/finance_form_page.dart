import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';

class FinanceFormPage extends StatefulWidget {
  final String title;
  final Map<String, dynamic>? initialData;

  const FinanceFormPage({super.key, required this.title, this.initialData});

  @override
  State<FinanceFormPage> createState() => _FinanceFormPageState();
}

class _FinanceFormPageState extends State<FinanceFormPage> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _transactionDate;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String? _selectedHead;
  bool _isEdit = false;

  final List<String> _heads = ['Office Rent', 'Salary', 'Electricity Bill', 'Internet Bill', 'Miscellaneous'];

  @override
  void initState() {
    super.initState();
    _isEdit = widget.initialData != null;
    _transactionDate = DateTime.now();
    
    if (_isEdit) {
      _selectedHead = widget.initialData!['head'];
      _amountController.text = widget.initialData!['amount'].toString().replaceAll(',', '');
      if (widget.initialData!['date'] != null) {
        try {
          _transactionDate = DateTime.parse(widget.initialData!['date']);
        } catch (_) {}
      }
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
    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      body: Column(
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
                    _buildFormHeader(),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('${widget.title} Head'),
                            _buildDropdownField(),
                            const SizedBox(height: 16),
                            _buildLabel('${widget.title} Amount'),
                            _buildTextField(_amountController, '${widget.title} Amount', isNumber: true),
                            const SizedBox(height: 16),
                            _buildLabel('Transaction Date'),
                            _buildDateField(),
                            const SizedBox(height: 16),
                            _buildLabel('Comments'),
                            _buildTextField(_commentController, 'Comments', maxLines: 3),
                            const SizedBox(height: 24),
                            _buildFormActions(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
                '${widget.title} Form',
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
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold),
              children: [
                TextSpan(text: '${_isEdit ? "Edit" : "New"} ${widget.title} '),
                WidgetSpan(
                  child: InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.list, size: 16, color: Color(0xFFBA6D6D)),
                  ),
                ),
              ],
            ),
          ),
        ],
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
            if (_formKey.currentState!.validate()) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${_isEdit ? "Updating" : "Saving"} data...')),
              );
              Navigator.pop(context);
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
          onPressed: () => Navigator.pop(context),
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
                _transactionDate = DateTime.now();
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

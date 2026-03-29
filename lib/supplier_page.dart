import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'dart:convert';
import 'session_manager.dart';

class SupplierPage extends StatefulWidget {
  const SupplierPage({super.key});

  @override
  State<SupplierPage> createState() => _SupplierPageState();
}

class _SupplierPageState extends State<SupplierPage> {
  bool _showForm = false;
  bool _isLoadingList = true;
  List<dynamic> _supplierList = [];

  // Form State
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactPersonController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _facebookLinkController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _thanaController = TextEditingController();
  final TextEditingController _supplierCategoryController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _commentsController = TextEditingController();
  final TextEditingController _statusController = TextEditingController();
  final TextEditingController _openingDrController = TextEditingController();
  final TextEditingController _openingCrController = TextEditingController();

  String? _selectedSupplier;
  Map<String, dynamic>? _editingSupplier;

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
    _fetchSupplierList();
  }

  Future<void> _fetchSupplierList() async {
    setState(() => _isLoadingList = true);
    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;

      final response = await http.get(
        Uri.parse('https://bs-org.com/index.php/api/Supplier/list?orgID=$orgId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['data'] != null) {
          setState(() {
            _supplierList = data['data'];
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load suppliers');
        }
      } else {
        throw Exception('Failed to load suppliers');
      }
    } catch (e) {
      debugPrint('Error fetching supplier list: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading suppliers: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingList = false);
      }
    }
  }

  void _toggleForm(bool show, [Map<String, dynamic>? supplier]) {
    setState(() {
      _showForm = show;
      _editingSupplier = supplier;
      if (show && supplier != null) {
        _nameController.text = supplier['name'] ?? '';
        _contactPersonController.text = supplier['contact_person'] ?? '';
        _contactController.text = supplier['contact'] ?? '';
        _emailController.text = supplier['email'] ?? '';
        _facebookLinkController.text = supplier['facebook_page_link'] ?? '';
        _districtController.text = supplier['district']?.toString() ?? '';
        _thanaController.text = supplier['police_station_name'] ?? supplier['police_station_thana'] ?? '';
        _supplierCategoryController.text = supplier['supplier_category'] ?? '';
        _addressController.text = supplier['address'] ?? '';
        _commentsController.text = supplier['comments'] ?? '';
        _statusController.text = supplier['status'] ?? 'Active';
        _openingDrController.text = (supplier['opening_dr'] ?? 0).toString();
        _openingCrController.text = (supplier['opening_cr'] ?? 0).toString();
      } else if (show) {
        _clearForm();
      }
    });
  }

  void _showDeleteConfirmation(int? supplierId) {
    if (supplierId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this supplier?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSupplier(supplierId);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _clearForm() {
    _nameController.clear();
    _contactPersonController.clear();
    _contactController.clear();
    _emailController.clear();
    _facebookLinkController.clear();
    _districtController.clear();
    _thanaController.clear();
    _supplierCategoryController.clear();
    _addressController.clear();
    _commentsController.clear();
    _statusController.text = 'Active';
    _openingDrController.clear();
    _openingCrController.clear();
    _editingSupplier = null;
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

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        final session = await SessionManager.getSession();
        final orgId = session['orgId'] ?? 106;
        final userId = session['userId'] ?? 1;

        final Map<String, dynamic> supplierData = {
          'name': _nameController.text,
          'contact_person': _contactPersonController.text,
          'contact': _contactController.text,
          'email': _emailController.text,
          'facebook_page_link': _facebookLinkController.text,
          'district': _districtController.text.isNotEmpty ? _districtController.text : null,
          'police_station_thana': _thanaController.text.isNotEmpty ? _thanaController.text : null,
          'supplier_category': _supplierCategoryController.text.isNotEmpty ? _supplierCategoryController.text : null,
          'address': _addressController.text,
          'comments': _commentsController.text,
          'status': _statusController.text,
          'opening_dr': double.tryParse(_openingDrController.text) ?? 0,
          'opening_cr': double.tryParse(_openingCrController.text) ?? 0,
          'orgID': orgId,
          'user_id': userId,
        };

        final response = await http.post(
          Uri.parse(_editingSupplier != null
              ? 'https://bs-org.com/index.php/api/Supplier/update?id=${_editingSupplier!['id']}'
              : 'https://bs-org.com/index.php/api/Supplier/create'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(supplierData),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == true) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_editingSupplier != null ? 'Supplier updated successfully!' : 'Supplier added successfully!')),
              );
              _toggleForm(false);
              _fetchSupplierList();
              _clearForm();
            }
          } else {
            throw Exception(data['message'] ?? 'Operation failed');
          }
        } else {
          throw Exception('Failed to ${_editingSupplier != null ? 'update' : 'create'} supplier');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
              const Icon(Icons.business, size: 20, color: Color(0xFF666666)),
              const SizedBox(width: 8),
              Text(
                _showForm ? 'Supplier Form' : 'Supplier',
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
            'Supplier List (',
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
                _editingSupplier != null ? 'Edit Supplier' : 'New Supplier',
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
            onPressed: _fetchSupplierList,
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

  Future<void> _deleteSupplier(int supplierId) async {
    try {
      final response = await http.get(
        Uri.parse('https://bs-org.com/index.php/api/Supplier/delete?id=$supplierId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Supplier deleted successfully!')),
          );
          _fetchSupplierList();
        } else {
          throw Exception(data['message'] ?? 'Delete failed');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting supplier: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _viewSupplierDetails(int supplierId) async {
    try {
      final response = await http.get(
        Uri.parse('https://bs-org.com/index.php/api/Supplier/details?id=$supplierId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true && data['data'] != null) {
          _showDetailsDialog(data['data']);
        } else {
          throw Exception(data['message'] ?? 'Failed to fetch details');
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching details: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showDetailsDialog(Map<String, dynamic> supplier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(supplier['name'] ?? 'Supplier Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Name', supplier['name']?.toString() ?? 'N/A'),
              _buildDetailRow('Contact Person', supplier['contact_person']?.toString() ?? 'N/A'),
              _buildDetailRow('Contact', supplier['contact']?.toString() ?? 'N/A'),
              _buildDetailRow('Email', supplier['email']?.toString() ?? 'N/A'),
              _buildDetailRow('District', supplier['district']?.toString() ?? 'N/A'),
              _buildDetailRow('Thana', supplier['police_station_thana']?.toString() ?? 'N/A'),
              _buildDetailRow('Category', supplier['supplier_category']?.toString() ?? 'N/A'),
              _buildDetailRow('Address', supplier['address']?.toString() ?? 'N/A'),
              _buildDetailRow('Facebook', supplier['facebook_page_link']?.toString() ?? 'N/A'),
              _buildDetailRow('Opening Dr', (supplier['opening_dr'] ?? 0).toString()),
              _buildDetailRow('Opening Cr', (supplier['opening_cr'] ?? 0).toString()),
              _buildDetailRow('Status', supplier['status']?.toString() ?? 'N/A'),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    if (_isLoadingList) {
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
          DataColumn(label: Text('SL#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Thana', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Op Dr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Op Cr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Bal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ],
        rows: [
          ..._supplierList.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final supplier = entry.value;
            final openingDr = supplier['opening_dr'] ?? 0;
            final openingCr = supplier['opening_cr'] ?? 0;
            final balance = openingDr - openingCr;
            return DataRow(cells: [
              DataCell(Text(index.toString(), style: const TextStyle(fontSize: 12))),
              DataCell(Text(supplier['name'] ?? 'N/A', style: const TextStyle(fontSize: 12))),
              DataCell(Text(supplier['contact'] ?? 'N/A', style: const TextStyle(fontSize: 12))),
              DataCell(Text(supplier['police_station_name'] ?? supplier['thana'] ?? 'N/A', style: const TextStyle(fontSize: 12))),
              DataCell(Text(openingDr.toStringAsFixed(2), style: const TextStyle(fontSize: 12))),
              DataCell(Text(openingCr.toStringAsFixed(2), style: const TextStyle(fontSize: 12))),
              DataCell(Text(balance.toStringAsFixed(2), style: TextStyle(fontSize: 12, color: balance >= 0 ? Colors.green : Colors.red))),
              DataCell(Text(supplier['status'] ?? 'Active', style: const TextStyle(fontSize: 12))),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildActionButton(Icons.search, Colors.blue, onPressed: () => _viewSupplierDetails(supplier['id'])),
                  const SizedBox(width: 4),
                  _buildActionButton(Icons.edit, Colors.orange, onPressed: () => _toggleForm(true, supplier)),
                  const SizedBox(width: 4),
                  _buildActionButton(Icons.delete, Colors.red, onPressed: () => _showDeleteConfirmation(supplier['id'])),
                ],
              )),
            ]);
          }),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, {VoidCallback? onPressed}) {
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

  Widget _buildFormSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('Supplier Name *'),
            _buildTextField(_nameController, 'Supplier Name'),
            const SizedBox(height: 16),
            _buildLabel('Contact Person'),
            _buildTextField(_contactPersonController, 'Contact Person', isRequired: false),
            const SizedBox(height: 16),
            _buildLabel('Contact Number'),
            _buildTextField(_contactController, 'Contact Number', isRequired: false),
            const SizedBox(height: 16),
            _buildLabel('Email'),
            _buildTextField(_emailController, 'Email', isRequired: false),
            const SizedBox(height: 16),
            _buildLabel('Facebook Page Link'),
            _buildTextField(_facebookLinkController, 'Facebook Link', isRequired: false),
            const SizedBox(height: 16),
            _buildLabel('District'),
            _buildTextField(_districtController, 'District', isRequired: false),
            const SizedBox(height: 16),
            _buildLabel('Police Station/Thana'),
            _buildTextField(_thanaController, 'Police Station/Thana', isRequired: false),
            const SizedBox(height: 16),
            _buildLabel('Supplier Category'),
            _buildTextField(_supplierCategoryController, 'Supplier Category', isRequired: false),
            const SizedBox(height: 16),
            _buildLabel('Address'),
            _buildTextField(_addressController, 'Address', maxLines: 3, isRequired: false),
            const SizedBox(height: 16),
            _buildLabel('Comments'),
            _buildTextField(_commentsController, 'Comments', maxLines: 3, isRequired: false),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Opening Dr (Debit)'),
                      _buildTextField(_openingDrController, 'Opening Dr', isNumber: true, isRequired: false),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Opening Cr (Credit)'),
                      _buildTextField(_openingCrController, 'Opening Cr', isNumber: true, isRequired: false),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLabel('Status'),
            _buildStatusDropdown(),
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
                  child: _isSubmitting ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_editingSupplier != null ? 'Update' : 'Submit'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _toggleForm(false);
                    _clearForm();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  ),
                  child: const Text('Cancel'),
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
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {int maxLines = 1, bool isNumber = false, bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
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

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF566D7E),
        borderRadius: BorderRadius.circular(3),
      ),
      child: DropdownSearch<String>(
        selectedItem: _statusController.text.isEmpty ? 'Active' : _statusController.text,
        items: ['Active', 'Inactive'],
        itemAsString: (item) => item,
        onChanged: (newValue) {
          setState(() {
            _statusController.text = newValue ?? 'Active';
          });
        },
        dropdownDecoratorProps: const DropDownDecoratorProps(
          dropdownSearchDecoration: InputDecoration(
            hintText: 'Select Status',
            hintStyle: TextStyle(color: Colors.white70, fontSize: 13),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        popupProps: const PopupProps.menu(
          showSearchBox: true,
          searchFieldProps: TextFieldProps(
            decoration: InputDecoration(
              hintText: 'Search status...',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ),
        dropdownBuilder: (context, selectedItem) {
          return Text(
            selectedItem ?? 'Active',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          );
        },
      ),
    );
  }
}
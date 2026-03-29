import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'session_manager.dart';

class DealerPage extends StatefulWidget {
  const DealerPage({super.key});

  @override
  State<DealerPage> createState() => _DealerPageState();
}

class _DealerPageState extends State<DealerPage> {
  bool _showForm = false;
  bool _isLoadingList = true;
  List<dynamic> _dealerList = [];

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _personController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _openingDrController = TextEditingController();
  final TextEditingController _openingCrController = TextEditingController();

  Map<String, dynamic>? _editingDealer;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchDealerList();
  }

  Future<void> _fetchDealerList() async {
    setState(() => _isLoadingList = true);
    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;

      final response = await http.get(
        Uri.parse('https://bs-org.com/index.php/api/Dealer/list?orgID=$orgId'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['status'] == true) {
          List<dynamic> fetchedDealers = [];
          if (data['data'] != null) {
            final list = data['data'];
            if (list is List) {
              fetchedDealers = list.where((item) => item != null).toList();
            }
          }
          setState(() {
            _dealerList = fetchedDealers;
          });
        } else {
          debugPrint('API Error: ${data['message']}');
        }
      }
    } catch (e) {
      debugPrint('Error fetching dealer list: $e');
    } finally {
      setState(() => _isLoadingList = false);
    }
  }

  void _toggleForm(bool show, [Map<String, dynamic>? dealer]) {
    setState(() {
      _showForm = show;
      _editingDealer = dealer;
      if (show && dealer != null) {
        _nameController.text = dealer['dealer_name'] ?? '';
        _codeController.text = dealer['dealer_code'] ?? '';
        _contactController.text = dealer['contact_no'] ?? '';
        _personController.text = dealer['contact_person'] ?? '';
        _openingDrController.text = (dealer['opening_dr'] ?? 0).toString();
        _openingCrController.text = (dealer['opening_cr'] ?? 0).toString();
      } else if (show) {
        _clearForm();
      }
    });
  }

  void _clearForm() {
    _nameController.clear();
    _codeController.clear();
    _contactController.clear();
    _personController.clear();
    _openingDrController.clear();
    _openingCrController.clear();
    _editingDealer = null;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;
      final token = await SessionManager.getToken();

      final Map<String, dynamic> dealerData = {
        'dealer_name': _nameController.text.trim(),
        'dealer_code': _codeController.text.trim(),
        'orgID': orgId,
      };

      final Map<String, dynamic> contactData = {
        'contact_no': _contactController.text.trim(),
        'contact_person': _personController.text.trim(),
      };

      final Map<String, dynamic> financeData = {
        'opening_dr': double.tryParse(_openingDrController.text.trim()) ?? 0,
        'opening_cr': double.tryParse(_openingCrController.text.trim()) ?? 0,
      };

      if (_editingDealer != null) {
        final dealerId = _editingDealer!['id'];
        final response = await http.post(
          Uri.parse('https://bs-org.com/index.php/api/Dealer/update?id=$dealerId'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: json.encode({...dealerData, ...contactData, ...financeData}),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is Map && data['status'] == true) {
            if (mounted) {
              setState(() => _isSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(data['message'] ?? 'Dealer updated successfully')),
              );
              _fetchDealerList();
              _toggleForm(false);
            }
          } else {
            throw Exception(data['message'] ?? 'Failed to update dealer');
          }
        } else {
          throw Exception('HTTP ${response.statusCode}: Failed to update dealer');
        }
      } else {
        final response = await http.post(
          Uri.parse('https://bs-org.com/index.php/api/Dealer/create'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: json.encode({...dealerData, ...contactData, ...financeData}),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data is Map && data['status'] == true) {
            if (mounted) {
              setState(() => _isSubmitting = false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(data['message'] ?? 'Dealer added successfully')),
              );
              _fetchDealerList();
              _toggleForm(false);
            }
          } else {
            throw Exception(data['message'] ?? 'Failed to create dealer');
          }
        } else {
          throw Exception('HTTP ${response.statusCode}: Failed to create dealer');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteDealer(int? dealerId) async {
    if (dealerId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this dealer?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await SessionManager.getToken();
      final response = await http.delete(
        Uri.parse('https://bs-org.com/index.php/api/Dealer/delete?id=$dealerId'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Dealer deleted successfully')),
          );
          _fetchDealerList();
        } else {
          throw Exception(data['message'] ?? 'Failed to delete dealer');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to delete dealer');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting dealer: $e'), backgroundColor: Colors.red),
      );
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
              const Icon(Icons.people, size: 20, color: Color(0xFF666666)),
              const SizedBox(width: 8),
              Text(
                _showForm ? 'Dealer Form' : 'Dealer Management',
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
            'Dealer List (',
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
                _editingDealer != null ? 'Edit Dealer' : 'New Dealer',
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

  Widget _buildDataTable() {
    if (_isLoadingList) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    double totalOpening = 0;
    double totalDues = 0;
    double totalBalance = 0;

    for (var dealer in _dealerList) {
      final opening = _parseDouble(dealer['opening_cr']);
      final dues = _parseDouble(dealer['do_amt']);
      totalOpening += opening;
      totalDues += dues;
      totalBalance += opening + dues;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 10,
        headingRowHeight: 40,
        dataRowMinHeight: 40,
        dataRowMaxHeight: 40,
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F5F5)),
        border: const TableBorder(
          verticalInside: BorderSide(color: Color(0xFFDDDDDD), width: 1),
          horizontalInside: BorderSide(color: Color(0xFFDDDDDD), width: 1),
        ),
        columns: const [
          DataColumn(label: Text('SL#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          DataColumn(label: Text('Person', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          DataColumn(label: Text('Opening', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          DataColumn(label: Text('Dues', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          DataColumn(label: Text('Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
          DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
        ],
        rows: [
          ..._dealerList.asMap().entries.map((entry) {
            final index = entry.key + 1;
            final dealer = entry.value;

            final code = dealer['dealer_code']?.toString() ?? '-';
            final name = dealer['dealer_name']?.toString() ?? 'N/A';
            final contact = dealer['contact_no']?.toString() ?? 'N/A';
            final person = dealer['contact_person']?.toString() ?? '-';
            final opening = _parseDouble(dealer['opening_cr']);
            final dues = _parseDouble(dealer['do_amt']);
            final balance = opening + dues;

            return DataRow(cells: [
              DataCell(Text(index.toString(), style: const TextStyle(fontSize: 10))),
              DataCell(Text(code, style: const TextStyle(fontSize: 10))),
              DataCell(Text(name, style: const TextStyle(fontSize: 10))),
              DataCell(Text(person, style: const TextStyle(fontSize: 10))),
              DataCell(Text(contact, style: const TextStyle(fontSize: 10))),
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('৳ ${NumberFormat('#,##0.00').format(opening)}', style: const TextStyle(fontSize: 10)),
                ),
              ),
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('৳ ${NumberFormat('#,##0.00').format(dues)}', style: const TextStyle(fontSize: 10)),
                ),
              ),
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('৳ ${NumberFormat('#,##0.00').format(balance)}', style: const TextStyle(fontSize: 10)),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionButton(Icons.search, Colors.blue, () {
                      _viewDealerDetails(dealer);
                    }),
                    const SizedBox(width: 4),
                    _buildActionButton(Icons.edit, Colors.orange, () {
                      _toggleForm(true, dealer);
                    }),
                    const SizedBox(width: 4),
                    _buildActionButton(Icons.delete, Colors.red, () {
                      if (dealer['id'] != null) {
                        _deleteDealer(dealer['id']);
                      }
                    }),
                  ],
                ),
              ),
            ]);
          }),
          DataRow(
            color: WidgetStateProperty.all(const Color(0xFFF0F0F0)),
            cells: [
              const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10))),
              const DataCell(Text('')),
              const DataCell(Text('')),
              const DataCell(Text('')),
              const DataCell(Text('')),
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('৳ ${NumberFormat('#,##0.00').format(totalOpening)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ),
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('৳ ${NumberFormat('#,##0.00').format(totalDues)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ),
              DataCell(
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('৳ ${NumberFormat('#,##0.00').format(totalBalance)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                ),
              ),
              const DataCell(Text('')),
            ],
          ),
        ],
      ),
    );
  }

  void _viewDealerDetails(Map<String, dynamic> dealer) {
    final code = dealer['dealer_code']?.toString() ?? '-';
    final name = dealer['dealer_name']?.toString() ?? 'N/A';
    final contact = dealer['contact_no']?.toString() ?? 'N/A';
    final person = dealer['contact_person']?.toString() ?? '-';
    final opening = _parseDouble(dealer['opening_cr']);
    final dues = _parseDouble(dealer['do_amt']);
    final balance = opening + dues;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Dealer Details - $name'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Code', code),
              _buildDetailRow('Name', name),
              _buildDetailRow('Contact Person', person),
              _buildDetailRow('Contact Number', contact),
              _buildDetailRow('Opening Balance', '৳ ${NumberFormat('#,##0.00').format(opening)}'),
              _buildDetailRow('Outstanding Dues', '৳ ${NumberFormat('#,##0.00').format(dues)}'),
              _buildDetailRow('Net Balance', '৳ ${NumberFormat('#,##0.00').format(balance)}'),
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
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
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
            _buildLabel('Dealer Code *'),
            _buildTextField(_codeController, 'Dealer Code'),
            const SizedBox(height: 16),
            _buildLabel('Dealer Name *'),
            _buildTextField(_nameController, 'Dealer Name'),
            const SizedBox(height: 16),
            _buildLabel('Contact Person *'),
            _buildTextField(_personController, 'Contact Person'),
            const SizedBox(height: 16),
            _buildLabel('Contact Number *'),
            _buildTextField(_contactController, 'Contact Number', isNumber: true),
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
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _editingDealer != null ? Colors.orange : const Color(0xFF0066CC),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(height: 15, width: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_editingDealer != null ? 'Update' : 'Submit'),
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
                    _clearForm();
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

  Widget _buildTextField(TextEditingController controller, String hint, {bool isNumber = false, bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontSize: 12),
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

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        debugPrint('Error parsing double from string: $value, error: $e');
        return 0.0;
      }
    }
    return 0.0;
  }
}

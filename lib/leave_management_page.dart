import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:math';
import 'session_manager.dart';

class LeaveManagementPage extends StatefulWidget {
  const LeaveManagementPage({super.key});

  @override
  State<LeaveManagementPage> createState() => _LeaveManagementPageState();
}

class _LeaveManagementPageState extends State<LeaveManagementPage> {
  bool _showForm = false;
  bool _isLoadingList = true;
  bool _isEditMode = false;
  Map<String, dynamic>? _editingLeave;
  List<dynamic> _leaveList = [];

  // Form State
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedLeaveTypeId;
  String? _selectedLeaveTypeName;

  final List<String> _leaveTypes = [];
  Map<int, String> _leaveTypeMap = {}; // id -> name mapping

  int _currentPage = 1;
  int _itemsPerPage = 10;
  int _totalItems = 0;

  // For employee dropdown
  List<dynamic> _employees = [];
  bool _isLoadingEmployees = false;
  int? _selectedEmployeeId;

  @override
  void initState() {
    super.initState();
    _fetchLeaveList();
    _fetchEmployees();
    _fetchLeaveSettings();
  }

  Future<void> _fetchLeaveList() async {
    setState(() => _isLoadingList = true);
    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;
      final token = await SessionManager.getToken();

      debugPrint('Fetching leave list with orgId: $orgId');

      final response = await http.get(
        Uri.parse('https://bs-org.com/index.php/api/LeaveApplication/getLeaveList?orgID=$orgId'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Leave list response status: ${response.statusCode}');
      debugPrint('Leave list response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> fetchedList = [];

        if (data is Map && data['data'] != null) {
          fetchedList = List.from(data['data']);
        } else if (data is List) {
          fetchedList = data;
        }

        setState(() {
          _leaveList = fetchedList;
          _totalItems = fetchedList.length;
          _currentPage = 1;
          _isLoadingList = false;
        });
      } else {
        setState(() => _isLoadingList = false);
      }
    } catch (e) {
      debugPrint('Error fetching leave list: $e');
      setState(() => _isLoadingList = false);
    }
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoadingEmployees = true);
    try {
      final session = await SessionManager.getSession();
      final orgId = session['orgId'] ?? 106;
      final token = await SessionManager.getToken();

      debugPrint('Fetching employees with orgId: $orgId');

      final response = await http.get(
        Uri.parse('https://bs-org.com/index.php/api/LeaveApplication/getEmployeeList?orgID=$orgId'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Employees response status: ${response.statusCode}');
      debugPrint('Employees response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['status'] == true) {
          List<dynamic> fetchedList = [];
          if (data['data'] != null) {
            fetchedList = List.from(data['data']);
          }

          setState(() {
            _employees = fetchedList;
            _isLoadingEmployees = false;
          });
        } else {
          setState(() => _isLoadingEmployees = false);
        }
      } else {
        setState(() => _isLoadingEmployees = false);
      }
    } catch (e) {
      debugPrint('Error fetching employees: $e');
      setState(() => _isLoadingEmployees = false);
    }
  }

  Future<void> _fetchLeaveSettings() async {
    try {
      final session = await SessionManager.getSession();
      final token = await SessionManager.getToken();

      debugPrint('Fetching leave settings');

      final response = await http.get(
        Uri.parse('https://bs-org.com/index.php/api/LeaveApplication/getLeaveSettings'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Leave settings response status: ${response.statusCode}');
      debugPrint('Leave settings response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data['status'] == true) {
          List<dynamic> settings = [];
          if (data['data'] != null) {
            settings = List.from(data['data']);
          }

          setState(() {
            // Update leave types from settings
            _leaveTypes.clear();
            _leaveTypeMap.clear();
            for (var setting in settings) {
              final id = setting['id'];
              final name = setting['name'] ?? 'Unknown';
              if (id != null) {
                if (id is int) {
                  _leaveTypeMap[id] = name;
                  _leaveTypes.add(name);
                } else if (id is String) {
                  final idInt = int.tryParse(id);
                  if (idInt != null) {
                    _leaveTypeMap[idInt] = name;
                    _leaveTypes.add(name);
                  } else {
                    // fallback: use string as key (not recommended but for flexibility)
                  }
                }
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching leave settings: $e');
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          _startDateController.text = DateFormat('yyyy-MM-dd').format(picked);
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
            _endDateController.clear();
          }
        } else {
          _endDate = picked;
          _endDateController.text = DateFormat('yyyy-MM-dd').format(picked);
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedEmployeeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an employee')),
        );
        return;
      }
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select start and end dates')),
        );
        return;
      }
      if (_selectedLeaveTypeId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select leave type')),
        );
        return;
      }

      setState(() => _isLoadingList = true);

      try {
        final session = await SessionManager.getSession();
        final token = await SessionManager.getToken();
        final orgId = session['orgId'] ?? 106;
        final userId = session['userId'];

        final userIdStr = userId?.toString() ?? '';
        final formData = {
          'orgID': orgId.toString(),
          'employee_id': _selectedEmployeeId!.toString(),
          'from_date': _startDateController.text.trim(),
          'to_date': _endDateController.text.trim(),
          'absent_type': _selectedLeaveTypeId?.toString() ?? '',
          'comments': _reasonController.text.trim(),
          'user_id': userIdStr,
        };
        final url = _isEditMode
            ? 'https://bs-org.com/index.php/api/LeaveApplication/update?orgID=$orgId'
            : 'https://bs-org.com/index.php/api/LeaveApplication/insert?orgID=$orgId';

        if (_isEditMode && _editingLeave != null) {
          formData['id'] = _editingLeave!['id'].toString();
        }

        debugPrint('Submitting leave application to: $url');
        debugPrint('Form data: ${json.encode(formData)}');

        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: json.encode(formData),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['status'] == true) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(data['message'] ?? (_isEditMode ? 'Leave updated successfully!' : 'Leave applied successfully!'))),
            );
            _toggleForm(false);
            _fetchLeaveList();
          } else {
            debugPrint('API Error Response: ${response.body}');
            throw Exception(data['message'] ?? 'Failed to save leave');
          }
        } else {
          debugPrint('HTTP ${response.statusCode} Response: ${response.body}');
          throw Exception('HTTP error: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        setState(() => _isLoadingList = false);
      }
    }
  }

  Future<void> _deleteLeave(int leaveId) async {
    try {
      final session = await SessionManager.getSession();
      final token = await SessionManager.getToken();
      final orgId = session['orgId'] ?? 106;

      final response = await http.post(
        Uri.parse('https://bs-org.com/index.php/api/LeaveApplication/delete'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: {
          'leaveID': leaveId.toString(),
          'orgID': orgId.toString(),
        },
      );

      debugPrint('Delete leave response status: ${response.statusCode}');
      debugPrint('Delete leave response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leave deleted successfully!')),
          );
          _fetchLeaveList();
        } else {
          throw Exception(data['message'] ?? 'Failed to delete leave');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error deleting leave: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting leave: ${e.toString()}')),
      );
    }
  }

  void _toggleForm(bool show, {bool isEdit = false, Map<String, dynamic>? leave}) {
    setState(() {
      _showForm = show;
      _isEditMode = isEdit;
      _editingLeave = isEdit ? leave : null;
    });

    if (show && isEdit && leave != null) {
      _populateFormForEdit(leave);
    } else if (show) {
      _clearForm();
    }
  }

  void _populateFormForEdit(Map<String, dynamic> leave) {
    // Set employee
    final employeeId = leave['employee_id']?.toString() ?? leave['employee_id']?.toString() ?? '';
    if (employeeId.isNotEmpty) {
      _selectedEmployeeId = int.tryParse(employeeId);
    }

    // Set leave type - the API returns absent_type as ID
    final leaveTypeId = leave['absent_type']?.toString() ?? '';
    if (leaveTypeId.isNotEmpty) {
      _selectedLeaveTypeId = int.tryParse(leaveTypeId);
      _selectedLeaveTypeName = _selectedLeaveTypeId != null && _leaveTypeMap.containsKey(_selectedLeaveTypeId)
          ? _leaveTypeMap[_selectedLeaveTypeId!]
          : null;
    }

    _reasonController.text = (leave['comments'] ?? leave['reason'] ?? leave['content'] ?? '').toString();

    final startDateStr = leave['from_date']?.toString() ?? '';
    final endDateStr = leave['to_date']?.toString() ?? '';

    if (startDateStr.isNotEmpty) {
      try {
        _startDate = DateFormat('yyyy-MM-dd').parse(startDateStr);
        _startDateController.text = DateFormat('yyyy-MM-dd').format(_startDate!);
      } catch (e) {
        _startDateController.text = startDateStr;
      }
    }

    if (endDateStr.isNotEmpty) {
      try {
        _endDate = DateFormat('yyyy-MM-dd').parse(endDateStr);
        _endDateController.text = DateFormat('yyyy-MM-dd').format(_endDate!);
      } catch (e) {
        _endDateController.text = endDateStr;
      }
    }
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    setState(() {
      _isEditMode = false;
      _editingLeave = null;
      _selectedEmployeeId = null;
      _selectedLeaveTypeId = null;
      _selectedLeaveTypeName = null;
      _startDate = null;
      _endDate = null;
      _reasonController.clear();
      _startDateController.clear();
      _endDateController.clear();
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
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
              const Icon(Icons.table_chart, size: 20, color: Color(0xFF666666)),
              const SizedBox(width: 8),
              Text(
                _showForm ? 'Leave Form' : 'Leave Request',
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
            'Leave List (',
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
                _isEditMode ? 'Edit Leave' : 'New Leave',
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

    final currentPageData = _getCurrentPageData();
    if (_leaveList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: const Center(
          child: Text('No data available', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 12,
            headingRowHeight: 40,
            dataRowMinHeight: 36,
            dataRowMaxHeight: 36,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F5F5)),
            border: const TableBorder(
              verticalInside: BorderSide(color: Color(0xFFDDDDDD), width: 1),
              horizontalInside: BorderSide(color: Color(0xFFDDDDDD), width: 1),
            ),
            columns: const [
              DataColumn(label: Text('SL #', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Employee Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('From Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('To Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Count Days', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Absent Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
            rows: [
              ...currentPageData.asMap().entries.map((entry) {
                final globalIndex = (_currentPage - 1) * _itemsPerPage + entry.key + 1;
                return _buildDataRow(globalIndex, entry.value);
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildPaginationControls(),
      ],
    );
  }

  DataRow _buildDataRow(int index, Map<String, dynamic> leave) {
    final fromDate = leave['from_date']?.toString() ?? '';
    final toDate = leave['to_date']?.toString() ?? '';
    String daysCount = '-';
    if (fromDate.isNotEmpty && toDate.isNotEmpty) {
      try {
        final start = DateFormat('yyyy-MM-dd').parse(fromDate);
        final end = DateFormat('yyyy-MM-dd').parse(toDate);
        final diff = end.difference(start).inDays + 1;
        daysCount = '$diff Day${diff > 1 ? 's' : ''}';
      } catch (e) {
        daysCount = '-';
      }
    }

    final status = leave['status']?.toString() ?? '0';
    Color statusColor;
    String statusText;
    if (status == '0') {
      statusText = 'Pending';
      statusColor = Colors.red;
    } else if (status == '1') {
      statusText = 'Approved';
      statusColor = Colors.green;
    } else if (status == '2') {
      statusText = 'Rejected';
      statusColor = Colors.red;
    } else {
      statusText = '-';
      statusColor = Colors.grey;
    }

    final leaveId = leave['id']?.toString() ?? '';
    final isEditable = status == '0' || status.toLowerCase() == 'pending';

    return DataRow(
      color: WidgetStateProperty.resolveWith<Color?>(
        (Set<WidgetState> states) {
          return index.isEven ? Colors.white : const Color(0xFFFAFAFA);
        },
      ),
      cells: [
        DataCell(Text(index.toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        DataCell(Text(leave['employee_name']?.toString() ?? '-', style: const TextStyle(fontSize: 12))),
        DataCell(Text(fromDate, style: const TextStyle(fontSize: 12))),
        DataCell(Text(toDate, style: const TextStyle(fontSize: 12))),
        DataCell(Text(daysCount, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12))),
        DataCell(Text(leave['absent_type_name']?.toString() ?? '-', style: const TextStyle(fontSize: 12))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(
              statusText,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
            ),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(Icons.search, const Color(0xFF5BC0DE), () => _viewLeaveDetails(leave)),
              const SizedBox(width: 4),
              if (isEditable)
                _buildActionButton(Icons.edit, const Color(0xFFF0AD4E), () => _toggleForm(true, isEdit: true, leave: leave)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed, {bool isVisible = true}) {
    if (!isVisible) return const SizedBox.shrink();
    final widget = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Icon(icon, size: 12, color: Colors.white),
    );
    return InkWell(onTap: onPressed, child: widget);
  }


  Future<void> _viewLeaveDetails(Map<String, dynamic> leave) async {
    final startDate = leave['from_date'] ?? leave['startDate'] ?? '-';
    final endDate = leave['to_date'] ?? leave['endDate'] ?? '-';
    final employeeName = (leave['employee_name'] ?? 'Unknown').toString();
    final leaveType = (leave['absent_type_name'] ?? '-').toString();
    final reason = (leave['comments'] ?? leave['reason'] ?? '-').toString();
    final status = leave['status']?.toString() ?? '0';
    String statusText = 'Pending';
    Color statusColor = Colors.orange;
    if (status == '1') {
      statusText = 'Approved';
      statusColor = Colors.green;
    } else if (status == '2') {
      statusText = 'Rejected';
      statusColor = Colors.red;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Leave Details - ${leave['id'] ?? ''}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Employee', employeeName.toString()),
              _buildDetailRow('Leave Type', leaveType.toString()),
              _buildDetailRow('From Date', startDate.toString()),
              _buildDetailRow('To Date', endDate.toString()),
              _buildDetailRow('Status', statusText, valueColor: statusColor),
              const SizedBox(height: 10),
              const Text('Reason/Comments:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(reason.toString(), style: const TextStyle(color: Colors.grey)),
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

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveLeave(int leaveId) async {
    try {
      final session = await SessionManager.getSession();
      final token = await SessionManager.getToken();
      final orgId = session['orgId'] ?? 106;

      // Using the approve endpoint from HTML (GET request)
      final response = await http.get(
        Uri.parse('https://bs-org.com/index.php/api/LeaveApplication/approveLeaveStatusById/$leaveId?orgID=$orgId'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Approve leave response status: ${response.statusCode}');
      debugPrint('Approve leave response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leave approved successfully')),
          );
          _fetchLeaveList();
        } else {
          throw Exception(data['message'] ?? 'Failed to approve leave');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error approving leave: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving leave: ${e.toString()}')),
      );
    }
  }

  Future<void> _declineLeave(int leaveId) async {
    try {
      final session = await SessionManager.getSession();
      final token = await SessionManager.getToken();
      final orgId = session['orgId'] ?? 106;

      // Using the decline endpoint from HTML (GET request)
      final response = await http.get(
        Uri.parse('https://bs-org.com/index.php/api/LeaveApplication/declineLeaveStatusById/$leaveId?orgID=$orgId'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('Decline leave response status: ${response.statusCode}');
      debugPrint('Decline leave response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Leave declined successfully')),
          );
          _fetchLeaveList();
        } else {
          throw Exception(data['message'] ?? 'Failed to decline leave');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error declining leave: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error declining leave: ${e.toString()}')),
      );
    }
  }

  Future<bool?> _showDeleteConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this leave application?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
            _buildLabel('Employee Name *'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCCCCCC)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedEmployeeId,
                  isExpanded: true,
                  hint: const Text('Select Employee', style: TextStyle(color: Colors.grey)),
                  items: _employees
                      .where((emp) {
                        final id = emp['id']?.toString() ?? emp['employee_id']?.toString() ?? '';
                        return id.isNotEmpty && int.tryParse(id) != null;
                      })
                      .map((emp) {
                        final id = int.parse(emp['id']?.toString() ?? emp['employee_id']?.toString() ?? '0');
                        final name = (emp['employee_name'] ?? emp['name'] ?? 'Unknown').toString();
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(name),
                        );
                      }).toList(),
                  onChanged: (val) => setState(() => _selectedEmployeeId = val),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLabel('From Date *'),
            _buildDateField(_startDateController, () => _selectDate(context, true)),
            const SizedBox(height: 16),
            _buildLabel('To Date *'),
            _buildDateField(_endDateController, () => _selectDate(context, false)),
            const SizedBox(height: 16),
            _buildLabel('Leave Type *'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFCCCCCC)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedLeaveTypeId,
                  isExpanded: true,
                  hint: const Text('Select Leave Type', style: TextStyle(color: Colors.grey)),
                  items: _leaveTypeMap.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedLeaveTypeId = val;
                      _selectedLeaveTypeName = _leaveTypeMap[val!];
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildLabel('Note'),
            TextFormField(
              controller: _reasonController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter note if any',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => _toggleForm(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black87,
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E4560),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_isEditMode ? 'Update' : 'Submit'),
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

  Widget _buildDateField(TextEditingController controller, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AbsorbPointer(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCCCCCC)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: TextField(
            controller: controller,
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

  List<dynamic> _getCurrentPageData() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _leaveList.length) {
      return [];
    }
    return _leaveList.sublist(startIndex, endIndex > _leaveList.length ? _leaveList.length : endIndex);
  }

  int get _totalPages => (_totalItems / _itemsPerPage).ceil();

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
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'session_manager.dart';
import 'attendance_details_page.dart';

class EmployeeHistoryPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EmployeeHistoryPage({super.key, required this.userData});

  @override
  State<EmployeeHistoryPage> createState() => _EmployeeHistoryPageState();
}

class _EmployeeHistoryPageState extends State<EmployeeHistoryPage> {
  int? _employeeId;
  bool _isLoading = false;
  String? _errorMessage;

  // Data containers
  Map<String, dynamic>? _employeeInfo;
  List<dynamic> _attendanceHistory = [];
  List<dynamic> _leaveApplications = [];
  List<dynamic> _expenseHistory = [];
  List<dynamic> _incomeHistory = [];

  // For expense and income date filtering
  DateTime? _expenseStartDate;
  DateTime? _expenseEndDate;
  DateTime? _incomeStartDate;
  DateTime? _incomeEndDate;

  @override
  void initState() {
    super.initState();
    _initializeEmployeeId();
  }

  void _initializeEmployeeId() {
    dynamic employeeId = widget.userData['employee_id'];
    if (employeeId == null || employeeId.toString().isEmpty) {
      employeeId = widget.userData['id'];
    }

    if (employeeId != null) {
      if (employeeId is int) {
        _employeeId = employeeId;
      } else {
        _employeeId = int.tryParse(employeeId.toString());
      }
    }

    debugPrint('EmployeeHistoryPage: Using employeeId = $_employeeId');
    debugPrint('EmployeeHistoryPage: userData = ${widget.userData}');

    if (_employeeId == null) {
      setState(() {
        _errorMessage = 'Employee ID not found in session';
      });
    } else {
      _fetchAllEmployeeData();
    }
  }

  Future<void> _fetchAllEmployeeData() async {
    if (_employeeId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    debugPrint('Fetching all employee data for employeeId: $_employeeId');

    try {
      // Fetch all data in parallel
      await Future.wait([
        _fetchEmployeeInfo(),
        _fetchAttendanceHistory(),
        _fetchLeaveApplications(),
        _fetchExpenseHistory(),
        _fetchIncomeHistory(),
      ]);
    } catch (e) {
      debugPrint('Error in _fetchAllEmployeeData: $e');
      setState(() {
        _errorMessage = 'Error loading data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchEmployeeInfo() async {
    try {
      final token = await SessionManager.getToken();
      final response = await http.get(
        Uri.parse('https://www.bs-org.com/index.php/api/Employee/${_employeeId!}'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          setState(() {
            // API might return employee data in either "data" or "employee" key
            _employeeInfo = data['data'] ?? data['employee'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching employee info: $e');
    }
  }

  // For attendance filtering by month/year
  int _selectedAttendanceMonth = DateTime.now().month;
  int _selectedAttendanceYear = DateTime.now().year;

  Future<void> _fetchAttendanceHistory() async {
    try {
      final token = await SessionManager.getToken();
      final orgId = await SessionManager.getOrgId();

      final uri = Uri.parse(
        'https://www.bs-org.com/index.php/api/Attendance/history/${_employeeId!}',
      ).replace(queryParameters: {
        'month': _selectedAttendanceMonth.toString(),
        'year': _selectedAttendanceYear.toString(),
        if (orgId != null) 'org_id': orgId.toString(),
      });

      debugPrint('Attendance API URL: $uri');
      debugPrint('Token present: ${token != null}');

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('Attendance API response: ${response.body}');
        if (data['status'] == true) {
          setState(() {
            // API returns attendance data in "attendance" key, not "data"
            final attendance = data['attendance'] ?? data['data'] ?? [];
            debugPrint('Parsed attendance count: ${attendance.length}');
            _attendanceHistory = attendance;
          });
        } else {
          debugPrint('Attendance API status false: ${data['message']}');
        }
      } else {
        debugPrint('Attendance API error status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching attendance history: $e');
    }
  }

  Future<void> _fetchLeaveApplications() async {
    try {
      final token = await SessionManager.getToken();
      final orgId = await SessionManager.getOrgId();

      // Try common leave API patterns
      final response = await http.get(
        Uri.parse('https://www.bs-org.com/index.php/api/LeaveApplication?employee_id=$_employeeId&org_id=$orgId'),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          setState(() {
            _leaveApplications = data['data'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching leave applications: $e');
      // This endpoint might not exist, that's okay
    }
  }

  Future<void> _fetchExpenseHistory() async {
    try {
      final token = await SessionManager.getToken();
      final orgId = await SessionManager.getOrgId();

      // NOTE: Expense API is org-wide, not employee-specific.
      // We'll fetch all expenses and filter by createBy employee ID locally if possible
      final uri = Uri.parse(
        'https://www.bs-org.com/index.php/api/Expense/list',
      ).replace(queryParameters: {
        'orgID': orgId.toString(),
        if (_expenseStartDate != null) 'start_date': DateFormat('yyyy-MM-dd').format(_expenseStartDate!),
        if (_expenseEndDate != null) 'end_date': DateFormat('yyyy-MM-dd').format(_expenseEndDate!),
      });

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          List<dynamic> allExpenses = data['data'] ?? [];
          // Filter by current employee if createBy field exists
          final filtered = allExpenses.where((exp) {
            final createBy = exp['createBy']?.toString();
            return createBy == _employeeId.toString();
          }).toList();
          setState(() {
            _expenseHistory = filtered;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching expense history: $e');
    }
  }

  Future<void> _fetchIncomeHistory() async {
    try {
      final token = await SessionManager.getToken();
      final orgId = await SessionManager.getOrgId();

      // Income API is typically org-wide, not employee-specific
      final uri = Uri.parse(
        'https://www.bs-org.com/index.php/api/Income/list',
      ).replace(queryParameters: {
        'orgID': orgId.toString(),
        if (_incomeStartDate != null) 'start_date': DateFormat('yyyy-MM-dd').format(_incomeStartDate!),
        if (_incomeEndDate != null) 'end_date': DateFormat('yyyy-MM-dd').format(_incomeEndDate!),
      });

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == true) {
          List<dynamic> allIncome = data['data'] ?? [];
          // Filter by current employee if createBy field exists
          final filtered = allIncome.where((inc) {
            final createBy = inc['createBy']?.toString();
            return createBy == _employeeId.toString();
          }).toList();
          setState(() {
            _incomeHistory = filtered;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching income history: $e');
    }
  }

  Future<void> _refreshData() async {
    await _fetchAllEmployeeData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8E8E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3A3A3A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _employeeInfo != null
              ? 'Employee History - ${_employeeInfo!['employee_name'] ?? _employeeInfo!['name'] ?? 'Employee'}'
              : 'Employee History',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildContent(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.grey[600], size: 64),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _refreshData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const TabBar(
            labelColor: Color(0xFF2E4560),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFF2E4560),
            tabs: [
              Tab(text: 'Profile'),
              Tab(text: 'Attendance'),
              Tab(text: 'History'),
              Tab(text: 'Expenses'),
              Tab(text: 'Income'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildProfileTab(),
                _buildAttendanceTab(),
                _buildHistoryTab(),
                _buildExpensesTab(),
                _buildIncomeTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab() {
    if (_employeeInfo == null) {
      return const Center(child: Text('No profile information available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFF2E4560),
                      child: Text(
                        (_employeeInfo!['employee_name']?[0] ?? _employeeInfo!['name']?[0] ?? 'E').toUpperCase(),
                        style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _employeeInfo!['employee_name'] ?? _employeeInfo!['name'] ?? 'Unknown',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _employeeInfo!['designation_name'] ?? _employeeInfo!['designation'] ?? 'Employee',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              const Divider(height: 32),

              // Employee Details
              _buildDetailRow('Employee ID', _employeeInfo!['employee_id']?.toString() ?? _employeeInfo!['id']?.toString() ?? 'N/A'),
              _buildDetailRow('Department', _employeeInfo!['department_name'] ?? _employeeInfo!['department'] ?? 'N/A'),
              _buildDetailRow('Joining Date', _employeeInfo!['joining_date'] ?? _employeeInfo!['created_at'] ?? 'N/A'),
              _buildDetailRow('Email', _employeeInfo!['email'] ?? _employeeInfo!['email_address'] ?? 'N/A'),
              _buildDetailRow('Phone', _employeeInfo!['phone'] ?? _employeeInfo!['mobile'] ?? 'N/A'),
              _buildDetailRow('Organization', widget.userData['org_name'] ?? 'N/A'),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Additional Info Section
              const Text(
                'Additional Information',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Status', _employeeInfo!['status']?.toString() ?? 'Active'),
              _buildDetailRow('Created By', _employeeInfo!['created_by_name'] ?? 'N/A'),
              if (_employeeInfo!['created_at'] != null)
                _buildDetailRow('Created At', _formatDate(_employeeInfo!['created_at'])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceTab() {
    final List<String> months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return Column(
      children: [
        // Filter Card with Month/Year selection
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedAttendanceMonth,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: List.generate(12, (index) {
                      final month = index + 1;
                      return DropdownMenuItem(
                        value: month,
                        child: Text(months[index]),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedAttendanceMonth = value;
                        });
                        _fetchAttendanceHistory();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedAttendanceYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      isDense: true,
                    ),
                    items: List.generate(10, (index) {
                      final year = DateTime.now().year - 5 + index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedAttendanceYear = value;
                        });
                        _fetchAttendanceHistory();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // Summary Card
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total Days', _attendanceHistory.length.toString()),
                _buildStatItem('Present', _countPresentDays().toString()),
                _buildStatItem('Absent', _countAbsentDays().toString()),
                _buildStatItem('Late', _countLateDays().toString()),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Full History Button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceDetailsPage(userData: widget.userData),
                  ),
                );
              },
              icon: const Icon(Icons.list, size: 18),
              label: const Text('View Full Attendance Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E4560),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Recent Attendance List
        Expanded(
          child: _attendanceHistory.isEmpty
              ? const Center(child: Text('No attendance records found for selected month'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _attendanceHistory.length,
                  itemBuilder: (context, index) {
                    final record = _attendanceHistory[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.calendar_today, color: Color(0xFF2E4560)),
                        title: Text(record['create_date'] ?? record['date'] ?? 'Unknown date'),
                        subtitle: Text('In: ${record['time_in'] ?? '--:--'} | Out: ${record['time_out'] ?? '--:--'}'),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getAttendanceStatusColor(record)?.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getAttendanceStatusText(record),
                            style: TextStyle(
                              color: _getAttendanceStatusColor(record),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Comprehensive History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            'This section will show all historical data including\nattendance trends, performance metrics, and more.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab() {
    return Column(
      children: [
        // Summary Card
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Count', _expenseHistory.length.toString()),
                _buildStatItem('Total', _formatCurrency(_expenseHistory.fold<double>(0, (sum, item) {
                  final amount = double.tryParse(item['expenseAmount']?.toString() ?? item['amount']?.toString() ?? '0') ?? 0;
                  return sum + amount;
                }))),
              ],
            ),
          ),
        ),
        // Date Filter
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _expenseStartDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() {
                          _expenseStartDate = date;
                        });
                        await _fetchExpenseHistory();
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'From',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                        _expenseStartDate != null
                            ? DateFormat('yyyy-MM-dd').format(_expenseStartDate!)
                            : 'Start date',
                        style: TextStyle(
                          color: _expenseStartDate != null ? Colors.black : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _expenseEndDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() {
                          _expenseEndDate = date;
                        });
                        await _fetchExpenseHistory();
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'To',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                        _expenseEndDate != null
                            ? DateFormat('yyyy-MM-dd').format(_expenseEndDate!)
                            : 'End date',
                        style: TextStyle(
                          color: _expenseEndDate != null ? Colors.black : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchExpenseHistory,
            child: _expenseHistory.isEmpty
                ? const Center(child: Text('No expense records found for this employee'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _expenseHistory.length,
                    itemBuilder: (context, index) {
                      final record = _expenseHistory[index];
                      final amount = record['expenseAmount'] ?? record['amount'] ?? '0';
                      final title = record['eHead'] ?? record['expense_title'] ?? record['title'] ?? 'Expense';
                      final date = record['date'] ?? 'N/A';
                      final comments = record['comments'] ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.money_off, color: Colors.red),
                          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            _formatDateOnly(date),
                            maxLines: 1,
                          ),
                          trailing: Text(
                            '৳ $amount',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncomeTab() {
    return Column(
      children: [
        // Summary Card
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Count', _incomeHistory.length.toString()),
                _buildStatItem('Total', _formatCurrency(_incomeHistory.fold<double>(0, (sum, item) {
                  final amount = double.tryParse(item['amount']?.toString() ?? '0') ?? 0;
                  return sum + amount;
                }))),
              ],
            ),
          ),
        ),
        // Date Filter
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _incomeStartDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() {
                          _incomeStartDate = date;
                        });
                        await _fetchIncomeHistory();
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'From',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                        _incomeStartDate != null
                            ? DateFormat('yyyy-MM-dd').format(_incomeStartDate!)
                            : 'Start date',
                        style: TextStyle(
                          color: _incomeStartDate != null ? Colors.black : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _incomeEndDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() {
                          _incomeEndDate = date;
                        });
                        await _fetchIncomeHistory();
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'To',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      child: Text(
                        _incomeEndDate != null
                            ? DateFormat('yyyy-MM-dd').format(_incomeEndDate!)
                            : 'End date',
                        style: TextStyle(
                          color: _incomeEndDate != null ? Colors.black : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchIncomeHistory,
            child: _incomeHistory.isEmpty
                ? const Center(child: Text('No income records found for this employee'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _incomeHistory.length,
                    itemBuilder: (context, index) {
                      final record = _incomeHistory[index];
                      final amount = record['amount'] ?? '0';
                      final title = record['income_title'] ?? record['title'] ?? 'Income';
                      final date = record['date'] ?? record['income_date'] ?? 'N/A';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.attach_money, color: Colors.green),
                          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            _formatDateOnly(date),
                            maxLines: 1,
                          ),
                          trailing: Text(
                            '৳ $amount',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2E4560)),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  int _countPresentDays() {
    return _attendanceHistory.where((record) {
      final status = record['status']?.toString().toLowerCase() ?? '';
      return status == 'present' || (record['time_in'] != null && record['time_out'] != null);
    }).length;
  }

  int _countAbsentDays() {
    return _attendanceHistory.where((record) {
      final status = record['status']?.toString().toLowerCase() ?? '';
      return status == 'absent' || (record['time_in'] == null && record['time_out'] == null);
    }).length;
  }

  int _countLateDays() {
    return _attendanceHistory.where((record) {
      final status = record['status']?.toString().toLowerCase() ?? '';
      return status == 'late';
    }).length;
  }

  Color? _getAttendanceStatusColor(dynamic record) {
    final status = record['status']?.toString().toLowerCase() ?? '';
    switch (status) {
      case 'present': return Colors.green;
      case 'late': return Colors.orange;
      case 'absent': return Colors.red;
      default: return Colors.grey;
    }
  }

  String _getAttendanceStatusText(dynamic record) {
    final status = record['status']?.toString() ?? '';
    if (status.isNotEmpty) return status;

    // Determine status from time fields
    final timeIn = record['time_in'];
    final timeOut = record['time_out'];
    if (timeIn == null || timeOut == null) return 'Absent';
    return 'Present';
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final parsed = DateTime.parse(date.toString());
      return DateFormat('yyyy-MM-dd HH:mm').format(parsed);
    } catch (e) {
      return date.toString();
    }
  }

  String _formatDateOnly(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final parsed = DateTime.parse(date.toString());
      return DateFormat('yyyy-MM-dd').format(parsed);
    } catch (e) {
      return date.toString();
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '৳ ', decimalDigits: 2).format(amount);
  }
}

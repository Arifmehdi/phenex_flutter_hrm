import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'session_manager.dart';

class AttendanceDetailsPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const AttendanceDetailsPage({super.key, required this.userData});

  @override
  State<AttendanceDetailsPage> createState() => _AttendanceDetailsPageState();
}

class _AttendanceDetailsPageState extends State<AttendanceDetailsPage> {
  int? _employeeId;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _isLoading = false;
  List<dynamic> _attendanceData = [];
  Map<String, dynamic>? _employeeInfo;
  String? _errorMessage;

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

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
    // Convert to int if it's a string or number
    if (employeeId != null) {
      if (employeeId is int) {
        _employeeId = employeeId;
      } else {
        _employeeId = int.tryParse(employeeId.toString());
      }
    }

    if (_employeeId == null) {
      _errorMessage = 'Employee ID not found or invalid';
    } else {
      _fetchEmployeeInfo();
      _fetchAttendanceDetails();
    }
  }

  Future<void> _fetchEmployeeInfo() async {
    if (_employeeId == null) return;
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
            _employeeInfo = data['data'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching employee info: $e');
    }
  }

  Future<void> _fetchAttendanceDetails() async {
    if (_employeeId == null) {
      setState(() {
        _errorMessage = 'Employee ID not found';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await SessionManager.getToken();
      final orgId = await SessionManager.getOrgId();

      debugPrint('AttendanceDetailsPage: employeeId = $_employeeId');
      debugPrint('AttendanceDetailsPage: month = $_selectedMonth, year = $_selectedYear');
      debugPrint('AttendanceDetailsPage: orgId = $orgId');

      // API endpoint from attendance_details.txt: https://bs-org.com/index.php/api/attendance/history/192
      // We'll pass month and year as query parameters
      final uri = Uri.parse(
        'https://www.bs-org.com/index.php/api/Attendance/history/${_employeeId!}',
      ).replace(queryParameters: {
        'month': _selectedMonth.toString(),
        'year': _selectedYear.toString(),
        if (orgId != null) 'org_id': orgId.toString(),
      });

      debugPrint('AttendanceDetailsPage: API URL = $uri');

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
          throw const FormatException('Server returned HTML instead of JSON');
        }

        final data = json.decode(body);
        debugPrint('AttendanceDetailsPage: API response: ${response.body}');
        if (data['status'] == true) {
          setState(() {
            // API returns data in "attendance" key, not "data"
            _attendanceData = data['attendance'] ?? data['data'] ?? [];
            debugPrint('AttendanceDetailsPage: Parsed ${_attendanceData.length} records');
            // Log each record's date
            for (var record in _attendanceData) {
              debugPrint('  Record: date=${record['create_date'] ?? record['date']}, time_in=${record['time_in']}, time_out=${record['time_out']}, punch_count=${record['punch_count']}');
            }
          });
        } else {
          setState(() {
            _errorMessage = data['message'] ?? 'No attendance data found';
            _attendanceData = [];
          });
          debugPrint('AttendanceDetailsPage: API error: ${data['message']}');
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to load attendance data (status: ${response.statusCode})';
        });
        debugPrint('AttendanceDetailsPage: HTTP error ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
      debugPrint('Error fetching attendance details: $e');
    }
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
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          _employeeInfo != null
              ? 'Attendance - ${_employeeInfo!['employee_name'] ?? _employeeInfo!['name']}'
              : 'Attendance Details',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchAttendanceDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
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
                    ],
                  ),
                )
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          _buildFilterCard(),
          const SizedBox(height: 16),
          _buildAttendanceTable(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    debugPrint('Building header with month: ${_selectedMonth}, year: ${_selectedYear}');
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.how_to_reg, color: Color(0xFF2E4560), size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _employeeInfo != null
                        ? _employeeInfo!['employee_name'] ?? _employeeInfo!['name'] ?? 'Employee'
                        : 'Employee Attendance',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Month of ${_months[_selectedMonth - 1]} $_selectedYear',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue),
              ),
              child: Text(
                'Total Records: ${_attendanceData.length}',
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by Month',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedMonth,
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
                        child: Text(_months[index]),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        debugPrint('Month changed to: $value (${_months[value - 1]})');
                        setState(() {
                          _selectedMonth = value;
                        });
                        _fetchAttendanceDetails();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedYear,
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
                        debugPrint('Year changed to: $value');
                        setState(() {
                          _selectedYear = value;
                        });
                        _fetchAttendanceDetails();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceTable() {
    if (_attendanceData.isEmpty) {
      return Card(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          child: Column(
            children: const [
              Icon(Icons.calendar_today, color: Colors.grey, size: 64),
              SizedBox(height: 16),
              Text(
                'No attendance records for this month',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    final startTime = '08:10:00';

    // Generate data for all days of the month (similar to PHP logic)
    List<Map<String, dynamic>> monthlyData = [];
    Duration totalOverTime = Duration.zero;

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_selectedYear, _selectedMonth, day);
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      final dayName = DateFormat('E').format(date);

      // Find attendance record for this day
      final dayRecord = _attendanceData.isNotEmpty
          ? _attendanceData.firstWhere(
              (record) {
                final recordDate = record['create_date'] ?? record['date'] ?? '';
                final matches = recordDate == dateString;
                if (day <= 3 || day >= 28) { // Log first few and last few days
                  debugPrint('Day $day: looking for $dateString, recordDate=$recordDate, matches=$matches');
                }
                return matches;
              },
              orElse: () => <String, dynamic>{},
            )
          : <String, dynamic>{};

      if (dayRecord.isNotEmpty) {
        final timeIn = (dayRecord['time_in'] ?? '').toString();
        final timeOut = (dayRecord['time_out'] ?? '').toString();
        final punchCount = dayRecord['punch_count'];
        final int punchCountInt = punchCount is int ? punchCount : int.tryParse(punchCount.toString()) ?? 0;
        final isHoliday = dayRecord['is_holiday'] ?? false;

        // Calculate overtime
        String overtime = '';
        if (timeIn.isNotEmpty && timeOut.isNotEmpty && punchCountInt > 1 && !isHoliday) {
          try {
            final timeInParse = DateFormat('HH:mm:ss').parse(timeIn);
            final timeOutParse = DateFormat('HH:mm:ss').parse(timeOut);
            final startTimeParse = DateFormat('HH:mm:ss').parse(startTime);

            // Calculate duration
            Duration workDuration = timeOutParse.isBefore(timeInParse)
                ? Duration(seconds: 0)
                : timeOutParse.difference(timeInParse);

            // Calculate late deduction
            Duration lateDeduction = Duration(seconds: 0);
            if (timeInParse.isAfter(startTimeParse) && !isHoliday) {
              lateDeduction = timeInParse.difference(startTimeParse);
            }

            // Net work duration
            Duration netDuration = workDuration - lateDeduction;

            if (timeOutParse.isAfter(timeInParse)) {
              overtime = _formatDuration(netDuration);
              totalOverTime += netDuration;
            }
          } catch (e) {
            overtime = '';
          }
        }

        monthlyData.add({
          'sl': day,
          'date': dateString,
          'day': dayName,
          'time_in': timeIn.isNotEmpty ? _formatTime12Hour(timeIn) : '--:--',
          'time_out': timeOut.isNotEmpty ? _formatTime12Hour(timeOut) : '--:--',
          'overtime': overtime,
          'is_holiday': isHoliday,
        });
      } else {
        // No attendance record for this day
        monthlyData.add({
          'sl': day,
          'date': dateString,
          'day': dayName,
          'time_in': '--:--',
          'time_out': '--:--',
          'overtime': '',
          'is_holiday': false,
        });
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: const MaterialStatePropertyAll(Color(0xFFF5F5F5)),
          columnSpacing: 12,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 60,
          columns: const [
            DataColumn(label: Text('SL#', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Day', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Time-In', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Time-Out', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Over Time', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: [
            ...monthlyData.map((record) {
              final isHoliday = record['is_holiday'] ?? false;
              return DataRow(
                color: MaterialStateProperty.all(
                  isHoliday ? Colors.red.withOpacity(0.1) : null,
                ),
                cells: [
                  DataCell(Text(record['sl'].toString())),
                  DataCell(Text(record['date'])),
                  DataCell(Text(record['day'])),
                  DataCell(Text(record['time_in'])),
                  DataCell(Text(record['time_out'])),
                  DataCell(
                    Text(
                      record['overtime'],
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  DataCell(
                    isHoliday
                        ? const Text(
                            'Holiday',
                            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                          )
                        : IconButton(
                            icon: const Icon(Icons.visibility, color: Colors.blue, size: 18),
                            tooltip: 'View Details',
                            onPressed: () {
                              // TODO: Implement day-wise details if needed
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Day details coming soon')),
                              );
                            },
                          ),
                  ),
                ],
              );
            }),
            DataRow(
              color: const MaterialStatePropertyAll(Color(0xFFE8E8E8)),
              cells: [
                const DataCell(Text('Total', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataCell(Text('')), // Date
                const DataCell(Text('')), // Day
                const DataCell(Text('')), // Time-In
                const DataCell(Text('')), // Time-Out
                DataCell(
                  Text(
                    _formatDuration(totalOverTime),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
                const DataCell(Text('')), // Action
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatTime12Hour(String time24) {
    try {
      final parts = time24.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = parts[1];
        final period = hour >= 12 ? 'PM' : 'AM';
        final hour12 = hour % 12 == 0 ? 12 : hour % 12;
        return '$hour12:$minute $period';
      }
    } catch (e) {
      debugPrint('Error formatting time: $e');
    }
    return time24;
  }
}

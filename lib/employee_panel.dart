import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'login_page.dart';
import 'session_manager.dart';
import 'employee_history_page.dart';
import 'attendance_details_page.dart';

class EmployeePanel extends StatefulWidget {
  final int initialIndex;
  const EmployeePanel({super.key, this.initialIndex = 0});

  @override
  State<EmployeePanel> createState() => _EmployeePanelState();
}

class _EmployeePanelState extends State<EmployeePanel> {
  late int _selectedIndex;

  static final List<Widget> _widgetOptions = <Widget>[
    const AttendanceScreen(),
    const LeaveScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _handleLogout() async {
    try {
      // Call logout API as mentioned in logout.txt
      await http.get(Uri.parse('https://www.bs-org.com/index.php/api/authentication/flutter_logout'));
    } catch (e) {
      // Log error if needed
    } finally {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Panel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2E4560),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Attendance',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.beach_access),
            label: 'Leave',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF2E4560),
        onTap: _onItemTapped,
      ),
    );
  }
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _checkInTime = '--:--';
  String _checkOutTime = '--:--';
  String _workingHours = '00:00';
  DateTime? _checkInDateTime;
  bool _isCheckedIn = false;
  bool _isCheckedOut = false;
  bool _isLoading = false;
  late Timer _timer;
  DateTime _currentTime = DateTime.now();
  List<dynamic> _recentAttendance = [];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
    _loadTodayStatus();
    _loadRecentAttendance();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _loadTodayStatus() async {
    final orgId = await SessionManager.getOrgId();
    final userData = await SessionManager.getUserData();

    if (orgId == null || userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please login again.')),
      );
      return;
    }

    var employeeId = userData['employee_id'];
    if (employeeId == null || employeeId.toString().isEmpty) {
      employeeId = userData['id'];
    }

    if (employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Employee ID not found.')),
      );
      return;
    }

    try {
      final token = await SessionManager.getToken();

      final response = await http.get(
        Uri.parse(
          'https://www.bs-org.com/index.php/api/Attendance/todayStatus?employee_id=$employeeId&orgID=$orgId',
        ),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final body = response.body.trim();
        if (body.startsWith('<!DOCTYPE') || body.startsWith('<html')) {
          throw const FormatException('Server returned HTML instead of JSON');
        }

        final data = json.decode(body);
        if (data['status'] == true) {
          setState(() {
            _isCheckedIn = data['checked_in'] ?? false;
            _isCheckedOut = data['checked_out'] ?? false;

            if (data['data'] != null) {
              final attendanceData = data['data'];
              final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
              if (attendanceData['time_in'] != null && attendanceData['time_in'] != '') {
                _checkInTime = _formatTime(attendanceData['time_in']);
                try {
                  _checkInDateTime = DateTime.parse('$today ${attendanceData['time_in']}');
                } catch (e) {
                  debugPrint('Error parsing check-in time: $e');
                }
              }
              if (attendanceData['time_out'] != null && attendanceData['time_out'] != '') {
                _checkOutTime = _formatTime(attendanceData['time_out']);
                if (_checkInDateTime != null) {
                  try {
                    final checkOutDateTime = DateTime.parse('$today ${attendanceData['time_out']}');
                    final duration = checkOutDateTime.difference(_checkInDateTime!);
                    final hours = duration.inHours.toString().padLeft(2, '0');
                    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
                    _workingHours = '$hours:$minutes';
                  } catch (e) {
                    debugPrint('Error parsing check-out time: $e');
                  }
                }
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading attendance status: $e');
    }
  }

  String _formatTime(String timeString) {
    try {
      if (timeString.isEmpty) return '--:--';
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final time = DateFormat('HH:mm').parse('${parts[0]}:${parts[1]}');
        return DateFormat('hh:mm a').format(time);
      }
      return timeString;
    } catch (e) {
      return timeString;
    }
  }

  Future<void> _loadRecentAttendance() async {
    debugPrint('_loadRecentAttendance: START');
    final orgId = await SessionManager.getOrgId();
    final userData = await SessionManager.getUserData();

    debugPrint('_loadRecentAttendance: orgId=$orgId');
    debugPrint('_loadRecentAttendance: userData keys: ${userData?.keys}');
    debugPrint('_loadRecentAttendance: userData employee_id=${userData?['employee_id']}');
    debugPrint('_loadRecentAttendance: userData id=${userData?['id']}');

    if (orgId == null || userData == null) {
      debugPrint('_loadRecentAttendance: session expired, aborting');
      return;
    }

    var employeeId = userData['employee_id'];
    if (employeeId == null || employeeId.toString().isEmpty) {
      employeeId = userData['id'];
    }

    debugPrint('_loadRecentAttendance: Using employeeId=$employeeId');

    if (employeeId == null) {
      debugPrint('_loadRecentAttendance: employee ID not found, aborting');
      return;
    }

    try {
      final token = await SessionManager.getToken();
      debugPrint('_loadRecentAttendance: Token present=${token != null}');

      // Get last 7 days (or current month data)
      // We'll fetch current month attendance like the details page
      final now = DateTime.now();
      final uri = Uri.parse(
        'https://www.bs-org.com/index.php/api/Attendance/history/$employeeId',
      ).replace(queryParameters: {
        'month': now.month.toString(),
        'year': now.year.toString(),
        if (orgId != null) 'org_id': orgId.toString(),
      });

      debugPrint('_loadRecentAttendance: API URL = $uri');

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      debugPrint('_loadRecentAttendance: HTTP status = ${response.statusCode}');
      debugPrint('_loadRecentAttendance: Response body = ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('_loadRecentAttendance: Decoded JSON status: ${data['status']}');
        if (data['status'] == true) {
          final allRecords = data['attendance'] ?? data['data'] ?? [];
          debugPrint('_loadRecentAttendance: Total records in API response: ${allRecords.length}');

          // Log first few records to see structure
          if (allRecords.isNotEmpty) {
            debugPrint('_loadRecentAttendance: First record: ${allRecords.first}');
          }

          // Get last 7 days with records (limit to 7)
          final recent = allRecords.take(7).toList();
          debugPrint('_loadRecentAttendance: Taking first ${recent.length} records (limit 7)');

          // Calculate status for each record
          final datedRecords = recent.map((record) {
            final timeIn = record['time_in']?.toString() ?? '';
            final timeOut = record['time_out']?.toString() ?? '';
            final punchCount = record['punch_count'];
            final int punchCountInt = punchCount is int ? punchCount : int.tryParse(punchCount.toString()) ?? 0;

            String status;
            if (timeIn.isNotEmpty && timeOut.isNotEmpty) {
              // Calculate work duration
              try {
                final timeInParse = DateFormat('HH:mm:ss').parse(timeIn);
                final timeOutParse = DateFormat('HH:mm:ss').parse(timeOut);
                Duration workDuration = timeOutParse.isBefore(timeInParse) ? Duration.zero : timeOutParse.difference(timeInParse);
                final hours = workDuration.inHours;
                status = hours >= 8 ? 'Present' : 'Late';
                debugPrint('_loadRecentAttendance: Record date=${record['create_date']}, timeIn=$timeIn, timeOut=$timeOut, hours=$hours, status=$status');
              } catch (e) {
                debugPrint('_loadRecentAttendance: Error calculating duration: $e');
                status = 'Present'; // fallback
              }
            } else {
              status = 'Absent';
              debugPrint('_loadRecentAttendance: Record date=${record['create_date']} is Absent (timeIn=$timeIn, timeOut=$timeOut)');
            }

            return {
              ...record,
              'status': status,
            };
          }).toList();

          setState(() {
            _recentAttendance = datedRecords;
          });
          debugPrint('_loadRecentAttendance: _recentAttendance now has ${_recentAttendance.length} records');
        } else {
          debugPrint('_loadRecentAttendance: API returned status=false');
        }
      } else {
        debugPrint('_loadRecentAttendance: HTTP error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('_loadRecentAttendance: EXCEPTION: $e');
    }
    debugPrint('_loadRecentAttendance: END');
  }

  Future<void> _takeCheckInPicture() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );

      if (photo != null) {
        final now = DateTime.now();
        setState(() {
          _checkInDateTime = now;
          _checkInTime = DateFormat('hh:mm a').format(now);
          _isCheckedIn = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in successful!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking picture: $e')),
      );
    }
  }

  Future<void> _takeCheckOutPicture() async {
    if (!_isCheckedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please check in first!')),
      );
      return;
    }

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
      );

      if (photo != null) {
        final now = DateTime.now();
        final duration = now.difference(_checkInDateTime!);
        final hours = duration.inHours.toString().padLeft(2, '0');
        final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');

        setState(() {
          _checkOutTime = DateFormat('hh:mm a').format(now);
          _workingHours = '$hours:$minutes';
          _isCheckedOut = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-out successful!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking picture: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTodayStatusCard(),
          const SizedBox(height: 20),
          const Text(
            'Attendance History',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
          ),
          const SizedBox(height: 10),
          _buildAttendanceList(),
        ],
      ),
    );
  }

  Widget _buildTodayStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              DateFormat('MMMM dd, yyyy').format(_currentTime),
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              DateFormat('hh:mm:ss a').format(_currentTime),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2E4560)),
            ),
            const Text('Current Time'),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  Icons.login,
                  'Check In',
                  Colors.green,
                  _isCheckedIn ? null : _takeCheckInPicture,
                ),
                _buildActionButton(
                  Icons.logout,
                  'Check Out',
                  Colors.orange,
                  (!_isCheckedIn || _isCheckedOut) ? null : _takeCheckOutPicture,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTimeInfo('Check In', _checkInTime),
                _buildTimeInfo('Check Out', _checkOutTime),
                _buildTimeInfo('Working Hr', _workingHours),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback? onPressed) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: onPressed == null ? Colors.grey : color,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: onPressed == null ? Colors.grey : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeInfo(String label, String time) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }

  Widget _buildAttendanceList() {
    debugPrint('_buildAttendanceList: _recentAttendance.length = ${_recentAttendance.length}');
    if (_recentAttendance.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No recent attendance records', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentAttendance.length,
      itemBuilder: (context, index) {
        final record = _recentAttendance[index];
        final date = record['create_date'] ?? record['date'] ?? 'N/A';
        final timeIn = record['time_in'] ?? '';
        final timeOut = record['time_out'] ?? '';
        final status = record['status'] ?? 'Absent';

        // Format time for display
        String formattedTimeIn = timeIn.isNotEmpty ? _formatTime(timeIn) : '--:--';
        String formattedTimeOut = timeOut.isNotEmpty ? _formatTime(timeOut) : '--:--';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: const Icon(Icons.calendar_today, color: Color(0xFF2E4560)),
            title: Text(
              date,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(
              'In: $formattedTimeIn | Out: $formattedTimeOut',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status?.toString().toLowerCase() ?? '') {
      case 'present': return Colors.green;
      case 'late': return Colors.orange;
      case 'absent': return Colors.red;
      default: return Colors.grey;
    }
  }
}

class LeaveScreen extends StatelessWidget {
  const LeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Leave Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
          ),
          const SizedBox(height: 12),
          _buildLeaveSummaryCards(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Leave Requests',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text('Apply', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E4560),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildLeaveRequestList(),
        ],
      ),
    );
  }

  Widget _buildLeaveSummaryCards() {
    return Row(
      children: [
        _buildSummaryCard('Total', '20', Colors.blue),
        const SizedBox(width: 10),
        _buildSummaryCard('Taken', '05', Colors.green),
        const SizedBox(width: 10),
        _buildSummaryCard('Balance', '15', Colors.orange),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveRequestList() {
    final requests = [
      {'type': 'Sick Leave', 'date': 'Mar 10 - Mar 12', 'days': '3', 'status': 'Pending'},
      {'type': 'Casual Leave', 'date': 'Feb 15 - Feb 15', 'days': '1', 'status': 'Approved'},
      {'type': 'Casual Leave', 'date': 'Jan 20 - Jan 21', 'days': '2', 'status': 'Rejected'},
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final req = requests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(req['type']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${req['date']} (${req['days']} days)'),
            trailing: _buildStatusBadge(req['status']!),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Approved': color = Colors.green; break;
      case 'Pending': color = Colors.orange; break;
      case 'Rejected': color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userData = await SessionManager.getUserData();
      debugPrint('ProfileScreen: Loaded userData from session: $userData');
      debugPrint('ProfileScreen: employee_id from session: ${userData?['employee_id']}');
      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('ProfileScreen: Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_userData == null) {
      return const Center(child: Text('Unable to load profile data'));
    }

    final employeeName = _userData!['employee_name'] ?? _userData!['name'] ?? 'Unknown';
    final employeeId = _userData!['employee_id']?.toString() ?? _userData!['id']?.toString() ?? 'N/A';
    final email = _userData!['email'] ?? _userData!['email_address'] ?? 'N/A';
    final phone = _userData!['phone'] ?? _userData!['mobile'] ?? _userData!['phone_number'] ?? 'N/A';
    final designation = _userData!['designation_name'] ?? _userData!['designation'] ?? 'Employee';
    final department = _userData!['department_name'] ?? _userData!['department'] ?? 'N/A';
    final joiningDate = _userData!['joining_date'] ?? _userData!['created_at'] ?? 'N/A';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12'),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: CircleAvatar(
                    backgroundColor: Color(0xFF2E4560),
                    radius: 18,
                    child: Icon(Icons.camera_alt, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            employeeName,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            designation,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 30),
          _buildProfileInfoItem(Icons.badge, 'Employee ID', employeeId),
          _buildProfileInfoItem(Icons.email, 'Email', email),
          _buildProfileInfoItem(Icons.phone, 'Phone', phone),
          _buildProfileInfoItem(Icons.business, 'Department', department),
          _buildProfileInfoItem(Icons.calendar_month, 'Joining Date', joiningDate),
          const SizedBox(height: 20),

          // View Full History Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmployeeHistoryPage(userData: _userData!),
                  ),
                );
              },
              icon: const Icon(Icons.history, size: 20),
              label: const Text('View Full History'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E4560),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                // Navigate to detailed attendance page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AttendanceDetailsPage(userData: _userData!),
                  ),
                );
              },
              icon: const Icon(Icons.list, size: 20),
              label: const Text('View Attendance Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF2E4560), size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }
}

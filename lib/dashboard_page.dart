import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'login_page.dart';
import 'session_manager.dart';
import 'employee_list_page.dart';
import 'finance_table_page.dart';
import 'accounts_payable_page.dart';

class DashboardPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final List<dynamic> menuData;

  const DashboardPage({
    super.key,
    required this.userData,
    required this.menuData,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? _selectedLink;
  bool _sidebarOpen = true;

  @override
  void initState() {
    super.initState();
    // Default dashboard based on login credentials
    final phone = widget.userData['phone']?.toString();
    final name = widget.userData['name']?.toString().toLowerCase();
    final orgName = widget.userData['org_name']?.toString().toLowerCase();

    if (phone == '01717956334') {
      _selectedLink = 'hrm/employeeDashboard';
    } else if (name == 'icon2' || orgName == 'icon2' || phone == 'icon2') {
      _selectedLink = 'classicDashboard';
    } else if (widget.menuData.isNotEmpty) {
      _selectedLink = widget.menuData.first['link'];
    }
  }

  void _onMenuSelected(String? link) {
    if (link != null && link != '#') {
      setState(() {
        _selectedLink = link;
      });
    }
  }

  Future<void> _handleLogout() async {
    try {
      await SessionManager.clearSession();
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
      backgroundColor: const Color(0xFF2B2B2B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3A3A3A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            setState(() {
              _sidebarOpen = !_sidebarOpen;
            });
          },
        ),
        title: const Text(
          'BS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: [
          _buildUserArea(),
        ],
      ),
      body: Container(
        color: const Color(0xFFE8E8E8),
        child: Stack(
          children: [
            // Main content
            Column(
              children: [
                if (_selectedLink != 'accounts/payable' && _selectedLink != 'accounts/receivable' && _selectedLink != 'hrm/employeeList')
                  const DashHeader(),
                Expanded(
                  child: _buildMainContent(),
                ),
              ],
            ),
            // Overlay menu
            if (_sidebarOpen)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _sidebarOpen = false;
                  });
                },
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            if (_sidebarOpen)
              SidebarWidget(
                menuData: widget.menuData,
                onMenuSelected: (link) {
                  _onMenuSelected(link);
                  setState(() {
                    _sidebarOpen = false;
                  });
                },
                selectedLink: _selectedLink,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_selectedLink == 'hrm/employeeDashboard' || 
        _selectedLink == 'cms/dashboard' || 
        _selectedLink == 'dashboard/pharmaDashboard') {
       return EmployeeDashboard(
         isSidebarOpen: false,
         onLinkSelected: _onMenuSelected,
       );
    } else if (_selectedLink == 'hrm/employeeAttendance') {
       return const AttendanceScreen();
    } else if (_selectedLink == 'hrm/leaveApplication') {
       return const LeaveApplicationPage();
    } else if (_selectedLink == 'hrm/employeeList') {
       return const EmployeeListPage();
    } else if (_selectedLink == 'classicDashboard') {
       return ClassicDashboard(
         isSidebarOpen: false,
         onLinkSelected: _onMenuSelected,
       );
    } else if (_selectedLink == 'accounts/payable') {
      return const AccountsPayablePage();
    } else if (_selectedLink == 'accounts/receivable') {
      return const FinanceTablePage(title: 'Receivable');
    }
    
    // Default to classic if nothing else matches but we have a selection
    if (_selectedLink != null) {
      return ClassicDashboard(
        isSidebarOpen: false,
        onLinkSelected: _onMenuSelected,
      );
    }
    
    return const Center(
      child: Text('Please select a module from the menu'),
    );
  }

  Widget _buildUserArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 15,
            backgroundImage: NetworkImage('https://i.pravatar.cc/30?img=12'),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.userData['name'] ?? 'User'} ▾',
            style: const TextStyle(color: Color(0xFFDDDDDD), fontSize: 14),
          ),
          const SizedBox(width: 18),
          const Icon(Icons.settings, color: Colors.grey, size: 18),
          const SizedBox(width: 18),
          const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 18),
          const SizedBox(width: 18),
          const Icon(Icons.search, color: Colors.grey, size: 18),
          const SizedBox(width: 18),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.exit_to_app, color: Colors.grey, size: 18),
            onPressed: _handleLogout,
          ),
        ],
      ),
    );
  }
}

class SidebarWidget extends StatefulWidget {
  final List<dynamic> menuData;
  final Function(String?) onMenuSelected;
  final String? selectedLink;

  const SidebarWidget({
    super.key, 
    required this.menuData,
    required this.onMenuSelected,
    this.selectedLink,
  });

  @override
  State<SidebarWidget> createState() => _SidebarWidgetState();
}

class _SidebarWidgetState extends State<SidebarWidget> {
  DateTime _currentDate = DateTime.now();

  final List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  void _previousMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + 1);
    });
  }

  int _daysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  int _firstWeekdayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1).weekday % 7;
  }

  List<MegaMenuItem> _buildMenuItems(List<dynamic> data, int level) {
    return data.map((item) {
      final children = item['children'] as List<dynamic>? ?? [];
      String? link = item['link'];
      String name = item['name'] ?? '';
      
      // Fallback links for Payable/Receivable
      if (link == null || link == '#') {
        if (name.toLowerCase().contains('payable')) {
          link = 'accounts/payable';
        } else if (name.toLowerCase().contains('receivable')) {
          link = 'accounts/receivable';
        }
      }

      return MegaMenuItem(
        label: name,
        link: link,
        level: level,
        active: widget.selectedLink == link,
        onTap: () => widget.onMenuSelected(link),
        children: _buildMenuItems(children, level + 1),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: const Color(0xFF3A3A3A),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ..._buildMenuItems(widget.menuData, 0),
          const Divider(color: Color(0xFF555555), height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCalendar(),
          ),
          const SizedBox(height: 20),
          const Center(child: Text('§', style: TextStyle(color: Color(0xFF777777), fontSize: 18))),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    int days = _daysInMonth(_currentDate);
    int startWeekday = _firstWeekdayOfMonth(_currentDate);
    DateTime today = DateTime.now();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: _previousMonth,
              child: const Icon(Icons.arrow_left, color: Colors.grey, size: 18),
            ),
            Text(
              '${_months[_currentDate.month - 1]} ${_currentDate.year}',
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            InkWell(
              onTap: _nextMonth,
              child: const Icon(Icons.arrow_right, color: Colors.grey, size: 18),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            ...['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map((d) => Center(child: Text(d, style: const TextStyle(color: Colors.grey, fontSize: 11)))),
            ...List.generate(startWeekday, (index) => const SizedBox.shrink()),
            ...List.generate(days, (index) {
              int day = index + 1;
              bool isToday = day == today.day && _currentDate.month == today.month && _currentDate.year == today.year;
              return Center(
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isToday ? Colors.red : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: TextStyle(color: isToday ? Colors.white : Colors.grey, fontSize: 12),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ],
    );
  }
}

class MegaMenuItem extends StatefulWidget {
  final String label;
  final String? link;
  final int? badge;
  final bool active;
  final List<MegaMenuItem> children;
  final int level;
  final VoidCallback onTap;

  const MegaMenuItem({
    super.key,
    required this.label,
    required this.onTap,
    this.link,
    this.badge,
    this.active = false,
    this.children = const [],
    this.level = 0,
  });

  @override
  State<MegaMenuItem> createState() => _MegaMenuItemState();
}

class _MegaMenuItemState extends State<MegaMenuItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    bool hasChildren = widget.children.isNotEmpty;

    return Column(
      children: [
        InkWell(
          onTap: () {
            if (hasChildren) {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            } else {
              if (widget.label.toLowerCase().contains('employee list') || 
                  widget.link == 'hrm/employeeList') {
                widget.onTap();
              } else {
                widget.onTap();
              }
            }
          },
          child: Container(
            padding: EdgeInsets.only(
              left: 16.0 + (widget.level * 12.0),
              right: 16.0,
              top: 10,
              bottom: 10,
            ),
            decoration: BoxDecoration(
              color: widget.active ? const Color(0xFF4A4A4A) : Colors.transparent,
              border: Border(
                left: BorderSide(
                  color: (widget.active && widget.level == 0) ? Colors.red : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        _getIconForLabel(widget.label),
                        size: 14,
                        color: widget.level == 0 ? const Color(0xFF8BCFEA) : Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.label,
                          style: TextStyle(
                            color: widget.level == 0 ? const Color(0xFF8BCFEA) : Colors.white70,
                            fontSize: widget.level == 0 ? 13 : 12,
                            fontWeight: widget.level == 0 ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    if (widget.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF555555),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.badge.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    if (hasChildren)
                      Icon(
                        _isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                        color: widget.level == 0 ? const Color(0xFF8BCFEA) : Colors.white70,
                        size: 14,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded && hasChildren)
          ...widget.children,
      ],
    );
  }

  IconData _getIconForLabel(String label) {
    label = label.toLowerCase();
    if (label.contains('dashboard')) return Icons.dashboard;
    if (label.contains('sale')) return Icons.shopping_cart;
    if (label.contains('inventory')) return Icons.inventory;
    if (label.contains('account')) return Icons.account_balance_wallet;
    if (label.contains('payable')) return Icons.receipt_long;
    if (label.contains('receivable')) return Icons.call_received;
    if (label.contains('report')) return Icons.assessment;
    if (label.contains('setting')) return Icons.settings;
    if (label.contains('employee')) return Icons.people;
    if (label.contains('attendance')) return Icons.how_to_reg;
    if (label.contains('leave')) return Icons.exit_to_app;
    return Icons.circle;
  }
}

class DashHeader extends StatelessWidget {
  const DashHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: const [
              Icon(Icons.home, size: 16, color: Colors.black87),
              SizedBox(width: 8),
              Text('Dashboard', style: TextStyle(color: Color(0xFF333333), fontSize: 16)),
            ],
          ),
          Row(
            children: const [
              Icon(Icons.menu, size: 16, color: Colors.grey),
              SizedBox(width: 12),
              Icon(Icons.refresh, size: 16, color: Colors.grey),
              SizedBox(width: 12),
              Icon(Icons.settings, size: 16, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }
}

class EmployeeDashboard extends StatelessWidget {
  final bool isSidebarOpen;
  final Function(String) onLinkSelected;

  const EmployeeDashboard({
    super.key, 
    required this.isSidebarOpen,
    required this.onLinkSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopNavIcons(),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),
          _buildDashboardGrid(),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          _buildReportSection(),
        ],
      ),
    );
  }

  Widget _buildTopNavIcons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTopNavItem(Icons.qr_code, 'Attendance', '0', () => onLinkSelected('hrm/employeeAttendance')),
        const SizedBox(width: 30),
        _buildTopNavItem(Icons.qr_code, 'Leave', '0', () => onLinkSelected('hrm/leaveApplication')),
        const SizedBox(width: 30),
        _buildTopNavItem(Icons.qr_code, 'Absent', '0', () {}),
      ],
    );
  }

  Widget _buildTopNavItem(IconData icon, String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 32, color: const Color(0xFF2E4560)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDashboardGrid() {
    final List<Map<String, dynamic>> items = [
      {'title': 'Payment || Year-2026', 'val': '0', 'amt': '', 'color': const Color(0xFFe8f0fe), 'btn': 'btn-blue', 'btnText': '✔ New Voucher', 'link': 'accounts/payable'},
      {'title': 'Receive || Year-2026', 'val': '8', 'amt': '৳ : 179855.00', 'color': const Color(0xFFd9f5df), 'btn': 'btn-green', 'btnText': '✔ New Voucher', 'link': 'accounts/receivable'},
      {'title': 'Journal || Year-2026', 'val': '0', 'amt': '', 'color': const Color(0xFFf8d7da), 'btn': 'btn-red', 'btnText': '✔ New Voucher'},
      {'title': 'Contra || Year-2026', 'val': '0', 'amt': '', 'color': const Color(0xFFd1ecf1), 'btn': 'btn-cyan', 'btnText': '✔ New Voucher'},
      {'title': 'Approve MRR || Year-2026', 'val': '0', 'amt': '', 'color': const Color(0xFFffe5c3), 'btn': 'btn-orange', 'btnText': '✔ View Approval'},
      {'title': 'Approve Chalan || Year-2026', 'val': '11', 'amt': '৳ : 325918.40', 'color': const Color(0xFFcfe9ea), 'btn': 'btn-cyan', 'btnText': '✔ View Approval'},
      {'title': 'Purchase Return || Year-2026', 'val': '0', 'amt': '', 'color': const Color(0xFFddd6f7), 'btn': 'btn-purple', 'btnText': '✔ View Approval'},
      {'title': 'Sales Return || Year-2026', 'val': '0', 'amt': '', 'color': const Color(0xFFf2d5f7), 'btn': 'btn-pink', 'btnText': '✔ View Approval'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isSidebarOpen ? 1 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: isSidebarOpen ? 1.5 : 1.3,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: () {
            if (item['link'] != null) {
              onLinkSelected(item['link']);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              border: Border.all(color: const Color(0xFFDDDDDD)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['title'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const Spacer(),
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: item['color'],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(item['val'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item['amt'],
                        style: TextStyle(
                          fontSize: 11, 
                          fontWeight: FontWeight.bold,
                          color: item['amt'].contains('179') || item['amt'].contains('325') ? Colors.green : Colors.black
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                SizedBox(
                  height: 24,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (item['link'] != null) {
                        onLinkSelected(item['link']);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getBtnColor(item['btn']),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
                    ),
                    child: Text(item['btnText'], style: const TextStyle(color: Colors.white, fontSize: 10)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getBtnColor(String type) {
    switch (type) {
      case 'btn-blue': return const Color(0xFF0d6efd);
      case 'btn-green': return const Color(0xFF198754);
      case 'btn-red': return const Color(0xFFdc3545);
      case 'btn-cyan': return const Color(0xFF0dcaf0);
      case 'btn-orange': return const Color(0xFFfd7e14);
      case 'btn-purple': return const Color(0xFF5B32A4);
      case 'btn-pink': return const Color(0xFFA820AD);
      default: return Colors.grey;
    }
  }

  Widget _buildReportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildReportCard('Top 5 Advance Reports', [
          {'name': 'Transaction Statement Report', 'color': const Color(0xFFDDDDDD), 'link': 'open-green'},
          {'name': 'Trial Balance', 'color': const Color(0xFFFFD8A8), 'link': 'open-red'},
          {'name': 'Party Balance', 'color': const Color(0xFFC3F0CA), 'link': 'open-green'},
        ]),
        const SizedBox(height: 15),
        _buildReportCard('Top 5 Financial Reports', [
          {'name': 'Comparative Financial Statements', 'color': const Color(0xFFDDDDDD), 'link': 'open-green'},
          {'name': 'Comparative Income Statement', 'color': const Color(0xFFFFD8A8), 'link': 'open-red'},
          {'name': 'Statement of Profit or Loss & Other Income', 'color': const Color(0xFFC3F0CA), 'link': 'open-green'},
        ]),
      ],
    );
  }

  Widget _buildReportCard(String title, List<Map<String, dynamic>> items) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        border: Border.all(color: const Color(0xFFDDDDDD)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: item['color'], shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(item['name'], style: const TextStyle(fontSize: 11))),
                Text(
                  item['link'] == 'open-green' ? '⬆ Open' : '⬇ Open',
                  style: TextStyle(
                    fontSize: 11, 
                    fontWeight: FontWeight.bold,
                    color: item['link'] == 'open-green' ? Colors.green : Colors.red
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class ClassicDashboard extends StatelessWidget {
  final bool isSidebarOpen;
  final Function(String) onLinkSelected;

  const ClassicDashboard({
    super.key, 
    required this.isSidebarOpen,
    required this.onLinkSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildStatCards(),
          const SizedBox(height: 20),
          const Text('⬤ ⬤ ⬤', style: TextStyle(color: Colors.grey, fontSize: 18)),
          const SizedBox(height: 20),
          _buildTablesRow(),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    final List<Widget> cards = [
      StatCard(
        icon: Icons.how_to_reg,
        label: 'Attendance',
        value: '0',
        color: Colors.blue,
        onTap: () => onLinkSelected('hrm/employeeAttendance'),
      ),
      StatCard(
        icon: Icons.directions_walk,
        label: 'Leave',
        value: '0',
        color: Colors.orange,
        onTap: () => onLinkSelected('hrm/leaveApplication'),
      ),
      StatCard(
        icon: Icons.event_busy,
        label: 'Absent',
        value: '0',
        color: Colors.red,
        onTap: () {},
      ),
    ];

    if (isSidebarOpen) {
      return Column(
        children: [
          cards[0],
          const SizedBox(height: 12),
          cards[1],
          const SizedBox(height: 12),
          cards[2],
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(child: cards[0]),
          const SizedBox(width: 12),
          Expanded(child: cards[1]),
          const SizedBox(width: 12),
          Expanded(child: cards[2]),
        ],
      );
    }
  }

  Widget _buildTablesRow() {
    return Column(
      children: const [
        TableCard(title: 'Top most punctual employee'),
        SizedBox(height: 20),
        TableCard(title: 'Top most delayed employee'),
      ],
    );
  }
}

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class TableCard extends StatelessWidget {
  final String title;

  const TableCard({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDDDDDD)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFFAFAFA),
            child: Text(title, style: const TextStyle(color: Color(0xFF333333), fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const Divider(height: 1),
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: const Text('No data available', style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12)),
          ),
        ],
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
  late Timer _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
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
    final history = [
      {'date': 'Mar 01', 'in': '09:05 AM', 'out': '06:10 PM', 'status': 'Present'},
      {'date': 'Feb 28', 'in': '08:55 AM', 'out': '06:05 PM', 'status': 'Present'},
      {'date': 'Feb 27', 'in': '09:15 AM', 'out': '06:20 PM', 'status': 'Late'},
      {'date': 'Feb 26', 'in': '--:--', 'out': '--:--', 'status': 'Absent'},
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: history.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final item = history[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item['date']!, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('In: ${item['in']} | Out: ${item['out']}'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(item['status']!).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              item['status']!,
              style: TextStyle(color: _getStatusColor(item['status']!), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Present': return Colors.green;
      case 'Late': return Colors.orange;
      case 'Absent': return Colors.red;
      default: return Colors.grey;
    }
  }
}

class LeaveApplicationPage extends StatefulWidget {
  const LeaveApplicationPage({super.key});

  @override
  State<LeaveApplicationPage> createState() => _LeaveApplicationPageState();
}

class _LeaveApplicationPageState extends State<LeaveApplicationPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _reasonController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedLeaveType;

  final List<String> _leaveTypes = ['Sick Leave', 'Casual Leave', 'Earned Leave', 'Maternity Leave', 'Paternity Leave'];

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
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _submitApplication() {
    if (_formKey.currentState!.validate()) {
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select start and end dates')),
        );
        return;
      }
      
      // Simulate submission
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Leave application submitted successfully!')),
      );
      
      setState(() {
        _selectedLeaveType = null;
        _startDate = null;
        _endDate = null;
        _reasonController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Apply for Leave',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
          ),
          const SizedBox(height: 20),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedLeaveType,
                      decoration: const InputDecoration(
                        labelText: 'Leave Type *',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                      ),
                      items: _leaveTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                      onChanged: (val) => setState(() => _selectedLeaveType = val),
                      validator: (val) => val == null ? 'Please select a leave type' : null,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, true),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Start Date *',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today, size: 18),
                              ),
                              child: Text(
                                _startDate == null ? 'Select' : DateFormat('yyyy-MM-dd').format(_startDate!),
                                style: TextStyle(color: _startDate == null ? Colors.grey : Colors.black, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectDate(context, false),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'End Date *',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today, size: 18),
                              ),
                              child: Text(
                                _endDate == null ? 'Select' : DateFormat('yyyy-MM-dd').format(_endDate!),
                                style: TextStyle(color: _endDate == null ? Colors.grey : Colors.black, fontSize: 13),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _reasonController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Reason for Leave *',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Please provide a reason' : null,
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitApplication,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E4560),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Submit Application', style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Recent Leave Status',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF333333)),
          ),
          const SizedBox(height: 15),
          _buildLeaveStatusList(),
        ],
      ),
    );
  }

  Widget _buildLeaveStatusList() {
    final history = [
      {'type': 'Sick Leave', 'date': 'Mar 10 - Mar 12', 'status': 'Pending'},
      {'type': 'Casual Leave', 'date': 'Feb 15', 'status': 'Approved'},
      {'type': 'Casual Leave', 'date': 'Jan 20 - Jan 21', 'status': 'Rejected'},
    ];

    return Column(
      children: history.map((item) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          title: Text(item['type']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Text(item['date']!, style: const TextStyle(fontSize: 12)),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(item['status']!).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getStatusColor(item['status']!)),
            ),
            child: Text(
              item['status']!,
              style: TextStyle(color: _getStatusColor(item['status']!), fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
        ),
      )).toList(),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved': return Colors.green;
      case 'Pending': return Colors.orange;
      case 'Rejected': return Colors.red;
      default: return Colors.grey;
    }
  }
}

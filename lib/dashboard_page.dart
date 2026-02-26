import 'package:flutter/material.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isSidebarOpen = false;

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
              _isSidebarOpen = !_isSidebarOpen;
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
      body: Row(
        children: [
          // Sidebar
          if (_isSidebarOpen) const SidebarWidget(),
          // Main Content
          Expanded(
            child: Container(
              color: const Color(0xFFE8E8E8),
              child: Column(
                children: [
                  const DashHeader(),
                  Expanded(
                    child: SingleChildScrollView(
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
          const Text('Sultan Ahmmed ▾', style: TextStyle(color: Color(0xFFDDDDDD), fontSize: 14)),
          const SizedBox(width: 18),
          const Icon(Icons.settings, color: Colors.grey, size: 18),
          const SizedBox(width: 18),
          const Icon(Icons.chat_bubble_outline, color: Colors.grey, size: 18),
          const SizedBox(width: 18),
          const Icon(Icons.search, color: Colors.grey, size: 18),
          const SizedBox(width: 18),
          const Icon(Icons.exit_to_app, color: Colors.grey, size: 18),
        ],
      ),
    );
  }

  Widget _buildStatCards() {
    final List<Widget> cards = [
      const StatCard(
        icon: Icons.how_to_reg,
        label: 'Attendance',
        value: '0',
        color: Colors.blue,
      ),
      const StatCard(
        icon: Icons.directions_walk,
        label: 'Leave',
        value: '0',
        color: Colors.orange,
      ),
      const StatCard(
        icon: Icons.event_busy,
        label: 'Absent',
        value: '0',
        color: Colors.red,
      ),
    ];

    if (_isSidebarOpen) {
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

class SidebarWidget extends StatefulWidget {
  const SidebarWidget({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: const Color(0xFF3A3A3A),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const MegaMenuItem(
            label: 'Dashboard',
            active: true,
            hasArrow: true,
            children: [
              MegaMenuItem(label: 'Overview'),
              MegaMenuItem(label: 'Analytics'),
            ],
          ),
          const MegaMenuItem(
            label: 'Admin',
            badge: 8,
            children: [
              MegaMenuItem(label: 'User Management'),
              MegaMenuItem(
                label: 'Settings',
                children: [
                  MegaMenuItem(label: 'General'),
                  MegaMenuItem(label: 'Security'),
                ],
              ),
            ],
          ),
          const MegaMenuItem(
            label: 'Employee',
            children: [
              MegaMenuItem(label: 'Employee List'),
              MegaMenuItem(label: 'Employee Type'),
              MegaMenuItem(label: 'Attendance'),
              MegaMenuItem(label: 'Leave Application'),
              MegaMenuItem(label: 'Shift Maping'),
              MegaMenuItem(label: 'Employee Loan'),
            ],
          ),
          const MegaMenuItem(
            label: 'Payroll',
            children: [
              MegaMenuItem(label: 'Salary Structure'),
              MegaMenuItem(label: 'Salary Sheet'),
            ],
          ),
          const MegaMenuItem(
            label: 'Leave',
            children: [
              MegaMenuItem(label: 'Leave Settings'),
              MegaMenuItem(label: 'Leave Management'),
            ],
          ),
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
  final int? badge;
  final bool active;
  final bool hasArrow;
  final List<MegaMenuItem> children;
  final int level;

  const MegaMenuItem({
    super.key,
    required this.label,
    this.badge,
    this.active = false,
    this.hasArrow = false,
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
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.level == 0 ? const Color(0xFF8BCFEA) : Colors.white70,
                      fontSize: widget.level == 0 ? 13 : 12,
                      fontWeight: widget.level == 0 ? FontWeight.w600 : FontWeight.normal,
                    ),
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
                      )
                    else if (widget.hasArrow)
                      const Icon(Icons.arrow_right, color: Color(0xFF8BCFEA), size: 14),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_isExpanded && hasChildren)
          ...widget.children.map((child) => MegaMenuItem(
                label: child.label,
                children: child.children,
                level: widget.level + 1,
                active: child.active,
                hasArrow: child.hasArrow,
                badge: child.badge,
              )),
      ],
    );
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

class StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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



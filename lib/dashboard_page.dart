import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2B2B2B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF3A3A3A),
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
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
      drawer: const Drawer(
        backgroundColor: Color(0xFF3A3A3A),
        child: SidebarWidget(),
      ),
      body: Row(
        children: [
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        StatCard(icon: Icons.bar_chart, label: 'Attendance', value: '0'),
        SizedBox(width: 20),
        StatCard(icon: Icons.bar_chart, label: 'Leave', value: '0'),
        SizedBox(width: 20),
        StatCard(icon: Icons.bar_chart, label: 'Absent', value: '0'),
      ],
    );
  }

  Widget _buildTablesRow() {
    return Row(
      children: const [
        Expanded(child: TableCard(title: 'Top most punctual employee')),
        SizedBox(width: 20),
        Expanded(child: TableCard(title: 'Top most delayed employee')),
      ],
    );
  }
}

class SidebarWidget extends StatelessWidget {
  const SidebarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: const Color(0xFF3A3A3A),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _buildMenuItem('Academy', badge: 8),
          _buildMenuItem('Dashboard', active: true, hasArrow: true),
          _buildMenuItem('Admin', badge: 8),
          _buildMenuItem('HRM', badge: 4, hasArrow: true),
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
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Icon(Icons.arrow_left, color: Colors.grey, size: 18),
            Text('February 2026', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            Icon(Icons.arrow_right, color: Colors.grey, size: 18),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            ...['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map((d) => Center(child: Text(d, style: const TextStyle(color: Colors.grey, fontSize: 11)))),
            ...List.generate(28, (index) {
              int day = index + 1;
              bool isToday = day == 26;
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

  Widget _buildMenuItem(String label, {int? badge, bool active = false, bool hasArrow = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF4A4A4A) : Colors.transparent,
        border: Border(left: BorderSide(color: active ? Colors.red : Colors.transparent, width: 3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8BCFEA), fontSize: 13, fontWeight: FontWeight.w600)),
          Row(
            children: [
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFF555555), borderRadius: BorderRadius.circular(10)),
                  child: Text(badge.toString(), style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
              if (hasArrow) ...[
                const SizedBox(width: 4),
                const Icon(Icons.arrow_right, color: Color(0xFF8BCFEA), size: 14),
              ],
            ],
          ),
        ],
      ),
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

  const StatCard({super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDDDDDD)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: const Color(0xFF999999)),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Color(0xFF666666), fontSize: 13)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Color(0xFF333333), fontSize: 18, fontWeight: FontWeight.bold)),
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



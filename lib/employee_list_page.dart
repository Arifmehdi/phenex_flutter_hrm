import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'session_manager.dart';
import 'employee_form_page.dart';

class EmployeeListPage extends StatefulWidget {
  const EmployeeListPage({super.key});

  @override
  State<EmployeeListPage> createState() => _EmployeeListPageState();
}

class _EmployeeListPageState extends State<EmployeeListPage> {
  List<dynamic> _employees = [];
  bool _isLoading = true;
  String _errorMessage = '';

  // Pagination variables
  int _currentPage = 1;
  int _itemsPerPage = 10;
  int _totalItems = 0;

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    final orgId = await SessionManager.getOrgId();
    if (orgId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Organization ID not found. Please login again.';
      });
      return;
    }

    try {
      final response = await http.get(
        Uri.parse(
          'https://www.bs-org.com/index.php/api/authentication/employee_list?orgID=$orgId',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _employees = data['data'] ?? [];
            _totalItems = _employees.length;
            _currentPage = 1; // Reset to first page when new data loads
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = data['message'] ?? 'Failed to load employees';
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Server error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
      });
    }
  }

  void _changePage(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _changeItemsPerPage(int itemsPerPage) {
    setState(() {
      _itemsPerPage = itemsPerPage;
      _currentPage = 1; // Reset to first page when changing items per page
    });
  }

  List<dynamic> _getCurrentPageData() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    if (startIndex >= _employees.length) {
      return [];
    }
    return _employees.sublist(startIndex, endIndex > _employees.length ? _employees.length : endIndex);
  }

  int get _totalPages => (_totalItems / _itemsPerPage).ceil();

  void _viewEmployee(Map<String, dynamic> employee) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Viewing employee: ${employee['employee_name']}')),
    );
  }

  void _editEmployee(Map<String, dynamic> employee) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmployeeFormPage(employeeData: employee),
      ),
    ).then((_) => _fetchEmployees()); // Refresh list after edit
  }

  void _deleteEmployee(Map<String, dynamic> employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete ${employee['employee_name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Deleting employee: ${employee['employee_name']}')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
                  _buildListHeader(),
                  _buildResponsiveTable(context),
                  if (!_isLoading && _errorMessage.isEmpty && _employees.isNotEmpty)
                    _buildPaginationControls(),
                ],
              ),
            ),
          ),
        ),
      ],
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
              const Icon(Icons.people, size: 20, color: Color(0xFF666666)),
              const SizedBox(width: 8),
              const Text(
                'Employee Management',
                style: TextStyle(
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

  Widget _buildListHeader() {
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
              style: const TextStyle(color: Colors.black87, fontSize: 13),
              children: [
                TextSpan(text: 'Employee List ('),
                WidgetSpan(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const EmployeeFormPage()),
                      ).then((_) => _fetchEmployees());
                    },
                    child: const Text(
                      ' + New ',
                      style: TextStyle(
                        color: Color(0xFFBA6D6D),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: ')'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveTable(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          headingRowHeight: 40,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 40,
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F5F5)),
          border: const TableBorder(
            verticalInside: BorderSide(color: Color(0xFFDDDDDD), width: 1),
            horizontalInside: BorderSide(color: Color(0xFFDDDDDD), width: 1),
          ),
          columns: const [
            DataColumn(label: Center(child: Text('SL#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
            DataColumn(label: Center(child: Text('Employee Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
            DataColumn(label: Center(child: Text('Employee Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
            DataColumn(label: Center(child: Text('Phone', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
            DataColumn(label: Center(child: Text('Designation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
            DataColumn(label: Center(child: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
            DataColumn(label: Center(child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
          ],
          rows: _isLoading
              ? [
                  DataRow(cells: [
                    const DataCell(Center(child: CircularProgressIndicator())),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                    const DataCell(Text('')),
                  ])
                ]
              : _errorMessage.isNotEmpty
                  ? [
                      DataRow(cells: [
                        DataCell(Center(child: Text(_errorMessage))),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                        const DataCell(Text('')),
                      ])
                    ]
                  : _employees.isEmpty
                      ? [
                          DataRow(cells: [
                            const DataCell(Center(child: Text('No employees found'))),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                            const DataCell(Text('')),
                          ])
                        ]
                      : List.generate(_getCurrentPageData().length, (index) {
                          final globalIndex = (_currentPage - 1) * _itemsPerPage + index + 1;
                          return _buildDataRow(globalIndex, _getCurrentPageData()[index]);
                        }),
        ),
      ),
    );
  }

  DataRow _buildDataRow(int sl, Map<String, dynamic> employee) {
    return DataRow(
      cells: [
        DataCell(Center(child: Text(sl.toString(), style: const TextStyle(fontSize: 12)))),
        DataCell(Text(employee['employee_name'] ?? 'No Name', style: const TextStyle(fontSize: 12))),
        DataCell(Center(child: Text(employee['employee_code'] ?? 'N/A', style: const TextStyle(fontSize: 12)))),
        DataCell(Center(child: Text(employee['contact'] ?? 'N/A', style: const TextStyle(fontSize: 12)))),
        DataCell(Text(employee['designation_title'] ?? 'N/A', style: const TextStyle(fontSize: 12))),
        DataCell(Text(employee['department_name'] ?? 'N/A', style: const TextStyle(fontSize: 12))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(Icons.visibility, Colors.blue, () => _viewEmployee(employee)),
              const SizedBox(width: 4),
              _buildActionButton(Icons.edit, Colors.orange, () => _editEmployee(employee)),
              const SizedBox(width: 4),
              _buildActionButton(Icons.delete, Colors.red, () => _deleteEmployee(employee)),
            ],
          ),
        ),
      ],
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

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        border: Border(top: BorderSide(color: Color(0xFFDDDDDD))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(width: 8),
                  Text(
                    'entries',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
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

          const SizedBox(height: 8),

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

  List<Widget> _buildPageNumbers() {
    List<Widget> pageWidgets = [];
    int startPage = (_currentPage - 2).clamp(1, _totalPages);
    int endPage = (startPage + 4).clamp(1, _totalPages);

    if (startPage > 1) {
      pageWidgets.add(_buildPageButton(1));
      if (startPage > 2) {
        pageWidgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(fontSize: 12, color: Colors.black87)),
        ));
      }
    }

    for (int i = startPage; i <= endPage; i++) {
      pageWidgets.add(_buildPageButton(i));
    }

    if (endPage < _totalPages) {
      if (endPage < _totalPages - 1) {
        pageWidgets.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(fontSize: 12, color: Colors.black87)),
        ));
      }
      pageWidgets.add(_buildPageButton(_totalPages));
    }

    return pageWidgets;
  }

  Widget _buildPageButton(int page) {
    bool isActive = page == _currentPage;
    return InkWell(
      onTap: () => _changePage(page),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFBA6D6D) : Colors.white,
          border: Border.all(color: const Color(0xFFDDDDDD)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          page.toString(),
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

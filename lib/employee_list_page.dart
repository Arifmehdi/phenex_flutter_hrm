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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee List'),
        backgroundColor: const Color(0xFF3A3A3A),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Employee',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const EmployeeFormPage()),
              ).then((_) => _fetchEmployees()); // Refresh list after add
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
          ? Center(child: Text(_errorMessage))
          : _employees.isEmpty
          ? const Center(child: Text('No employees found'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _employees.length,
              separatorBuilder: (context, index) => const Divider(),
              itemBuilder: (context, index) {
                final employee = _employees[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF2299CC),
                      child: Text(
                        (employee['employee_name'] ?? 'E')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      employee['employee_name'] ?? 'No Name',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Employee Code: ${employee['employee_code'] ?? 'N/A'}',
                        ),
                        Text('Phone: ${employee['contact'] ?? 'N/A'}'),
                        Text(
                          'Designation: ${employee['designation_title'] ?? 'N/A'}',
                        ),
                        Text(
                          'Department: ${employee['department_name'] ?? 'N/A'}',
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.visibility, color: Colors.blue, size: 20),
                          onPressed: () => _viewEmployee(employee),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.edit, color: Colors.green, size: 20),
                          onPressed: () => _editEmployee(employee),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () => _deleteEmployee(employee),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

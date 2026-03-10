import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'session_manager.dart';

class EmployeeFormPage extends StatefulWidget {
  final Map<String, dynamic>? employeeData;

  const EmployeeFormPage({super.key, this.employeeData});

  @override
  State<EmployeeFormPage> createState() => _EmployeeFormPageState();
}

class _EmployeeFormPageState extends State<EmployeeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  File? _image;
  bool _isLoadingDropdowns = true;

  // Controllers
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _fatherNameController = TextEditingController();
  final TextEditingController _motherNameController = TextEditingController();
  final TextEditingController _spouseNameController = TextEditingController();
  final TextEditingController _nationalityController = TextEditingController(text: 'Bangladeshi');
  final TextEditingController _presentAddressController = TextEditingController();
  final TextEditingController _permanentAddressController = TextEditingController();
  final TextEditingController _prevCompanyController = TextEditingController();

  DateTime? _birthDate;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedGender;
  String? _selectedBloodGroup;

  // Dropdown data
  List<dynamic> _departments = [];
  List<dynamic> _designations = [];
  List<dynamic> _sections = [];

  String? _selectedDepartment;
  String? _selectedDesignation;
  String? _selectedSection;

  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _fetchDropdownData();
    if (widget.employeeData != null) {
      _populateFields();
    }
  }

  Future<void> _fetchDropdownData() async {
    final orgId = await SessionManager.getOrgId();
    if (orgId == null) {
      if (mounted) {
        setState(() => _isLoadingDropdowns = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Organization ID not found. Please login again.')),
        );
      }
      return;
    }

    try {
      final results = await Future.wait([
        http.get(Uri.parse('https://www.bs-org.com/index.php/api/authentication/department_list?orgID=$orgId')),
        http.get(Uri.parse('https://www.bs-org.com/index.php/api/authentication/designation_list?orgID=$orgId')),
        http.get(Uri.parse('https://www.bs-org.com/index.php/api/authentication/section_list?orgID=$orgId')),
      ]);

      if (mounted) {
        setState(() {
          final deptData = json.decode(results[0].body);
          final desgData = json.decode(results[1].body);
          final sectData = json.decode(results[2].body);

          _departments = deptData['data'] ?? [];
          _designations = desgData['data'] ?? [];
          _sections = sectData['data'] ?? [];
          
          _isLoadingDropdowns = false;
          
          // If editing, try to match current values
          if (widget.employeeData != null) {
            _selectedDepartment = widget.employeeData!['department_id']?.toString();
            _selectedDesignation = widget.employeeData!['designation_id']?.toString();
            _selectedSection = widget.employeeData!['section_id']?.toString();
          }
        });
      }
    } catch (e) {
      debugPrint('Dropdown Fetch Error: $e');
      if (mounted) {
        setState(() => _isLoadingDropdowns = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load menu data: $e')),
        );
      }
    }
  }

  void _populateFields() {
    final data = widget.employeeData!;
    _codeController.text = data['employee_code'] ?? '';
    _nameController.text = data['employee_name'] ?? '';
    _contactController.text = data['contact'] ?? '';
    _selectedGender = data['employee_gender'];
    _emailController.text = data['email'] ?? '';
    _fatherNameController.text = data['father_name'] ?? '';
    _motherNameController.text = data['mother_name'] ?? '';
    _spouseNameController.text = data['spouse_name'] ?? '';
    _nationalityController.text = data['nationality'] ?? 'Bangladeshi';
    _presentAddressController.text = data['present_address'] ?? '';
    _permanentAddressController.text = data['permanent_address'] ?? '';
    _prevCompanyController.text = data['previous_company'] ?? '';
    _selectedBloodGroup = data['blood_group'];
    
    if (data['birth_date'] != null) _birthDate = DateTime.tryParse(data['birth_date']);
    if (data['start_date'] != null) _startDate = DateTime.tryParse(data['start_date']);
    if (data['end_date'] != null) _endDate = DateTime.tryParse(data['end_date']);
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDate(BuildContext context, String type) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (type == 'birth') _birthDate = picked;
        if (type == 'start') _startDate = picked;
        if (type == 'end') _endDate = picked;
      });
    }
  }

  bool _isSubmitting = false;

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_birthDate == null || _startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select required dates')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final orgId = await SessionManager.getOrgId();
    final userId = await SessionManager.getUserId();

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://www.bs-org.com/index.php/api/employeeInsertApi'),
      );

      // Add text fields
      request.fields['orgID'] = orgId.toString();
      request.fields['userID'] = userId.toString();
      request.fields['employee_name'] = _nameController.text.trim();
      request.fields['employee_code'] = _codeController.text.trim();
      request.fields['department_id'] = _selectedDepartment ?? '';
      request.fields['designation_id'] = _selectedDesignation ?? '';
      request.fields['section_id'] = _selectedSection ?? '';
      request.fields['employee_gender'] = _selectedGender ?? '';
      request.fields['birth_date'] = DateFormat('yyyy-MM-dd').format(_birthDate!);
      request.fields['contact'] = _contactController.text.trim();
      request.fields['email'] = _emailController.text.trim();
      request.fields['fathers_name'] = _fatherNameController.text.trim();
      request.fields['mothers_name'] = _motherNameController.text.trim();
      request.fields['h_w_name'] = _spouseNameController.text.trim();
      request.fields['nationality'] = _nationalityController.text.trim();
      request.fields['blood_group'] = _selectedBloodGroup ?? '';
      request.fields['present_address'] = _presentAddressController.text.trim();
      request.fields['permanent_address'] = _permanentAddressController.text.trim();
      request.fields['start_date'] = DateFormat('yyyy-MM-dd').format(_startDate!);
      if (_endDate != null) {
        request.fields['end_date'] = DateFormat('yyyy-MM-dd').format(_endDate!);
      }
      request.fields['previous_company_name'] = _prevCompanyController.text.trim();

      // Add image if selected
      if (_image != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'image',
          _image!.path,
        ));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['status'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'] ?? 'Employee inserted successfully')),
            );
            Navigator.pop(context, true); // Return true to indicate success
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['message'] ?? 'Failed to insert employee')),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employeeData == null ? 'Add Employee' : 'Edit Employee'),
        backgroundColor: const Color(0xFF3A3A3A),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo Section
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _image != null ? FileImage(_image!) : null,
                        child: _image == null
                            ? const Icon(Icons.camera_alt, size: 40, color: Colors.grey)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Form Fields
                  _buildTextField('Employee Code *', _codeController, isRequired: true),
                  _buildTextField('Employee Name *', _nameController, isRequired: true),
                  
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: const InputDecoration(labelText: 'Gender *', border: OutlineInputBorder()),
                    items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) => setState(() => _selectedGender = val),
                    validator: (val) => val == null ? 'Field required' : null,
                  ),
                  const SizedBox(height: 16),

                  _buildDatePicker('Birth Date *', _birthDate, () => _selectDate(context, 'birth'), isRequired: true),
                  _buildTextField('Employee Contact *', _contactController, isRequired: true, keyboardType: TextInputType.phone),
                  _buildTextField('Employee Email', _emailController, keyboardType: TextInputType.emailAddress),
                  _buildTextField('Father\'s Name', _fatherNameController),
                  _buildTextField('Mother\'s Name', _motherNameController),
                  _buildTextField('Husband/Wife\'s Name', _spouseNameController),
                  _buildTextField('Nationality *', _nationalityController, isRequired: true),

                  DropdownButtonFormField<String>(
                    value: _selectedBloodGroup,
                    decoration: const InputDecoration(labelText: 'Blood Group', border: OutlineInputBorder()),
                    items: _bloodGroups.map((bg) => DropdownMenuItem(value: bg, child: Text(bg))).toList(),
                    onChanged: (val) => setState(() => _selectedBloodGroup = val),
                  ),
                  const SizedBox(height: 16),

                  _buildTextField('Present Address *', _presentAddressController, isRequired: true, maxLines: 2),
                  _buildTextField('Permanent Address', _permanentAddressController, maxLines: 2),
                  
                  if (_isLoadingDropdowns)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else ...[
                    DropdownButtonFormField<String>(
                      value: _selectedDesignation,
                      decoration: const InputDecoration(labelText: 'Designation', border: OutlineInputBorder()),
                      items: _designations.map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text(d['designation_title']))).toList(),
                      onChanged: (val) => setState(() => _selectedDesignation = val),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedDepartment,
                      decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
                      items: _departments.map((d) => DropdownMenuItem(value: d['id'].toString(), child: Text(d['department_name']))).toList(),
                      onChanged: (val) => setState(() => _selectedDepartment = val),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedSection,
                      decoration: const InputDecoration(labelText: 'Section', border: OutlineInputBorder()),
                      items: _sections.map((s) => DropdownMenuItem(value: s['id'].toString(), child: Text(s['section_title']))).toList(),
                      onChanged: (val) => setState(() => _selectedSection = val),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  _buildDatePicker('Start Date *', _startDate, () => _selectDate(context, 'start'), isRequired: true),
                  _buildDatePicker('End Date', _endDate, () => _selectDate(context, 'end')),
                  
                  _buildTextField('Previous Company Name', _prevCompanyController),

                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2299CC),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSubmitting 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('SAVE EMPLOYEE', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool isRequired = false, TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: (value) {
          if (isRequired && (value == null || value.trim().isEmpty)) {
            return 'This field is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? selectedDate, VoidCallback onTap, {bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          child: Text(
            selectedDate == null ? 'Select Date' : DateFormat('yyyy-MM-dd').format(selectedDate),
            style: TextStyle(color: selectedDate == null ? Colors.grey[600] : Colors.black),
          ),
        ),
      ),
    );
  }
}

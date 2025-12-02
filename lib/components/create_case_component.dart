import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/api_services.dart' as api;
import 'package:firebase_auth/firebase_auth.dart';

class CreateCaseComponent extends StatefulWidget {
  const CreateCaseComponent({Key? key}) : super(key: key);

  @override
  State<CreateCaseComponent> createState() => _CreateCaseComponentState();
}

class _CreateCaseComponentState extends State<CreateCaseComponent> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _caseTitleController = TextEditingController();
  final _clientNameController = TextEditingController();
  final _clientEmailController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCaseType = 'Criminal';
  String _selectedPriority = 'Medium Priority';
  bool _isCreating = false;

  late AnimationController _controller;

  // Staggered animations for form fields
  late List<Animation<Offset>> _slideAnimations;
  late List<Animation<double>> _fadeAnimations;

  final List<Map<String, dynamic>> _caseTypes = [
    {'name': 'Criminal', 'icon': Icons.gavel_rounded, 'color': Color(0xFFEF4444)},
    {'name': 'Civil', 'icon': Icons.balance_rounded, 'color': Color(0xFF06B6D4)},
    {'name': 'Corporate', 'icon': Icons.business_rounded, 'color': Color(0xFFF59E0B)},
    {'name': 'Family', 'icon': Icons.family_restroom_rounded, 'color': Color(0xFF10B981)},
    {'name': 'Other', 'icon': Icons.folder_outlined, 'color': Color(0xFF8B5CF6)},
  ];

  final List<Map<String, dynamic>> _priorities = [
    {'name': 'Low Priority', 'color': Color(0xFF10B981), 'icon': Icons.low_priority_rounded},
    {'name': 'Medium Priority', 'color': Color(0xFFF59E0B), 'icon': Icons.remove_rounded},
    {'name': 'High Priority', 'color': Color(0xFFEF4444), 'icon': Icons.priority_high_rounded},
  ];

  @override
  void initState() {
    super.initState();

    // Setup staggered entrance animation
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Create 6 staggered animations for the 6 main sections
    _slideAnimations = List.generate(6, (index) {
      final start = index * 0.1;
      final end = start + 0.4;
      return Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0), curve: Curves.easeOutCubic),
        ),
      );
    });

    _fadeAnimations = List.generate(6, (index) {
      final start = index * 0.1;
      final end = start + 0.4;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0), curve: Curves.easeOut),
        ),
      );
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _caseTitleController.dispose();
    _clientNameController.dispose();
    _clientEmailController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String _convertPriorityToBackend(String displayPriority) {
    switch (displayPriority) {
      case 'Low Priority': return 'low';
      case 'Medium Priority': return 'medium';
      case 'High Priority': return 'high';
      default: return 'medium';
    }
  }

  String _convertCaseTypeToBackend(String caseType) {
    return caseType.toLowerCase();
  }

  Future<void> _createCase() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isCreating = true);

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception('User not authenticated');

        final caseData = {
          'title': _caseTitleController.text.trim(),
          'type': _convertCaseTypeToBackend(_selectedCaseType),
          'priority': _convertPriorityToBackend(_selectedPriority),
          'status': 'active',
          'clientName': _clientNameController.text.trim().isNotEmpty ? _clientNameController.text.trim() : null,
          'clientEmail': _clientEmailController.text.trim().isNotEmpty ? _clientEmailController.text.trim() : null,
          'description': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
          'userId': user.uid,
          'createdAt': DateTime.now().toIso8601String(),
        };

        final response = await api.createCase(caseData);
        final createdCase = response is Map ? (response['data']?['case'] ?? response['case'] ?? response) : response;

        if (mounted) {
          Navigator.pop(context, createdCase);
          _showSuccessSnackBar();
        }
      } catch (error) {
        if (mounted) {
          setState(() => _isCreating = false);
          _showErrorSnackBar(error.toString());
        }
      }
    }
  }

  void _showSuccessSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Case created successfully!', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.5)),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed: $error'),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Dark Theme Background
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAnimatedSection(0, _buildCaseTitleField()),
                        const SizedBox(height: 24),
                        _buildAnimatedSection(1, _buildCaseTypeSelector()),
                        const SizedBox(height: 24),
                        _buildAnimatedSection(2, _buildPrioritySelector()),
                        const SizedBox(height: 24),
                        _buildAnimatedSection(3, Row(
                          children: [
                            Expanded(child: _buildClientNameField()),
                            const SizedBox(width: 12),
                            Expanded(child: _buildClientEmailField()),
                          ],
                        )),
                        const SizedBox(height: 24),
                        _buildAnimatedSection(4, _buildDescriptionField()),
                        const SizedBox(height: 40),
                        _buildAnimatedSection(5, _buildActionButtons()),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedSection(int index, Widget child) {
    return FadeTransition(
      opacity: _fadeAnimations[index],
      child: SlideTransition(
        position: _slideAnimations[index],
        child: child,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.8),
        border: Border(bottom: BorderSide(color: const Color(0xFF334155).withOpacity(0.5))),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF475569),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add_chart_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'New Legal Case',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF1F5F9),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Initialize a new case file',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isCreating ? null : () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155).withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFFE2E8F0),
              letterSpacing: 0.3,
            ),
          ),
          if (required)
            const Text(' *', style: TextStyle(color: Color(0xFFEF4444), fontSize: 14)),
        ],
      ),
    );
  }

  InputDecoration _getInputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
      filled: true,
      fillColor: const Color(0xFF1E293B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildCaseTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Case Title', required: true),
        TextFormField(
          controller: _caseTitleController,
          enabled: !_isCreating,
          style: const TextStyle(color: Colors.white),
          decoration: _getInputDecoration(hint: 'e.g., Smith vs. State', icon: Icons.title_rounded),
          validator: (value) => value == null || value.trim().length < 3
              ? 'Title must be at least 3 chars'
              : null,
        ),
      ],
    );
  }

  Widget _buildCaseTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Case Type'),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _caseTypes.map((type) {
            final isSelected = _selectedCaseType == type['name'];
            final color = type['color'] as Color;

            return _AnimatedSelectionCard(
              isSelected: isSelected,
              onTap: _isCreating ? null : () => setState(() => _selectedCaseType = type['name']),
              color: color,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    type['icon'] as IconData,
                    color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    type['name'],
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Priority Level'),
        Row(
          children: _priorities.map((priority) {
            final isSelected = _selectedPriority == priority['name'];
            final color = priority['color'] as Color;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _AnimatedSelectionCard(
                  isSelected: isSelected,
                  onTap: _isCreating ? null : () => setState(() => _selectedPriority = priority['name']),
                  color: color,
                  isFullWidth: true,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        priority['icon'] as IconData,
                        color: isSelected ? Colors.white : color.withOpacity(0.7),
                        size: 22,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        priority['name'].toString().replaceAll(' Priority', ''),
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildClientNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Client Name'),
        TextFormField(
          controller: _clientNameController,
          enabled: !_isCreating,
          style: const TextStyle(color: Colors.white),
          decoration: _getInputDecoration(hint: 'Full Name', icon: Icons.person_rounded),
        ),
      ],
    );
  }

  Widget _buildClientEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Email'),
        TextFormField(
          controller: _clientEmailController,
          enabled: !_isCreating,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.emailAddress,
          decoration: _getInputDecoration(hint: 'address@email.com', icon: Icons.email_rounded),
        ),
      ],
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildInputLabel('Description'),
            const Text('Optional', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ],
        ),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          enabled: !_isCreating,
          style: const TextStyle(color: Colors.white),
          decoration: _getInputDecoration(hint: 'Add case details...', icon: Icons.description_rounded),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _isCreating ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              foregroundColor: const Color(0xFF94A3B8),
            ),
            child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isCreating ? null : _createCase,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isCreating
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Create Case',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Helper Widget for "Blast" Animation on Selection
class _AnimatedSelectionCard extends StatefulWidget {
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget child;
  final Color color;
  final bool isFullWidth;

  const _AnimatedSelectionCard({
    required this.isSelected,
    required this.onTap,
    required this.child,
    required this.color,
    this.isFullWidth = false,
  });

  @override
  State<_AnimatedSelectionCard> createState() => _AnimatedSelectionCardState();
}

class _AnimatedSelectionCardState extends State<_AnimatedSelectionCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0.0,
      upperBound: 0.1,
    );
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(_AnimatedSelectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) {
          _controller.forward().then((_) => _controller.reverse());
          widget.onTap!();
        }
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: 1.0 + _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              padding: EdgeInsets.symmetric(
                  horizontal: widget.isFullWidth ? 0 : 16,
                  vertical: widget.isFullWidth ? 16 : 12
              ),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? widget.color.withOpacity(0.2)
                    : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: widget.isSelected ? widget.color : const Color(0xFF334155),
                  width: widget.isSelected ? 1.5 : 1,
                ),
                boxShadow: widget.isSelected
                    ? [
                  BoxShadow(
                    color: widget.color.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  )
                ]
                    : [],
              ),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}
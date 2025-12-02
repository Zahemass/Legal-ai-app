import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:arm_app/services/api_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:arm_app/onboarding_screen/login_screen.dart';
import 'package:arm_app/screens/ai_analysis_document.dart';
import 'package:arm_app/screens/dashboard_screen.dart';
import 'package:arm_app/screens/cases_screen.dart';
import 'package:arm_app/components/bottom_bar_component.dart';

class DocumentScreen extends StatefulWidget {
  final String caseId;
  final String?  caseTitle;
  final String?  caseCategory;

  const DocumentScreen({
    super.key,
    required this. caseId,
    this. caseTitle,
    this. caseCategory,
  });

  @override
  State<DocumentScreen> createState() => _DocumentScreenState();
}

class _DocumentScreenState extends State<DocumentScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? caseDetails;
  List<dynamic> documents = [];
  bool loading = true;
  bool uploading = false;
  String?  errorMessage;

  User? currentUser;
  late AnimationController _headerController;
  late AnimationController _listController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _selectedIndex = 2;

  static const List<String> allowedExtensions = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx',
    'ppt', 'pptx', 'txt', 'rtf', 'csv',
    'jpg', 'jpeg', 'png', 'gif', 'webp'
  ];

  @override
  void initState() {
    super.initState();
    currentUser = FirebaseAuth.instance. currentUser;

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    fetchData();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _listController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> fetchData() async {
    try {
      setState(() {
        loading = true;
        errorMessage = null;
      });

      final caseResp = await getCaseById(widget.caseId);
      final docsResp = await getDocuments(widget.caseId);

      if (mounted) {
        setState(() {
          caseDetails = caseResp["data"]?["case"] ?? caseResp["case"] ?? caseResp;
          documents = docsResp;
          loading = false;
        });
        _headerController.forward();
        _listController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          errorMessage = e.toString();
        });
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    }
  }

  Future<void> _refreshDocuments() async {
    _listController.reset();
    await fetchData();
  }

  bool _isValidFileType(String fileName) {
    final extension = _getFileExtension(fileName);
    return allowedExtensions.contains(extension);
  }

  Future<void> uploadNewDocument() async {
    try {
      setState(() => uploading = true);

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result == null) {
        setState(() => uploading = false);
        return;
      }

      final pickedFile = result.files.single;
      final filePath = pickedFile.path;

      if (filePath == null) throw Exception('Unable to access file path');
      if (!_isValidFileType(pickedFile.name)) throw Exception('Invalid file type');

      final file = File(filePath);
      final fileSize = await file.length();
      const maxSize = 10 * 1024 * 1024;

      if (fileSize > maxSize) throw Exception('File size exceeds 10MB limit');

      final userId = FirebaseAuth.instance.currentUser! .uid;

      if (mounted) {
        _showLoadingSnackBar("Uploading ${pickedFile.name}...");
      }

      await uploadDocument(
        filePath: filePath,
        caseId: widget.caseId,
        userId: userId,
      );

      await fetchData();

      if (mounted) {
        _showSuccessSnackBar("${pickedFile.name} uploaded successfully!");
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("Upload failed: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  void _showLoadingSnackBar(String message) {
    ScaffoldMessenger.of(context). showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior. floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withOpacity(0.2),
                    const Color(0xFF3B82F6).withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withOpacity(0.15),
                    const Color(0xFF8B5CF6).withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: loading ?  _buildLoadingState() : _buildBody(),
          ),
        ],
      ),
      floatingActionButton: _buildFAB(),
      bottomNavigationBar: BottomBarComponent(
        selectedIndex: _selectedIndex,
        onTabSelected: (index) {
          setState(() => _selectedIndex = index);
          _handleNavigation(index);
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final displayTitle = widget.caseTitle ?? caseDetails?['title'] ?? 'Case Documents';
    final displayCategory = widget.caseCategory ?? (caseDetails?['type'] ?? 'OTHER'). toString(). toUpperCase();

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      toolbarHeight: 65,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment. bottomRight,
                colors: [
                  const Color(0xFF1E293B).withOpacity(0.95),
                  const Color(0xFF0F172A).withOpacity(0.95),
                ],
              ),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF3B82F6).withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.only(left: 8),
        child: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getCategoryColor(displayCategory). withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _getCategoryColor(displayCategory).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  displayCategory,
                  style: TextStyle(
                    color: _getCategoryColor(displayCategory),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Documents',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            displayTitle,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.2),
                width: 1,
              ),
            ),
            child: const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8), size: 18),
          ),
          onPressed: _refreshDocuments,
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: _showProfileBottomSheet,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  currentUser?.displayName?. substring(0, 1). toUpperCase() ??
                      currentUser?.email?.substring(0, 1). toUpperCase() ??
                      'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (errorMessage != null) return _buildErrorState();

    return RefreshIndicator(
      onRefresh: _refreshDocuments,
      color: const Color(0xFF3B82F6),
      backgroundColor: const Color(0xFF1E293B),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCaseHeader(),
            const SizedBox(height: 20),
            _buildStatsRow(),
            const SizedBox(height: 24),
            _buildDocumentListHeader(),
            const SizedBox(height: 16),
            documents.isEmpty ?  _buildEmptyState() : _buildDocumentList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCaseHeader() {
    if (caseDetails == null) return const SizedBox. shrink();

    final data = caseDetails! ;
    final caseType = widget.caseCategory ?? (data['type'] ?? 'other').toString().toUpperCase();
    final status = data['status'] ?? 'active';
    final caseTitle = widget.caseTitle ?? data['title'] ?? 'Untitled Case';

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, -0.2), end: Offset.zero). animate(
        CurvedAnimation(parent: _headerController, curve: Curves.easeOutBack),
      ),
      child: FadeTransition(
        opacity: _headerController,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF1E293B),
                const Color(0xFF334155),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF3B82F6).withOpacity(0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                blurRadius: 30,
                spreadRadius: -5,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(caseType). withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border. all(
                        color: _getCategoryColor(caseType). withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getCategoryIcon(caseType),
                          color: _getCategoryColor(caseType),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          caseType,
                          style: TextStyle(
                            color: _getCategoryColor(caseType),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border. all(
                        color: _getStatusColor(status).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _capitalizeFirst(status),
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontSize: 11,
                            fontWeight: FontWeight. w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                caseTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              if (data['description'] != null && data['description']. toString().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  data['description'],
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Documents',
            documents.length.toString(),
            Icons.folder_rounded,
            const Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Processed',
            documents.where((d) => d['processed'] == true).length.toString(),
            Icons.analytics_rounded,
            const Color(0xFF8B5CF6),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return FadeTransition(
      opacity: _headerController,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape. circle,
                border: Border.all(
                  color: color.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: color. withOpacity(0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentListHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.library_books_rounded,
                color: Color(0xFF3B82F6),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Document Library',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius. circular(8),
            border: Border.all(
              color: const Color(0xFF3B82F6).withOpacity(0.2),
            ),
          ),
          child: Text(
            '${documents.length} files',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF3B82F6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: documents.length,
      itemBuilder: (context, index) {
        final doc = documents[index];
        final delay = (index * 100).clamp(0, 500);

        return AnimatedBuilder(
          animation: _listController,
          builder: (context, child) {
            double interval = ((_listController.value * 1000) - delay) / 500;
            interval = interval.clamp(0.0, 1.0);

            final double animValue = Curves.easeOutCubic.transform(interval);

            return Transform. translate(
              offset: Offset(0, 30 * (1 - animValue)),
              child: Opacity(
                opacity: animValue,
                child: child,
              ),
            );
          },
          child: _buildDocumentCard(doc, index),
        );
      },
    );
  }

  Widget _buildDocumentCard(dynamic doc, int index) {
    final fileName = doc["filename"] ?? "Document ${index + 1}";
    final uploadedAt = doc["uploadedAt"] ?? "";
    final docId = doc["id"] ?? doc["_id"] ?? "";
    final fileExtension = _getFileExtension(fileName);
    final formattedDate = _formatDate(uploadedAt);
    final color = _getFileColor(fileExtension);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF475569).withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors. black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showPreview(docId, fileName),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: color.withOpacity(0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.2),
                            blurRadius: 12,
                            spreadRadius: -2,
                          )
                        ],
                      ),
                      child: Icon(_getFileIcon(fileExtension), color: color, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFF1F5F9),
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  fileExtension.toUpperCase(),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: const Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                formattedDate,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF64748B)),
                      onPressed: () => _showDocumentOptions(docId, fileName),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionButton(
                        'Preview',
                        Icons.visibility_rounded,
                        const Color(0xFF3B82F6),
                            () => _showPreview(docId, fileName),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildActionButton(
                        'AI Analysis',
                        Icons.auto_awesome_rounded,
                        const Color(0xFF8B5CF6),
                            () => _navigateToAIAnalysis(docId, fileName),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: color. withOpacity(0.1),
        borderRadius: BorderRadius. circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF3B82F6).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: uploading ? null : uploadNewDocument,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (uploading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.upload_file_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    uploading ? "Uploading..." : "Upload File",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius. circular(20),
                border: Border.all(
                  color: const Color(0xFF3B82F6).withOpacity(0.2),
                ),
              ),
              child: const CircularProgressIndicator(
                color: Color(0xFF3B82F6),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Loading documents...',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  size: 48,
                  color: Color(0xFF3B82F6),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Documents Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Upload your first document to get started',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton. icon(
              onPressed: uploadNewDocument,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Upload Document'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius. circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFEF4444). withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 50,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            errorMessage ??  "Error loading documents",
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          TextButton. icon(
            onPressed: fetchData,
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF3B82F6),
            ),
          ),
        ],
      ),
    );
  }

  void _showPreview(String docId, String fileName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
      ),
    );

    try {
      final preview = await getDocumentPreview(docId);
      if (mounted) {
        Navigator.pop(context);
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
            height: MediaQuery.of(context).size. height * 0.85,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF475569),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.description_rounded,
                          color: Color(0xFF3B82F6),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          fileName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: const Color(0xFF334155). withOpacity(0.5)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      preview,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        height: 1.6,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorSnackBar('Failed to load preview');
      }
    }
  }

  void _showDocumentOptions(String docId, String fileName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment. bottomCenter,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Text(
              fileName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              maxLines: 2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _buildOptionTile(
              Icons.download_rounded,
              'Download',
              const Color(0xFF10B981),
                  () {
                Navigator.pop(context);
                _showSnackBar('Download feature coming soon! ');
              },
            ),
            _buildOptionTile(
              Icons.share_outlined,
              'Share',
              const Color(0xFF8B5CF6),
                  () {
                Navigator.pop(context);
                _showSnackBar('Share feature coming soon!');
              },
            ),
            _buildOptionTile(
              Icons.delete_outline_rounded,
              'Delete',
              const Color(0xFFEF4444),
                  () {
                Navigator.pop(context);
                _showSnackBar('Delete feature coming soon!');
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight. w600,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _showProfileBottomSheet() {
    final displayName = currentUser?.displayName ?? 'User';
    final email = currentUser?.email ?? 'No email';
    final initials = displayName.isNotEmpty ? displayName. substring(0, 1). toUpperCase() : 'U';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius. circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF475569),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF1F5F9),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 20),
            _buildProfileOption(
              icon: Icons.person_outline_rounded,
              title: 'Profile Settings',
              onTap: () => Navigator.pop(context),
            ),
            _buildProfileOption(
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () => Navigator.pop(context),
            ),
            _buildProfileOption(
              icon: Icons.help_outline_rounded,
              title: 'Help & Support',
              onTap: () => Navigator.pop(context),
            ),
            Divider(height: 28, color: const Color(0xFF475569).withOpacity(0.3)),
            _buildProfileOption(
              icon: Icons.logout_rounded,
              title: 'Sign Out',
              color: const Color(0xFFEF4444),
              onTap: () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 200), _showSignOutDialog);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    final itemColor = color ?? const Color(0xFF94A3B8);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Row(
            children: [
              Icon(icon, color: itemColor, size: 19),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: itemColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: itemColor. withOpacity(0.5), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sign Out',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFF1F5F9),
            fontSize: 17,
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (! mounted) return;
                Navigator. pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Sign out failed: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _navigateToAIAnalysis(String docId, String fileName) {
    Navigator. push(
      context,
      MaterialPageRoute(
        builder: (_) => AiAnalysisDocument(
          documentId: docId,
          fileName: fileName,
        ),
      ),
    );
  }

  void _handleNavigation(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CasesScreen()),
        );
        break;
      case 3:
        _showProfileBottomSheet();
        break;
    }
  }

  String _getFileExtension(String name) => name.split('.').last.toLowerCase();

  IconData _getFileIcon(String ext) {
    if (['jpg', 'png', 'jpeg', 'gif', 'webp'].contains(ext)) return Icons.image_rounded;
    if (['pdf']. contains(ext)) return Icons.picture_as_pdf_rounded;
    if (['doc', 'docx'].contains(ext)) return Icons.description_rounded;
    if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart_rounded;
    if (['ppt', 'pptx'].contains(ext)) return Icons.slideshow_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _getFileColor(String ext) {
    if (ext == 'pdf') return const Color(0xFFEF4444);
    if (['doc', 'docx']. contains(ext)) return const Color(0xFF3B82F6);
    if (['jpg', 'png', 'jpeg', 'gif', 'webp'].contains(ext)) return const Color(0xFF8B5CF6);
    if (['xls', 'xlsx'].contains(ext)) return const Color(0xFF10B981);
    if (['ppt', 'pptx'].contains(ext)) return const Color(0xFFF59E0B);
    return const Color(0xFF64748B);
  }

  Color _getCategoryColor(String type) {
    switch (type. toLowerCase()) {
      case 'criminal':
        return const Color(0xFFEF4444);
      case 'civil':
        return const Color(0xFF06B6D4);
      case 'corporate':
        return const Color(0xFFF59E0B);
      case 'family':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category. toLowerCase()) {
      case 'criminal':
        return Icons.gavel_rounded;
      case 'civil':
        return Icons. balance_rounded;
      case 'corporate':
        return Icons.business_rounded;
      case 'family':
        return Icons.family_restroom_rounded;
      default:
        return Icons.folder_outlined;
    }
  }

  Color _getStatusColor(String status) {
    return status.toLowerCase() == 'active' ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
  }

  String _capitalizeFirst(String s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : s;

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';

      return "${dt.day}/${dt.month}/${dt.year}";
    } catch (_) {
      return "Unknown";
    }
  }
}
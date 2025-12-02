import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:arm_app/services/api_services.dart';
import 'package:path_provider/path_provider.dart';

class AiAnalysisDocument extends StatefulWidget {
  final String documentId;
  final String fileName;

  const AiAnalysisDocument({
    super.key,
    required this. documentId,
    required this. fileName,
  });

  static Future<void> open(BuildContext context, String documentId, String fileName) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiAnalysisDocument(documentId: documentId, fileName: fileName),
      ),
    );
  }

  @override
  State<AiAnalysisDocument> createState() => _AiAnalysisDocumentState();
}

class _AiAnalysisDocumentState extends State<AiAnalysisDocument> with TickerProviderStateMixin {
  bool loading = true;
  bool error = false;
  bool exporting = false;
  Map<String, dynamic> analysisData = {};

  late TabController _tabController;
  late AnimationController _listAnimController;
  late AnimationController _pulseController;
  late AnimationController _loadingRotation;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _listAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _loadingRotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    fetchAnalysis();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _listAnimController.dispose();
    _pulseController.dispose();
    _loadingRotation.dispose();
    _shimmerController.dispose();
    super. dispose();
  }

  Future<void> fetchAnalysis({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        loading = true;
        error = false;
      });
    }

    try {
      int retries = 0;
      const maxRetries = 30;
      const waitDuration = Duration(seconds: 2);
      Map<String, dynamic>? finalData;

      while (retries < maxRetries) {
        final resp = await analyzeDocument(widget.documentId);
        final raw = resp is Map ?  (resp["data"] ??  resp) : resp;

        final summary = _extractSummary(raw);
        final keyPoints = _extractList(raw["keyPoints"]);
        final recommendations = _extractList(raw["recommendations"]);
        final nestedSummary = (raw is Map && raw['analysis'] is Map) ? _extractSummary(raw['analysis']) : '';
        final chosenSummary = summary. trim().isNotEmpty ? summary : nestedSummary;

        final bool hasSummary = chosenSummary.trim().isNotEmpty;
        final bool hasKeyPoints = keyPoints. isNotEmpty;
        final bool hasRecommendations = recommendations. isNotEmpty;
        final bool backendReady = raw is Map && ["complete", "ready"].contains(raw["status"]?.toString(). toLowerCase());

        if (hasSummary || hasKeyPoints || hasRecommendations || backendReady) {
          finalData = {
            "summary": chosenSummary,
            "keyPoints": keyPoints,
            "recommendations": recommendations,
          };
          break;
        }

        if (raw is Map && (raw['status'] == 'complete' || raw['status'] == 'ready')) {
          finalData = {
            "summary": chosenSummary,
            "keyPoints": keyPoints,
            "recommendations": recommendations,
          };
          break;
        }

        retries++;
        await Future.delayed(waitDuration);
      }

      if (finalData == null) {
        throw Exception("AI analysis still processing");
      }

      if (! mounted) return;
      setState(() {
        analysisData = finalData! ;
        loading = false;
        error = false;
      });

      _listAnimController.forward(from: 0.0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = true;
      });
      _showSnackBar('Analysis failed: ${e.toString()}', isError: true);
    }
  }

  String _extractSummary(dynamic raw) {
    final candidates = [
      raw is Map ? raw["summary"] : null,
      raw is Map ? raw["aiSummary"] : null,
      raw is Map ? raw["documentSummary"] : null,
      raw is Map ? (raw["analysis"]? ["summary"]) : null,
      raw is Map ? raw["extractedText"] : null,
    ];

    for (var c in candidates) {
      if (c is String && c.trim().isNotEmpty) return c;
      if (c is Map && (c["content"] ??  "").toString().trim().isNotEmpty) {
        return c["content"].toString();
      }
    }
    return "";
  }

  List<String> _extractList(dynamic v) {
    if (v is List) return v. map((e) => e.toString()).toList();
    if (v is String && v.trim().isNotEmpty) {
      final lines = v.split(RegExp(r'[\r\n\u2022\-]')). map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      return lines;
    }
    return [];
  }

  List<String> formatMaybeList(dynamic v) {
    if (v == null) return [];
    if (v is List) return v.map((e) => e?. toString() ?? '').toList();
    if (v is String && v.isNotEmpty) {
      if (v.contains('\n')) return v.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      return [v];
    }
    return [v. toString()];
  }

  Future<void> _exportPdf() async {
    try {
      setState(() => exporting = true);
      final Uint8List bytes = await exportAnalysisPDF(widget.documentId);
      final tempDir = await getTemporaryDirectory();
      final safeName = widget.fileName.replaceAll(' ', '_'). replaceAll(RegExp(r'[^\w\-_\.]'), '');
      final file = File('${tempDir.path}/${safeName}_analysis.pdf');
      await file.writeAsBytes(bytes);
      setState(() => exporting = false);

      if (! mounted) return;
      _showSnackBar('PDF exported successfully to ${file.path}');
    } catch (e) {
      setState(() => exporting = false);
      if (!mounted) return;
      _showSnackBar('Export failed: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        backgroundColor: isError ?  const Color(0xFFEF4444) : const Color(0xFF10B981),
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
      body: Stack(
        children: [
          // Background Gradients
          Positioned(
            top: -150,
            right: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF3B82F6).withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    switchInCurve: Curves. easeOutBack,
                    child: loading
                        ? _buildLoadingState()
                        : error
                        ? _buildErrorState()
                        : _buildContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: ! loading && !error ?  _buildFab() : null,
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B). withOpacity(0.95),
            const Color(0xFF0F172A).withOpacity(0.95),
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF3B82F6).withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF3B82F6).withOpacity(0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "AI Document Analysis",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.fileName,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              _buildIconButton(
                icon: Icons.picture_as_pdf_rounded,
                onTap: exporting ? null : _exportPdf,
                isLoading: exporting,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius. circular(24),
              border: Border.all(
                color: const Color(0xFF3B82F6).withOpacity(0.2),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              labelColor: Colors.white,
              unselectedLabelColor: const Color(0xFF94A3B8),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: "Summary"),
                Tab(text: "Key Points"),
                Tab(text: "Actions"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback?  onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFF3B82F6).withOpacity(0.3),
            ),
          ),
          child: isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF3B82F6),
            ),
          )
              : Icon(icon, color: const Color(0xFF3B82F6), size: 20),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated rotating circles
          AnimatedBuilder(
            animation: _loadingRotation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring
                  Transform.rotate(
                    angle: _loadingRotation.value * 2 * 3.14159,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withOpacity(0.3),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                  // Inner ring
                  Transform. rotate(
                    angle: -_loadingRotation.value * 2 * 3.14159,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                  // Center icon with pulse
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_pulseController.value * 0.1),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF3B82F6).withOpacity(0.5),
                                blurRadius: 20 * _pulseController.value,
                                spreadRadius: 5 * _pulseController.value,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors. white,
                            size: 28,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 40),
          const Text(
            "Analyzing Document",
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "AI is extracting insights and key information",
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          // Shimmer dots
          AnimatedBuilder(
            animation: _shimmerController,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) {
                  final delay = index * 0.3;
                  final value = ((_shimmerController.value - delay) % 1.0). clamp(0.0, 1.0);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color. lerp(
                        const Color(0xFF334155),
                        const Color(0xFF3B82F6),
                        value,
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
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
                color: Color(0xFFEF4444),
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Analysis Failed",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight. bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "Unable to analyze the document.\nPlease try again.",
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton. icon(
              onPressed: () => fetchAnalysis(showLoading: true),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text(
                "Try Again",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton. styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final summary = analysisData['summary'] ?? '';
    final keyPoints = formatMaybeList(analysisData['keyPoints']);
    final recommendations = formatMaybeList(analysisData['recommendations']);

    return TabBarView(
      controller: _tabController,
      children: [
        _buildSummaryTab(summary),
        _buildListTab(
          keyPoints,
          Icons.stars_rounded,
          const Color(0xFFF59E0B),
          "No key points available",
        ),
        _buildListTab(
          recommendations,
          Icons.lightbulb_rounded,
          const Color(0xFF10B981),
          "No recommendations available",
        ),
      ],
    );
  }

  Widget _buildSummaryTab(String summary) {
    if (summary.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.description_outlined,
                color: Color(0xFF64748B),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "No summary available",
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: _3DCard(
        delay: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF334155)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF3B82F6).withOpacity(0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.summarize_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    "Executive Summary",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ... summary.split('\n').where((e) => e.trim().isNotEmpty).map(
                    (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    p. trim(),
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 15,
                      height: 1.7,
                      letterSpacing: 0.2,
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

  Widget _buildListTab(
      List<String> items,
      IconData icon,
      Color accentColor,
      String emptyMessage,
      ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                shape: BoxShape. circle,
              ),
              child: Icon(
                icon,
                color: const Color(0xFF64748B),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _listAnimController,
          builder: (context, child) {
            final start = (index * 0.1).clamp(0.0, 1.0);
            final end = (start + 0.4).clamp(0.0, 1.0);
            final curve = CurvedAnimation(
              parent: _listAnimController,
              curve: Interval(start, end, curve: Curves.easeOutBack),
            );

            return Transform. translate(
              offset: Offset(0, 50 * (1 - curve.value)),
              child: Opacity(
                opacity: curve. value,
                child: child,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF334155)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: accentColor.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor. withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: accentColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    items[index],
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 15,
                      height: 1.6,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFab() {
    return Container(
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
          onTap: () => fetchAnalysis(showLoading: true),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  "Re-Analyze",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 3D Card Animation Widget
class _3DCard extends StatefulWidget {
  final Widget child;
  final int delay;

  const _3DCard({required this.child, this.delay = 0});

  @override
  State<_3DCard> createState() => _3DCardState();
}

class _3DCardState extends State<_3DCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final val = _anim.value;
        return Transform.translate(
          offset: Offset(0, 30 * (1 - val)),
          child: Opacity(
            opacity: val,
            child: widget.child,
          ),
        );
      },
    );
  }
}
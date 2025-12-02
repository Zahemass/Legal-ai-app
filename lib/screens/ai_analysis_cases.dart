import 'package:flutter/material.dart';
import 'package:arm_app/services/api_services.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class AiAnalysisCases extends StatefulWidget {
  final String caseId;

  const AiAnalysisCases({super.key, required this.caseId});

  @override
  State<AiAnalysisCases> createState() => _AiAnalysisCasesState();
}

class _AiAnalysisCasesState extends State<AiAnalysisCases>
    with TickerProviderStateMixin {
  dynamic _analysisData;
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedTabIndex = 0;

  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late AnimationController _progressController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;

  int _elapsedSeconds = 0;
  Timer? _timer;
  double _estimatedProgress = 0.0;
  String _currentStatus = "Initializing AI analysis...";

  final List<String> _statusMessages = [
    "Initializing AI analysis...",
    "Reading case documents...",
    "Analyzing legal precedents...",
    "Evaluating case strength...",
    "Identifying key arguments...",
    "Reviewing applicable laws...",
    "Assessing evidence quality...",
    "Generating recommendations...",
    "Finalizing analysis report...",
  ];

  final List<Map<String, dynamic>> _tabs = [
    {'icon': Icons.description_rounded, 'label': 'Summary'},
    {'icon': Icons.search_rounded, 'label': 'Findings'},
    {'icon': Icons. warning_rounded, 'label': 'Risk'},
    {'icon': Icons.lightbulb_rounded, 'label': 'Strategy'},
  ];

  @override
  void initState() {
    super. initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0). animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );

    _startTimer();
    _fetchCaseAnalysis();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (! _isLoading) {
        timer.cancel();
        return;
      }

      setState(() {
        _elapsedSeconds++;
        _estimatedProgress = math.min(
          0.95,
          (_elapsedSeconds / 600) * 100 + (math.Random().nextDouble() * 2),
        );

        if (_elapsedSeconds % 45 == 0) {
          int index = (_elapsedSeconds ~/ 45) % _statusMessages.length;
          _currentStatus = _statusMessages[index];
        }
      });
    });
  }

  Future<void> _fetchCaseAnalysis() async {
    try {
      final response = await getCaseAnalysis(widget.caseId);

      // ✅ Animate progress to 100% smoothly
      setState(() {
        _currentStatus = "Analysis complete!  Loading results...";
      });

      await _progressController.forward();

      // Small delay to show 100%
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _analysisData = response;
        _isLoading = false;
        _estimatedProgress = 100;
      });
      _timer?.cancel();
      _fadeController.forward();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
      _timer?.cancel();
      _fadeController.forward();
    }
  }

  String _formatElapsedTime() {
    int minutes = _elapsedSeconds ~/ 60;
    int seconds = _elapsedSeconds % 60;
    return "$minutes:${seconds.toString().padLeft(2, '0')}";
  }

  // ✅ IMPROVED: Format text with bold, hide symbols, bigger font
  List<TextSpan> _formatTextWithBold(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*\*|##)(.*?)(\*\*|##)');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      // Add normal text before match
      if (match.start > lastIndex) {
        final normalText = text.substring(lastIndex, match.start);
        if (normalText.isNotEmpty) {
          spans.add(TextSpan(
            text: normalText,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFFCBD5E1),
              height: 1.6,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.2,
            ),
          ));
        }
      }

      // Add bold text WITHOUT symbols
      final boldText = match.group(2) ?? '';
      if (boldText.isNotEmpty) {
        spans.add(TextSpan(
          text: boldText,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFFF1F5F9),
            height: 1.6,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ));
      }

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text. length) {
      final remainingText = text.substring(lastIndex);
      if (remainingText.isNotEmpty) {
        spans.add(TextSpan(
          text: remainingText,
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFFCBD5E1),
            height: 1.6,
            fontWeight: FontWeight. w400,
            letterSpacing: 0.2,
          ),
        ));
      }
    }

    return spans. isEmpty
        ? [
      TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 15,
          color: Color(0xFFCBD5E1),
          height: 1.6,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.2,
        ),
      )
    ]
        : spans;
  }

  Map<String, dynamic> _parseAnalysisData() {
    if (_analysisData == null || _analysisData is! Map) {
      return {
        'summary': '',
        'findings': [],
        'risks': {},
        'strategy': '',
        'confidence': 0.0,
        'documentCount': 0,
      };
    }

    return {
      'summary': _analysisData['executiveSummary'] ?? '',
      'findings': _analysisData['keyFindings'] ?? [],
      'risks': _analysisData['riskAssessment'] ?? {},
      'strategy': _analysisData['strategicAdvice'] ?? '',
      'recommendations': _analysisData['recommendations'] ?? [],
      'confidence': (_analysisData['confidence'] ??  0.0) * 100,
      'documentCount': _analysisData['documentCount'] ?? 0,
      'processingTime': _analysisData['processingTime'] ??  0.0,
      'strengths': _analysisData['strengthsWeaknesses']? ['strengths'] ?? [],
      'weaknesses': _analysisData['strengthsWeaknesses']? ['weaknesses'] ?? [],
    };
  }

  Future<void> _downloadPDF() async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (! status.isGranted) {
          status = await Permission.storage.request();
          if (! status.isGranted) {
            _showSnackBar("Storage permission required to download PDF");
            return;
          }
        }
      }

      _showSnackBar("Generating PDF...", duration: Duration(seconds: 2));

      final pdfBytes = await exportAnalysisPDF(widget.caseId);

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${directory! .path}/case_analysis_$timestamp.pdf';
      final file = File(filePath);

      await file.writeAsBytes(pdfBytes);

      _showSnackBar(
        "✅ PDF saved to Downloads folder",
        duration: Duration(seconds: 3),
      );
    } catch (e) {
      _showSnackBar("Failed to download PDF: ${e.toString()}");
    }
  }

  Widget _loadingAnimation() {
    final displayProgress = _progressController.isAnimating
        ? _estimatedProgress + ((_progressAnimation.value) * (100 - _estimatedProgress))
        : _estimatedProgress;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F172A),
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Stack(
                alignment: Alignment.center,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF3B82F6). withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF60A5FA).withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _rotationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _rotationController. value * 2 * math.pi,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: SweepGradient(
                              colors: [
                                const Color(0xFF3B82F6),
                                const Color(0xFF60A5FA),
                                const Color(0xFF3B82F6).withOpacity(0.1),
                                const Color(0xFF3B82F6),
                              ],
                              stops: const [0.0, 0.3, 0.6, 1.0],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E293B),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.5),
                          blurRadius: 25,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.psychology_rounded,
                      size: 45,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                ).createShader(bounds),
                child: const Text(
                  "AI Analysis in Progress",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors. white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _currentStatus,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey. shade400,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF334155),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: const Color(0xFF3B82F6),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Estimated Time",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  Text(
                                    "5-10 minutes",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(0xFF60A5FA),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: AnimatedBuilder(
                                  animation: _progressAnimation,
                                  builder: (context, child) {
                                    return LinearProgressIndicator(
                                      value: displayProgress / 100,
                                      minHeight: 6,
                                      backgroundColor: const Color(0xFF0F172A),
                                      valueColor: const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF3B82F6),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildLoadingStat(
                          icon: Icons.schedule_rounded,
                          label: "Elapsed",
                          value: _formatElapsedTime(),
                        ),
                        Container(
                          width: 1,
                          height: 35,
                          color: const Color(0xFF334155),
                        ),
                        AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            return _buildLoadingStat(
                              icon: Icons.percent_rounded,
                              label: "Progress",
                              value: "${displayProgress.toStringAsFixed(0)}%",
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B). withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF334155),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: const Color(0xFF60A5FA),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "AI is analyzing your case documents and legal precedents.  This may take 5-10 minutes.",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildProgressDots(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF3B82F6), size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _rotationController,
          builder: (context, child) {
            double opacity = (math.sin((_rotationController.value * 2 * math.pi) +
                (index * math.pi * 2 / 3)) +
                1) /
                2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF3B82F6).withOpacity(opacity),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF3B82F6).withOpacity(opacity * 0.5),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            );
          },
        );
      }),
    );
  }

  Widget _analysisView() {
    if (_analysisData == null) {
      return _emptyState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F172A),
              const Color(0xFF1E293B),
              const Color(0xFF0F172A),
            ],
          ),
        ),
        child: Column(
          children: [
            _buildAnalysisHeader(),
            _buildTabNavigation(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: _buildTabContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisHeader() {
    final parsedData = _parseAnalysisData();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white. withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Analysis Complete",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${parsedData['documentCount']} docs analyzed",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors. white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _downloadPDF,
                child: Container(
                  padding: const EdgeInsets. symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.file_download_outlined,
                        color: const Color(0xFF3B82F6),
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        "PDF",
                        style: TextStyle(
                          color: Color(0xFF3B82F6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildHeaderStat(
                  icon: Icons.verified_rounded,
                  label: "Confidence",
                  value: "${parsedData['confidence']. toStringAsFixed(0)}%",
                ),
                Container(
                  width: 1,
                  height: 25,
                  color: Colors.white. withOpacity(0.3),
                ),
                _buildHeaderStat(
                  icon: Icons.description_outlined,
                  label: "Documents",
                  value: "${parsedData['documentCount']}",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabNavigation() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius. circular(12),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: Row(
        children: List.generate(_tabs.length, (index) {
          final isSelected = _selectedTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTabIndex = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  )
                      : null,
                  borderRadius: BorderRadius. circular(10),
                ),
                child: Column(
                  children: [
                    Icon(
                      _tabs[index]['icon'],
                      color: isSelected ? Colors.white : Colors.grey. shade600,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _tabs[index]['label'],
                      style: TextStyle(
                        fontSize: 11,
                        color: isSelected ? Colors.white : Colors.grey.shade600,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    final parsedData = _parseAnalysisData();

    switch (_selectedTabIndex) {
      case 0:
        return _buildSummaryTab(parsedData['summary']);
      case 1:
        return _buildFindingsTab(parsedData['findings']);
      case 2:
        return _buildRiskTab(
            parsedData['risks'], parsedData['strengths'], parsedData['weaknesses']);
      case 3:
        return _buildStrategyTab(parsedData['strategy'], parsedData['recommendations']);
      default:
        return _buildSummaryTab(parsedData['summary']);
    }
  }

  Widget _buildSummaryTab(String summary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildSectionTitle(
          icon: Icons.description_rounded,
          title: "Executive Summary",
          color: const Color(0xFF3B82F6),
        ),
        const SizedBox(height: 16),
        if (summary.isNotEmpty) _buildContentCard(summary) else _buildEmptyCard("No summary available"),
      ],
    );
  }

  Widget _buildFindingsTab(List<dynamic> findings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildSectionTitle(
          icon: Icons.search_rounded,
          title: "Key Findings",
          color: const Color(0xFF8B5CF6),
        ),
        const SizedBox(height: 16),
        if (findings.isNotEmpty)
          ... findings.asMap().entries.map((entry) {
            return _buildFindingItem(
              number: entry.key + 1,
              content: entry.value. toString(),
            );
          }).toList()
        else
          _buildEmptyCard("No findings available"),
      ],
    );
  }

  Widget _buildRiskTab(
      Map<String, dynamic> risks, List<dynamic> strengths, List<dynamic> weaknesses) {
    final riskLevel = risks['overallRiskLevel'] ??  'Medium';
    final keyRiskFactors = risks['keyRiskFactors'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _buildSectionTitle(
          icon: Icons.warning_rounded,
          title: "Risk Assessment",
          color: const Color(0xFFF59E0B),
        ),
        const SizedBox(height: 16),
        _buildOverallRiskCard(riskLevel),
        const SizedBox(height: 16),
        if (keyRiskFactors.isNotEmpty) ...[
          _buildSubSectionTitle("Key Risk Factors"),
          const SizedBox(height: 12),
          ...keyRiskFactors.asMap().entries.map((entry) {
            return _buildRiskItem(
              content: entry.value.toString(),
              level: _getRiskLevel(entry.key, keyRiskFactors. length),
            );
          }). toList(),
        ],
        if (keyRiskFactors.isEmpty) _buildEmptyCard("No risk factors identified"),
        if (strengths.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSubSectionTitle("Case Strengths"),
          const SizedBox(height: 12),
          ...strengths.take(5).map((strength) {
            if (strength.toString().trim().isNotEmpty && strength.toString() != '--') {
              return _buildStrengthItem(strength.toString());
            }
            return const SizedBox. shrink();
          }).toList(),
        ],
        if (weaknesses.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSubSectionTitle("Potential Weaknesses"),
          const SizedBox(height: 12),
          ...weaknesses.take(5).map((weakness) {
            if (weakness.toString(). trim().isNotEmpty && weakness. toString() != '--') {
              return _buildWeaknessItem(weakness.toString());
            }
            return const SizedBox. shrink();
          }).toList(),
        ],
      ],
    );
  }

  Widget _buildStrategyTab(String strategy, List<dynamic> recommendations) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const SizedBox(height: 8),
    _buildSectionTitle(
    icon: Icons. lightbulb_rounded,
    title: "Strategic Advice",
    color: const Color(0xFF10B981),
    ),
    const SizedBox(height: 16),
    if (strategy.isNotEmpty)
    _buildContentCard(strategy)
    else
    _buildEmptyCard("No strategic advice available"),
    if (recommendations.isNotEmpty) ...[
    const SizedBox(height: 20),
    _buildSubSectionTitle("Recommendations"),
    const SizedBox(height: 12),
    ... recommendations.asMap().entries.map((entry) {
    final rec = entry.value as Map<String, dynamic>;
    return _buildRecommendationItem(
    number: entry.key + 1,
    action: rec['action'] ?? '',
    priority: rec['priority'] ?? 'Medium',
    );
    }).toList(),
    ],
    ],
    );
  }

  String _getRiskLevel(int index, int total) {
    if (total <= 2) return 'HIGH';
    if (index == 0) return 'HIGH';
    if (index < total / 2) return 'MEDIUM';
    return 'LOW';
  }

  Widget _buildOverallRiskCard(String riskLevel) {
    Color riskColor;
    IconData riskIcon;

    switch (riskLevel. toUpperCase()) {
      case 'HIGH':
        riskColor = const Color(0xFFEF4444);
        riskIcon = Icons.dangerous_rounded;
        break;
      case 'LOW':
        riskColor = const Color(0xFF10B981);
        riskIcon = Icons.check_circle_rounded;
        break;
      default:
        riskColor = const Color(0xFFF59E0B);
        riskIcon = Icons.warning_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius. circular(12),
        border: Border.all(
          color: riskColor. withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: riskColor. withOpacity(0.15),
              shape: BoxShape. circle,
            ),
            child: Icon(riskIcon, color: riskColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Overall Risk Level",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  riskLevel. toUpperCase(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade300,
      ),
    );
  }

  Widget _buildSectionTitle({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color. withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContentCard(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: RichText(
        text: TextSpan(
          children: _formatTextWithBold(content),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.grey.shade600,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFindingItem({required int number, required String content}) {
    if (content.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: _formatTextWithBold(content),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskItem({required String content, required String level}) {
    if (content.trim().isEmpty) return const SizedBox.shrink();

    Color levelColor;
    switch (level) {
      case 'HIGH':
        levelColor = const Color(0xFFEF4444);
        break;
      case 'MEDIUM':
        levelColor = const Color(0xFFF59E0B);
        break;
      default:
        levelColor = const Color(0xFF10B981);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: levelColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: levelColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  level,
                  style: TextStyle(
                    color: levelColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.warning_rounded,
                color: levelColor,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: _formatTextWithBold(content),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthItem(String content) {
    if (content.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF10B981). withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: const Color(0xFF10B981),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: _formatTextWithBold(content),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeaknessItem(String content) {
    if (content.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFEF4444).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cancel_rounded,
            color: const Color(0xFFEF4444),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: _formatTextWithBold(content),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationItem({
    required int number,
    required String action,
    required String priority,
  }) {
    if (action.trim().isEmpty) return const SizedBox.shrink();

    Color priorityColor;
    switch (priority.toLowerCase()) {
      case 'high':
        priorityColor = const Color(0xFFEF4444);
        break;
      case 'low':
        priorityColor = const Color(0xFF10B981);
        break;
      default:
        priorityColor = const Color(0xFFF59E0B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF334155),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF34D399)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor. withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    priority,
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: _formatTextWithBold(action),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment. bottomRight,
            colors: [
              const Color(0xFF0F172A),
              const Color(0xFF1E293B),
              const Color(0xFF0F172A),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E293B),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 50,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Analysis Failed",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _errorMessage ??  "Something went wrong",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors. grey.shade500,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isLoading = true;
                      _errorMessage = null;
                      _elapsedSeconds = 0;
                      _estimatedProgress = 0.0;
                      _currentStatus = "Initializing AI analysis...";
                    });
                    _progressController.reset();
                    _startTimer();
                    _fetchCaseAnalysis();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3B82F6).withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          "Retry Analysis",
                          style: TextStyle(
                            color: Colors. white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F172A),
            const Color(0xFF1E293B),
            const Color(0xFF0F172A),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E293B),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                size: 50,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "No Analysis Data",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message, {Duration?  duration}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF3B82F6),
        behavior: SnackBarBehavior.floating,
        duration: duration ?? const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _progressController.dispose();
    _timer?. cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "AI Case Analysis",
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading ?  _loadingAnimation() : _errorMessage != null ? _errorView() : _analysisView(),
    );
  }
}
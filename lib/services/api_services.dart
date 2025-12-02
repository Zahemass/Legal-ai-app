// lib/services/api_services.dart
//
// Flutter equivalent of frontend/services/api.js
// - Reads VITE_* env variables via flutter_dotenv
// - Uses Firebase ID token for Authorization header (auto)
// - Provides helper functions mirroring api.js:
//   getCases, getCaseById, createCase, runCaseAnalysis,
//   getCaseAnalysis, getDocuments, uploadDocument (multipart),
//   getDocumentPreview, analyzeDocument, exportAnalysisPDF,
//   sendAIMessage, getAIChatHistory, getAIAgents, getAIAgentHealth
//
// Requirements:
//   - await dotenv.load(fileName: ".env") in main()
//   - await initializeFirebase() (from firebase.dart) in main()
//   - ensure user is authenticated before calling protected APIs

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// --------------------
/// Env config (VITE_* keys)
/// --------------------
final String CASE_API_URL =
    dotenv.env['VITE_CASE_API_URL'] ?? 'http://localhost:8080';
final String DOCUMENT_API_URL =
    dotenv.env['VITE_DOCUMENT_API_URL'] ?? 'http://localhost:8080';
final String ANALYSIS_API_URL =
    dotenv.env['VITE_ANALYSIS_API_URL'] ?? 'http://localhost:8080';
final String CASE_ANALYSIS_API_URL =
    dotenv.env['VITE_CASE_ANALYSIS_API_URL'] ?? 'http://localhost:8080';
final String AI_AGENT_API_URL =
    dotenv.env['VITE_AI_AGENT_API_URL'] ?? 'http://localhost:8080';

/// --------------------
/// Firebase token helper (auto-generates ID token)
/// --------------------
final FirebaseAuth _auth = FirebaseAuth.instance;

Future<String> _getAuthToken() async {
  final user = _auth.currentUser;
  if (user == null) throw Exception('User not authenticated');

  final token = await user.getIdToken();
  if (token == null) throw Exception('Failed to generate Firebase token');

  return token;
}

/// --------------------
/// Generic request helper: automatically adds Authorization header
/// --------------------
Future<dynamic> request(
    String baseUrl,
    String path, {
      String method = 'GET',
      Map<String, String>? headers,
      dynamic body,
      Duration timeout = const Duration(minutes: 10),
    }) async {
  final token = await _getAuthToken();

  final Map<String, String> finalHeaders = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
    if (headers != null) ...headers,
  };

  final uri = Uri.parse(baseUrl + path);

  http.Response res;
  try {
    if (method == 'GET') {
      res = await http.get(uri, headers: finalHeaders).timeout(timeout);
    } else if (method == 'POST') {
      res = await http
          .post(uri, headers: finalHeaders, body: jsonEncode(body))
          .timeout(timeout);
    } else if (method == 'PUT') {
      res = await http
          .put(uri, headers: finalHeaders, body: jsonEncode(body))
          .timeout(timeout);
    } else if (method == 'PATCH') {
      res = await http
          .patch(uri, headers: finalHeaders, body: jsonEncode(body))
          .timeout(timeout);
    } else if (method == 'DELETE') {
      res = await http.delete(uri, headers: finalHeaders).timeout(timeout);
    } else {
      throw Exception('Unsupported HTTP method: $method');
    }
  } catch (e) {
    throw Exception('Network error: $e');
  }

  if (res.statusCode < 200 || res.statusCode >= 300) {
    final errorText = res.body.isNotEmpty ? res.body : res.reasonPhrase;
    throw Exception('❌ API Error ${res.statusCode}: $errorText');
  }

  if (res.statusCode == 204 || res.body.isEmpty) return null;

  try {
    return jsonDecode(res.body);
  } catch (_) {
    return res.body;
  }
}

/// --------------------
/// CASE MANAGEMENT
/// --------------------
Future<Map<String, dynamic>> getCases() async {
  final resp = await request(CASE_API_URL, '/cases', method: 'GET');

  final List rawCases = resp is Map && resp['data'] != null && resp['data']['cases'] != null
      ? resp['data']['cases'] as List
      : resp is Map && resp['cases'] != null
      ? resp['cases'] as List
      : resp is List
      ? resp
      : [];

  final normalized = rawCases.map<Map<String, dynamic>>((c) {
    final Map<String, dynamic> m = Map<String, dynamic>.from(c as Map);
    final int documentCount = m['documentCount'] is int
        ? m['documentCount']
        : m['document_count'] is int
        ? m['document_count']
        : (m['data']?['documentCount'] ?? 0) as int;
    final int analysisCount = m['analysisCount'] is int
        ? m['analysisCount']
        : m['analysis_count'] is int
        ? m['analysis_count']
        : (m['data']?['analysisCount'] ?? 0) as int;

    return {
      ...m,
      'documentCount': documentCount,
      'analysisCount': analysisCount,
      'title': m['title'] ?? 'Untitled Case',
      'status': m['status'] ?? 'active',
      'priority': m['priority'] ?? 'medium',
      'type': m['type'] ?? 'other',
    };
  }).toList();

  return {
    'success': true,
    'data': {'cases': normalized},
  };
}

Future<dynamic> getCaseById(String caseId) {
  if (caseId.isEmpty) throw Exception('Case ID is required');
  return request(CASE_API_URL, '/cases/$caseId', method: 'GET');
}

Future<dynamic> createCase(Map<String, dynamic> caseData) {
  if (caseData['title'] == null) throw Exception('Case title is required');
  return request(CASE_API_URL, '/cases', method: 'POST', body: caseData);
}

Future<dynamic> runCaseAnalysis(String caseId) {
  if (caseId.isEmpty) throw Exception('Case ID is required');
  return request(CASE_API_URL, '/cases/$caseId/analyze', method: 'POST');
}

/// --------------------
/// CASE ANALYSIS SERVICE
/// --------------------
Future<dynamic> getCaseAnalysis(String caseId) async {
  if (caseId.isEmpty) throw Exception('Case ID is required');
  final resp = await request(
    CASE_ANALYSIS_API_URL,
    '/analyze',
    method: 'POST',
    body: {'caseId': caseId, 'analysisType': 'comprehensive'},
  );
  return resp is Map && resp['data'] != null ? resp['data'] : resp;
}

/// --------------------
/// MIME Type Helper
/// --------------------
String _getMimeType(String filePath) {
  final extension = filePath.split('.').last.toLowerCase();

  switch (extension) {
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'txt':
      return 'text/plain';
    case 'rtf':
      return 'application/rtf';
    case 'csv':
      return 'text/csv';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    default:
      return 'application/octet-stream';
  }
}

/// Validate if file extension is allowed
bool _isValidFileExtension(String filePath) {
  const allowedExtensions = [
    'pdf', 'doc', 'docx', 'xls', 'xlsx',
    'ppt', 'pptx', 'txt', 'rtf', 'csv',
    'jpg', 'jpeg', 'png', 'gif', 'webp'
  ];

  final extension = filePath.split('.').last.toLowerCase();
  return allowedExtensions.contains(extension);
}

/// --------------------
/// DOCUMENT MANAGEMENT
/// --------------------
Future<List<dynamic>> getDocuments(String caseId) async {
  if (caseId.isEmpty) throw Exception('Case ID is required');
  final resp = await request(DOCUMENT_API_URL, '/documents?caseId=$caseId', method: 'GET');

  if (resp is Map && resp['data'] != null && resp['data']['documents'] != null) {
    return resp['data']['documents'] as List<dynamic>;
  } else if (resp is Map && resp['documents'] != null) {
    return resp['documents'] as List<dynamic>;
  } else if (resp is List) {
    return resp;
  }
  return [];
}

/// Upload a file with proper MIME type handling
Future<dynamic> uploadDocument({
  required String filePath,
  required String caseId,
  required String userId,
}) async {
  if (caseId.isEmpty) throw Exception('Case ID is required');

  final file = File(filePath);
  if (!await file.exists()) {
    throw Exception('File not found at $filePath');
  }

  // Validate file extension
  if (!_isValidFileExtension(filePath)) {
    throw Exception(
        'Invalid file type. Allowed types: PDF, DOC, DOCX, XLS, XLSX, PPT, PPTX, TXT, RTF, CSV, JPG, PNG, GIF, WEBP'
    );
  }

  // Check file size (max 10MB)
  final fileSize = await file.length();
  const maxSize = 10 * 1024 * 1024; // 10MB
  if (fileSize > maxSize) {
    throw Exception('File size exceeds 10MB limit');
  }

  final token = await _getAuthToken();
  final uri = Uri.parse('$DOCUMENT_API_URL/documents/upload');

  final requestMultipart = http.MultipartRequest('POST', uri)
    ..fields['caseId'] = caseId
    ..fields['userId'] = userId
    ..headers['Authorization'] = 'Bearer $token';

  // Get the correct MIME type
  final mimeType = _getMimeType(filePath);
  final mimeTypeParts = mimeType.split('/');

  print('📤 Uploading file: $filePath');
  print('📄 MIME Type: $mimeType');
  print('📦 Case ID: $caseId');
  print('👤 User ID: $userId');
  print('📊 File Size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

  // Create multipart file with explicit MIME type
  final multipartFile = await http.MultipartFile.fromPath(
    'files',
    filePath,
    contentType: MediaType(mimeTypeParts[0], mimeTypeParts[1]),
  );

  requestMultipart.files.add(multipartFile);

  final streamedResponse = await requestMultipart.send();
  final response = await http.Response.fromStream(streamedResponse);

  print('✅ Response Status: ${response.statusCode}');
  print('📝 Response Body: ${response.body}');

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Upload failed: ${response.statusCode} ${response.body}');
  }

  try {
    return jsonDecode(response.body);
  } catch (_) {
    return response.body;
  }
}

/// --------------------
/// Document preview & analysis
/// --------------------
Future<String> getDocumentPreview(String documentId) async {
  if (documentId.isEmpty) throw Exception('Document ID is required');
  final resp = await request(DOCUMENT_API_URL, '/documents/$documentId/preview', method: 'GET');

  if (resp is Map) {
    return resp['data']?['textPreview']?['content'] ??
        resp['data']?['content'] ??
        resp['content'] ??
        resp['summary'] ??
        'No preview available.';
  }

  return resp?.toString() ?? 'No preview available.';
}

Future<dynamic> analyzeDocument(String documentId) async {
  if (documentId.isEmpty) throw Exception('Document ID is required');

  final token = await _getAuthToken();
  final uri = Uri.parse('$ANALYSIS_API_URL/analyze');

  final res = await http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({'documentId': documentId, 'analysisType': 'full'}),
  );

  final text = res.body;
  if (res.statusCode < 200 || res.statusCode >= 300) {
    try {
      final jsonErr = jsonDecode(text);
      throw Exception(jsonErr['error'] ?? 'AI Analysis failed');
    } catch (e) {
      throw Exception('AI Analysis failed: ${res.statusCode} ${res.reasonPhrase}');
    }
  }

  try {
    final data = jsonDecode(text);
    return data;
  } catch (e) {
    throw Exception('Invalid response from AI analysis service');
  }
}

/// --------------------
/// Export PDF
/// --------------------
Future<Uint8List> exportAnalysisPDF(String caseId) async {
  final token = await _getAuthToken();
  final uri = Uri.parse('$DOCUMENT_API_URL/documents/$caseId/export');

  final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});

  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('Failed to export analysis PDF');
  }

  return res.bodyBytes;
}

/// --------------------
/// AI Agent Service
/// --------------------
Future<dynamic> sendAIMessage(String caseId, String userId, String message) async {
  if (caseId.isEmpty || userId.isEmpty || message.isEmpty) {
    throw Exception('caseId, userId, and message are required');
  }

  final token = await _getAuthToken();
  final uri = Uri.parse('$AI_AGENT_API_URL/chat/send');

  final res = await http.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({'caseId': caseId, 'userId': userId, 'message': message}),
  );

  if (res.statusCode < 200 || res.statusCode >= 300) {
    try {
      final err = jsonDecode(res.body);
      throw Exception(err['error'] ?? 'Failed to send message');
    } catch (_) {
      throw Exception('Failed to send AI message');
    }
  }

  return jsonDecode(res.body);
}

Future<dynamic> getAIChatHistory(String caseId) async {
  if (caseId.isEmpty) throw Exception('Case ID is required');

  final token = await _getAuthToken();
  final uri = Uri.parse('$AI_AGENT_API_URL/chat/history/$caseId');

  final res = await http.get(uri, headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $token',
  });

  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('Failed to fetch chat history');
  }

  return jsonDecode(res.body);
}

/// --------------------
/// Agents & Health
/// --------------------
Future<List<dynamic>> getAIAgents() async {
  final response = await request(AI_AGENT_API_URL, '/agents', method: 'GET');
  if (response is Map && response['agents'] != null) return response['agents'] as List<dynamic>;
  return response is List ? response : [];
}

Future<dynamic> getAIAgentHealth() async {
  final res = await http.get(Uri.parse('$AI_AGENT_API_URL/health'));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('AI Agent Service is not reachable');
  }
  return jsonDecode(res.body);
}

/// --------------------
/// Mock helpers
/// --------------------
const _mockDelay = Duration(milliseconds: 500);

Future<List<Map<String, dynamic>>> getMockDocuments(String caseId) async {
  await Future.delayed(_mockDelay);
  return [
    {
      'id': '1',
      'filename': 'contract.pdf',
      'caseId': caseId,
      'uploadedAt': DateTime.now().toIso8601String(),
      'pageCount': 5,
      'size': 1024000,
    }
  ];
}

Future<Map<String, dynamic>> uploadMockDocument(Map<String, dynamic> file, String caseId, String userId) async {
  await Future.delayed(Duration(seconds: 1));
  return {
    'id': DateTime.now().millisecondsSinceEpoch.toString(),
    'filename': file['name'] ?? 'file',
    'caseId': caseId,
    'uploadedAt': DateTime.now().toIso8601String(),
    'pageCount': 1,
    'size': file['size'] ?? 0,
    'uploadedBy': userId,
  };
}

/// --------------------
/// Utilities
/// --------------------
String? lookupMimeType(String path) {
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'txt':
      return 'text/plain';
    case 'rtf':
      return 'application/rtf';
    case 'csv':
      return 'text/csv';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    default:
      return null;
  }
}
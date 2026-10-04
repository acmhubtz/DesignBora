import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/utils/verification_labels.dart';

class _VerificationStatus {
  final String status;
  final String? note;
  final List<Map<String, dynamic>> documents;

  _VerificationStatus({
    required this.status,
    this.note,
    required this.documents,
  });

  factory _VerificationStatus.fromJson(Map<String, dynamic> json) {
    final docs = json['documents'];
    return _VerificationStatus(
      status: json['verificationStatus'] ?? 'PENDING',
      note: json['verificationNote'],
      documents: docs is List
          ? docs.whereType<Map<String, dynamic>>().toList()
          : const [],
    );
  }
}

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final ApiClient _apiClient = ApiClient();

  _VerificationStatus? _data;
  bool _loading = true;
  bool _uploading = false;
  String _documentType = 'NATIONAL_ID';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final response = await _apiClient.dio.get('/verification/status');
      if (!mounted) return;
      setState(() {
        _data = _VerificationStatus.fromJson(response.data['data']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.single;
    final messenger = ScaffoldMessenger.of(context);
    if (file.bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Imeshindwa kusoma faili')),
      );
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Faili ni kubwa mno. Kikomo ni 10MB')),
      );
      return;
    }

    setState(() => _uploading = true);
    try {
      await _apiClient.dio.post(
        '/verification/documents',
        data: FormData.fromMap({
          'documentType': _documentType,
          'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
        }),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Nyaraka imepakiwa. Admin ataikagua hivi karibuni.'),
          backgroundColor: AppColors.statusCompleted,
        ),
      );
      await _load();
    } catch (e) {
      String message = 'Imeshindwa kupakia nyaraka';
      try {
        final m = (e as dynamic).response?.data?['message'];
        if (m != null) message = m.toString();
      } catch (_) {}
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Uhakiki wa Akaunti'),
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : RefreshIndicator(
              color: AppColors.accent,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatusCard(),
                  const SizedBox(height: 20),
                  _buildUploadCard(),
                  const SizedBox(height: 20),
                  const Text(
                    'NYARAKA ULIZOPAKIA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if ((_data?.documents ?? []).isEmpty)
                    const Text(
                      'Bado hujapakia nyaraka.',
                      style: TextStyle(color: AppColors.textSecondary),
                    )
                  else
                    ..._data!.documents.map((doc) {
                      final style = verificationStyle(
                        doc['status'] ?? 'PENDING',
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: AppDecorations.card(radius: 14),
                          child: Row(
                            children: [
                              Icon(
                                Icons.description_rounded,
                                color: style.color,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  documentTypeLabel(
                                    doc['documentType'] ?? 'OTHER',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Text(
                                style.label,
                                style: TextStyle(
                                  color: style.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    final status = _data?.status ?? 'PENDING';
    final style = verificationStyle(status);
    final String message;
    switch (status) {
      case 'VERIFIED':
        message = 'Akaunti yako imethibitishwa. Wateja wanaona alama ya uthibitisho kwenye wasifu wako.';
      case 'REJECTED':
        message = 'Uhakiki haukukubaliwa. Rekebisha kulingana na sababu hapa chini, kisha pakia nyaraka mpya.';
      default:
        message = (_data?.documents ?? []).isEmpty
            ? 'Pakia kitambulisho chako (na leseni ya biashara kama ni kampuni) ili akaunti yako ihakikiwe.'
            : 'Nyaraka zako zinakaguliwa na admin. Utaona mabadiliko hapa.';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: style.color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(style.icon, color: style.color),
              const SizedBox(width: 8),
              Text(
                status == 'VERIFIED'
                    ? 'Umethibitishwa'
                    : status == 'REJECTED'
                    ? 'Umekataliwa'
                    : 'Inasubiri uhakiki',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: style.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(fontSize: 13, height: 1.4)),
          if (status == 'REJECTED' && (_data?.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Sababu: ${_data!.note}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Pakia nyaraka',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'Picha (JPG/PNG) au PDF, hadi 10MB. Hakikisha maandishi yanasomeka vizuri.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _documentType,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.badge_rounded, size: 20),
            ),
            items: documentTypes
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(documentTypeLabel(t)),
                  ),
                )
                .toList(),
            onChanged: _uploading
                ? null
                : (v) => setState(() => _documentType = v ?? 'NATIONAL_ID'),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _uploading ? null : _pickAndUpload,
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file_rounded, size: 20),
              label: Text(
                _uploading ? 'Inapakia...' : 'Chagua faili na upakie',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

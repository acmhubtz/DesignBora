import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../core/calls/call_manager.dart';

import '../../core/api/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/widgets/text_input_dialog.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/chat_message_model.dart';
import '../../models/draft_model.dart';
import '../../models/order_model.dart';
import '../auth/auth_provider.dart';
import 'chat_attachment.dart';
import 'draft_preview_screen.dart';
import 'draft_widgets.dart';
import 'order_service.dart';

class OrderChatScreen extends StatefulWidget {
  final int orderId;

  /// Jina la mtu wa upande mwingine (mbunifu kwa mteja, mteja kwa mbunifu)
  final String designerName;
  final String serviceTitle;

  const OrderChatScreen({
    super.key,
    required this.orderId,
    required this.designerName,
    required this.serviceTitle,
  });

  @override
  State<OrderChatScreen> createState() => _OrderChatScreenState();
}

class _OrderChatScreenState extends State<OrderChatScreen> {
  static const int _maxDraftBytes = 50 * 1024 * 1024; // 50MB, sawa na backend

  final ApiClient _apiClient = ApiClient();
  final OrderService _orderService = OrderService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  StompClient? _stompClient;
  List<ChatMessageModel> _messages = [];
  List<DraftModel> _drafts = [];
  bool _loadingHistory = true;
  bool _connected = false;
  bool _confirming = false;
  bool _uploadingDraft = false;
  bool _downloading = false;
  double _uploadProgress = 0;
  String _orderStatus = 'PAID';
  int? _myUserId;
  OrderModel? _order;

  @override
  void initState() {
    super.initState();
    _loadMyUserId();
    _loadHistory();
    _loadDrafts();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _stompClient?.deactivate();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------- Kupakia data ----------

  Future<void> _loadMyUserId() async {
    final id = await _apiClient.getUserId();
    if (!mounted) return;
    setState(() => _myUserId = id);
  }

  Future<void> _loadHistory() async {
    try {
      final response = await _apiClient.dio.get(
        '/orders/${widget.orderId}/messages',
      );
      final List data = response.data['data'];
      if (!mounted) return;
      setState(() {
        _messages = data
            .map((json) => ChatMessageModel.fromJson(json))
            .toList();
        _loadingHistory = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingHistory = false);
    }
  }

  Future<void> _loadDrafts() async {
    try {
      final drafts = await _orderService.getDrafts(widget.orderId);
      final order = await _orderService.getOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _drafts = drafts;
        _orderStatus = order.status;
        _order = order;
      });
    } catch (e) {
      // Kimya - drafts hazipo bado, ni kawaida
    }
  }

  // ---------- WebSocket ----------

  Future<void> _connectWebSocket() async {
    final token = await _apiClient.getToken();

    _stompClient = StompClient(
      config: StompConfig(
        url: ApiConstants.wsUrl,
        onConnect: _onConnect,
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        onWebSocketError: (error) => debugPrint('WebSocket error: $error'),
        onStompError: (frame) => debugPrint('STOMP error: ${frame.body}'),
      ),
    );

    _stompClient!.activate();
  }

  void _onConnect(StompFrame frame) {
    if (!mounted) return;
    setState(() => _connected = true);

    _stompClient!.subscribe(
      destination: '/topic/chat/${widget.orderId}',
      callback: (frame) {
        if (frame.body == null || !mounted) return;
        final json = jsonDecode(frame.body!);
        final message = ChatMessageModel.fromJson(json);
        setState(() => _messages.add(message));
        _scrollToBottom();
        // Draft mpya inaweza kuwa imetumwa - pakua upya orodha
        _loadDrafts();
      },
    );
  }

  bool _sendChatText(String text) {
    if (text.isEmpty || _stompClient == null || !_connected) return false;
    _stompClient!.send(
      destination: '/app/chat.send/${widget.orderId}',
      body: jsonEncode({'message': text}),
    );
    return true;
  }

  void _sendMessage() {
    if (_sendChatText(_messageController.text.trim())) {
      _messageController.clear();
    }
  }

  // ---------- Kuthibitisha (mteja) ----------

  Future<void> _confirmCompletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Thibitisha kazi?'),
        content: const Text(
          'Ukithibitisha, oda itakamilika na malipo yatatolewa kwa mbunifu. '
          'Hatua hii haiwezi kurudishwa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Ghairi',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Thibitisha',
              style: TextStyle(
                color: AppColors.statusCompleted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _confirming = true);
    try {
      final order = await _orderService.confirmCompletion(widget.orderId);
      if (!mounted) return;
      setState(() {
        _orderStatus = order.status;
        _order = order;
        _confirming = false;
      });
      _showSnack(
        'Umethibitisha! Sasa unaweza kupakua faili kamili.',
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      _showSnack(_extractError(e) ?? 'Imeshindwa kuthibitisha. Jaribu tena.');
    }
  }

  // ---------- Kutuma draft (mbunifu) ----------

  Future<void> _pickAndSubmitDraft() async {
    if (_uploadingDraft) return;

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(withData: true);
    } catch (e) {
      debugPrint('FilePicker error: $e');
      if (!mounted) return;
      _showSnack('Imeshindwa kufungua kichagua faili: $e');
      return;
    }
    if (result == null || result.files.isEmpty || !mounted) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _showSnack('Imeshindwa kusoma faili. Jaribu tena.');
      return;
    }
    if (file.size > _maxDraftBytes) {
      _showSnack('Faili ni kubwa mno. Kikomo ni 50MB.');
      return;
    }

    final confirmed = await _confirmDraftSheet(file.name, file.size);
    if (confirmed != true || !mounted) return;

    setState(() {
      _uploadingDraft = true;
      _uploadProgress = 0;
    });

    try {
      await _orderService.submitDraft(
        widget.orderId,
        bytes: bytes,
        fileName: file.name,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );
      if (!mounted) return;
      setState(() => _uploadingDraft = false);

      await _loadDrafts();
      final version = _drafts.isNotEmpty ? ' v${_drafts.last.versionNo}' : '';
      // Ujumbe huu unamjulisha mteja papo hapo na kufanya drafts zake zipakie upya
      _sendChatText('Nimetuma Draft$version. Tafadhali ikague.');
      if (!mounted) return;
      _showSnack('Draft imetumwa! Mteja amejulishwa.', success: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingDraft = false);
      _showSnack(_extractError(e) ?? 'Imeshindwa kutuma draft. Jaribu tena.');
    }
  }

  Future<bool?> _confirmDraftSheet(String name, int size) {
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : '';
    final previewable = DraftModel.previewableExtensions.contains(extension);

    return showModalBottomSheet<bool>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tuma Draft?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    FileTypeIcon(extension: extension, size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formatFileSize(size) ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    previewable
                        ? Icons.verified_user_rounded
                        : Icons.info_rounded,
                    size: 18,
                    color: previewable
                        ? AppColors.statusCompleted
                        : AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      previewable
                          ? 'Mteja ataona nakala yenye watermark. Faili kamili atalipata baada ya kuthibitisha.'
                          : 'Faili la aina hii halina preview. Mteja atalipakua baada ya kuthibitisha, '
                                'kwa hiyo fikiria kutuma pia picha ya mfano.',
                      style: const TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text('Ghairi'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.pop(sheetContext, true),
                        icon: const Icon(Icons.send_rounded, size: 18),
                        label: const Text(
                          'Tuma',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Preview na kupakua ----------

  Future<void> _openDraftPreview(DraftModel draft, bool isDesigner) async {
    final result = await Navigator.push<DraftPreviewResult>(
      context,
      MaterialPageRoute(
        builder: (_) => DraftPreviewScreen(
          orderId: widget.orderId,
          draft: draft,
          isDesigner: isDesigner,
          orderCompleted: _orderStatus == 'COMPLETED',
        ),
      ),
    );
    if (result == DraftPreviewResult.confirm && mounted) {
      _confirmCompletion();
    }
  }

  Future<void> _downloadLatest() async {
    if (_drafts.isEmpty || _downloading) return;
    setState(() => _downloading = true);
    await downloadDraftOriginal(
      context,
      _orderService,
      widget.orderId,
      _drafts.last,
    );
    if (mounted) setState(() => _downloading = false);
  }

  // ---------- Mgogoro (mteja) ----------

  Future<void> _openDispute() async {
    final reason = await showTextInputDialog(
      context,
      title: 'Fungua mgogoro',
      hint: 'Eleza tatizo: mfano kazi hailingani na tulichokubaliana...',
      confirmLabel: 'Fungua',
      confirmColor: Colors.red,
      maxLines: 4,
    );
    if (reason == null || !mounted) return;
    if (reason.length < 10) {
      _showSnack('Eleza tatizo kwa undani zaidi (angalau herufi 10)');
      return;
    }
    try {
      await _orderService.openDispute(widget.orderId, reason);
      if (!mounted) return;
      await _loadDrafts();
      if (!mounted) return;
      _showSnack(
        'Mgogoro umefunguliwa. DesignBora itakagua na kutoa uamuzi.',
        success: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(_extractError(e) ?? 'Imeshindwa kufungua mgogoro');
    }
  }

  // ---------- Kupiga simu ----------

  // ---------- Faili za chat ----------

  /// Mteja: faili la maelezo moja kwa moja. Mbunifu: achague Draft au faili la kawaida.
  Future<void> _onAttachPressed(bool isDesigner) async {
    if (!isDesigner) {
      await _pickAndSendAttachment();
      return;
    }
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.accent,
                ),
                title: const Text(
                  'Tuma kama Draft',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Kazi yako ili mteja aikague na kuithibitisha',
                ),
                onTap: () => Navigator.pop(sheetContext, 'draft'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.attach_file_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Faili la kawaida',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Mfano, maelezo au swali - si kazi ya kuthibitishwa',
                ),
                onTap: () => Navigator.pop(sheetContext, 'file'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'draft') await _pickAndSubmitDraft();
    if (choice == 'file') await _pickAndSendAttachment();
  }

  Future<void> _pickAndSendAttachment() async {
    if (_uploadingDraft) return;
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(withData: true);
    } catch (e) {
      debugPrint('FilePicker error: $e');
    }
    final file = result?.files.single;
    if (file == null || file.bytes == null || !mounted) return;
    if (file.size > kMaxAttachmentBytes) {
      _showSnack('Faili lisizidi MB 25');
      return;
    }

    setState(() {
      _uploadingDraft = true;
      _uploadProgress = 0;
    });
    try {
      await ChatAttachments.upload(
        orderId: widget.orderId,
        file: file,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );
      // Ujumbe wenye faili unafika kupitia WebSocket kama ujumbe mwingine wowote
    } catch (e) {
      String msg = 'Faili halikutumwa. Jaribu tena.';
      try {
        final d = (e as dynamic).response?.data;
        if (d != null && d['message'] != null) msg = d['message'].toString();
      } catch (_) {}
      if (mounted) _showSnack(msg);
    } finally {
      if (mounted) setState(() => _uploadingDraft = false);
    }
  }

  Future<void> _callOtherParty(bool isDesigner) async {
    if (kIsWeb) {
      _showSnack('Simu za sauti zinapatikana kwenye app ya simu tu');
      return;
    }
    if (CallManager.instance.busy) {
      _showSnack('Tayari uko kwenye simu');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Piga simu ya sauti kwa ${widget.designerName}?'),
        content: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_rounded, size: 18, color: AppColors.accentDark),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Simu inapigwa ndani ya DesignBora: namba zenu za simu hazionekani. '
                  'Simu hazirekodiwi, kwa hiyo makubaliano yoyote (mabadiliko ya kazi, muda, bei) '
                  'yaandikeni pia hapa kwenye chat ili yawe ushahidi kama kutatokea mgogoro.',
                  style: TextStyle(fontSize: 12.5, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Ghairi',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Piga',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await CallManager.instance.startOutgoing(
      orderId: widget.orderId,
      otherName: widget.designerName,
    );
  }

  // ---------- Wasaidizi ----------

  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.statusCompleted : null,
      ),
    );
  }

  String? _extractError(Object e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data != null && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}
    return null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final latestDraft = _drafts.isNotEmpty ? _drafts.last : null;
    final isDesigner = context.watch<AuthProvider>().user?.role == 'DESIGNER';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        titleSpacing: 0,
        title: Row(
          children: [
            UserAvatar(
              name: widget.designerName,
              avatarUrl: isDesigner
                  ? _order?.customerAvatarUrl
                  : _order?.designerAvatarUrl,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.designerName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _connected
                              ? AppColors.statusCompleted
                              : AppColors.textMuted,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _connected
                              ? 'Oda #${widget.orderId} • ${widget.serviceTitle}'
                              : 'Inaunganisha...',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_orderStatus != 'COMPLETED')
            IconButton(
              tooltip: 'Piga simu',
              onPressed: () => _callOtherParty(isDesigner),
              icon: const Icon(Icons.call_rounded, color: AppColors.primary),
            ),
          if (!isDesigner &&
              const [
                'PAID',
                'IN_PROGRESS',
                'DRAFT_SUBMITTED',
              ].contains(_orderStatus))
            PopupMenuButton<String>(
              tooltip: 'Zaidi',
              onSelected: (value) {
                if (value == 'dispute') _openDispute();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'dispute',
                  child: ListTile(
                    leading: Icon(
                      Icons.report_problem_rounded,
                      color: Colors.red,
                    ),
                    title: Text('Fungua mgogoro'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 8),
            child: Center(child: _StatusBadge(status: _orderStatus)),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_orderStatus == 'DISPUTED')
            const _DisputeBanner()
          else if (_orderStatus == 'COMPLETED')
            _CompletedBanner(
              downloading: _downloading,
              onDownload: _drafts.isNotEmpty ? _downloadLatest : null,
            )
          else if (latestDraft != null)
            _DraftBanner(
              draft: latestDraft,
              confirming: _confirming,
              canConfirm: !isDesigner,
              onConfirm: _confirmCompletion,
              onPreview: () => _openDraftPreview(latestDraft, isDesigner),
            ),
          Expanded(
            child: _loadingHistory
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : _messages.isEmpty
                ? const _EmptyChat()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isMine = _myUserId != null
                          ? message.senderId == _myUserId
                          : message.senderName != widget.designerName;
                      return _ChatBubble(message: message, isMine: isMine);
                    },
                  ),
          ),
          if (_uploadingDraft) _buildUploadProgress(),
          if (_orderStatus != 'COMPLETED' && _orderStatus != 'CANCELLED')
            _buildInputBar(isDesigner),
        ],
      ),
    );
  }

  Widget _buildUploadProgress() {
    final percent = (_uploadProgress * 100).toStringAsFixed(0);
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _uploadProgress > 0
                ? 'Inatuma draft... $percent%'
                : 'Inatuma draft...',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _uploadProgress > 0 ? _uploadProgress : null,
              minHeight: 4,
              color: AppColors.accent,
              backgroundColor: AppColors.background,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isDesigner) {
    const inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(24)),
      borderSide: BorderSide.none,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              tooltip: 'Ambatisha faili',
              onPressed: _uploadingDraft
                  ? null
                  : () => _onAttachPressed(isDesigner),
              icon: const Icon(
                Icons.attach_file_rounded,
                color: AppColors.primary,
              ),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Andika ujumbe...',
                  filled: true,
                  fillColor: AppColors.background,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: inputBorder,
                  enabledBorder: inputBorder,
                  focusedBorder: inputBorder,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: _connected ? AppColors.accent : AppColors.textMuted,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _connected ? _sendMessage : null,
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------- Banners ----------

class _DraftBanner extends StatelessWidget {
  final DraftModel draft;
  final bool confirming;
  final bool canConfirm;
  final VoidCallback onConfirm;
  final VoidCallback onPreview;

  const _DraftBanner({
    required this.draft,
    required this.confirming,
    required this.canConfirm,
    required this.onConfirm,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: AppDecorations.card(radius: 16),
      child: Column(
        children: [
          InkWell(
            onTap: onPreview,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                DraftThumbnail(draft: draft, size: 60),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'v${draft.versionNo}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Flexible(
                            child: Text(
                              'Draft mpya imetumwa',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        draft.detailsLabel,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        canConfirm
                            ? 'Iangalie, kisha thibitisha ukiridhika'
                            : 'Inasubiri mteja aikague na kuthibitisha',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: onPreview,
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: const Text(
                      'Angalia',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              if (canConfirm) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusCompleted,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: confirming ? null : onConfirm,
                      icon: confirming
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text(
                        'Thibitisha',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  final bool downloading;
  final VoidCallback? onDownload;

  const _CompletedBanner({required this.downloading, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusCompleted.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.statusCompleted,
                size: 22,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Oda imekamilika!',
                      style: TextStyle(
                        color: AppColors.statusCompleted,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Faili kamili (bila watermark) liko tayari.',
                      style: TextStyle(
                        color: AppColors.statusCompleted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onDownload != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusCompleted,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: downloading ? null : onDownload,
                icon: downloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: const Text(
                  'Pakua Faili Kamili',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 52, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'Anza mazungumzo',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            SizedBox(height: 4),
            Text(
              'Elezeni mahitaji ya kazi: rangi, maandishi, ukubwa na mtindo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  Color get _color {
    switch (status) {
      case 'PAID':
        return AppColors.statusPaid;
      case 'IN_PROGRESS':
        return AppColors.statusInProgress;
      case 'DRAFT_SUBMITTED':
        return AppColors.statusDraftSubmitted;
      case 'COMPLETED':
        return AppColors.statusCompleted;
      case 'DISPUTED':
        return AppColors.statusDisputed;
      case 'CANCELLED':
        return AppColors.textMuted;
      default:
        return AppColors.textSecondary;
    }
  }

  String get _label {
    switch (status) {
      case 'PAID':
        return 'Imelipwa';
      case 'IN_PROGRESS':
        return 'Inaendelea';
      case 'DRAFT_SUBMITTED':
        return 'Draft';
      case 'COMPLETED':
        return 'Imekamilika';
      case 'DISPUTED':
        return 'Mgogoro';
      case 'CANCELLED':
        return 'Imeghairiwa';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool isMine;

  const _ChatBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMine ? AppColors.primary : AppColors.surface,
            border: isMine ? null : Border.all(color: AppColors.border),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isMine) ...[
                Text(
                  message.senderName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentDark,
                  ),
                ),
                const SizedBox(height: 3),
              ],
              ChatMessageBody(
                message: message,
                text: Text(
                  message.message,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: isMine ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisputeBanner extends StatelessWidget {
  const _DisputeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusDisputed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.statusDisputed.withValues(alpha: 0.3),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel_rounded, color: AppColors.statusDisputed),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mgogoro unakaguliwa',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.statusDisputed,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Pesa imeshikiliwa salama. Timu ya DesignBora inakagua mazungumzo na kazi, '
                  'na itatoa uamuzi hapa kwenye chat.',
                  style: TextStyle(fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

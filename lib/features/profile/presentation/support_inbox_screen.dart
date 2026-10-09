import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app/app_providers.dart';
import '../../../core/config/app_config.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/services/api_client.dart';
import '../../../core/theme/mohajon_warm_theme.dart';
import '../../../core/utils/app_error.dart';

/// A server-backed, single-attachment support conversation. It intentionally
/// stays online-only: a support ticket must reach Mohajon's team immediately.
class SupportInboxScreen extends ConsumerStatefulWidget {
  const SupportInboxScreen({super.key});

  @override
  ConsumerState<SupportInboxScreen> createState() => _SupportInboxScreenState();
}

class _SupportInboxScreenState extends ConsumerState<SupportInboxScreen> {
  final _messageController = TextEditingController();
  final _picker = ImagePicker();
  List<Map<String, dynamic>> _tickets = const [];
  List<Map<String, dynamic>> _messages = const [];
  Map<String, dynamic>? _selectedTicket;
  File? _image;
  bool _supportAdmin = false;
  bool _loading = true;
  bool _sending = false;
  bool _hasOlderMessages = false;
  bool _hasMoreTickets = false;
  int _messagePage = 0;
  int _ticketPage = 0;

  ApiClient get _api => ApiClient(ref.read(localDatabaseProvider));

  @override
  void initState() {
    super.initState();
    _loadInbox();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadInbox({bool more = false}) async {
    if (!more) setState(() => _loading = true);
    try {
      final access = await _api.get('/api/v1/support/access');
      _supportAdmin = access['supportAdmin'] == true;
      final page = more ? _ticketPage + 1 : 0;
      final data = await _api.get(
        _supportAdmin
            ? '/api/v1/support/admin/tickets'
            : '/api/v1/support/tickets',
        query: {'page': '$page', 'size': '30'},
      );
      if (!mounted) return;
      setState(() {
        final fetched = _mapList(data['items']);
        _tickets = more ? [..._tickets, ...fetched] : fetched;
        _ticketPage = page;
        _hasMoreTickets = data['hasMore'] == true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(
        friendlyErrorMessage(error, l10n: AppLocalizations.of(context)),
        true,
      );
    }
  }

  Future<void> _openTicket(Map<String, dynamic> ticket) async {
    setState(() {
      _selectedTicket = ticket;
      _messages = const [];
      _messagePage = 0;
      _hasOlderMessages = false;
      _loading = true;
    });
    await _loadMessages();
  }

  Future<void> _loadMessages({bool older = false}) async {
    final ticketId = _selectedTicket?['ticketId']?.toString();
    if (ticketId == null) return;
    final page = older ? _messagePage + 1 : 0;
    try {
      final data = await _api.get(
        '/api/v1/support/tickets/$ticketId/messages',
        query: {'page': '$page', 'size': '30'},
      );
      if (!mounted) return;
      final newestFirst = _mapList(data['items']);
      setState(() {
        final fetched = newestFirst.reversed.toList();
        _messages = older ? [...fetched, ..._messages] : fetched;
        _selectedTicket = data['ticket'] is Map<String, dynamic>
            ? data['ticket'] as Map<String, dynamic>
            : _selectedTicket;
        _messagePage = page;
        _hasOlderMessages = data['hasMore'] == true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _toast(
        friendlyErrorMessage(error, l10n: AppLocalizations.of(context)),
        true,
      );
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 84,
      maxWidth: 1800,
    );
    if (picked != null && mounted) setState(() => _image = File(picked.path));
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final message = _messageController.text.trim();
    if (message.isEmpty && _image == null) {
      _toast(l10n.t('supportMessageRequired'), true);
      return;
    }
    if (!await ref.read(syncServiceProvider).isOnline) {
      if (mounted) _toast(l10n.t('supportInternetRequired'), true);
      return;
    }
    setState(() => _sending = true);
    try {
      String? imageUrl;
      if (_image != null) {
        final uploaded = await _api.uploadFile('/api/v1/files', _image!);
        imageUrl = uploaded['url']?.toString();
        if (imageUrl == null || imageUrl.isEmpty) {
          throw StateError('Image upload failed');
        }
      }
      final selectedId = _selectedTicket?['ticketId']?.toString();
      if (selectedId == null) {
        final created = await _api.post('/api/v1/support/tickets', {
          'message': message,
          'imageUrl': imageUrl,
        });
        if (mounted) await _openTicket(created);
      } else {
        final endpoint = _supportAdmin
            ? '/api/v1/support/admin/tickets/$selectedId/messages'
            : '/api/v1/support/tickets/$selectedId/messages';
        await _api.post(endpoint, {'message': message, 'imageUrl': imageUrl});
        if (mounted) await _loadMessages();
      }
      if (!mounted) return;
      _messageController.clear();
      setState(() => _image = null);
      _toast(l10n.t('supportSent'));
      await _loadInbox();
    } catch (error) {
      if (mounted) _toast(friendlyErrorMessage(error, l10n: l10n), true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _toast(String text, [bool error = false]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? MohajonWarm.red : MohajonWarm.ink,
        behavior: SnackBarBehavior.floating,
        content: Text(text),
      ),
    );
  }

  List<Map<String, dynamic>> _mapList(Object? value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : const [];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = _selectedTicket;
    return Theme(
      data: MohajonWarm.theme(Theme.of(context), locale: l10n.locale),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: MohajonWarm.pageGradient),
          child: SafeArea(
            child: Column(
              children: [
                _SupportHeader(
                  title: selected == null
                      ? (_supportAdmin
                            ? l10n.t('supportAdminInbox')
                            : l10n.t('supportInbox'))
                      : selected['shopName']?.toString() ??
                            l10n.t('supportInbox'),
                  subtitle: selected == null
                      ? l10n.t('supportInboxSubtitle')
                      : l10n.t('supportReplied'),
                  onBack: selected == null
                      ? () => Navigator.of(context).maybePop()
                      : () => setState(() => _selectedTicket = null),
                ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : selected == null
                      ? _TicketList(
                          tickets: _tickets,
                          isAdmin: _supportAdmin,
                          onOpen: _openTicket,
                          emptyTitle: _supportAdmin
                              ? l10n.t('supportAdminEmpty')
                              : l10n.t('supportEmpty'),
                          emptyHint: l10n.t('supportEmptyHint'),
                          hasMore: _hasMoreTickets,
                          onLoadMore: () => _loadInbox(more: true),
                        )
                      : _Conversation(
                          messages: _messages,
                          hasOlder: _hasOlderMessages,
                          onLoadOlder: () => _loadMessages(older: true),
                          isAdmin: _supportAdmin,
                        ),
                ),
                _Composer(
                  controller: _messageController,
                  image: _image,
                  sending: _sending,
                  enabled: selected != null || !_supportAdmin,
                  onImage: _pickImage,
                  onRemoveImage: () => setState(() => _image = null),
                  onSend: _send,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportHeader extends StatelessWidget {
  const _SupportHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: MohajonWarm.primary.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.support_agent_rounded,
            color: MohajonWarm.primary,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: MohajonWarm.ink,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: MohajonWarm.muted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TicketList extends StatelessWidget {
  const _TicketList({
    required this.tickets,
    required this.isAdmin,
    required this.onOpen,
    required this.emptyTitle,
    required this.emptyHint,
    required this.hasMore,
    required this.onLoadMore,
  });
  final List<Map<String, dynamic>> tickets;
  final bool isAdmin;
  final ValueChanged<Map<String, dynamic>> onOpen;
  final String emptyTitle;
  final String emptyHint;
  final bool hasMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.forum_outlined,
                size: 52,
                color: MohajonWarm.primary,
              ),
              const SizedBox(height: 12),
              Text(
                emptyTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                emptyHint,
                textAlign: TextAlign.center,
                style: const TextStyle(color: MohajonWarm.muted, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: tickets.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        if (index == tickets.length) {
          return Center(
            child: TextButton(
              onPressed: onLoadMore,
              child: Text(AppLocalizations.of(context).t('supportLoadOlder')),
            ),
          );
        }
        final ticket = tickets[index];
        final replied = ticket['status']?.toString() == 'WAITING_FOR_OWNER';
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () => onOpen(ticket),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: MohajonWarm.goldBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (replied ? MohajonWarm.green : MohajonWarm.orange)
                          .withValues(alpha: .13),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      replied
                          ? Icons.mark_email_read_rounded
                          : Icons.mark_email_unread_rounded,
                      color: replied ? MohajonWarm.green : MohajonWarm.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAdmin
                              ? ticket['shopName']?.toString() ?? ''
                              : replied
                              ? AppLocalizations.of(context).t('supportReplied')
                              : AppLocalizations.of(context).t('supportOpen'),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: MohajonWarm.ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ticket['preview']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: MohajonWarm.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: MohajonWarm.muted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({
    required this.messages,
    required this.hasOlder,
    required this.onLoadOlder,
    required this.isAdmin,
  });
  final List<Map<String, dynamic>> messages;
  final bool hasOlder;
  final VoidCallback onLoadOlder;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
    children: [
      if (hasOlder)
        Center(
          child: TextButton(
            onPressed: onLoadOlder,
            child: Text(AppLocalizations.of(context).t('supportLoadOlder')),
          ),
        ),
      ...messages.map(
        (message) => _MessageBubble(
          message: message,
          mine: (message['senderType'] == 'ADMIN') == isAdmin,
        ),
      ),
    ],
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.mine});
  final Map<String, dynamic> message;
  final bool mine;

  // The app canvas is warm yellow, so an outgoing yellow bubble visually
  // disappears into it. This deep jade keeps the premium warm palette while
  // giving the shop owner's message a calm, unmistakable conversation state.
  static const _outgoingJade = Color(0xFF155C59);

  @override
  Widget build(BuildContext context) {
    final body = message['body']?.toString() ?? '';
    final image = message['imageUrl']?.toString() ?? '';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 290),
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: mine ? _outgoingJade : const Color(0xFFFFFEFA),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: mine ? const Radius.circular(4) : null,
            bottomLeft: mine ? null : const Radius.circular(4),
          ),
          border: mine
              ? Border.all(color: const Color(0xFF0F4947))
              : Border.all(color: MohajonWarm.goldBorder),
          boxShadow: [
            BoxShadow(
              color: mine
                  ? const Color(0xFF155C59).withValues(alpha: .20)
                  : const Color(0xFF604E1C).withValues(alpha: .06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (body.isNotEmpty)
              Text(
                body,
                style: TextStyle(
                  color: mine ? Colors.white : MohajonWarm.ink,
                  height: 1.35,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (image.isNotEmpty) ...[
              if (body.isNotEmpty) const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  '${AppConfig.apiBaseUrl}$image',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 80,
                    width: 150,
                    child: Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.image,
    required this.sending,
    required this.enabled,
    required this.onImage,
    required this.onRemoveImage,
    required this.onSend,
  });
  final TextEditingController controller;
  final File? image;
  final bool sending;
  final bool enabled;
  final VoidCallback onImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: MohajonWarm.goldBorder)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        image!,
                        width: 62,
                        height: 62,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: -7,
                      top: -7,
                      child: InkWell(
                        onTap: onRemoveImage,
                        child: const CircleAvatar(
                          radius: 11,
                          backgroundColor: MohajonWarm.red,
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (image != null) const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  onPressed: enabled && !sending ? onImage : null,
                  tooltip: l10n.t('supportAttachImage'),
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: MohajonWarm.primary,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: enabled && !sending,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: enabled
                          ? l10n.t('supportMessageHint')
                          : l10n.t('supportAdminEmpty'),
                      isDense: true,
                      filled: true,
                      fillColor: MohajonWarm.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 44,
                  height: 44,
                  child: FilledButton(
                    onPressed: enabled && !sending ? onSend : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: MohajonWarm.primary,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

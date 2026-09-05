import 'enums.dart';
import 'user.dart';

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class MessageAttachment {
  MessageAttachment({
    required this.id,
    required this.url,
    this.fileName,
    this.fileType,
    this.fileSize,
    this.durationSeconds,
  });

  final int id;
  final String url;
  final String? fileName;
  final String? fileType;
  final int? fileSize;
  final int? durationSeconds;

  bool get isImage => (fileType ?? '').startsWith('image/');
  bool get isVoice => (fileType ?? '').startsWith('audio/');
  bool get isVideo => (fileType ?? '').startsWith('video/');
  bool get isDocument => !isImage && !isVoice && !isVideo;

  factory MessageAttachment.fromJson(Map<String, dynamic> j) =>
      MessageAttachment(
        id: (j['id'] as num).toInt(),
        url: j['url'] as String? ?? '',
        fileName: j['file_name'] as String?,
        fileType: j['file_type'] as String?,
        fileSize: (j['file_size'] as num?)?.toInt(),
        durationSeconds: (j['duration_seconds'] as num?)?.toInt(),
      );
}

class MessageReplyPreview {
  MessageReplyPreview({
    required this.id,
    this.senderName,
    this.body,
    this.deleted = false,
  });

  final int id;
  final String? senderName;
  final String? body;
  final bool deleted;

  factory MessageReplyPreview.fromJson(Map<String, dynamic> j) =>
      MessageReplyPreview(
        id: (j['id'] as num).toInt(),
        senderName: j['sender_name'] as String?,
        body: j['body'] as String?,
        deleted: j['deleted'] as bool? ?? false,
      );
}

class MessageReaction {
  MessageReaction({
    required this.emoji,
    required this.count,
    required this.mine,
  });

  final String emoji;
  final int count;
  final bool mine;

  factory MessageReaction.fromJson(Map<String, dynamic> j) => MessageReaction(
    emoji: j['emoji'] as String,
    count: (j['count'] as num).toInt(),
    mine: j['mine'] as bool? ?? false,
  );
}

class Message {
  Message({
    required this.id,
    required this.conversationId,
    required this.kind,
    required this.createdAt,
    this.senderId,
    this.sender,
    this.body,
    this.readBy = const [],
    this.attachments = const [],
    this.reactions = const [],
    this.replyTo,
    this.deleted = false,
    this.pending = false,
  });

  final int id;
  final int conversationId;
  final int? senderId;
  final User? sender;
  final String? body;
  final MessageKind kind;
  final List<int> readBy;
  final List<MessageAttachment> attachments;
  final List<MessageReaction> reactions;
  final MessageReplyPreview? replyTo;
  final bool deleted;
  final DateTime createdAt;
  final bool pending;

  factory Message.fromJson(Map<String, dynamic> j) => Message(
    id: (j['id'] as num).toInt(),
    conversationId: (j['conversation_id'] as num).toInt(),
    senderId: (j['sender_id'] as num?)?.toInt(),
    sender: j['sender'] is Map ? User.fromJson(j['sender']) : null,
    body: j['body'] as String?,
    kind: MessageKind.from(j['type'] as String?),
    readBy: (j['read_by'] as List? ?? const [])
        .map((e) => (e as num).toInt())
        .toList(),
    attachments: (j['attachments'] as List? ?? const [])
        .map((e) => MessageAttachment.fromJson(e as Map<String, dynamic>))
        .toList(),
    reactions: (j['reactions'] as List? ?? const [])
        .map((e) => MessageReaction.fromJson(e as Map<String, dynamic>))
        .toList(),
    replyTo: j['reply_to'] is Map
        ? MessageReplyPreview.fromJson(j['reply_to'] as Map<String, dynamic>)
        : null,
    deleted: j['deleted'] as bool? ?? false,
    createdAt: _date(j['created_at']) ?? DateTime.now(),
  );
}

class Conversation {
  Conversation({
    required this.id,
    required this.type,
    this.name,
    this.departmentId,
    this.createdBy,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.participants = const [],
    this.participantRoles = const {},
    this.latestMessage,
  });

  final int id;
  final ConversationType type;
  final String? name;
  final int? departmentId;
  final int? createdBy;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final List<User> participants;
  final Map<int, String> participantRoles;
  final Message? latestMessage;

  bool isAdmin(int userId) =>
      participantRoles[userId] == 'admin' || createdBy == userId;

  /// Display title: channel/group name, or the "other" participant for a DM.
  String titleFor(int currentUserId) {
    if (name != null && name!.isNotEmpty) return name!;
    final other = participants.where((p) => p.id != currentUserId).toList();
    return other.isEmpty
        ? 'Direct message'
        : other.map((p) => p.name).join(', ');
  }

  User? otherParticipant(int currentUserId) =>
      participants.where((p) => p.id != currentUserId).firstOrNull;

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
    id: (j['id'] as num).toInt(),
    type: ConversationType.from(j['type'] as String?),
    name: j['name'] as String?,
    departmentId: (j['department_id'] as num?)?.toInt(),
    createdBy: (j['created_by'] as num?)?.toInt(),
    lastMessageAt: _date(j['last_message_at']),
    unreadCount: (j['unread_count'] as num?)?.toInt() ?? 0,
    participants: (j['participants'] as List? ?? const [])
        .map((e) => User.fromJson(e as Map<String, dynamic>))
        .toList(),
    participantRoles: {
      for (final e in (j['participants'] as List? ?? const []))
        if (e is Map && e['id'] != null)
          (e['id'] as num).toInt():
              e['conversation_role'] as String? ?? 'member',
    },
    latestMessage: j['latest_message'] is Map
        ? Message.fromJson(j['latest_message'] as Map<String, dynamic>)
        : null,
  );

  Conversation copyWith({
    int? unreadCount,
    Message? latestMessage,
    DateTime? lastMessageAt,
  }) => Conversation(
    id: id,
    type: type,
    name: name,
    departmentId: departmentId,
    createdBy: createdBy,
    lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    unreadCount: unreadCount ?? this.unreadCount,
    participants: participants,
    participantRoles: participantRoles,
    latestMessage: latestMessage ?? this.latestMessage,
  );
}

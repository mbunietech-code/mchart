import 'package:flutter/material.dart';

import '../../theme/app_color.dart';

/// Built-in sticker pack. A sticker message stores only the id; the app
/// draws it, so there are no image assets to host or download.
class ChatSticker {
  const ChatSticker(this.id, this.emoji, this.caption, this.color);
  final String id;
  final String emoji;
  final String caption;
  final Color color;
}

const chatStickers = <ChatSticker>[
  ChatSticker('thumbs_up', '👍', 'Got it!', AppColor.brand),
  ChatSticker('done', '✅', 'Done', AppColor.success),
  ChatSticker('thanks', '🙏', 'Thank you', Color(0xFF7C3AED)),
  ChatSticker('congrats', '🎉', 'Congrats!', Color(0xFFDB2777)),
  ChatSticker('on_it', '💪', 'On it', AppColor.urgent),
  ChatSticker('meeting', '📅', 'Meeting time', AppColor.navy),
  ChatSticker('coffee', '☕', 'Coffee break', Color(0xFF92400E)),
  ChatSticker('urgent', '🚨', 'Urgent!', AppColor.danger),
  ChatSticker('good_morning', '🌅', 'Good morning', Color(0xFFD97706)),
  ChatSticker('good_night', '🌙', 'Good night', Color(0xFF4338CA)),
  ChatSticker('love_it', '😍', 'Love it', Color(0xFFE11D48)),
  ChatSticker('haha', '😂', 'Haha', Color(0xFFCA8A04)),
  ChatSticker('thinking', '🤔', 'Let me think', AppColor.slate),
  ChatSticker('wait', '⏳', 'One moment', Color(0xFF0E7490)),
  ChatSticker('approved', '👌', 'Approved', Color(0xFF15803D)),
  ChatSticker('welcome', '👋', 'Karibu!', Color(0xFF0369A1)),
];

ChatSticker? stickerById(String? id) =>
    chatStickers.where((s) => s.id == id).firstOrNull;

/// How a sticker message renders: big, no bubble.
class StickerView extends StatelessWidget {
  const StickerView({super.key, required this.stickerId, this.size = 120});
  final String? stickerId;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = stickerById(stickerId);
    if (s == null) {
      return const Text('Sticker', style: TextStyle(color: AppColor.textMuted));
    }
    return SizedBox(
      width: size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.emoji, style: TextStyle(fontSize: size * 0.5, height: 1.1)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: s.color,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              s.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _emojiGroups = <String, String>{
  'Smileys':
      '😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 😉 😌 😍 🥰 😘 😋 😛 😜 🤪 😎 🤩 🥳 😏 😒 😞 😔 😟 😕 🙁 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🤗 🤔 🤭 🤫 🤥 😶 😐 😑 😬 🙄 😯 😦 😧 😮 😲 🥱 😴 🤤 😪 😵 🤐 🥴 🤢 🤮 🤧 😷 🤒 🤕',
  'Gestures':
      '👍 👎 👌 ✌️ 🤞 🤟 🤘 🤙 👈 👉 👆 👇 ☝️ ✋ 🤚 🖐️ 🖖 👋 👏 🙌 👐 🤲 🤝 🙏 ✍️ 💪 🫡 🫶',
  'Hearts': '❤️ 🧡 💛 💚 💙 💜 🖤 🤍 🤎 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝',
  'Work':
      '✅ ☑️ ✔️ ❌ ⚠️ 🚨 📌 📍 📅 📆 🗓️ ⏰ ⏳ ⌛ 📝 📄 📊 📈 📉 💼 📁 📂 🗂️ 💻 🖥️ 📱 ☎️ 📞 📧 📨 🔔 🔕 💡 🔧 🛠️ 🔒 🔑 🏆 🎯 🚀 🔥 ⭐ ✨',
  'Food & fun':
      '☕ 🍵 🥤 🍔 🍕 🍟 🌮 🍰 🎂 🍎 🍌 🍉 🎉 🎊 🎁 🎈 ⚽ 🏀 🎵 🎶 📸 ✈️ 🚗 🏠 🌍 🌞 🌙 🌧️ ⛈️ 🌈',
};

/// Bottom panel with an emoji grid and the sticker pack. [onEmoji] inserts
/// into the composer; [onSticker] sends right away.
class EmojiStickerPanel extends StatelessWidget {
  const EmojiStickerPanel({
    super.key,
    required this.onEmoji,
    required this.onSticker,
  });
  final ValueChanged<String> onEmoji;
  final ValueChanged<ChatSticker> onSticker;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SizedBox(
        height: 300,
        child: Column(
          children: [
            const TabBar(
              tabs: [
                Tab(text: 'Emoji'),
                Tab(text: 'Stickers'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      for (final g in _emojiGroups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
                          child: Text(
                            g.key,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        Wrap(
                          children: [
                            for (final e in g.value.split(' '))
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => onEmoji(e),
                                child: SizedBox(
                                  width: 42,
                                  height: 42,
                                  child: Center(
                                    child: Text(
                                      e,
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  GridView.count(
                    crossAxisCount: 4,
                    padding: const EdgeInsets.all(10),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: [
                      for (final s in chatStickers)
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => onSticker(s),
                          child: Center(
                            child: StickerView(stickerId: s.id, size: 70),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

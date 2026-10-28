<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\MessageType;
use App\Events\MessageSent;
use App\Events\UserTyping;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreMessageRequest;
use App\Http\Resources\MessageResource;
use App\Models\Conversation;
use App\Models\Message;
use App\Services\AttachmentStorage;
use App\Services\NotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class MessageController extends Controller
{
    /** Same window WhatsApp gives. */
    public const EDIT_WINDOW_MINUTES = 15;

    public function __construct(
        private readonly AttachmentStorage $storage,
        private readonly NotificationService $notifications,
    ) {
    }

    public function index(Request $request, Conversation $conversation): AnonymousResourceCollection
    {
        $this->authorize('view', $conversation);

        $messages = $conversation->messages()
            ->whereNotIn('id', DB::table('hidden_messages')->where('user_id', $request->user()->id)->select('message_id'))
            ->with(['sender', 'attachments', 'replyTo.sender', 'reactions'])
            ->latest('id')
            ->when($request->filled('before'), fn ($q) => $q->where('id', '<', $request->integer('before')))
            // In-chat search: matching text messages, newest first.
            ->when($request->filled('search'), fn ($q) => $q->whereNull('deleted_at')
                ->where('body', 'like', '%'.addcslashes($request->string('search'), '%_'.chr(92)).'%'))
            ->limit($request->integer('limit', 30))
            ->get()
            ->reverse()
            ->values();

        return MessageResource::collection($messages);
    }

    public function store(StoreMessageRequest $request, Conversation $conversation): JsonResponse
    {
        $this->authorize('sendMessage', $conversation);

        $files = $request->file('attachments', []);
        $type = $request->input('type');
        if (! $type) {
            $type = $files ? $this->typeFor($files[0]->getClientMimeType()) : MessageType::Text->value;
        }

        // Forwarding copies another message the sender can see.
        $source = null;
        if ($request->filled('forward_message_id')) {
            $source = Message::with('attachments', 'conversation')->findOrFail($request->integer('forward_message_id'));
            $this->authorize('view', $source->conversation);
            abort_if($source->isDeleted(), 422, 'A deleted message cannot be forwarded.');
            $type = $source->type->value;
        }

        $message = DB::transaction(function () use ($request, $conversation, $files, $type, $source) {
            $message = $conversation->messages()->create([
                'sender_id' => $request->user()->id,
                'reply_to_id' => $source ? null : $request->input('reply_to_id'),
                'forwarded' => $source !== null,
                'body' => $source ? $source->body : $request->input('body'),
                'type' => $type,
                'read_by' => [$request->user()->id],
            ]);

            foreach ($source?->attachments ?? [] as $a) {
                $message->attachments()->create([
                    'file_path' => $this->storage->copy($a->file_path, "conversations/{$conversation->id}"),
                    'file_name' => $a->file_name,
                    'file_type' => $a->file_type,
                    'file_size' => $a->file_size,
                    'duration_seconds' => $a->duration_seconds,
                ]);
            }

            foreach ($files as $i => $file) {
                $meta = $this->storage->store($file, "conversations/{$conversation->id}");
                $message->attachments()->create([
                    ...$meta,
                    'duration_seconds' => $request->input("attachment_meta.$i.duration_seconds"),
                ]);
            }

            $conversation->forceFill(['last_message_at' => now()])->save();
            $conversation->participants()
                ->where('user_id', $request->user()->id)
                ->update(['last_read_at' => now()]);

            return $message;
        });

        broadcast(new MessageSent($message))->toOthers();

        $this->notifyParticipants($conversation, $message);

        return (new MessageResource($message->load('sender', 'attachments', 'replyTo.sender', 'reactions')))
            ->response()
            ->setStatusCode(201);
    }

    private function typeFor(string $mime): string
    {
        return match (true) {
            Str::startsWith($mime, 'image/') => MessageType::Image->value,
            Str::startsWith($mime, 'audio/') => MessageType::Voice->value,
            default => MessageType::File->value,
        };
    }

    public function typing(Request $request, Conversation $conversation): JsonResponse
    {
        $this->authorize('sendMessage', $conversation);

        broadcast(new UserTyping($conversation->id, $request->user()))->toOthers();

        return response()->json(['message' => 'ok']);
    }

    public function markRead(Request $request, Conversation $conversation): JsonResponse
    {
        $this->authorize('view', $conversation);
        $userId = $request->user()->id;

        $conversation->participants()
            ->where('user_id', $userId)
            ->update(['last_read_at' => now()]);

        // Append this user to read_by for every not-yet-read message from
        // someone else, so senders see an accurate "read" (double-check) state.
        $conversation->messages()
            ->where('sender_id', '!=', $userId)
            ->whereJsonDoesntContain('read_by', $userId)
            ->get()
            ->each(function (Message $message) use ($userId) {
                $message->update(['read_by' => [...($message->read_by ?? []), $userId]]);
            });

        return response()->json(['message' => 'Marked as read.']);
    }

    /** Fix a typo: own text messages, within the edit window. */
    public function update(Request $request, Conversation $conversation, Message $message): MessageResource
    {
        abort_unless($message->conversation_id === $conversation->id, 404);
        abort_unless($message->sender_id === $request->user()->id, 403);
        abort_if($message->isDeleted() || $message->type !== MessageType::Text, 422, 'Only text messages can be edited.');
        abort_if(
            $message->created_at->lt(now()->subMinutes(self::EDIT_WINDOW_MINUTES)),
            422,
            'Messages can only be edited within '.self::EDIT_WINDOW_MINUTES.' minutes.',
        );

        $data = $request->validate(['body' => ['required', 'string', 'max:10000']]);
        $message->update(['body' => $data['body'], 'edited_at' => now()]);

        return new MessageResource($message->load('sender', 'attachments', 'replyTo.sender', 'reactions'));
    }

    /** "Delete for me": hide from this user only; works on deleted ones too. */
    public function hide(Request $request, Conversation $conversation, Message $message): JsonResponse
    {
        abort_unless($message->conversation_id === $conversation->id, 404);
        $this->authorize('view', $conversation);

        DB::table('hidden_messages')->insertOrIgnore([
            'message_id' => $message->id,
            'user_id' => $request->user()->id,
            'created_at' => now(),
        ]);

        return response()->json(['message' => 'Message removed for you.']);
    }

    public function destroy(Request $request, Conversation $conversation, Message $message): JsonResponse
    {
        abort_unless($message->conversation_id === $conversation->id, 404);
        $this->authorize('deleteMessage', [$conversation, $message]);

        $message->update([
            'body' => null,
            'deleted_at' => now(),
        ]);
        $message->attachments()->each(function (\App\Models\MessageAttachment $a) {
            $this->storage->delete($a->file_path);
            $a->delete();
        });

        return response()->json(['message' => 'Message deleted.']);
    }

    private function notifyParticipants(Conversation $conversation, Message $message): void
    {
        // Muted chats still count as unread, but don't notify (like WhatsApp).
        $recipients = $conversation->users()
            ->where('users.id', '!=', $message->sender_id)
            ->where('conversation_participants.muted', false)
            ->get();

        $preview = match (true) {
            $message->type === MessageType::Sticker => '[sticker]',
            (bool) $message->body => Str::limit($message->body, 120),
            default => '[attachment]',
        };

        $title = $conversation->name
            ? "{$message->sender->name} in {$conversation->name}"
            : $message->sender->name;

        $this->notifications->sendMany(
            $recipients,
            'new_message',
            $title,
            $preview,
            $message,
            ['conversation_id' => $conversation->id, 'message_id' => $message->id],
        );
    }
}

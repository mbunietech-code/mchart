<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\MessageType;
use App\Events\MessageSent;
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
    public function __construct(
        private readonly AttachmentStorage $storage,
        private readonly NotificationService $notifications,
    ) {
    }

    public function index(Request $request, Conversation $conversation): AnonymousResourceCollection
    {
        $this->authorize('view', $conversation);

        $messages = $conversation->messages()
            ->with(['sender', 'attachments'])
            ->latest('id')
            ->when($request->filled('before'), fn ($q) => $q->where('id', '<', $request->integer('before')))
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
            $type = $files ? (Str::startsWith($files[0]->getClientMimeType(), 'image/') ? MessageType::Image->value : MessageType::File->value)
                : MessageType::Text->value;
        }

        $message = DB::transaction(function () use ($request, $conversation, $files, $type) {
            $message = $conversation->messages()->create([
                'sender_id' => $request->user()->id,
                'body' => $request->input('body'),
                'type' => $type,
                'read_by' => [$request->user()->id],
            ]);

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

        return (new MessageResource($message->load('sender', 'attachments')))
            ->response()
            ->setStatusCode(201);
    }

    public function markRead(Request $request, Conversation $conversation): JsonResponse
    {
        $this->authorize('view', $conversation);

        $conversation->participants()
            ->where('user_id', $request->user()->id)
            ->update(['last_read_at' => now()]);

        return response()->json(['message' => 'Marked as read.']);
    }

    private function notifyParticipants(Conversation $conversation, Message $message): void
    {
        $recipients = $conversation->users()
            ->where('users.id', '!=', $message->sender_id)
            ->get();

        $preview = $message->body
            ? Str::limit($message->body, 120)
            : '[attachment]';

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

<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\MessageResource;
use App\Models\Conversation;
use App\Models\Message;
use Illuminate\Http\Request;

class MessageReactionController extends Controller
{
    public function store(Request $request, Conversation $conversation, Message $message): MessageResource
    {
        abort_unless($message->conversation_id === $conversation->id, 404);
        $this->authorize('view', $conversation);

        $data = $request->validate(['emoji' => ['required', 'string', 'max:16']]);

        $message->reactions()->updateOrCreate(
            ['user_id' => $request->user()->id],
            ['emoji' => $data['emoji']],
        );

        return new MessageResource($message->load('sender', 'attachments', 'replyTo.sender', 'reactions'));
    }

    public function destroy(Request $request, Conversation $conversation, Message $message): MessageResource
    {
        abort_unless($message->conversation_id === $conversation->id, 404);
        $this->authorize('view', $conversation);

        $message->reactions()->where('user_id', $request->user()->id)->delete();

        return new MessageResource($message->load('sender', 'attachments', 'replyTo.sender', 'reactions'));
    }
}

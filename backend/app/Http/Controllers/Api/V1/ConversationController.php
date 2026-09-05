<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\ConversationType;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreConversationRequest;
use App\Http\Resources\ConversationResource;
use App\Models\Conversation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;

class ConversationController extends Controller
{
    public function index(Request $request): AnonymousResourceCollection
    {
        $user = $request->user();

        $conversations = Conversation::query()
            ->whereHas('participants', fn ($q) => $q->where('user_id', $user->id))
            ->with(['users', 'latestMessage.sender'])
            ->orderByRaw('last_message_at IS NULL, last_message_at DESC')
            ->orderByDesc('id')
            ->paginate($request->integer('per_page', 30));

        // Attach unread counts in one extra query.
        $unread = DB::table('messages')
            ->join('conversation_participants as cp', function ($join) use ($user) {
                $join->on('cp.conversation_id', '=', 'messages.conversation_id')
                    ->where('cp.user_id', '=', $user->id);
            })
            ->whereRaw("messages.created_at > COALESCE(cp.last_read_at, '1970-01-01 00:00:00')")
            ->where('messages.sender_id', '!=', $user->id)
            ->select('messages.conversation_id', DB::raw('COUNT(*) as c'))
            ->groupBy('messages.conversation_id')
            ->pluck('c', 'messages.conversation_id');

        $conversations->getCollection()->transform(function (Conversation $c) use ($unread) {
            $c->unread_count = (int) ($unread[$c->id] ?? 0);

            return $c;
        });

        return ConversationResource::collection($conversations);
    }

    public function store(StoreConversationRequest $request): JsonResponse
    {
        $user = $request->user();
        $participantIds = collect($request->input('participant_ids'))
            ->push($user->id)
            ->unique()
            ->values();

        // Reuse an existing direct conversation between the same two people.
        if ($request->input('type') === ConversationType::Direct->value) {
            $existing = Conversation::where('type', ConversationType::Direct)
                ->whereHas('participants', fn ($q) => $q->where('user_id', $participantIds[0]))
                ->whereHas('participants', fn ($q) => $q->where('user_id', $participantIds[1]))
                ->withCount('participants')
                ->having('participants_count', 2)
                ->first();

            if ($existing) {
                return (new ConversationResource($existing->load('users')))->response()->setStatusCode(200);
            }
        }

        $conversation = DB::transaction(function () use ($request, $user, $participantIds) {
            $conversation = Conversation::create([
                'type' => $request->input('type'),
                'name' => $request->input('name'),
                'department_id' => $request->input('department_id'),
                'created_by' => $user->id,
            ]);

            $conversation->participants()->createMany(
                $participantIds->map(fn ($id) => [
                    'user_id' => $id,
                    'role' => $id === $user->id ? 'admin' : 'member',
                    'joined_at' => now(),
                ])->all()
            );

            return $conversation;
        });

        return (new ConversationResource($conversation->load('users')))->response()->setStatusCode(201);
    }

    public function show(Conversation $conversation): ConversationResource
    {
        $this->authorize('view', $conversation);

        return new ConversationResource($conversation->load(['users', 'latestMessage.sender']));
    }

    public function update(Request $request, Conversation $conversation): ConversationResource
    {
        $this->authorize('update', $conversation);

        $conversation->update($request->validate([
            'name' => ['required', 'string', 'max:150'],
        ]));

        return new ConversationResource($conversation->load('users'));
    }
}

<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ConversationResource;
use App\Models\Conversation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ConversationParticipantController extends Controller
{
    public function store(Request $request, Conversation $conversation): ConversationResource
    {
        $this->authorize('manageParticipants', $conversation);

        $data = $request->validate([
            'user_ids' => ['required', 'array', 'min:1'],
            'user_ids.*' => ['integer', 'exists:users,id'],
        ]);

        $existing = $conversation->participants()->pluck('user_id')->all();
        $toAdd = array_diff($data['user_ids'], $existing);

        if ($toAdd) {
            $conversation->participants()->createMany(
                array_map(fn ($id) => ['user_id' => $id, 'role' => 'member', 'joined_at' => now()], $toAdd)
            );
        }

        return new ConversationResource($conversation->load('users'));
    }

    public function destroy(Request $request, Conversation $conversation, int $user): JsonResponse
    {
        // A member removing themselves is "leave"; removing someone else needs group-admin rights.
        if ($user === $request->user()->id) {
            $this->authorize('leave', $conversation);
        } else {
            $this->authorize('manageParticipants', $conversation);
        }

        abort_if(
            $conversation->created_by === $user && $user !== $request->user()->id,
            403,
            'The group creator can only be removed by leaving on their own.',
        );

        $conversation->participants()->where('user_id', $user)->delete();

        return response()->json(['message' => 'Removed from conversation.']);
    }
}

<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreUserRequest;
use App\Http\Requests\UpdateUserRequest;
use App\Http\Resources\UserResource;
use App\Mail\UserInvitation;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Str;

class UserController extends Controller
{
    /** Readable but strong: no look-alike characters, always mixed. */
    public static function temporaryPassword(): string
    {
        $pick = fn (string $set, int $n) => collect(range(1, $n))
            ->map(fn () => $set[random_int(0, strlen($set) - 1)])->implode('');

        return Str::of($pick('ABCDEFGHJKLMNPQRSTUVWXYZ', 2)
            .$pick('abcdefghijkmnpqrstuvwxyz', 5)
            .$pick('23456789', 3)
            .$pick('@#%*!', 1))->toString();
    }

    private function sendInvitation(User $user, string $temporary, string $invitedBy): bool
    {
        try {
            Mail::to($user->email)->send(new UserInvitation($user, $temporary, $invitedBy));

            return config('mail.default') !== 'log';
        } catch (\Throwable $e) {
            // The account still exists; the admin sees the password and can share it.
            Log::warning('[invite] email failed', ['user_id' => $user->id, 'error' => $e->getMessage()]);

            return false;
        }
    }

    public function index(Request $request): AnonymousResourceCollection
    {
        $query = User::query()->with('department', 'role');

        if ($request->filled('department_id')) {
            $query->where('department_id', $request->integer('department_id'));
        }

        if ($request->filled('role')) {
            $query->whereRelation('role', 'level', $request->string('role'));
        }

        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        if ($request->filled('search')) {
            $term = '%'.$request->string('search').'%';
            $query->where(fn ($q) => $q->where('name', 'like', $term)->orWhere('email', 'like', $term));
        }

        // Non-admins can only browse colleagues, not manage them.
        if (! $request->user()->isAdmin() && ! $request->user()->isManager()) {
            $query->where('status', 'active');
        }

        return UserResource::collection($query->orderBy('name')->paginate($request->integer('per_page', 25)));
    }

    public function store(StoreUserRequest $request): JsonResponse
    {
        $data = $request->validated();
        $data['role_id'] = ($data['role_id'] ?? null) ?: Role::where('name', $data['role'])->value('id');
        unset($data['role']);

        // The admin knows this password either way, so the new user must
        // replace it on first sign-in.
        $temporary = ($data['password'] ?? null) ?: self::temporaryPassword();
        $data['password'] = $temporary;
        $data['must_change_password'] = true;

        $user = User::create($data);
        $invited = $this->sendInvitation($user, $temporary, $request->user()->name);

        return (new UserResource($user->load('department', 'role')))
            ->additional([
                'invitation_sent' => $invited,
                // Shown once to the admin so they can pass it on if the email
                // doesn't arrive; never stored in plain text.
                'temporary_password' => $temporary,
            ])
            ->response()
            ->setStatusCode(201);
    }

    public function show(User $user): UserResource
    {
        return new UserResource($user->load('department', 'role'));
    }

    public function update(UpdateUserRequest $request, User $user): UserResource
    {
        $data = $request->validated();

        if (! empty($data['role_id'])) {
            unset($data['role']);
        } elseif (isset($data['role'])) {
            $data['role_id'] = Role::where('name', $data['role'])->value('id');
            unset($data['role']);
        }

        if (empty($data['password'])) {
            unset($data['password']);
        } elseif ($request->user()->id !== $user->id) {
            // An admin-set password is a temporary one for someone else.
            $data['must_change_password'] = true;
            $user->tokens()->delete();
        }

        $user->update($data);

        if (($data['status'] ?? null) === 'inactive') {
            $user->tokens()->delete();
        }

        return new UserResource($user->load('department', 'role'));
    }

    /**
     * New temporary password, emailed again. Only while the person hasn't
     * chosen their own yet (never resets someone's real password).
     */
    public function resendInvitation(Request $request, User $user): JsonResponse
    {
        abort_unless($user->must_change_password, 422, 'This user has already set their own password.');

        $temporary = self::temporaryPassword();
        $user->forceFill(['password' => $temporary])->save();
        $user->tokens()->delete();

        return response()->json([
            'invitation_sent' => $this->sendInvitation($user, $temporary, $request->user()->name),
            'temporary_password' => $temporary,
        ]);
    }

    /**
     * Permanently remove an account that was never really used (typically a
     * mistyped or unwanted invitation), freeing its email for a new invite.
     * Anyone with history is refused: deleting them would cascade away tasks
     * and conversations other people rely on, so deactivate them instead.
     */
    public function forceDestroy(Request $request, User $user): JsonResponse
    {
        abort_if($user->is($request->user()), 422, 'You cannot delete your own account.');

        $history = [
            'messages' => DB::table('messages')->where('sender_id', $user->id)->exists(),
            'tasks' => DB::table('tasks')->where('created_by', $user->id)->orWhere('assigned_to', $user->id)->exists(),
            'task comments' => DB::table('task_comments')->where('user_id', $user->id)->exists(),
            'conversations' => DB::table('conversations')->where('created_by', $user->id)->exists(),
            'announcements' => DB::table('announcements')->where('author_id', $user->id)->exists(),
        ];
        $used = array_keys(array_filter($history));

        if ($used !== []) {
            return response()->json([
                'message' => 'This account has '.implode(', ', $used).' that other people rely on. Deactivate it instead.',
                'code' => 'user_has_history',
            ], 422);
        }

        DB::transaction(function () use ($user) {
            $user->tokens()->delete();
            $user->delete(); // devices, notifications, memberships cascade
        });

        return response()->json(['message' => 'User deleted.']);
    }

    public function destroy(User $user): JsonResponse
    {
        // Soft "removal": deactivate + revoke sessions rather than hard delete,
        // so task/chat history stays intact (SRS FR-AUTH-06, §6 data retention).
        $user->update(['status' => 'inactive']);
        $user->tokens()->delete();

        return response()->json(['message' => 'User deactivated.']);
    }
}

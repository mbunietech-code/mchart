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
            $query->whereRelation('role', 'name', $request->string('role'));
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
        $data['role_id'] = Role::where('name', $data['role'])->value('id');
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

        if (isset($data['role'])) {
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

    public function destroy(User $user): JsonResponse
    {
        // Soft "removal": deactivate + revoke sessions rather than hard delete,
        // so task/chat history stays intact (SRS FR-AUTH-06, §6 data retention).
        $user->update(['status' => 'inactive']);
        $user->tokens()->delete();

        return response()->json(['message' => 'User deactivated.']);
    }
}

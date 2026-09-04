<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreUserRequest;
use App\Http\Requests\UpdateUserRequest;
use App\Http\Resources\UserResource;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;

class UserController extends Controller
{
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

        $user = User::create($data);

        return (new UserResource($user->load('department', 'role')))
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

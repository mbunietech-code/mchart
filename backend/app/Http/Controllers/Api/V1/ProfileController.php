<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\UserResource;
use App\Services\AttachmentStorage;
use Illuminate\Http\Request;

/** The signed-in user's own name, phone and photo. */
class ProfileController extends Controller
{
    public function __construct(private readonly AttachmentStorage $storage)
    {
    }

    public function update(Request $request): UserResource
    {
        $data = $request->validate([
            'name' => ['sometimes', 'required', 'string', 'max:150'],
            'phone' => ['sometimes', 'nullable', 'string', 'max:30'],
        ]);

        $request->user()->update($data);

        return new UserResource($request->user()->load('department', 'role'));
    }

    public function avatar(Request $request): UserResource
    {
        $request->validate([
            'avatar' => ['required', 'image', 'mimes:jpeg,png,webp', 'max:5120'],
        ]);

        $user = $request->user();
        $this->storage->delete($user->avatar_path);
        $user->update([
            'avatar_path' => $this->storage->store($request->file('avatar'), 'avatars')['file_path'],
        ]);

        return new UserResource($user->load('department', 'role'));
    }

    public function removeAvatar(Request $request): UserResource
    {
        $user = $request->user();
        $this->storage->delete($user->avatar_path);
        $user->update(['avatar_path' => null]);

        return new UserResource($user->load('department', 'role'));
    }
}

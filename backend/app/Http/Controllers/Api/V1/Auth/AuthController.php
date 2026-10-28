<?php

namespace App\Http\Controllers\Api\V1\Auth;

use App\Http\Controllers\Controller;
use App\Http\Requests\Auth\LoginRequest;
use App\Http\Resources\UserResource;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function login(LoginRequest $request): JsonResponse
    {
        $user = User::where('email', $request->email)->first();

        if (! $user || ! Hash::check($request->password, $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['These credentials do not match our records.'],
            ]);
        }

        if (! $user->isActive()) {
            throw ValidationException::withMessages([
                'email' => ['Your account has been deactivated. Contact an administrator.'],
            ]);
        }

        $user->forceFill(['last_seen_at' => now()])->save();

        $device = $request->input('device_name', 'api');
        $token = $user->createToken($device)->plainTextToken;

        return response()->json([
            'token' => $token,
            'user' => new UserResource($user->load('department', 'role')),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        // This phone stops receiving the account's pushes.
        if ($request->filled('push_token')) {
            $request->user()->devices()->where('push_token', $request->string('push_token'))->delete();
        }

        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Logged out.']);
    }

    /** First sign-in with a temporary password, or a voluntary change. */
    public function changePassword(Request $request): UserResource
    {
        $data = $request->validate([
            'current_password' => ['required', 'current_password:sanctum'],
            'password' => ['required', 'confirmed', 'different:current_password', Password::defaults()],
        ]);

        $user = $request->user();
        $user->forceFill(['password' => $data['password'], 'must_change_password' => false])->save();

        // Other sessions were opened with the old password.
        $user->tokens()->whereKeyNot($user->currentAccessToken()->id)->delete();

        return new UserResource($user->load('department', 'role'));
    }

    public function me(Request $request): UserResource
    {
        return new UserResource($request->user()->load('department', 'role'));
    }
}

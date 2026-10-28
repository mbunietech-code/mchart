<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules\Password as PasswordRule;
use Illuminate\View\View;

/**
 * The page the "Reset password" email links to: a plain web form, so it
 * works from any phone's mail app without the MChart app installed.
 */
class ResetPasswordPageController extends Controller
{
    public function show(Request $request): View
    {
        return view('auth.reset-password', [
            'token' => (string) $request->query('token'),
            'email' => (string) $request->query('email'),
        ]);
    }

    public function update(Request $request): View
    {
        $data = $request->validate([
            'token' => ['required', 'string'],
            'email' => ['required', 'email'],
            'password' => ['required', 'confirmed', PasswordRule::defaults()],
        ]);

        $status = Password::reset($data + ['password_confirmation' => $request->input('password_confirmation')],
            function ($user, $password) {
                $user->forceFill([
                    'password' => $password,
                    'must_change_password' => false,
                    'remember_token' => Str::random(60),
                ])->save();
                $user->tokens()->delete();
            });

        if ($status !== Password::PasswordReset) {
            return view('auth.reset-password', [
                'token' => $data['token'],
                'email' => $data['email'],
                'error' => __($status),
            ]);
        }

        return view('auth.reset-password', ['done' => true]);
    }
}

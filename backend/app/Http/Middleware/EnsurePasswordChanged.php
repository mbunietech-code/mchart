<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Accounts created with a temporary password may only identify themselves,
 * sign out, register a device, or change the password until they do.
 */
class EnsurePasswordChanged
{
    private const ALLOWED = ['api/v1/me', 'api/v1/auth/logout', 'api/v1/auth/password/change', 'api/v1/devices'];

    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user?->must_change_password && ! in_array($request->path(), self::ALLOWED, true)) {
            return response()->json([
                'message' => 'Please change your temporary password to continue.',
                'code' => 'password_change_required',
            ], 403);
        }

        return $next($request);
    }
}

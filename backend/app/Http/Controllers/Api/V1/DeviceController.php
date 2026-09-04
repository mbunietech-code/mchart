<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\RegisterDeviceRequest;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceController extends Controller
{
    public function store(RegisterDeviceRequest $request): JsonResponse
    {
        $device = $request->user()->devices()->updateOrCreate(
            ['push_token' => $request->string('push_token')->toString()],
            [
                'platform' => $request->string('platform')->toString(),
                'device_name' => $request->input('device_name'),
                'last_active_at' => now(),
            ],
        );

        return response()->json(['data' => $device], $device->wasRecentlyCreated ? 201 : 200);
    }

    public function destroy(Request $request): JsonResponse
    {
        $request->validate(['push_token' => ['required', 'string']]);

        $request->user()->devices()
            ->where('push_token', $request->string('push_token'))
            ->delete();

        return response()->json(['message' => 'Device unregistered.']);
    }
}

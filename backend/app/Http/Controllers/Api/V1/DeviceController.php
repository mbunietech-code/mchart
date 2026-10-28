<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\RegisterDeviceRequest;
use App\Models\Device;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DeviceController extends Controller
{
    public function store(RegisterDeviceRequest $request): JsonResponse
    {
        // A phone belongs to whoever is signed in on it now: drop the token
        // from any other account so their pushes stop landing here.
        Device::where('push_token', $request->string('push_token')->toString())
            ->where('user_id', '!=', $request->user()->id)
            ->delete();

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

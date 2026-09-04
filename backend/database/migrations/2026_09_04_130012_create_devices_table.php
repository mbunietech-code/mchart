<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('devices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            $table->enum('platform', ['windows', 'macos', 'android']);
            $table->string('push_token', 255);          // FCM token or desktop notification identifier
            $table->string('device_name', 150)->nullable();
            $table->timestamp('last_active_at')->nullable();
            $table->timestamps();

            $table->unique(['user_id', 'push_token']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('devices');
    }
};

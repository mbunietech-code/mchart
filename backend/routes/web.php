<?php

use App\Http\Controllers\FileController;
use Illuminate\Support\Facades\Route;

// API-only backend. Keep this closure-free so `route:cache` works.
Route::view('/', 'welcome');

// Private uploads (chat, tasks, announcements) behind a path signature.
Route::get('files/{expires}/{signature}/{path}', [FileController::class, 'show'])
    ->where(['expires' => '[0-9]+', 'signature' => '[a-f0-9]{64}', 'path' => '.*'])
    ->name('files.show');

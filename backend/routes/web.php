<?php

use App\Http\Controllers\FileController;
use App\Http\Controllers\ResetPasswordPageController;
use Illuminate\Support\Facades\Route;

// API-only backend. Keep this closure-free so `route:cache` works.
Route::view('/', 'welcome');

// "Forgot password" email lands here (web form; no app needed).
Route::get('reset-password', [ResetPasswordPageController::class, 'show'])->name('password.reset');
Route::post('reset-password', [ResetPasswordPageController::class, 'update'])->middleware('throttle:6,1');

// Private uploads (chat, tasks, announcements) behind a path signature.
Route::get('files/{expires}/{signature}/{path}', [FileController::class, 'show'])
    ->where(['expires' => '[0-9]+', 'signature' => '[a-f0-9]{64}', 'path' => '.*'])
    ->name('files.show');

<?php

use App\Http\Controllers\Api\V1\Auth\AuthController;
use App\Http\Controllers\Api\V1\Auth\PasswordResetController;
use App\Http\Controllers\Api\V1\ConversationController;
use App\Http\Controllers\Api\V1\DashboardController;
use App\Http\Controllers\Api\V1\DepartmentController;
use App\Http\Controllers\Api\V1\DeviceController;
use App\Http\Controllers\Api\V1\MessageController;
use App\Http\Controllers\Api\V1\NotificationController;
use App\Http\Controllers\Api\V1\RoleController;
use App\Http\Controllers\Api\V1\TaskAttachmentController;
use App\Http\Controllers\Api\V1\TaskCommentController;
use App\Http\Controllers\Api\V1\TaskController;
use App\Http\Controllers\Api\V1\TaskWorkflowController;
use App\Http\Controllers\Api\V1\UserController;
use Illuminate\Support\Facades\Route;

/*
| All routes are served under the /api/v1 prefix (see bootstrap/app.php).
*/

// ----- Public -----------------------------------------------------------
Route::post('auth/login', [AuthController::class, 'login'])
    ->middleware('throttle:6,1');
Route::post('auth/password/forgot', [PasswordResetController::class, 'sendResetLink'])
    ->middleware('throttle:6,1');
Route::post('auth/password/reset', [PasswordResetController::class, 'reset'])
    ->middleware('throttle:6,1');

// ----- Authenticated ---------------------------------------------------
Route::middleware(['auth:sanctum', 'active'])->group(function () {
    Route::post('auth/logout', [AuthController::class, 'logout']);
    Route::get('me', [AuthController::class, 'me']);

    // Devices (push registration)
    Route::post('devices', [DeviceController::class, 'store']);
    Route::delete('devices', [DeviceController::class, 'destroy']);

    // Directory
    Route::get('users', [UserController::class, 'index']);
    Route::get('users/{user}', [UserController::class, 'show']);
    Route::get('roles', [RoleController::class, 'index']);
    Route::get('departments', [DepartmentController::class, 'index']);
    Route::get('departments/{department}', [DepartmentController::class, 'show']);

    // Admin-only administration
    Route::middleware('role:admin')->group(function () {
        Route::post('users', [UserController::class, 'store']);
        Route::patch('users/{user}', [UserController::class, 'update']);
        Route::delete('users/{user}', [UserController::class, 'destroy']);
        Route::post('departments', [DepartmentController::class, 'store']);
        Route::patch('departments/{department}', [DepartmentController::class, 'update']);
        Route::delete('departments/{department}', [DepartmentController::class, 'destroy']);
    });

    // Chat
    Route::get('conversations', [ConversationController::class, 'index']);
    Route::post('conversations', [ConversationController::class, 'store']);
    Route::get('conversations/{conversation}', [ConversationController::class, 'show']);
    Route::get('conversations/{conversation}/messages', [MessageController::class, 'index']);
    Route::post('conversations/{conversation}/messages', [MessageController::class, 'store']);
    Route::post('conversations/{conversation}/read', [MessageController::class, 'markRead']);

    // Tasks
    Route::get('tasks', [TaskController::class, 'index']);
    Route::post('tasks', [TaskController::class, 'store']);
    Route::get('tasks/{task}', [TaskController::class, 'show']);
    Route::patch('tasks/{task}', [TaskController::class, 'update']);
    Route::delete('tasks/{task}', [TaskController::class, 'destroy']);

    Route::post('tasks/{task}/start', [TaskWorkflowController::class, 'start']);
    Route::post('tasks/{task}/complete', [TaskWorkflowController::class, 'complete']);
    Route::post('tasks/{task}/approve', [TaskWorkflowController::class, 'approve']);
    Route::post('tasks/{task}/return', [TaskWorkflowController::class, 'return']);

    Route::get('tasks/{task}/comments', [TaskCommentController::class, 'index']);
    Route::post('tasks/{task}/comments', [TaskCommentController::class, 'store']);
    Route::post('tasks/{task}/attachments', [TaskAttachmentController::class, 'store']);
    Route::delete('tasks/{task}/attachments/{attachment}', [TaskAttachmentController::class, 'destroy']);

    // Notifications
    Route::get('notifications', [NotificationController::class, 'index']);
    Route::get('notifications/unread-count', [NotificationController::class, 'unreadCount']);
    Route::post('notifications/read-all', [NotificationController::class, 'markAllRead']);
    Route::post('notifications/{notification}/read', [NotificationController::class, 'markRead']);
    Route::delete('notifications/{notification}', [NotificationController::class, 'destroy']);

    // Dashboard
    Route::get('dashboard/summary', [DashboardController::class, 'summary']);
    Route::get('dashboard/activity', [DashboardController::class, 'activity']);
});

<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\TaskStatus;
use App\Http\Controllers\Controller;
use App\Http\Resources\TaskStatusHistoryResource;
use App\Models\Task;
use App\Models\TaskStatusHistory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class DashboardController extends Controller
{
    /**
     * Task counts and completion rate, scoped by role (SDD §5.5, §6.5).
     */
    public function summary(Request $request): JsonResponse
    {
        $user = $request->user();
        $from = $request->date('from') ?? now()->subDays(30)->startOfDay();
        $to = $request->date('to') ?? now()->endOfDay();

        $base = fn () => Task::query()->visibleTo($user)
            ->when($request->filled('department_id'), fn ($q) => $q->where('department_id', $request->integer('department_id')))
            ->when($request->filled('assignee_id'), fn ($q) => $q->where('assigned_to', $request->integer('assignee_id')));

        $byStatus = $base()
            ->selectRaw('status, COUNT(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');

        $counts = [
            'assigned' => (int) ($byStatus[TaskStatus::Assigned->value] ?? 0),
            'in_progress' => (int) ($byStatus[TaskStatus::InProgress->value] ?? 0),
            'completed' => (int) ($byStatus[TaskStatus::Completed->value] ?? 0),
            'approved' => (int) ($byStatus[TaskStatus::Approved->value] ?? 0),
            'revision' => (int) ($byStatus[TaskStatus::Revision->value] ?? 0),
        ];
        $counts['open'] = $counts['assigned'] + $counts['in_progress'] + $counts['revision'];
        $counts['overdue'] = (int) $base()->overdue()->count();

        $createdInPeriod = (int) $base()->whereBetween('created_at', [$from, $to])->count();
        $approvedInPeriod = (int) $base()->where('status', TaskStatus::Approved->value)
            ->whereBetween('approved_at', [$from, $to])->count();

        $completionRate = $createdInPeriod > 0
            ? round($approvedInPeriod / $createdInPeriod * 100, 1)
            : null;

        $perAssignee = $base()
            ->selectRaw('assigned_to, COUNT(*) as total,
                SUM(status = ?) as approved,
                SUM(deadline IS NOT NULL AND deadline < NOW() AND status NOT IN (?, ?)) as overdue', [
                TaskStatus::Approved->value, TaskStatus::Completed->value, TaskStatus::Approved->value,
            ])
            ->whereNotNull('assigned_to')
            ->groupBy('assigned_to')
            ->with('assignee:id,name')
            ->get()
            ->map(fn ($row) => [
                'assignee_id' => $row->assigned_to,
                'assignee' => $row->assignee?->name,
                'total' => (int) $row->total,
                'approved' => (int) $row->approved,
                'overdue' => (int) $row->overdue,
            ]);

        return response()->json([
            'period' => ['from' => $from, 'to' => $to],
            'counts' => $counts,
            'completion_rate' => $completionRate,
            'created_in_period' => $createdInPeriod,
            'approved_in_period' => $approvedInPeriod,
            'per_assignee' => $perAssignee,
        ]);
    }

    /**
     * Recent task / approval activity feed.
     */
    public function activity(Request $request): JsonResponse
    {
        $user = $request->user();

        $visibleTaskIds = Task::query()->visibleTo($user)->pluck('id');

        $history = TaskStatusHistory::query()
            ->whereIn('task_id', $visibleTaskIds)
            ->with(['changedBy:id,name', 'task:id,title'])
            ->orderByDesc('id')
            ->limit($request->integer('limit', 40))
            ->get()
            ->map(fn (TaskStatusHistory $h) => [
                'id' => $h->id,
                'task_id' => $h->task_id,
                'task_title' => $h->task?->title,
                'old_status' => $h->old_status,
                'new_status' => $h->new_status,
                'note' => $h->note,
                'actor' => $h->changedBy?->name,
                'at' => $h->changed_at,
            ]);

        return response()->json(['data' => $history]);
    }
}

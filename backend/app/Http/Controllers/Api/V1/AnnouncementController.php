<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\AnnouncementCategory;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreAnnouncementRequest;
use App\Http\Resources\AnnouncementResource;
use App\Models\Announcement;
use App\Services\AttachmentStorage;
use App\Services\NotificationService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\AnonymousResourceCollection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Status / Announcements: official notices kept apart from chat.
 */
class AnnouncementController extends Controller
{
    public function __construct(
        private readonly NotificationService $notifications,
        private readonly AttachmentStorage $storage,
    ) {
    }

    public function index(Request $request): AnonymousResourceCollection
    {
        $query = $this->listQuery($request)
            ->with(['author.role', 'department'])
            ->withCount('readers')
            ->orderByDesc('pinned')
            ->latest();

        if ($request->filled('category')) {
            $query->where('category', $request->string('category'));
        }

        if ($request->filled('search')) {
            $term = '%'.$request->string('search').'%';
            $query->where(fn (Builder $q) => $q->where('title', 'like', $term)->orWhere('body', 'like', $term));
        }

        return AnnouncementResource::collection($query->paginate($request->integer('per_page', 30)));
    }

    public function unreadCount(Request $request): JsonResponse
    {
        $user = $request->user();

        return response()->json([
            'unread' => Announcement::query()->visibleTo($user)->active()->unreadBy($user)->count(),
        ]);
    }

    public function store(StoreAnnouncementRequest $request): JsonResponse
    {
        $this->authorize('create', Announcement::class);

        $data = $request->safe()->except(['image', 'remove_image', 'archived']);
        $data['author_id'] = $request->user()->id;
        if ($request->hasFile('image')) {
            $data['image_path'] = $this->storage->store($request->file('image'), 'announcements')['file_path'];
        }

        $announcement = Announcement::create($data);
        $this->notifyAudience($announcement);

        return (new AnnouncementResource($this->present($announcement, $request)))
            ->response()
            ->setStatusCode(201);
    }

    public function show(Request $request, Announcement $announcement): AnnouncementResource
    {
        $this->authorize('view', $announcement);

        return new AnnouncementResource($this->present($announcement, $request));
    }

    public function update(StoreAnnouncementRequest $request, Announcement $announcement): AnnouncementResource
    {
        $this->authorize('update', $announcement);

        $data = $request->safe()->except(['image', 'remove_image', 'archived']);
        if ($request->has('archived')) {
            $data['archived_at'] = $request->boolean('archived') ? now() : null;
        }
        if ($request->hasFile('image') || $request->boolean('remove_image')) {
            $this->storage->delete($announcement->image_path);
            $data['image_path'] = $request->hasFile('image')
                ? $this->storage->store($request->file('image'), 'announcements')['file_path']
                : null;
        }

        $announcement->update($data);

        return new AnnouncementResource($this->present($announcement, $request));
    }

    public function destroy(Announcement $announcement): JsonResponse
    {
        $this->authorize('delete', $announcement);

        $this->storage->delete($announcement->image_path);
        $announcement->delete();

        return response()->json(['message' => 'Announcement deleted.']);
    }

    public function markRead(Request $request, Announcement $announcement): JsonResponse
    {
        $this->authorize('view', $announcement);

        // Idempotent: the first read time is the one that counts.
        DB::table('announcement_reads')->insertOrIgnore([
            'announcement_id' => $announcement->id,
            'user_id' => $request->user()->id,
            'read_at' => now(),
        ]);

        return response()->json(['message' => 'Marked as read.']);
    }

    private function listQuery(Request $request): Builder
    {
        $user = $request->user();

        return Announcement::query()
            ->visibleTo($user)
            ->when($request->boolean('archived'), fn (Builder $q) => $q->archived(), fn (Builder $q) => $q->active())
            ->withExists(['readers as is_read' => fn (Builder $q) => $q->whereKey($user->id)]);
    }

    private function present(Announcement $announcement, Request $request): Announcement
    {
        return $announcement->fresh()
            ->load(['author.role', 'department'])
            ->loadCount('readers')
            ->loadExists(['readers as is_read' => fn (Builder $q) => $q->whereKey($request->user()->id)]);
    }

    private function notifyAudience(Announcement $announcement): void
    {
        // "Meeting: Friday all-hands", unless the title already says so.
        $prefix = $announcement->category === AnnouncementCategory::Urgent
            ? 'URGENT'
            : $announcement->category->label();
        $title = Str::startsWith(Str::lower($announcement->title), Str::lower($prefix))
            ? $announcement->title
            : $prefix.': '.$announcement->title;

        $this->notifications->sendMany(
            $announcement->audience()->get(),
            'announcement',
            Str::limit($title, 150, ''),
            Str::limit($announcement->body, 250),
            $announcement,
            ['announcement_id' => $announcement->id, 'category' => $announcement->category->value],
        );
    }
}

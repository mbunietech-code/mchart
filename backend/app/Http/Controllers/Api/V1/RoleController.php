<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\UserRole;
use App\Http\Controllers\Controller;
use App\Models\Role;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;

/**
 * Roles are job titles ("Accountant", "Designer") that each sit on one of
 * the three permission levels. Permissions follow the level only, so a new
 * title can never grant more than its level allows.
 */
class RoleController extends Controller
{
    /** The built-in roles; their level can't change and they can't be deleted. */
    private const BUILT_IN = ['admin', 'manager', 'staff'];

    public function index(): JsonResponse
    {
        return response()->json([
            'data' => Role::orderByRaw("FIELD(level, 'admin', 'manager', 'staff')")
                ->orderBy('label')
                ->withCount('users')
                ->get()
                ->map(fn (Role $r) => $this->present($r)),
        ]);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'label' => ['required', 'string', 'max:100', Rule::unique('roles', 'label')],
            'level' => ['required', Rule::enum(UserRole::class)],
        ]);

        $role = Role::create([
            'name' => $this->uniqueSlug($data['label']),
            'label' => $data['label'],
            'level' => $data['level'],
        ]);

        return response()->json(['data' => $this->present($role->loadCount('users'))], 201);
    }

    public function update(Request $request, Role $role): JsonResponse
    {
        $builtIn = in_array($role->name, self::BUILT_IN, true);
        $data = $request->validate([
            'label' => ['sometimes', 'required', 'string', 'max:100', Rule::unique('roles', 'label')->ignore($role->id)],
            'level' => ['sometimes', Rule::enum(UserRole::class)],
        ]);

        // The built-in admin/manager/staff keep their level.
        if ($builtIn) {
            unset($data['level']);
        }
        $role->update($data);

        return response()->json(['data' => $this->present($role->loadCount('users'))]);
    }

    public function destroy(Role $role): JsonResponse
    {
        abort_if(in_array($role->name, self::BUILT_IN, true), 422, 'Built-in roles cannot be deleted.');
        abort_if($role->users()->exists(), 422, 'Move the people in this role to another role first.');

        $role->delete();

        return response()->json(['message' => 'Role deleted.']);
    }

    private function present(Role $r): array
    {
        return [
            'id' => $r->id,
            'name' => $r->name,
            'label' => $r->label,
            'level' => $r->level,
            'built_in' => in_array($r->name, self::BUILT_IN, true),
            'users_count' => (int) ($r->users_count ?? 0),
        ];
    }

    private function uniqueSlug(string $label): string
    {
        $base = Str::slug($label) ?: 'role';
        $slug = $base;
        for ($i = 2; Role::where('name', $slug)->exists(); $i++) {
            $slug = "{$base}-{$i}";
        }

        return $slug;
    }
}

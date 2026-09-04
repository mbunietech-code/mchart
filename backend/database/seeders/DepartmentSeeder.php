<?php

namespace Database\Seeders;

use App\Models\Department;
use Illuminate\Database\Seeder;

class DepartmentSeeder extends Seeder
{
    public function run(): void
    {
        $departments = [
            'Programming' => 'Software development and engineering',
            'Design' => 'Product and graphic design',
            'Sales' => 'Sales and business development',
            'Operations' => 'Company operations and administration',
        ];

        foreach ($departments as $name => $description) {
            Department::updateOrCreate(['name' => $name], ['description' => $description]);
        }
    }
}

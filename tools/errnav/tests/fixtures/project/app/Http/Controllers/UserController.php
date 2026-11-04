<?php

namespace App\Http\Controllers;

use App\Services\UserService;

class UserController extends Controller
{
    public function show(UserService $users, int $id)
    {
        $user = $users->find($id);
        return view('users.show', ['user' => $usr]);
    }
}

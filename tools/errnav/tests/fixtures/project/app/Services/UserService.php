<?php
class UserService {
    public function find($id) {
        $users = [1 => 'alice'];
        if (!isset($users[$id])) {
            throw new RuntimeException("User not found: $id");
        }
        return $users[$id];
    }
}

<?php
require __DIR__ . '/Services/UserService.php';
function handle($id) {
    $svc = new UserService();
    return $svc->find($id);
}
handle(42);

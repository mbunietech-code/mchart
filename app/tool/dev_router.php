<?php
// Dev-only static server for `build/web`, run from build/web/:
//   php -S 127.0.0.1:PORT ../../tool/dev_router.php
// Adds Cross-Origin-Opener/Embedder-Policy so CanvasKit's SharedArrayBuffer
// path can initialize in browsers that need cross-origin isolation.
header('Cross-Origin-Opener-Policy: same-origin');
header('Cross-Origin-Embedder-Policy: require-corp');
header('Cross-Origin-Resource-Policy: cross-origin');

$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$file = __DIR__ . '/../build/web' . $path;

if ($path !== '/' && is_file($file)) {
    $ext = strtolower(pathinfo($file, PATHINFO_EXTENSION));
    $types = [
        'js' => 'text/javascript', 'mjs' => 'text/javascript',
        'wasm' => 'application/wasm', 'json' => 'application/json',
        'html' => 'text/html', 'css' => 'text/css',
        'png' => 'image/png', 'jpg' => 'image/jpeg', 'svg' => 'image/svg+xml',
        'otf' => 'font/otf', 'ttf' => 'font/ttf', 'woff2' => 'font/woff2',
        'bin' => 'application/octet-stream', 'symbols' => 'text/plain',
    ];
    if (isset($types[$ext])) {
        header('Content-Type: ' . $types[$ext]);
    }
    readfile($file);
    return true;
}

header('Content-Type: text/html');
readfile(__DIR__ . '/../build/web/index.html');
return true;

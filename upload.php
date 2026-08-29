<?php
// snap.afterworkphotos.com/upload.php — receives one square JPEG from the
// afterworksnap app and PUTs it into afterworkphotos/inbox/ through the
// GitHub contents API. The ingest workflow does the rest. Nothing else:
// no listing, no delete.
//
// POST, Authorization: Bearer <app secret>, Content-Type: image/jpeg,
// X-Filename: yyyyMMdd-HHmmss.jpg, the JPEG as the body.
// 201 created · 200 already there · 400 bad body or name · 401 wrong secret
// 405 not POST or not HTTPS · 413 over 12 MB · 502 GitHub failed

require __DIR__ . '/snap-secret.php';

const MAX_BYTES = 12 * 1024 * 1024;
const REPO      = '01msmr/afterworkphotos';
const BRANCH    = 'main';

header('Content-Type: text/plain; charset=utf-8');
function answer(int $code, string $text): never { http_response_code($code); echo $text, "\n"; exit; }

$https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
      || (($_SERVER['HTTP_X_FORWARDED_PROTO'] ?? '') === 'https');
if (!$https || ($_SERVER['REQUEST_METHOD'] ?? '') !== 'POST') answer(405, 'POST over HTTPS only');

$auth = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
$given = preg_match('/^Bearer\s+(\S+)$/', $auth, $m) ? $m[1] : '';
if (!hash_equals(UPLOAD_SECRET, $given)) answer(401, 'wrong secret');

$name = $_SERVER['HTTP_X_FILENAME'] ?? '';
if (!preg_match('/^\d{8}-\d{6}\.jpg$/', $name)) answer(400, 'bad filename');

$len = (int)($_SERVER['CONTENT_LENGTH'] ?? 0);
if ($len > MAX_BYTES) answer(413, 'over 12 MB');
$data = file_get_contents('php://input');
if (strlen($data) > MAX_BYTES) answer(413, 'over 12 MB');
if (strlen($data) < 100 || substr($data, 0, 3) !== "\xFF\xD8\xFF") answer(400, 'not a JPEG');

$ch = curl_init('https://api.github.com/repos/' . REPO . '/contents/inbox/' . $name);
curl_setopt_array($ch, [
    CURLOPT_CUSTOMREQUEST  => 'PUT',
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_TIMEOUT        => 60,
    CURLOPT_HTTPHEADER     => [
        'Authorization: Bearer ' . GITHUB_TOKEN,
        'Accept: application/vnd.github+json',
        'X-GitHub-Api-Version: 2022-11-28',
        'User-Agent: afterworksnap-upload/1.0',
        'Content-Type: application/json',
    ],
    CURLOPT_POSTFIELDS => json_encode([
        'message' => "photo $name",
        'content' => base64_encode($data),
        'branch'  => BRANCH,
    ]),
]);
$body = curl_exec($ch);
$code = curl_getinfo($ch, CURLINFO_RESPONSE_CODE);
curl_close($ch);

if ($code === 201) answer(201, "created inbox/$name");
if ($code === 422) answer(200, "already there: inbox/$name");   // path exists, no sha given
answer(502, "GitHub answered $code");

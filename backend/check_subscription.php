<?php

require_once __DIR__ . '/config.php';

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=utf-8");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

function bdapps_normalize_mobile($raw) {
    $digits = preg_replace('/\D+/', '', $raw);
    if (strlen($digits) === 13 && substr($digits, 0, 3) === '880') {
        $digits = '0' . substr($digits, 3);
    } elseif (strlen($digits) === 12 && substr($digits, 0, 2) === '88') {
        $digits = '0' . substr($digits, 2);
    }
    return $digits;
}

$rawMobile = trim($_POST['user_mobile'] ?? $_POST['subscriberId'] ?? '');
$digits = bdapps_normalize_mobile($rawMobile);

if (!preg_match('/^01[3-9][0-9]{8}$/', $digits)) {
    http_response_code(400);
    echo json_encode([
        'success'            => false,
        'error'              => 'Invalid mobile number format',
        'subscriptionStatus' => 'UNKNOWN',
    ]);
    exit;
}

$subscriberId = 'tel:88' . $digits;

$requestData = [
    'applicationId' => BDAPPS_APP_ID,
    'password'      => BDAPPS_APP_PASSWORD,
    'subscriberId'  => $subscriberId,
];

// Query BD Apps getStatus endpoint
$ch = curl_init('https://developer.bdapps.com/subscription/getStatus');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($requestData));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);

$responseJson = curl_exec($ch);
$curlError = curl_error($ch);
curl_close($ch);

if ($responseJson === false) {
    http_response_code(502);
    echo json_encode([
        'success'            => false,
        'error'              => $curlError,
        'subscriberId'       => $subscriberId,
        'subscriptionStatus' => 'UNKNOWN',
    ]);
    exit;
}

$response = json_decode($responseJson, true);
if (!is_array($response)) {
    echo json_encode([
        'success'            => false,
        'error'              => 'Invalid BD Apps response',
        'subscriberId'       => $subscriberId,
        'subscriptionStatus' => 'UNKNOWN',
    ]);
    exit;
}

$statusCode = $response['statusCode'] ?? null;
$subscriptionStatus = $response['subscriptionStatus'] ?? 'UNREGISTERED';
$isSubscribed = (strtoupper((string)$subscriptionStatus) === 'REGISTERED');

echo json_encode([
    'success'            => $statusCode === 'S1000',
    'isSubscribed'       => $isSubscribed,
    'subscriberId'       => $subscriberId,
    'statusCode'         => $statusCode,
    'statusDetail'       => $response['statusDetail'] ?? null,
    'subscriptionStatus' => $subscriptionStatus,
    'version'            => $response['version'] ?? '1.0',
]);

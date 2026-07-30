<?php

require_once 'config.php';

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

/**
 * Normalize a user-supplied BD mobile ("01XXXXXXXXX", "8801XXXXXXXXX",
 * "+8801XXXXXXXXX", etc.) to the canonical 11-digit "01XXXXXXXXX" form.
 */
function meditrack_normalize_mobile($raw) {
    $digits = preg_replace('/\D+/', '', $raw);
    if (strlen($digits) === 13 && substr($digits, 0, 3) === '880') {
        $digits = '0' . substr($digits, 3);
    } elseif (strlen($digits) === 12 && substr($digits, 0, 2) === '88') {
        $digits = '0' . substr($digits, 2);
    }
    return $digits;
}

$digits = meditrack_normalize_mobile($_POST['user_mobile'] ?? '');

if (!preg_match('/^01[3-9][0-9]{8}$/', $digits)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Invalid mobile number format']);
    exit;
}

$message = trim($_POST['message'] ?? '');

if ($message === '') {
    http_response_code(400);
    echo json_encode(['success' => false, 'error' => 'Empty message']);
    exit;
}

$subscriberId = 'tel:88' . $digits;

// BD Apps SMS Send API requires destinationAddresses array AND subscriberId for single target compatibility
$requestData = [
    'applicationId'        => BDAPPS_APP_ID,
    'password'             => BDAPPS_APP_PASSWORD,
    'subscriberId'         => $subscriberId,
    'destinationAddresses' => [$subscriberId],
    'message'              => $message,
];

$ch = curl_init('https://developer.bdapps.com/sms/send');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($requestData));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);

$responseJson = curl_exec($ch);
$curlError = curl_error($ch);
$statusCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($responseJson === false) {
    http_response_code(502);
    echo json_encode([
        'success'      => false,
        'error'        => 'Connection failed: ' . $curlError,
        'subscriberId' => $subscriberId,
        'message'      => $message,
    ]);
    exit;
}

$response = json_decode($responseJson, true);
$apiStatusCode = $response['statusCode'] ?? null;
$apiStatusDetail = $response['statusDetail'] ?? null;

echo json_encode([
    'success'      => $apiStatusCode === 'S1000',
    'address'      => $subscriberId,
    'message'      => $message,
    'statusCode'   => $apiStatusCode,
    'statusDetail' => $apiStatusDetail,
    'httpStatus'   => $statusCode,
]);

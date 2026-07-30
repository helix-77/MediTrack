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
    echo json_encode(['success' => false, 'message' => 'Invalid mobile number format', 'referenceNo' => null]);
    exit;
}

$subscriberId = 'tel:88' . $digits;

$requestData = [
    'applicationId' => BDAPPS_APP_ID,
    'password' => BDAPPS_APP_PASSWORD,
    'subscriberId' => $subscriberId,
    'applicationHash' => 'MediTrack',
    'applicationMetaData' => [
        'client'  => 'MOBILEAPP',
        'device'  => 'MediTrack Android',
        'os'      => 'android',
        'appCode' => 'https://play.google.com/store/apps/details?id=com.meditrack.app'
    ]
];

$ch = curl_init('https://developer.bdapps.com/subscription/otp/request');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($requestData));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);

$responseJson = curl_exec($ch);

if ($responseJson === false) {
    $error = curl_error($ch);
    curl_close($ch);
    echo json_encode(['success' => false, 'message' => 'Connection error: ' . $error, 'referenceNo' => null]);
    exit;
}
curl_close($ch);

$response = json_decode($responseJson, true);

if (!is_array($response)) {
    echo json_encode(['success' => false, 'message' => 'Invalid server response', 'referenceNo' => null]);
    exit;
}

$referenceNo = trim((string)($response['referenceNo'] ?? ''));

if ($referenceNo !== '') {
    echo json_encode([
        'success'       => true,
        'referenceNo'   => $referenceNo,
        'statusCode'    => $response['statusCode'] ?? '',
        'statusDetail'  => $response['statusDetail'] ?? '',
        'version'       => $response['version'] ?? '',
        'subscriberId'  => $subscriberId
    ]);
    exit;
}

echo json_encode([
    'success'       => false,
    'message'       => $response['statusDetail'] ?? 'OTP reference not returned',
    'referenceNo'   => null,
    'statusCode'    => $response['statusCode'] ?? '',
    'subscriberId'  => $subscriberId
]);

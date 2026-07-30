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
    if (strpos($digits, '880') === 0 && strlen($digits) === 13) {
        $digits = '0' . substr($digits, 3);
    } elseif (strpos($digits, '88') === 0 && strlen($digits) === 12) {
        $digits = '0' . substr($digits, 2);
    }
    return $digits;
}

$digits = bdapps_normalize_mobile($_POST['user_mobile'] ?? $_POST['subscriberId'] ?? '');

if (!preg_match('/^01[3-9][0-9]{8}$/', $digits)) {
    echo json_encode([
        'success'     => false,
        'message'     => 'Invalid mobile number format. BD Apps requires a valid 11-digit mobile number.',
        'referenceNo' => null,
        'statusCode'  => 'E1325',
    ]);
    exit;
}

$subscriberId = 'tel:88' . $digits;

$requestData = [
    'applicationId'   => BDAPPS_APP_ID,
    'password'        => BDAPPS_APP_PASSWORD,
    'subscriberId'    => $subscriberId,
    'applicationHash' => 'MediTrack',
    'applicationMetaData' => [
        'client'  => 'MOBILEAPP',
        'device'  => 'Samsung S10',
        'os'      => 'android 8',
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
    echo json_encode([
        'success'     => false,
        'message'     => 'Connection error: ' . $error,
        'referenceNo' => null,
        'statusCode'  => 'E1000',
    ]);
    exit;
}
curl_close($ch);

$response = json_decode($responseJson, true);

if (!is_array($response)) {
    echo json_encode([
        'success'     => false,
        'message'     => 'Invalid server response',
        'referenceNo' => null,
        'statusCode'  => 'E1000',
    ]);
    exit;
}

$referenceNo = trim((string)($response['referenceNo'] ?? ''));

if ($referenceNo !== '') {
    echo json_encode([
        'success'      => true,
        'referenceNo'  => $referenceNo,
        'subscriberId' => $subscriberId,
        'statusCode'   => $response['statusCode'] ?? '',
        'statusDetail' => $response['statusDetail'] ?? '',
        'version'      => $response['version'] ?? ''
    ]);
    exit;
}

echo json_encode([
    'success'      => false,
    'message'      => $response['statusDetail'] ?? 'OTP reference not returned',
    'referenceNo'  => null,
    'statusCode'   => $response['statusCode'] ?? '',
    'statusDetail' => $response['statusDetail'] ?? '',
    'subscriberId' => $subscriberId
]);

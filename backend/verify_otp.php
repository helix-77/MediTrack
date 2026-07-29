<?php

require_once __DIR__ . '/config.php';

header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");

if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

$otp = trim($_POST['Otp'] ?? $_POST['otp'] ?? '');
$referenceNo = trim($_POST['referenceNo'] ?? '');

if ($otp === '' || $referenceNo === '') {
    echo json_encode(['statusCode' => 'FAILED', 'message' => 'Missing OTP or referenceNo', 'statusDetail' => 'Missing OTP or referenceNo']);
    exit;
}

$requestData = [
    'applicationId' => BDAPPS_APP_ID,
    'password' => BDAPPS_APP_PASSWORD,
    'referenceNo' => $referenceNo,
    'otp' => $otp
];

$ch = curl_init('https://developer.bdapps.com/subscription/otp/verify');
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($requestData));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 15);
curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);

$responseJson = curl_exec($ch);

if ($responseJson === false) {
    $error = curl_error($ch);
    curl_close($ch);
    echo json_encode(['statusCode' => 'FAILED', 'message' => 'Connection error: ' . $error, 'statusDetail' => 'Unable to connect to BDApps server']);
    exit;
}
curl_close($ch);

$response = json_decode($responseJson, true);

if (!is_array($response)) {
    echo json_encode(['statusCode' => 'FAILED', 'message' => 'Invalid server response', 'statusDetail' => 'Failed to parse BDApps response']);
    exit;
}

echo json_encode([
    'statusCode' => $response['statusCode'] ?? 'FAILED',
    'statusDetail' => $response['statusDetail'] ?? '',
    'subscriptionStatus' => $response['subscriptionStatus'] ?? '',
    'subscriberId' => $response['subscriberId'] ?? '',
    'version' => $response['version'] ?? ''
]);
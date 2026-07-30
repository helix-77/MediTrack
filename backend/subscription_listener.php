<?php

/**
 * MediTrack - BD Apps Subscription Notification Listener
 *
 * BD Apps posts JSON notifications to this URL when a user's subscription
 * status changes (e.g. REGISTERED, UNREGISTERED).
 *
 * Configured in BD Apps Portal as:
 * Subscription Notification URL:
 * https://www.bdappsdigitalapps.com/NADB26067/subscription_listener.php
 */

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header('Content-Type: application/json; charset=utf-8');

// Handle preflight requests
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Read raw incoming notification JSON body
$rawInput = file_get_contents('php://input');
$data = json_decode($rawInput, true);

// Optional: Log notifications to file for auditing/debugging
$logLine = date('Y-m-d H:i:s') . ' | IP: ' . ($_SERVER['REMOTE_ADDR'] ?? 'UNKNOWN') . ' | BODY: ' . $rawInput . PHP_EOL;
@file_put_contents(__DIR__ . '/subscription_events.log', $logLine, FILE_APPEND | LOCK_EX);

// Extract status & subscriberId if available
$subscriberId = $data['subscriberId'] ?? null;
$status       = $data['status'] ?? $data['subscriptionStatus'] ?? null;
$appId        = $data['appId'] ?? $data['applicationId'] ?? null;

// Return mandatory BD Apps acknowledgment JSON
http_response_code(200);
echo json_encode([
    'statusCode'   => 'S1000',
    'statusDetail' => 'Subscription notification received successfully',
    'subscriberId' => $subscriberId,
    'status'       => $status,
]);

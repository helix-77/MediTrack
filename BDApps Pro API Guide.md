BDApps API Guide
Document Version1.1.1

Robi Corporate Centre
53 Gulshan South Avenue
Gulshan 1
phone:+88 02 9887146-52
fax:+88 02 9885463
Dhaka-1212
Bangladesh
Document Code ROB-API-DGD v1.1.1 Last edited: 13 May 2015
Copyright © 1997-2015 hSenid Mobile Solutions (Pvt) Ltd. All rights reserved. No part of this publication may be
reproduced, transmitted, transcribed, stored in a retrieval system, or translated into any language, in any form
or by any means, electronic, mechanical, photocopying, recording, or otherwise, without prior written
permission from hSenid Mobile. All copyright, confidential information, patents, design rights and all other
intellectual property rights of whatsoever nature in and to any source code contained herein (including any
header files and demonstration code that may be included), are and shall remain the sole and exclusive
property of hSenid Mobile. The information furnished herein is believed to be accurate and reliable. However,
no responsibility is assumed by hSenid Mobile for its use, or for any infringements of patents or other rights of
third parties resulting from its use.
All other trademarks in this publication are the property of their respective owners.

BDApps API Guide
Table of contents
1 Overview .....................................................................................................................................6
1.1 SMS Service ..........................................................................................................................6
1.2 USSD .....................................................................................................................................6
1.3 CAAS .....................................................................................................................................6
2 HTTP REST ...................................................................................................................................8
2.1 JSON Objects ........................................................................................................................8
3 SMS .............................................................................................................................................9
3.1 Send Service .........................................................................................................................9
3.1.1 Request ..........................................................................................................................9
3.1.2 Response...................................................................................................................... 13
3.2 Receive Service ................................................................................................................... 16
3.2.1 Request ........................................................................................................................ 16
3.2.2 Response...................................................................................................................... 17
3.3 Delivery Status Report ........................................................................................................ 18
3.3.1 Request ........................................................................................................................ 18
3.3.2 Response...................................................................................................................... 20
4 USSD.......................................................................................................................................... 22
4.1 Send Service ....................................................................................................................... 22
4.1.1 Request ........................................................................................................................ 22
4.1.2 Response...................................................................................................................... 25
4.2 Receive Service ................................................................................................................... 26
4.2.1 Request ........................................................................................................................ 26
4.2.2 Response...................................................................................................................... 28
5 CAAS .......................................................................................................................................... 30
5.1 Query Balance..................................................................................................................... 30
5.1.1 Request ........................................................................................................................ 30
5.1.2 Response...................................................................................................................... 33
5.2 Get Payment Instrument List............................................................................................... 35
5.2.1 Request ........................................................................................................................ 35
5.2.2 Response...................................................................................................................... 36
5.3 Direct Debit ........................................................................................................................ 38
5.3.1 Request ........................................................................................................................ 38
5.3.2 Response...................................................................................................................... 40
Status Codes (Non Retry-able) .................................................................................................... 42
Error Codes (Non Retry-able) ...................................................................................................... 42
Error Codes (Retry-able) ............................................................................................................. 44
© 2015 hSenid Mobile. All rights reserved Page 3 of 45

BDApps API Guide
Appendix B ....................................................................................................................................... 45
© 2015 hSenid Mobile. All rights reserved Page 4 of 45

BDApps API Guide
About This Document
The purpose of this document is to provide developing information on BDApps API for SMS and USSD
services.
The intended audience for this document is the Application Developers.
The document is divided into the following chapters:
Chapter Description
1 Overview This chapter gives a brief description of document content.
2 HTTP Rest This chapter gives a brief description of involvement of HTTP REST in
the context.
3 SMS This chapter gives a brief description of SMS REST Service.
4 USSD This chapter gives a brief description of USSD Service.
5 CAAS This chapter gives a brief description of CAAS Service.
© 2015 hSenid Mobile. All rights reserved Page 5 of 45

BDApps API Guide
1 Overview
This chapter describes how the Service Providers can use HTTP-based Interfaces from BDApps API for
SMS, and USSD services. For more details on each service please refer the relevant chapter.
1.1 SMS Service
The SMS Interface allows applications to send and receive SMS messages using a HTTP-based API.
Supported services are as follows:
Send Service – An application wishing to initiate an MT (Mobile Terminated) SMS
message should use this operation type.
Receive Service – This retrieves the SMS sent to the application.
Status Report Service – If an application when performing a Send service Operation had
requested for a status report from BDApps API, then the BDApps API will initiate the
status report service to hand over the status report to the application.
1.2 USSD
The USSD Interface allows applications to initiate USSD sessions using a HTTP-based API. Supported
services are as follows:
Send Service – An application wishing to send response to MO USSD session should call
this method.
Deliver Service – Deliver Service can be either a user initiated session or a response to
an existing USSD session.
1.3 CAAS
Applications have CAAS NCS access if charging as a service requests are required by the application.
Query Balance – This service retrieves the account balance and other related
information of a given subscriber MSISDN.
Direct Debit – This service charges a specific amount from a subscriber’s account.
Get Payment Instrument List - Get Payment Instrument List is to get a list of all the
available payment instruments for a particular subscriber.
© 2015 hSenid Mobile. All rights reserved Page 6 of 45

BDApps API Guide
MO (Mobile Originated) flow:
In MO, first the MO request will be sent to application from the BDApps API. There will be a response
sent from the application to BDApps API subsequently.
1. MO request
BDApps API
Application
2. Response from Application
MT (Mobile Terminated) flow:
In MT, a MT request is sent from application to the BDApps API. The MT request response will be
from the BDApps API to application subsequently.
1. MT request
BDApps API
Application
2. MT Request Response
© 2015 hSenid Mobile. All rights reserved Page 7 of 45

BDApps API Guide
2 HTTP REST
In this context, both requests/responses used to exchange information are with content type
"application/json".
2.1 JSON Objects
JSON objects are used as content type to communicate between application and BDApps API. JSON is
an open, text-based data exchange format; it is human-readable, independent, and supports a wide
availability of implementations.
© 2015 hSenid Mobile. All rights reserved Page 8 of 45

BDApps API Guide
3 SMS
The SMS REST Service provides operations for sending SMS to BDApps API and to receive the SMS.
E.g., A user sending a text message to a mobile phone from an application and receiving SMS from a
mobile phone to an application.
3.1 Send Service
This service let the user send SMS to one or more terminals (phones or any SMS-enabled device)
from their application.
Send service supports only POST HTTP requests. This is used when sending SMS to a mobile phone
from an application.
An application wishing to initiate an MT SMS message should use this operation type.
The URL for SMS Send service is as follows:
https://developer.bdapps.com/sms/send
3.1.1 Request
Following is a sample request of send service.
{
"applicationId":"APP_000027",
"password":"10d8769c825f4aad0c511dfe3de3f121",
"message":"Sample Message",
"destinationAddresses":["tel:8801812345678"]
}
Following are the Request parameters of Send service.
Parameter Name Description Type Mandatory /
Optional
© 2015 hSenid Mobile. All rights reserved Page 9 of 45

|     |     |     |     | BDApps API Guide  |
| --- | --- | --- | --- | ----------------- |
applicationId  Application  ID  as  given  when  String  Mandatory
provisioned
| password  | Password  | given  | when  String  | Mandatory  |
| --------- | --------- | ------ | ------------- | ---------- |
provisioned
| version  | API version                    |     | String  | Optional              |
| -------- | ------------------------------ | --- | ------- | --------------------- |
|          | shall be numbered as 1.0, 2.0  |     |         | If  not  specified    |
|          | etc                            |     |         | shall  be  validated  |
against  the  latest
version
destinationAddresses  List of destination addresses  String  at  least  one  need
to be specified
should be telephone numbers
tel - for MSISDN
tel: 8801812345678,
tel: 8801812345678
|     | Address  can  | also  have  | the  |     |
| --- | ------------- | ----------- | ---- | --- |
value - tel: all
which will in turn be a message
to the subscribed base of the
application
|     | Note:  tel  | might  be  a  | masked  |     |
| --- | ----------- | ------------- | ------- | --- |
number depending on the type
of application.
| message  | The message that need to be  |     | String  | Mandatory   |
| -------- | ---------------------------- | --- | ------- | ----------- |
sent, Messages over the limit
shall be broken up by the and
messaged.
sourceAddress  The  sender  address  to  be  String  Optional
|     | shown  -  can  | be  one  | of  the  |     |
| --- | -------------- | -------- | -------- | --- |
provisioned values in alias list
© 2015 hSenid Mobile. All rights reserved                                                                            Page 10 of 45

  BDApps API Guide
deliveryStatusRequest  To  indicate  the  need  of  Enumerator  Optional
Delivery Status Report for the
|     |     | 0  -  Delivery  | If  | not  specified  |     |
| --- | --- | --------------- | --- | --------------- | --- |
message.
|     |     | Report          | not  shall  | be  assumed     |       |
| --- | --- | --------------- | ----------- | --------------- | ----- |
|     |     | required        | to          | be  a  request  |       |
|     |     |                 | without     | the             | need  |
|     |     | 1  -  Delivery  |             |                 |       |
for Delivery Report
Report Required
encoding  Encoding  scheme  used  in  the  Enumerated   Optional
message
|     |     | 0 – Text  | If             | not  specified  |     |
| --- | --- | --------- | -------------- | --------------- | --- |
|     |     |           | taken as Text  |                 |     |
16- Bengali
|     |     |     | If  | the  encoding  |     |
| --- | --- | --- | --- | -------------- | --- |
240 - Flash SMS
|     |     |     | type  | is  “Binary”  |     |
| --- | --- | --- | ----- | ------------- | --- |
245 - Binary SMS
|     |     |     | then     | the  message  |     |
| --- | --- | --- | -------- | ------------- | --- |
|     |     |     | content  | will          | be  |
represented as hex
encoded.
chargingAmount  Charging amount specified for  Number  to  2  Optional
| variable  charging  | applications  | decimal  places  | -       |     |     |
| ------------------- | ------------- | ---------------- | ------- | --- | --- |
| only                |               | shall            | be      |     |     |
|                     |               | considered       | only    |     |     |
|                     |               | in               | system  |     |     |
|                     |               | currency         | Eg.     |     |     |
78.05
binaryHeader  For  advanced  type  messages  Hexadecimal  Optional  (‘Binary
| where the binary header shall  |     | String  | Header’    |     | is  |
| ------------------------------ | --- | ------- | ---------- | --- | --- |
| be sent from the application   |     |         | Mandatory  |     | if  |
message
‘encoding’ is ‘Flash’
or ‘Binary’ )

© 2015 hSenid Mobile. All rights reserved                                                                            Page 11 of 45

BDApps API Guide
Comprehensive sample request:
{
"password":"c609a16c0b01aac11396cea484f8e535",
"message":"Sample Message",
"destinationAddresses":["tel:8801812345678"],
"applicationId":"APP_000006",
"deliveryStatusRequest":”0”,
"version":”1.0”,
"sourceAddress":”<shortcode_appname>”,
"encoding":”16”,
"binary-header":”7663697479”,
"chargingAmount": ”8.252342”
}
© 2015 hSenid Mobile. All rights reserved Page 12 of 45

BDApps API Guide
3.1.2 Response
Following is a sample response of send service.
{
"statusCode":"S1000",
"requestId":"101307311109540017",
"statusDetail":"Request was successfully processed",
"destinationResponses":[{"statusCode":"S1000",
"timeStamp":"20130731110954",
"address":"tel: 8801812345677",
"statusDetail":"Request was successfully processed",
"messageId":"101307311109540017"}],
"version":"1.0"
}
Following are the Response parameters of Send service.
Parameter Name Description Type Mandatory
/ Optional
version API version String Mandatory
shall be numbered as 1.0, 2.0 etc
If version was specified in request, same
version must be sent in response.
If version was not specified in request, then
latest version will be specified in response.
requestId requestId to uniquely Identify the request String Mandatory
within the BDApps API
© 2015 hSenid Mobile. All rights reserved Page 13 of 45

BDApps API Guide
statusCode The status code for the entire request String Mandatory
statusDetail The status detail for the entire request String Mandatory
destinationResponses The list of Responses for the full list of String Mandatory
Addresses It will be a collection with
individual entry for each element in the
Address list of the request.
Address
TimeStamp - Processed Time stamp
MessageId - Message Identifier
StatusCode - Error Code
StatusDetail - Error detail
Eg:
{"DesinationResponses" : {
"DestinationResponse" : [ { "Address": "tel:
+880183216345490", "TimeStamp":
"yyyymmddhhmmss", "MessageId":
"dfsfs1213", "StatusCode": "SBL-SMS-MT-
2000", "StatusDetail": "Success" } {
"Address": "tel: 8801832165490",
"TimeStamp": "yyyymmddhhmmss",
"MessageId": "dfsfs12232", "StatusCode":
"SBL-SMS-MT-2000", "StatusDetail":
"Success" } ] },
© 2015 hSenid Mobile. All rights reserved Page 14 of 45

BDApps API Guide
Sample Destination Response:
"destinationResponses":[{"statusCode":"S1000",
"timeStamp":"20130731114407",
"address":"tel : 8801812345677",
"statusDetail":"Request was successfully processed",
"messageId":"101307311144070043"}],
Comprehensive sample response:
{
"statusCode":"S1000",
"requestId":"101307311144070043",
"statusDetail":"Request was successfully processed",
"destinationResponses":[{"statusCode":"S1000",
"timeStamp":"20130731114407",
"address":"8801812345677",
"statusDetail":"Request was successfully processed",
"messageId":"101307311144070043"}],
"version":"1.0"
}
© 2015 hSenid Mobile. All rights reserved Page 15 of 45

BDApps API Guide
3.2 Receive Service
This retrieves the SMS sent to the web application. Receive service returns only a list of SMS
messages received since the previous invocation of the method to receive SMSs.
3.2.1 Request
Following is a sample request of receive service.
{
"message":"Test Message",
"requestId":"51307311302350037",
"applicationId":"APP_000006",
"sourceAddress":"tel: 8801832160987",
"version":”1.0”,
"encoding":”16”
}
Following are the Request parameters of receive service.
Parameter Name Description Type Mandatory
/ Optional
version API version String Mandatory
shall be numbered as 1.0, 2.0 etc
applicationId Application ID as given when String Mandatory
provisioned
sourceAddress source address String at least one
will be
sourceAddress: tel: +8801832160987
specified
© 2015 hSenid Mobile. All rights reserved Page 16 of 45

BDApps API Guide
message Message as sent from the user String Mandatory
requestId Request Identifier in the BDApps API. String Mandatory
encoding Encoding scheme used in the Enumerated Mandatory
message
0 – Text
16- Bengali
If the encoding type is “Binary” then
240 - Flash SMS
the message content will be
245 - Binary SMS
represented as hex encoded.
3.2.2 Response
Following is a sample response of receive service.
{
"statusCode":"S1000",
"statusDetail":"Success"
}
Following are the Response parameters of receive service.
Parameter Description Type Mandatory
Name / Optional
statusCode The error code for the entire request String Mandatory
statusDetail The error detail for the entire request String Mandatory
© 2015 hSenid Mobile. All rights reserved Page 17 of 45

BDApps API Guide
Comprehensive sample response:
{
"statusCode":"S1000",
"statusDetail":"Success"
}
3.3 Delivery Status Report
When performing a SendSms Operation if an application had requested for a Delivery Response
message from the Message Centre, then the BDApps API will initiate the Delivery Report service to
hand over the Delivery Response message to the application. The messageId should be used to
match the MT response with the Delivery Report.
3.3.1 Request
Following is a sample request of delivery status report service.
{
"destinationAddress":"tel:8801832160987",
"timeStamp":"20120113082110",
"requestId":"51307311302350037",
"deliveryStatus":"DELIVERED"
}
© 2015 hSenid Mobile. All rights reserved Page 18 of 45

BDApps API Guide
Following are the request parameters of delivery status report service.
Parameter Name Description Type Mandatory
/ Optional
destinationAddress Address of the subscriber String Mandatory
E.g., tel: 8801832160987
timeStamp The timestamp sent from the SMS String Mandatory
"yyMMddHHmm"
yy – last two digits of the year (00-99)
MM – month (01-12)
dd – day (01-31)
HH – hour (00-23)
mm- minute (00-59)
requestId requestId to uniquely Identify the String Mandatory
request within the BDApps API
deliveryStatus Enum From SMPP Gateway : DELIVRD, Mandatory
EXPIRED, DELETED, UNDELIV, ACCEPTD,
UNKNOWN, REJECTD
Enum from bd-apps to Application:
DELIVERED, EXPIRED, DELETED,
UNDELIVERABLE, ACCEPTED,
UNKNOWN, REJECTED
© 2015 hSenid Mobile. All rights reserved Page 19 of 45

BDApps API Guide
Comprehensive sample request:
{
"destinationAddress":"tel: 8801832160987",
"timeStamp":"20120113082110",
"requestId":"51307311302350037",
"deliveryStatus":"DELIVERED"
}
3.3.2 Response
Following is a sample request of delivery status report service.
{
"statusCode":"S1000",
"statusDetail":"Success"
}
Following are the response parameters of delivery status report service.
Parameter Description Type Mandatory
Name / Optional
statusCode The status code for the entire request String Mandatory
statusDetail The status detail for the entire request String Mandatory
© 2015 hSenid Mobile. All rights reserved Page 20 of 45

BDApps API Guide
Comprehensive sample response:
{
"statusCode":"S1000",
"statusDetail":"Success"
}
Note: Sample status and error codes are listed in the Appendix A
© 2015 hSenid Mobile. All rights reserved Page 21 of 45

BDApps API Guide
4 USSD
USSD (Unstructured Supplementary Service Data) is a capability built into SMS-based mobile devices.
USSD information is directly sent from the sender’s device to an application which is with USSD . A
USSD service can be invoked either by the mobile user or by a USSD .
4.1 Send Service
This service lets the user send USSD to one or more terminals from the application.
Send service supports only POST HTTP requests. This is used when sending USSD messages to a
mobile phone from an application.
The URL for USSD Send service is as follows:
https://developer.bdapps.com/ussd/send
4.1.1 Request
Following is a sample request for send service.
{
"applicationId":"APP_003117",
"password":"18b834673a1eed3913ce72fec6d91df4",
"message": "1. Press One
2. Press two
3. Press three
4. Exit",
"sessionId": "1330929317043",
"ussdOperation": "mt-cont",
"destinationAddress": "tel: 8801812345678"
}
© 2015 hSenid Mobile. All rights reserved Page 22 of 45

|     |     |     |     |     | BDApps API Guide  |
| --- | --- | --- | --- | --- | ----------------- |
Following are the Request parameters of send service.

| Parameter Name  | Description  |     |     | Type  | M / O  |
| --------------- | ------------ | --- | --- | ----- | ------ |
applicationId  Application ID as given when provisioned  String  M
| password  | Password given when provisioned             |     |     | String  | M   |
| --------- | ------------------------------------------- | --- | --- | ------- | --- |
| version   | API version (shall be numbered as 1.0 etc)  |     |     |         | O   |
If not specified shall be validated against
the latest version
| sessionId  | Unique  | number  that  | USSD  Gateway  | String  | M   |
| ---------- | ------- | ------------- | -------------- | ------- | --- |
assigns to the application for the duration
|     | of  the  | session.  This  | number  will  be  |     |     |
| --- | -------- | --------------- | ----------------- | --- | --- |
maintained in all messages throughout a
single session.
ussdOperation  mo-init  :  BDApps  API  to  assign  when  a  Enumerator  M
USSD session is initiated by subscriber
|     |                                           |                     |                | Data  type              | will  be  |
| --- | ----------------------------------------- | ------------------- | -------------- | ----------------------- | --------- |
|     | mo-cont : BDApps API to assign for any    |                     |                | string  where           | the       |
|     | USSD message originated from subscriber,  |                     |                | operation               | name      |
|     | that comes after a init                   |                     |                | itself will be used in  |           |
|     |                                           |                     |                | the  parameter          |           |
|     | mt-init                                   | :  App  to  assign  | when  a  USSD  |                         |           |
value.
session is initiated by an application
|     | mt-cont  | :  App  to  assign  | for  any  USSD  |     |     |
| --- | -------- | ------------------- | --------------- | --- | --- |
message originated from application, that
comes after a init
mt-fin : App to assign when session ends
in final message
© 2015 hSenid Mobile. All rights reserved                                                                            Page 23 of 45

|                     |                      |     |     |         | BDApps API Guide  |
| ------------------- | -------------------- | --- | --- | ------- | ----------------- |
| destinationAddress  | Destination address  |     |     | String  | M                 |
should be a telephone number
tel - for MSISDN

tel: 8801812345678
|     | Note  :  | tel  might  be  | a  masked  number  |     |     |
| --- | -------- | --------------- | ------------------ | --- | --- |
depending on the type of application
encoding  Encoding scheme used in the message  Enumerated   O
|     | 440 - Plain ASCII characters  |     |     |     |     |
| --- | ----------------------------- | --- | --- | --- | --- |
16- Bengali
| message   | Message as sent to the user  |     |     | String  | M   |
| --------- | ---------------------------- | --- | --- | ------- | --- |
chargingAmount  Charging  amount  specified  for  variable  number  to  2  O
|     | charging applications only  |     |     | decimal  places  | -   |
| --- | --------------------------- | --- | --- | ---------------- | --- |
shall be considered
|     |     |     |     | only  in  system  |     |
| --- | --- | --- | --- | ----------------- | --- |
currency Eg. 78.05

Comprehensive sample request:

{
    "applicationId": "APP_000001",
    "password": "18b834673a1eed3913ce72fec6d91df4",
    "message": "1. Press One
        2. Press two
        3. Press three
        4. Exit",
    "sessionId": "1330929317043",
    "ussdOperation": "mt-cont",
    "destinationAddress": "tel: 8801812345678",
© 2015 hSenid Mobile. All rights reserved                                                                            Page 24 of 45

BDApps API Guide
"version":”1.0”,
"encoding":”16”,
"chargingAmount":”8.252342”
}
4.1.2 Response
USSD-Send-Response is a response from the BDApps API to the application, which will be sent as a
response to the USSD-Send-Request message.
Following are the response parameters of send service.
Parameter Name Description Type M / O
version API version (shall be numbered as 1.0 etc) String M
requestId requestId to uniquely Identify the request String M
within the BDApps API
statusCode The status code for the entire request String M
statusDetail The status detail for the entire request String M
Comprehensive sample response:
{
"statusCode":"S1000",
"requestId":"101308060614220956",
"statusDetail":"Success",
"version":"1.0"
}
© 2015 hSenid Mobile. All rights reserved Page 25 of 45

BDApps API Guide
4.2 Receive Service
The ReceiveUssd service allows BDApps API to deliver MO messages to the application using HTTP –
based API. The flow of messages is initiated by a MO request sent to an application, the BDApps API
will deliver the message to the application as an acknowledgement. Hence it could be either request-
response exchange or a request-exception exchange.
Receive USSD request is a MO message which will be sent to the application through the BDApps API
as a delivery request.
4.2.1 Request
Following is a sample request for receive service.
{
"message":"010",
"ussdOperation":"mo-init",
"requestId":"071308060343170263",
"sessionId":"1209992331266121",
"encoding":"16",
"applicationId":"APP_003117",
"sourceAddress":"tel: 8801812345678",
"version":"1.0"
}
© 2015 hSenid Mobile. All rights reserved Page 26 of 45

|     |     |     |     |     |     | BDApps API Guide  |
| --- | --- | --- | --- | --- | --- | ----------------- |
Following are the request parameters of receive service.

| Parameter  | Description  |     |     |     | Type  | M / O  |
| ---------- | ------------ | --- | --- | --- | ----- | ------ |
Name
version  API version (shall be numbered as 1.0 etc)  String  M
applicationId  Application ID as given when provisioned  String  M
sessionId  Unique  number  that  USSD  GW  assigns  to  the  String  M
application for the duration of the session
ussdOperation  mo-init  :  BDApps  API  to  assign  when  a  USSD  Integer   M
session is initiated by subscriber
|     | mo-cont  | :  BDApps  API  | to  assign  | for  any  USSD  |     |     |
| --- | -------- | --------------- | ----------- | --------------- | --- | --- |
message originated from subscriber, that comes
after a init
mt-init : App to assign when a USSD session is
initiated by an application
|     | mt-cont : App  | to assign for any USSD message  |     |     |     |     |
| --- | -------------- | ------------------------------- | --- | --- | --- | --- |
originated from application, that comes after a init
mt-fin : App to assign when session ends in final
message
| sourceAddress  | sender address  |     |     |     | String  | M   |
| -------------- | --------------- | --- | --- | --- | ------- | --- |
sourceAddress: tel: 8801832165490
| message  | Message as sent from the user  |     |     |     | String  | M   |
| -------- | ------------------------------ | --- | --- | --- | ------- | --- |
encoding  Encoding scheme used in the message  Enumerated   M
|     | 440 - Plain ASCII characters  |     |     |     |     |     |
| --- | ----------------------------- | --- | --- | --- | --- | --- |
16- Bengali
requestId  Request ID to uniquely Identify the request within  String  M
the BDApps API

© 2015 hSenid Mobile. All rights reserved                                                                            Page 27 of 45

BDApps API Guide
Comprehensive sample request:
{
"message":"010",
"ussdOperation":"mo-init",
"requestId":"071308060343170263",
"sessionId":"1209992331266121",
"encoding":"16",
"applicationId":"APP_003117",
"sourceAddress":"tel: 8801812345678",
"version":"1.0"
}
4.2.2 Response
Deliver-USSD-Response should be the response given by the Application to the BDApps API as an
acknowledgement on the receipt of a MO message submitted by BDApps API.
Following are the response parameters of receive service.
Parameter Name Description Type M / O
statusCode The status code for the entire request String M
statusDetail The status detail for the entire request String M
© 2015 hSenid Mobile. All rights reserved Page 28 of 45

BDApps API Guide
Comprehensive sample response:
{
"statusCode": "S1000",
"statusDetail": "Success"
}
© 2015 hSenid Mobile. All rights reserved Page 29 of 45

BDApps API Guide
5 CAAS
Applications have Caas NCS access if charging as a service requests are required by the application.
5.1 Query Balance
This service retrieves the account balance and other related information of a given subscriber
MSISDN. Account information comprises of Account type (Pre paid or Post paid) and Account’s status
(Activate or Disable).
The URL for Query Balance service is as follows:
https://developer.bdapps.com/caas/balance/query
5.1.1 Request
Following is a sample request for query balance service.
{
"applicationId":"APP_000010",
"password":"8f57d2e8de06e6f2d6ee5da6107d0a4f",
"subscriberId":"tel: 8801812345678"
"paymentInstrumentName":"Mobile Account"
}
© 2015 hSenid Mobile. All rights reserved Page 30 of 45

BDApps API Guide
Following are the Request parameters of query balance service.
Parameter Name Description Type M / O
applicationId Used to identify the application. This is a String (32) M
unique identifier generated while provisioning
an application.
Only a single value can be sent per request.
password Used to authenticate the application String(32) M
originated message against the service
provider’s credentials.
Encoded, single value.
subscriberId This can be the MSISDN of the subscriber String M
whose account balance is being queried.
Note: tel: number might be a masked number
depending on the type of the application.
Only a single value can be sent per request.
paymentInstrumentName The name of the payment instrument. Enumerator M
Only a single value can be sent per request.
accountId The account of the payment instrument. String O
Only a single value can be sent per request.
currency The currency of the amount. String O
Only a single value can be sent per request.
Only ‘BDT’ is allowed.
© 2015 hSenid Mobile. All rights reserved Page 31 of 45

BDApps API Guide
Comprehensive sample request:
{
"applicationId":"APP_000010",
"password":"8f57d2e8de06e6f2d6ee5da6107d0a4f",
"subscriberId":"tel: 8801812345678",
"currency":"BDT",
"accountId":"8801812345678",
"paymentInstrumentName":"Mobile Account"
}
© 2015 hSenid Mobile. All rights reserved Page 32 of 45

|     |     |     |     |     | BDApps API Guide  |
| --- | --- | --- | --- | --- | ----------------- |
5.1.2 Response
Following are the response parameters of query balance service.

| Parameter Name  | Description  |     |     | Type  | M / O  |
| --------------- | ------------ | --- | --- | ----- | ------ |
accountType  Account  type  of  the  subscriber  id.  String  M
E.g. Prepaid/Post paid for GSM domain.
Only a single set of elements can be sent per
request.
accountStatus  Account status of the subscriber ID  String  M
Only a single set of elements can be sent per
request
| statusCode  | Status of the operation.  |     |     | String  | M   |
| ----------- | ------------------------- | --- | --- | ------- | --- |
Only a single set of elements can be sent per
request.
statusDetail  The  textual  description  of  the  operation's  String  M
status.
Only a single set of elements can be sent per
request.
chargeableBalanc Available chargeable balance of the subscriber.  String  M
e
|     | Refers                                           | to  either  remaining  | account  balance  | (rounded      | up  to  |
| --- | ------------------------------------------------ | ---------------------- | ----------------- | ------------- | ------- |
|     | (prepaid user) or the difference between credit  |                        |                   | two  decimal  |         |
|     | limit and outstanding bill (postpaid user).      |                        |                   | points)       |         |
Only a single value can be sent per request.

© 2015 hSenid Mobile. All rights reserved                                                                            Page 33 of 45

BDApps API Guide
Comprehensive sample response:
{
"statusCode":"S1000",
"chargeableBalance":"100",
"statusDetail":"Request was successfully processed",
"accountStatus":"0",
"accountType":"PREPAID"
}
© 2015 hSenid Mobile. All rights reserved Page 34 of 45

|                                   |     |     | BDApps API Guide  |
| --------------------------------- | --- | --- | ----------------- |
| 5.2  Get Payment Instrument List  |     |     |                   |
Get Payment Instrument List is to get a list of all the available payment instruments for a particular
subscriber. In the request, the payment instrument list can be specified; either asynchronous or
synchronous.
If the payment instrument type is not specified, the entire available payment instrument list will be
sent.
The URL for 'Get Payment Instrument List' service is as follows:
https://developer.bdapps.com/caas/list/pi

5.2.1 Request
Following are the request parameters of Get Payment Instrument List.

| Parameter  | Description  | Type  | M / O  |
| ---------- | ------------ | ----- | ------ |
Name
| applicationId  | appId of the application     | String  | M   |
| -------------- | ---------------------------- | ------- | --- |
| password       | Password of the application  | String  | M   |
subscriberId  This can be the MSISDN of the subscriber. This is a  String   M
unique identifier.
Tel: is for MSISDN
Subscriber: tel: 8801812345678
Note: tel might be a masked number depending
on the type of the application
| type  | Payment instrument type  | Enumerated  | O   |
| ----- | ------------------------ | ----------- | --- |
|       | Possible values:         |             |     |
- sync
- async
- all
(by default: all)
Comprehensive sample request:
© 2015 hSenid Mobile. All rights reserved                                                                            Page 35 of 45

BDApps API Guide
{
"applicationId":"APP_000010",
"password":"8f57d2e8de06e6f2d6ee5da6107d0a4f",
"subscriberId":"tel: 8801812345678",
"type":"all"
}
5.2.2 Response
Following are the response parameters of Get Payment Instrument List.
Parameter Name Description Type M / O
paymentInstrumentList This is the list of payment instruments String M
configured to the subscriber. It should be as
(if the
follows.
request is
E.g., successful)
[
{"name":"Mobile Account",
"type":"sync"},
]
- name : payment instrument name
- type: payment instrument type
statusCode Status of the operation String M
statusDetail The textual description of the operation's String M
status
© 2015 hSenid Mobile. All rights reserved Page 36 of 45

BDApps API Guide
Comprehensive sample response:
{
"statusCode": "S1000",
"statusDetail": "Success",
"paymentInstrumentList": [
{
"name": "Mobile Account",
"type": "sync"
}
]
}
© 2015 hSenid Mobile. All rights reserved Page 37 of 45

BDApps API Guide
5.3 Direct Debit
This service charges a specific amount from a subscriber’s account.
The URL for Direct Debit service is as follows:
https://developer.bdapps.com/caas/direct/debit
5.3.1 Request
Following is a sample request for direct debit service.
{
"externalTrxId":"25609",
"amount":"5",
"applicationId":"APP_000010",
"password":"8f57d2e8de06e6f2d6ee5da6107d0a4f",
"subscriberId":"tel: 8801812345678",
"paymentInstrumentName":"Mobile Account"
}
Following are the request parameters of direct debit service.
Parameter Name Description Type M /
O
applicationId Used to identify the application. This is a String(32) M
unique identifier generated by bd-apps when
provisioning an application.
Only a single value can be sent per request.
© 2015 hSenid Mobile. All rights reserved Page 38 of 45

BDApps API Guide
password Used to authenticate the application String(32) M
originated message against the service
providers credentials.
Encoded, single value.
externalTrxId This is the transaction ID generated by the String(32) M
application to map the request with the
response.
This is needed to avoid any conflicts when SP
inquires about a transaction.
Only a single value can be sent per request.
subscriberId This can be the MSISDN the subscriber to be String M
charged. This is a unique identifier.
Tel: is for MSISDN
Subscriber: tel: 8801812345678
Note: tel might be a masked number
depending on the type of the application
Only a single value can be sent per request.
paymentInstrumentName The name of the payment instrument. Enumerator M
Only a single value can be sent per request.
accountId The account of the payment instrument. String O
Only a single value can be sent per request.
amount Amount to be reserved for charging. String M
Only a single value can be sent per request. (rounded up
to two
decimal
points)
currency The currency of the amount. String O
Only a single value can be sent per request.
Only ‘BDT’ is allowed.
Comprehensive sample request for direct debit service:
© 2015 hSenid Mobile. All rights reserved Page 39 of 45

BDApps API Guide
{
"externalTrxId":"25609",
"amount":"5",
"applicationId":"APP_000010",
"password":"8f57d2e8de06e6f2d6ee5da6107d0a4f",
"subscriberId":"tel: 8801812345678",
"currency":"BDT",
"accountId":"8801812345678",
"paymentInstrumentName":"Mobile Account"
}
5.3.2 Response
Following are the response parameters of direct debit service.
Parameter Name Description Type M / O
externalTrxId The transaction ID generated by the String M
application to map the request with the
response.
Only a single value can be sent per request.
internalTrxId Internal Transaction ID generated by the String(32) M
Payment Gateway for the transaction. This
is unique per transaction.
Only a single value can be sent per request.
referenceId Unique number generated by the system for 8 digits O
the payment request. This is required to be
entered in the external charging
system/menu.
© 2015 hSenid Mobile. All rights reserved Page 40 of 45

BDApps API Guide
timeStamp System date and time of success or failed Date/Time string
transaction. in ISO-8601
format
Only a single value can be sent per request.
e.g.'2011-08-
23T16:50:31.418
+05:30'
statusCode Status of the operation. String M
Only a single set of elements can be sent
per request.
statusDetail The textual description of the operation's String M
status.
Only a single set of elements can be sent
per request.
Comprehensive sample response:
{
"statusCode":"S1000",
"timeStamp":"2013-08-01T08:43:34.344+05:30",
"externalTrxId":"25609",
"statusDetail":"Request was successfully processed",
"internalTrxId":"913080108430074"
}
© 2015 hSenid Mobile. All rights reserved Page 41 of 45

BDApps API Guide
Appendix A
Status Codes and Error Codes
Status Codes (Non Retry-able)
Code Description
S1000 Process completed successfully for all the available destination
numbers.
Error Codes (Non Retry-able)
Code Description
E1313 Authentication failed. No such active application with applicationId
<application-id>, or no active service provider or the given password
in the request is invalid.
E1303 IP address from which this request originated is not provisioned to
send request to application <application-id>. Please use a
provisioned system to send request or contact system admin to
provision the new IP.
E1312 Request is Invalid. <specify_the_reason> Refer the BDApps API NBL
API Developer Guide for the mandatory fields and correct format of
the request.
E1309 Requested SMS service is not allowed for this Application. Please
check the issue with BDApps API system administrator.
E1311 Mobile terminated SMS messages have not enabled. Check your NCS
configuration in provisioning.
E1315 Cannot find the requested service SMS or it is not active.
E1317 <MSISDN> in request is invalid or not allowed.
© 2015 hSenid Mobile. All rights reserved Page 42 of 45

BDApps API Guide
E1328 Charging operation {operation} not allowed. Please check the NCS
configuration.
E1341 Request failed. Errors occurred while sending the request for all the
destinations.
E1334 SMS sent to <application name> application could not be processed
as the message length is too long. Maximum message length allowed
is <specify_max_limit>
E1335 SMS sent to <application name> application could not be processed
as the advertisement message length is too long. Maximum message
length allowed for advertisements is <specify_max_adv_limit>
E1337 Duplicate request.
E1601 System experienced an unexpected error.
E1342 MSISDN is black listed. Not authorized to use the application
<application_name>
E1343 MSISDN is not white listed. Only white list numbers are allowed to
send messages at this state.
E1325 Format of the address is invalid. Expected format is "tel:
8801812345678"
E1331 <sourceAddress> is not allowed. Please use one of the values
configured in alias configuration in the SLAs or send the request
without <sourceAddress>, so BDApps API will use the default source
address to send the message to subscriber.
E1308 Permanent charging error due <specify_reason E.g., Insufficient
Balance>.
© 2015 hSenid Mobile. All rights reserved Page 43 of 45

  BDApps API Guide
Error Codes (Retry-able)
| Code  | Description  |     |
| ----- | ------------ | --- |
E1318  Transaction limit per second has exceeded. Please throttle requests
not to exceed the transaction limit. Contact BDApps API admin to
increase the traffic limit.
E1319  Transaction limit for today is exceeded. Please try again tomorrow or
contact BDApps API  admin to increase the transaction per day limit
| E1326  | Insufficient balance.                  |     |
| ------ | -------------------------------------- | --- |
| E1602  | Message delivery failed. Please retry  |     |
E1603  Temporary System Error occurred while delivering your request.

© 2015 hSenid Mobile. All rights reserved                                                                            Page 44 of 45

BDApps API Guide
Appendix B
What follows is a list of definitions of all terms, acronyms and abbreviations required to properly
interpret this document.
NCS – Network Capability Service
SMS –Simple Message Service
HTTP – Hyper Text Transfer Protocol
MO – Mobile Originated
MT – Mobile Terminated
MSISDN – Mobile Station Integrated Services Digital Network
SLA – Service Level Agreement
© 2015 hSenid Mobile. All rights reserved Page 45 of 45
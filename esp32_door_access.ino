#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

// Wifi configuration
const char *WIFI_SSID = "YOUR_WIFI_SSID";
const char *WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// Backend configuration
const char *BACKEND_HOST = "your-backend.example.com";
const char *BACKEND_PATH = "/access/validate";
const char *BLE_CHALLENGE_PATH = "/access/ble/challenge";
const char *BLE_VERIFY_PATH = "/access/ble/verify";
const char *DEVICE_ID = "esp32_01";
const char *DOOR_ID = "door_1";
const char *DEVICE_KEY = "your-device-key";

// BLE configuration
#define SERVICE_UUID "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHALLENGE_CHAR_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define RESPONSE_CHAR_UUID "beb5483e-36e2-4688-b7f5-ea07361b26a8"
#define STATUS_CHAR_UUID "beb5483e-36e3-4688-b7f5-ea07361b26a8"

// Timeout and retry behavior
const unsigned long WIFI_RECONNECT_INTERVAL_MS = 5000;
const unsigned long HTTP_TIMEOUT_MS = 8000;
const int MAX_VALIDATE_RETRIES = 2;
const unsigned long SCAN_COOLDOWN_MS = 2000;
const unsigned long DOOR_COOLDOWN_MS = 5000;
const unsigned long RELAY_ACTIVE_MS = 3000;
const unsigned long HEARTBEAT_INTERVAL_MS = 60000;
const unsigned long BLE_CONNECTION_TIMEOUT_MS = 10000;
const unsigned long BLE_CHALLENGE_TIMEOUT_MS = 30000;

// Pin configuration
const int SCANNER_RX_PIN = 16;
const int SCANNER_TX_PIN = 17;
const int RELAY_PIN = 26;
const int STATUS_LED_PIN = 2;
const int RELAY_ACTIVE_STATE = HIGH;
const int RELAY_INACTIVE_STATE = (RELAY_ACTIVE_STATE == HIGH ? LOW : HIGH);

// TLS root certificate for backend; replace with your CA certificate
const char BACKEND_ROOT_CA[] = R"EOF(
-----BEGIN CERTIFICATE-----
MIID...YOUR_ROOT_CA_CERTIFICATE...AB
-----END CERTIFICATE-----
)EOF";

WiFiClientSecure secureClient;
BLEServer *pServer = NULL;
BLECharacteristic *pChallengeCharacteristic = NULL;
BLECharacteristic *pResponseCharacteristic = NULL;
BLECharacteristic *pStatusCharacteristic = NULL;

String scannerBuffer = "";
String currentChallengeId = "";
String currentChallenge = "";
unsigned long lastScanMillis = 0;
unsigned long lastDoorActionMillis = 0;
unsigned long doorOpenUntil = 0;
unsigned long lastWifiAttemptMillis = 0;
unsigned long lastHeartbeatMillis = 0;
unsigned long bleConnectionStart = 0;
unsigned long bleChallengeStart = 0;
bool bleClientConnected = false;

void setup()
{
    Serial.begin(115200);
    delay(100);
    Serial.println("ESP32 Door Access Booting...");

    pinMode(RELAY_PIN, OUTPUT);
    pinMode(STATUS_LED_PIN, OUTPUT);
    digitalWrite(RELAY_PIN, RELAY_INACTIVE_STATE);
    digitalWrite(STATUS_LED_PIN, LOW);

    Serial2.begin(115200, SERIAL_8N1, SCANNER_RX_PIN, SCANNER_TX_PIN);
    setupBLE();
    connectToWiFi();
}

void loop()
{
    handleWiFiReconnect();
    processScannerInput();
    processBLE();
    updateDoorRelay();
    sendHeartbeatIfNeeded();
}

void connectToWiFi()
{
    Serial.printf("Connecting to WiFi SSID '%s'...\n", WIFI_SSID);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    unsigned long start = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - start < 10000)
    {
        delay(200);
        Serial.print('.');
    }
    if (WiFi.status() == WL_CONNECTED)
    {
        Serial.println("\nWiFi connected");
        Serial.print("IP address: ");
        Serial.println(WiFi.localIP());
    }
    else
    {
        Serial.println("\nWiFi connection failed, retrying later");
    }
}

void handleWiFiReconnect()
{
    if (WiFi.status() == WL_CONNECTED)
    {
        return;
    }

    unsigned long now = millis();
    if (now - lastWifiAttemptMillis < WIFI_RECONNECT_INTERVAL_MS)
    {
        return;
    }

    lastWifiAttemptMillis = now;
    connectToWiFi();
}

class ServerCallbacks : public BLEServerCallbacks
{
    void onConnect(BLEServer *pServer)
    {
        bleClientConnected = true;
        bleConnectionStart = millis();
        Serial.println("BLE client connected");
        // Generate new challenge when client connects
        generateAndSendChallenge();
    }

    void onDisconnect(BLEServer *pServer)
    {
        bleClientConnected = false;
        currentChallengeId = "";
        currentChallenge = "";
        Serial.println("BLE client disconnected");
    }
};

class ResponseCallbacks : public BLECharacteristicCallbacks
{
    void onWrite(BLECharacteristic *pCharacteristic)
    {
        std::string value = pCharacteristic->getValue();
        if (value.length() > 0)
        {
            String response = String(value.c_str());
            Serial.print("BLE response received: ");
            Serial.println(response);
            processBleResponse(response);
        }
    }
};

void generateAndSendChallenge()
{
    if (WiFi.status() != WL_CONNECTED)
    {
        Serial.println("Cannot generate BLE challenge: WiFi not connected");
        pStatusCharacteristic->setValue("ERROR: WiFi disconnected");
        pStatusCharacteristic->notify();
        return;
    }

    secureClient.setCACert(BACKEND_ROOT_CA);
    HTTPClient https;
    if (!https.begin(secureClient, BACKEND_HOST, 443, BLE_CHALLENGE_PATH, true))
    {
        Serial.println("BLE challenge request begin failed");
        pStatusCharacteristic->setValue("ERROR: HTTP failed");
        pStatusCharacteristic->notify();
        https.end();
        return;
    }

    https.addHeader("Content-Type", "application/json");
    https.addHeader("x-device-key", DEVICE_KEY);
    String body = "{\"doorId\":\"" + String(DOOR_ID) + "\",\"deviceId\":\"" + String(DEVICE_ID) + "\"}";
    int httpCode = https.POST(body);

    if (httpCode == HTTP_CODE_OK)
    {
        String payload = https.getString();
        Serial.print("BLE challenge response: ");
        Serial.println(payload);

        // Parse challenge response
        int challengeIdStart = payload.indexOf("\"challengeId\":\"") + 15;
        int challengeIdEnd = payload.indexOf("\"", challengeIdStart);
        int challengeStart = payload.indexOf("\"challenge\":\"") + 13;
        int challengeEnd = payload.indexOf("\"", challengeStart);

        if (challengeIdStart > 14 && challengeStart > 12)
        {
            currentChallengeId = payload.substring(challengeIdStart, challengeIdEnd);
            currentChallenge = payload.substring(challengeStart, challengeEnd);
            bleChallengeStart = millis();

            // Send challenge to BLE client
            pChallengeCharacteristic->setValue(currentChallenge.c_str());
            pChallengeCharacteristic->notify();

            pStatusCharacteristic->setValue("CHALLENGE_SENT");
            pStatusCharacteristic->notify();

            Serial.print("BLE challenge sent: ");
            Serial.println(currentChallenge);
        }
        else
        {
            Serial.println("Failed to parse challenge response");
            pStatusCharacteristic->setValue("ERROR: Parse failed");
            pStatusCharacteristic->notify();
        }
    }
    else
    {
        Serial.printf("BLE challenge HTTP error: %d\n", httpCode);
        pStatusCharacteristic->setValue("ERROR: HTTP " + String(httpCode));
        pStatusCharacteristic->notify();
    }
    https.end();
}

void processBleResponse(String response)
{
    if (currentChallengeId.length() == 0 || currentChallenge.length() == 0)
    {
        Serial.println("No active BLE challenge");
        pStatusCharacteristic->setValue("ERROR: No challenge");
        pStatusCharacteristic->notify();
        return;
    }

    if (millis() - bleChallengeStart > BLE_CHALLENGE_TIMEOUT_MS)
    {
        Serial.println("BLE challenge timeout");
        currentChallengeId = "";
        currentChallenge = "";
        pStatusCharacteristic->setValue("ERROR: Timeout");
        pStatusCharacteristic->notify();
        return;
    }

    // Verify response with backend
    if (WiFi.status() != WL_CONNECTED)
    {
        Serial.println("BLE verification failed: WiFi not connected");
        pStatusCharacteristic->setValue("ERROR: WiFi disconnected");
        pStatusCharacteristic->notify();
        return;
    }

    secureClient.setCACert(BACKEND_ROOT_CA);
    HTTPClient https;
    if (!https.begin(secureClient, BACKEND_HOST, 443, BLE_VERIFY_PATH, true))
    {
        Serial.println("BLE verify request begin failed");
        pStatusCharacteristic->setValue("ERROR: HTTP failed");
        pStatusCharacteristic->notify();
        https.end();
        return;
    }

    https.addHeader("Content-Type", "application/json");
    https.addHeader("x-device-key", DEVICE_KEY);
    String body = "{\"challengeId\":\"" + currentChallengeId + "\",\"signedChallenge\":\"" + response + "\",\"doorId\":\"" + String(DOOR_ID) + "\",\"deviceId\":\"" + String(DEVICE_ID) + "\"}";
    int httpCode = https.POST(body);

    bool accessGranted = false;
    if (httpCode == HTTP_CODE_OK)
    {
        String payload = https.getString();
        Serial.print("BLE verify response: ");
        Serial.println(payload);

        if (payload.indexOf("\"access\":true") > 0)
        {
            accessGranted = true;
            pStatusCharacteristic->setValue("ACCESS_GRANTED");
            pStatusCharacteristic->notify();
            openDoor();
        }
        else
        {
            pStatusCharacteristic->setValue("ACCESS_DENIED");
            pStatusCharacteristic->notify();
        }
    }
    else
    {
        Serial.printf("BLE verify HTTP error: %d\n", httpCode);
        pStatusCharacteristic->setValue("ERROR: HTTP " + String(httpCode));
        pStatusCharacteristic->notify();
    }
    https.end();

    // Clear challenge after verification
    currentChallengeId = "";
    currentChallenge = "";

    if (!accessGranted)
    {
        denyAccess();
    }
}

void processBLE()
{
    // Check for BLE connection timeout
    if (bleClientConnected && millis() - bleConnectionStart > BLE_CONNECTION_TIMEOUT_MS)
    {
        Serial.println("BLE connection timeout, disconnecting");
        pServer->disconnect(pServer->getConnId());
        return;
    }

    // Check for challenge timeout
    if (currentChallengeId.length() > 0 && millis() - bleChallengeStart > BLE_CHALLENGE_TIMEOUT_MS)
    {
        Serial.println("BLE challenge timeout");
        currentChallengeId = "";
        currentChallenge = "";
        pStatusCharacteristic->setValue("ERROR: Challenge timeout");
        pStatusCharacteristic->notify();
    }
}

void setupBLE()
{

    void setupBLE()
    {
        BLEDevice::init("ESP32-Door-" + String(DEVICE_ID));
        pServer = BLEDevice::createServer();
        pServer->setCallbacks(new ServerCallbacks());

        BLEService *pService = pServer->createService(SERVICE_UUID);

        pChallengeCharacteristic = pService->createCharacteristic(
            CHALLENGE_CHAR_UUID,
            BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);

        pResponseCharacteristic = pService->createCharacteristic(
            RESPONSE_CHAR_UUID,
            BLECharacteristic::PROPERTY_WRITE);
        pResponseCharacteristic->setCallbacks(new ResponseCallbacks());

        pStatusCharacteristic = pService->createCharacteristic(
            STATUS_CHAR_UUID,
            BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);

        pService->start();

        BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
        pAdvertising->addServiceUUID(SERVICE_UUID);
        pAdvertising->setScanResponse(true);
        pAdvertising->setMinPreferred(0x06);
        pAdvertising->setMinPreferred(0x12);
        BLEDevice::startAdvertising();

        Serial.println("BLE server started, advertising...");
    }

    void processScannerInput()
    {
        while (Serial2.available() > 0)
        {
            char c = Serial2.read();
            if (c == '\r' || c == '\n')
            {
                if (scannerBuffer.length() == 0)
                {
                    continue;
                }

                String token = scannerBuffer;
                token.trim();
                scannerBuffer = "";

                if (token.length() == 0)
                {
                    continue;
                }

                if (!isValidJwt(token))
                {
                    Serial.println("Invalid QR payload received, ignoring.");
                    continue;
                }

                if (millis() - lastScanMillis < SCAN_COOLDOWN_MS)
                {
                    Serial.println("Scan ignored: cooldown active.");
                    continue;
                }

                if (doorOpenUntil > millis())
                {
                    Serial.println("Scan ignored: door is still open or cooling down.");
                    continue;
                }

                lastScanMillis = millis();
                Serial.print("Token received: ");
                Serial.println(token);
                bool granted = validateToken(token, DOOR_ID, DEVICE_ID);
                if (granted)
                {
                    openDoor();
                }
                else
                {
                    denyAccess();
                }
            }
            else
            {
                if (scannerBuffer.length() < 512)
                {
                    scannerBuffer += c;
                }
            }
        }
    }

    bool isValidJwt(const String &token)
    {
        if (token.length() < 20)
        {
            return false;
        }
        int firstDot = token.indexOf('.');
        int secondDot = token.indexOf('.', firstDot + 1);
        return firstDot > 0 && secondDot > firstDot + 1 && secondDot < token.length() - 1;
    }

    bool validateToken(const String &token, const char *doorId, const char *deviceId)
    {
        if (WiFi.status() != WL_CONNECTED)
        {
            Serial.println("Validation failed: WiFi not connected.");
            return false;
        }

        secureClient.setCACert(BACKEND_ROOT_CA);
        secureClient.setTimeout(HTTP_TIMEOUT_MS / 1000);

        bool success = false;
        for (int attempt = 0; attempt <= MAX_VALIDATE_RETRIES; attempt++)
        {
            HTTPClient https;
            if (!https.begin(secureClient, BACKEND_HOST, 443, BACKEND_PATH, true))
            {
                Serial.println("HTTPS begin failed.");
                https.end();
                continue;
            }

            https.setTimeout(HTTP_TIMEOUT_MS / 1000);
            https.addHeader("Content-Type", "application/json");
            https.addHeader("x-device-key", DEVICE_KEY);

            String body = "{\"token\":\"" + token + "\",\"doorId\":\"" + doorId + "\",\"deviceId\":\"" + deviceId + "\"}";
            int httpCode = https.POST(body);

            if (httpCode == HTTP_CODE_OK)
            {
                String payload = https.getString();
                bool access = false;
                if (parseAccessResponse(payload, access))
                {
                    Serial.printf("Backend response: %s\n", payload.c_str());
                    success = access;
                    https.end();
                    break;
                }
                Serial.println("Invalid backend JSON response.");
            }
            else
            {
                Serial.printf("Backend HTTP error %d\n", httpCode);
            }

            https.end();
            if (attempt < MAX_VALIDATE_RETRIES)
            {
                Serial.println("Retrying validation...");
                delay(500);
            }
        }

        if (!success)
        {
            Serial.println("Access denied by backend or validation failed.");
        }
        return success;
    }

    bool parseAccessResponse(const String &payload, bool &access)
    {
        int keyIndex = payload.indexOf("\"access\"");
        if (keyIndex < 0)
        {
            return false;
        }

        int colonIndex = payload.indexOf(':', keyIndex);
        if (colonIndex < 0)
        {
            return false;
        }

        String remainder = payload.substring(colonIndex + 1);
        remainder.trim();
        if (remainder.startsWith("true"))
        {
            access = true;
            return true;
        }
        if (remainder.startsWith("false"))
        {
            access = false;
            return true;
        }
        return false;
    }

    void openDoor()
    {
        Serial.println("Access granted: opening door.");
        digitalWrite(RELAY_PIN, RELAY_ACTIVE_STATE);
        digitalWrite(STATUS_LED_PIN, HIGH);
        doorOpenUntil = millis() + RELAY_ACTIVE_MS;
        lastDoorActionMillis = millis();
    }

    void denyAccess()
    {
        Serial.println("Access denied.");
        blinkStatusLed(2, 100);
    }

    void updateDoorRelay()
    {
        if (doorOpenUntil > 0 && millis() >= doorOpenUntil)
        {
            digitalWrite(RELAY_PIN, RELAY_INACTIVE_STATE);
            digitalWrite(STATUS_LED_PIN, LOW);
            doorOpenUntil = 0;
            Serial.println("Door relay deactivated.");
        }
    }

    void blinkStatusLed(int times, int intervalMs)
    {
        for (int i = 0; i < times; i++)
        {
            digitalWrite(STATUS_LED_PIN, HIGH);
            delay(intervalMs);
            digitalWrite(STATUS_LED_PIN, LOW);
            delay(intervalMs);
        }
    }

    void sendHeartbeatIfNeeded()
    {
        static const bool HEARTBEAT_ENABLED = false;
        if (!HEARTBEAT_ENABLED)
        {
            return;
        }

        unsigned long now = millis();
        if (now - lastHeartbeatMillis < HEARTBEAT_INTERVAL_MS)
        {
            return;
        }

        lastHeartbeatMillis = now;
        if (WiFi.status() != WL_CONNECTED)
        {
            Serial.println("Heartbeat skipped: WiFi disconnected.");
            return;
        }

        secureClient.setCACert(BACKEND_ROOT_CA);
        HTTPClient https;
        if (!https.begin(secureClient, BACKEND_HOST, 443, "/device/heartbeat", true))
        {
            Serial.println("Heartbeat begin failed.");
            https.end();
            return;
        }

        https.addHeader("Content-Type", "application/json");
        https.addHeader("x-device-key", DEVICE_KEY);
        String body = "{\"deviceId\":\"" + DEVICE_ID + "\"}";
        int httpCode = https.POST(body);
        if (httpCode == HTTP_CODE_OK)
        {
            Serial.println("Heartbeat sent successfully.");
        }
        else
        {
            Serial.printf("Heartbeat failed: %d\n", httpCode);
        }
        https.end();
    }

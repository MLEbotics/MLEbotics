/*
 * Running Companion — Robot Pacer Firmware
 * Hardware: Freenove 4WD ESP32 Car Kit + NEO-6M GPS module + SG90 servo
 *
 * GPS Wiring (ESP32 → NEO-6M):
 *   3.3V → VCC
 *   GND  → GND
 *   GPIO16 (RX2) → TX on GPS
 *   GPIO17 (TX2) → RX on GPS
 *
 * Servo Wiring (ESP32 → SG90, mounts the front ultrasonic sensor):
 *   GPIO13 → Signal (orange wire)
 *   5V     → VCC (red wire)
 *   GND    → GND (brown wire)
 *
 * What this does:
 *   - Connects to your phone's WiFi hotspot (phone keeps full internet!)
 *   - Advertises itself as "runner-companion.local" via mDNS
 *   - Listens for commands from the Flutter app
 *   - Drives at target pace along GPS waypoints
 *   - Slows down if runner falls behind (back ultrasonic sensor)
 *   - Sweeps front ultrasonic left/right to find clear path around obstacles
 *   - Steers around people, bins, trees — resumes route after clearing them
 *
 * SETUP: Edit PHONE_HOTSPOT_SSID and PHONE_HOTSPOT_PASSWORD below
 *   to match your phone's personal hotspot name and password,
 *   then flash to ESP32. Phone connects to internet via cellular;
 *   robot connects to phone hotspot; app talks to robot-companion.local.
 */

#include <WiFi.h>
#include <ESPmDNS.h>
#include <WebServer.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include <TinyGPS++.h>
#include <HardwareSerial.h>
#include <ESP32Servo.h>
#include "esp_camera.h"

// ─── Camera pin definitions (ESP32-WROVER-KIT / Freenove FNK0053) ────────────
//
// ╔══════════════════════════════════════════════════════════════════════════╗
// ║  ⚠  PIN CONFLICT WARNING — VERIFY BEFORE FLASHING WITH CAMERA  ⚠       ║
// ║                                                                          ║
// ║  The WROVER-KIT camera uses GPIO 26 (SIOD), 27 (SIOC), 25 (VSYNC),      ║
// ║  and 4 (Y2). The current firmware also uses:                             ║
// ║    MOTOR_L_FWD = 26  ← conflicts with SIOD (camera I²C data)            ║
// ║    MOTOR_L_BWD = 27  ← conflicts with SIOC (camera I²C clock)           ║
// ║    MOTOR_R_PWM = 25  ← conflicts with VSYNC                             ║
// ║    BACK_TRIG   =  4  ← conflicts with Y2 (camera data bit 0)            ║
// ║                                                                          ║
// ║  ACTION REQUIRED when hardware arrives:                                  ║
// ║    Open the FNK0053 PCB silkscreen / wiring diagram and note the         ║
// ║    actual GPIO numbers printed next to the motor driver connectors.      ║
// ║    Re-assign MOTOR_L_FWD, MOTOR_L_BWD, MOTOR_R_PWM and BACK_TRIG        ║
// ║    to GPIOs NOT in the camera list below.                                ║
// ║                                                                          ║
// ║  GPIOs safe to use for motors (not claimed by camera):                   ║
// ║    0, 1, 2, 3, 12, 13, 14, 15, 16, 17, 32, 33                           ║
// ║  (Avoid: 4, 5, 18, 19, 21, 22, 23, 25, 26, 27, 34, 35, 36, 39)         ║
// ╚══════════════════════════════════════════════════════════════════════════╝

#define PWDN_GPIO_NUM -1
#define RESET_GPIO_NUM -1
#define XCLK_GPIO_NUM 21
#define SIOD_GPIO_NUM 26
#define SIOC_GPIO_NUM 27
#define Y9_GPIO_NUM 35
#define Y8_GPIO_NUM 34
#define Y7_GPIO_NUM 39
#define Y6_GPIO_NUM 36
#define Y5_GPIO_NUM 19
#define Y4_GPIO_NUM 18
#define Y3_GPIO_NUM 5
#define Y2_GPIO_NUM 4
#define VSYNC_GPIO_NUM 25
#define HREF_GPIO_NUM 23
#define PCLK_GPIO_NUM 22

// ─── WiFi provisioning ─────────────────────────────────────────────────────────
// Credentials are stored in NVS (survives reboots, set via /configure endpoint).
// On first boot (no credentials saved) the robot creates a setup hotspot:
//   SSID:     RunnerCompanion-Setup
//   Password: setup1234
// Connect your phone to that, open the app → Robot Setup, enter your
// phone's normal Personal Hotspot name/password, tap Save.
// Robot reboots, connects to your hotspot, you get full internet.

const char *SETUP_AP_SSID = "RunnerCompanion-Setup";
const char *SETUP_AP_PASSWORD = "setup1234";
const char *MDNS_HOSTNAME = "runner-companion";

Preferences prefs;
String savedSsid;
String savedPassword;
bool inSetupMode = false; // true when no credentials → AP mode

// ─── Motor pins (Freenove 4WD layout) ──────────────────────────────
// Left motors
#define MOTOR_L_FWD 26
#define MOTOR_L_BWD 27
#define MOTOR_L_PWM 14
// Right motors
#define MOTOR_R_FWD 33
#define MOTOR_R_BWD 32
#define MOTOR_R_PWM 25

// ─── Ultrasonic sensor pins ─────────────────────────────────────────
#define FRONT_TRIG 12
#define FRONT_ECHO 13
#define BACK_TRIG 4
#define BACK_ECHO 2

// ─── Servo pin (rotates front ultrasonic sensor) ────────────────────
#define SERVO_PIN 15
Servo scanServo;
// Servo positions: 90=straight, 0=full right, 180=full left
#define SERVO_CENTER 90
#define SERVO_LEFT 150
#define SERVO_RIGHT 30

// ─── GPS Serial ────────────────────────────────────────────────────
HardwareSerial gpsSerial(2); // UART2: GPIO16=RX, GPIO17=TX
TinyGPSPlus gps;

// ─── Web servers ───────────────────────────────────────────────────
WebServer server(80);       // main: /status /start /stop /command …
WebServer cameraServer(81); // camera: /camera (MJPEG stream)

// ─── Camera state ──────────────────────────────────────────────────
bool cameraEnabled = false;
TaskHandle_t cameraTaskHandle = NULL;

// ─── State ─────────────────────────────────────────────────────────
bool isPacing = false;
float targetPaceKmH = 8.0;     // default 8 km/h ≈ 7:30 min/km
float maxDistanceBehind = 5.0; // metres — if runner is >5m behind, slow down
float obstacleStopDist = 50.0; // cm — start avoidance if obstacle <50cm ahead

// ─── Runner-lost detection ─────────────────────────────────────────
// If the back sensor sees the runner >runnerLostDist for more than
// runnerLostTimeoutMs, the robot stops and waits until they're back.
const float runnerLostDist = 8.0;               // metres
const unsigned long runnerLostTimeoutMs = 3000; // 3 seconds
bool runnerLost = false;
unsigned long runnerOutOfRangeStartMs = 0; // millis() when runner first went out

// ─── Runner monitoring data (sent from phone's Garmin BLE every second) ─────
// Phone (mounted on robot) reads runner's pace from Garmin watch via BLE and
// pushes speedKmh to /runner_update for display in /status.
// This data is MONITORING ONLY — it does NOT change the robot's target pace.
// The robot leads at its set pace; the runner follows (robot is the pacer).
double runnerLat = 0.0;
double runnerLng = 0.0;
float runnerSpeedKmH = 0.0;                     // live GPS speed from phone
bool hasRunnerGps = false;                      // true once first update received
unsigned long lastRunnerUpdateMs = 0;           // millis() of last /runner_update
const unsigned long RUNNER_GPS_STALE_MS = 3000; // treat as stale after 3 s

// ─── Avoidance state ───────────────────────────────────────────────
enum AvoidState
{
  NONE,
  SCANNING,
  AVOIDING_LEFT,
  AVOIDING_RIGHT,
  RESUMING
};
AvoidState avoidState = NONE;
unsigned long avoidStartMs = 0;
int avoidTurnMs = 0;    // how long to turn to get around obstacle
float savedBearing = 0; // GPS bearing before avoidance started

struct Waypoint
{
  double lat;
  double lng;
};
std::vector<Waypoint> waypoints;
int currentWaypoint = 0;

// ─── Helpers ───────────────────────────────────────────────────────
float measureDistance(int trigPin, int echoPin)
{
  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);
  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);
  digitalWrite(trigPin, LOW);
  long duration = pulseIn(echoPin, HIGH, 30000);
  return duration * 0.034 / 2.0; // cm
}

// Convert pace (km/h) to PWM speed (0–255)
// Freenove motors: ~255 = ~12 km/h max on flat ground
int paceToMotorSpeed(float kmh)
{
  float clamped = constrain(kmh, 0, 12.0);
  return (int)((clamped / 12.0) * 200) + 55; // 55–255 range
}

void setMotors(int leftSpeed, int rightSpeed)
{
  leftSpeed = constrain(leftSpeed, -255, 255);
  rightSpeed = constrain(rightSpeed, -255, 255);

  // Left
  if (leftSpeed > 0)
  {
    digitalWrite(MOTOR_L_FWD, HIGH);
    digitalWrite(MOTOR_L_BWD, LOW);
    analogWrite(MOTOR_L_PWM, leftSpeed);
  }
  else if (leftSpeed < 0)
  {
    digitalWrite(MOTOR_L_FWD, LOW);
    digitalWrite(MOTOR_L_BWD, HIGH);
    analogWrite(MOTOR_L_PWM, -leftSpeed);
  }
  else
  {
    digitalWrite(MOTOR_L_FWD, LOW);
    digitalWrite(MOTOR_L_BWD, LOW);
    analogWrite(MOTOR_L_PWM, 0);
  }

  // Right
  if (rightSpeed > 0)
  {
    digitalWrite(MOTOR_R_FWD, HIGH);
    digitalWrite(MOTOR_R_BWD, LOW);
    analogWrite(MOTOR_R_PWM, rightSpeed);
  }
  else if (rightSpeed < 0)
  {
    digitalWrite(MOTOR_R_FWD, LOW);
    digitalWrite(MOTOR_R_BWD, HIGH);
    analogWrite(MOTOR_R_PWM, -rightSpeed);
  }
  else
  {
    digitalWrite(MOTOR_R_FWD, LOW);
    digitalWrite(MOTOR_R_BWD, LOW);
    analogWrite(MOTOR_R_PWM, 0);
  }
}

void stopMotors() { setMotors(0, 0); }

// ─── Obstacle sweep & avoidance ────────────────────────────────────

// Measure distance at a given servo angle
float measureAtAngle(int angle)
{
  scanServo.write(angle);
  delay(250); // wait for servo to reach position
  return measureDistance(FRONT_TRIG, FRONT_ECHO);
}

// Struct to hold sweep result
struct SweepResult
{
  float centerCm;
  float leftCm;
  float rightCm;
  bool leftClear;  // >80cm on left
  bool rightClear; // >80cm on right
};

// Sweep left and right, return readings
SweepResult sweepForClearPath()
{
  SweepResult r;
  r.centerCm = measureAtAngle(SERVO_CENTER);
  r.rightCm = measureAtAngle(SERVO_RIGHT);
  r.leftCm = measureAtAngle(SERVO_LEFT);
  // Return servo to center
  scanServo.write(SERVO_CENTER);
  delay(200);
  r.leftClear = (r.leftCm <= 0 || r.leftCm > 80);
  r.rightClear = (r.rightCm <= 0 || r.rightCm > 80);
  return r;
}

// Run one cycle of the avoidance state machine
// Returns true when avoidance is complete and normal driving can resume
bool runAvoidance(int baseSpeed)
{
  unsigned long now = millis();

  switch (avoidState)
  {
  case NONE:
    return true; // nothing to avoid

  case SCANNING:
  {
    stopMotors();
    SweepResult sweep = sweepForClearPath();

    if (sweep.leftClear && sweep.rightClear)
    {
      // Both sides clear — pick the more open side
      avoidState = (sweep.leftCm >= sweep.rightCm)
                       ? AVOIDING_LEFT
                       : AVOIDING_RIGHT;
    }
    else if (sweep.leftClear)
    {
      avoidState = AVOIDING_LEFT;
    }
    else if (sweep.rightClear)
    {
      avoidState = AVOIDING_RIGHT;
    }
    else
    {
      // Both sides blocked — back up a little and re-scan
      setMotors(-baseSpeed * 0.5, -baseSpeed * 0.5);
      delay(400);
      stopMotors();
      // Stay in SCANNING state to try again next loop
    }
    avoidStartMs = millis();
    // Estimate turn time based on speed (roughly 600ms at full speed = 90 degrees)
    avoidTurnMs = (int)(700.0f * (180.0f / baseSpeed));
    avoidTurnMs = constrain(avoidTurnMs, 400, 1200);
    break;
  }

  case AVOIDING_LEFT:
    // Turn left around the obstacle
    setMotors(-baseSpeed * 0.7, baseSpeed * 0.7);
    if (now - avoidStartMs > (unsigned long)avoidTurnMs)
    {
      // Done turning — drive forward past the obstacle
      setMotors(baseSpeed, baseSpeed);
      avoidStartMs = now;
      avoidState = RESUMING;
    }
    break;

  case AVOIDING_RIGHT:
    // Turn right around the obstacle
    setMotors(baseSpeed * 0.7, -baseSpeed * 0.7);
    if (now - avoidStartMs > (unsigned long)avoidTurnMs)
    {
      setMotors(baseSpeed, baseSpeed);
      avoidStartMs = now;
      avoidState = RESUMING;
    }
    break;

  case RESUMING:
    // Drive forward a bit, then check if path ahead is clear
    if (now - avoidStartMs > 800)
    {
      float ahead = measureDistance(FRONT_TRIG, FRONT_ECHO);
      if (ahead <= 0 || ahead > obstacleStopDist)
      {
        // Clear! Return to GPS navigation
        avoidState = NONE;
        scanServo.write(SERVO_CENTER);
        return true;
      }
      else
      {
        // Still blocked — scan again
        avoidState = SCANNING;
        avoidStartMs = now;
      }
    }
    break;
  }
  return false; // still avoiding
}
void steerToBearing(float targetBearing, float currentBearing, int baseSpeed)
{
  float error = targetBearing - currentBearing;
  if (error > 180)
    error -= 360;
  if (error < -180)
    error += 360;

  int turn = (int)(error * 0.8); // proportional steering
  turn = constrain(turn, -80, 80);

  setMotors(baseSpeed - turn, baseSpeed + turn);
}

// ─── Camera init ───────────────────────────────────────────────────
bool initCamera()
{
  camera_config_t config;
  // Use LEDC channel 1 & timer 1 — channel 0 / timer 0 reserved for motors
  config.ledc_channel = LEDC_CHANNEL_1;
  config.ledc_timer = LEDC_TIMER_1;
  config.pin_d0 = Y2_GPIO_NUM;
  config.pin_d1 = Y3_GPIO_NUM;
  config.pin_d2 = Y4_GPIO_NUM;
  config.pin_d3 = Y5_GPIO_NUM;
  config.pin_d4 = Y6_GPIO_NUM;
  config.pin_d5 = Y7_GPIO_NUM;
  config.pin_d6 = Y8_GPIO_NUM;
  config.pin_d7 = Y9_GPIO_NUM;
  config.pin_xclk = XCLK_GPIO_NUM;
  config.pin_pclk = PCLK_GPIO_NUM;
  config.pin_vsync = VSYNC_GPIO_NUM;
  config.pin_href = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn = PWDN_GPIO_NUM;
  config.pin_reset = RESET_GPIO_NUM;
  config.xclk_freq_hz = 10000000; // 10 MHz XCLK
  config.pixel_format = PIXFORMAT_JPEG;

  if (psramFound())
  {
    // WROVER has 8 MB PSRAM — use VGA for good quality at moderate bandwidth
    config.frame_size = FRAMESIZE_VGA; // 640×480
    config.jpeg_quality = 15;          // 0–63; lower = better quality
    config.fb_count = 2;
  }
  else
  {
    config.frame_size = FRAMESIZE_CIF; // 352×288 — lower fallback
    config.jpeg_quality = 20;
    config.fb_count = 1;
  }

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK)
  {
    Serial.printf("Camera init failed: 0x%x\n", err);
    return false;
  }

  // Drop frame rate slightly to leave CPU headroom for motor control
  sensor_t *s = esp_camera_sensor_get();
  if (s)
  {
    s->set_framesize(s, FRAMESIZE_VGA);
    s->set_quality(s, 15);
  }
  Serial.println("Camera OK");
  return true;
}

// GET /camera (on port 81) — MJPEG stream for the phone to record.
// Streams continuously until the client disconnects.
// Runs on Core 0 via cameraTask — does NOT block the motor control loop.
void handleCameraStream()
{
  if (!cameraEnabled)
  {
    cameraServer.send(503, "text/plain", "Camera not available");
    return;
  }

  WiFiClient client = cameraServer.client();

  // MJPEG / multipart response headers
  client.println("HTTP/1.1 200 OK");
  client.println("Content-Type: multipart/x-mixed-replace; boundary=frame");
  client.println("Access-Control-Allow-Origin: *");
  client.println("Cache-Control: no-cache, no-store, must-revalidate");
  client.println("Connection: keep-alive");
  client.println();

  const uint32_t FRAME_INTERVAL_MS = 100; // 10 fps — gentle on WiFi + CPU
  uint32_t lastFrameAt = 0;

  while (client.connected())
  {
    uint32_t now = millis();
    if (now - lastFrameAt < FRAME_INTERVAL_MS)
    {
      vTaskDelay(5 / portTICK_PERIOD_MS);
      continue;
    }
    lastFrameAt = now;

    camera_fb_t *fb = esp_camera_fb_get();
    if (!fb)
    {
      Serial.println("cam: capture failed");
      vTaskDelay(100 / portTICK_PERIOD_MS);
      continue;
    }

    // Write one MJPEG frame boundary + JPEG payload
    client.printf("--frame\r\n"
                  "Content-Type: image/jpeg\r\n"
                  "Content-Length: %u\r\n\r\n",
                  (unsigned)fb->len);
    client.write(fb->buf, fb->len);
    client.print("\r\n");

    esp_camera_fb_return(fb);
  }
}

// FreeRTOS task: runs camera HTTP server on Core 0.
// The main loop() — and all motor/GPS logic — runs on Core 1.
void cameraTask(void * /*pvParameters*/)
{
  cameraServer.begin();
  Serial.println("Camera server listening on port 81");
  for (;;)
  {
    cameraServer.handleClient();
    vTaskDelay(1 / portTICK_PERIOD_MS);
  }
}

// ─── HTTP Handlers ─────────────────────────────────────────────────

// GET /status — returns robot GPS + state as JSON
void handleStatus()
{
  StaticJsonDocument<384> doc;
  doc["lat"] = gps.location.isValid() ? gps.location.lat() : 0.0;
  doc["lng"] = gps.location.isValid() ? gps.location.lng() : 0.0;
  doc["speedKmh"] = gps.speed.isValid() ? gps.speed.kmph() : 0.0;
  doc["isPacing"] = isPacing;
  doc["waypoint"] = currentWaypoint;
  doc["totalWaypoints"] = waypoints.size();
  doc["gpsFix"] = gps.location.isValid();
  float frontDist = measureDistance(FRONT_TRIG, FRONT_ECHO);
  float backDist = measureDistance(BACK_TRIG, BACK_ECHO);
  doc["frontCm"] = frontDist;
  doc["backCm"] = backDist;
  doc["avoiding"] = (avoidState != NONE);
  doc["runnerLost"] = runnerLost;

  // Runner GPS from phone (live sync via /runner_update)
  bool runnerGpsFresh = hasRunnerGps &&
                        (millis() - lastRunnerUpdateMs < RUNNER_GPS_STALE_MS);
  doc["runnerLat"] = runnerLat;
  doc["runnerLng"] = runnerLng;
  doc["runnerSpeedKmH"] = runnerSpeedKmH;
  doc["runnerGpsSync"] = runnerGpsFresh; // true = phone GPS data is current
  doc["targetPaceKmH"] = targetPaceKmH;
  doc["cameraOk"] = cameraEnabled; // true when camera is streaming on :81/camera

  String json;
  serializeJson(doc, json);
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", json);
}

// POST /start — starts pacing, body: {"pace":8.0,"waypoints":[{"lat":...,"lng":...},...]}
void handleStart()
{
  if (!server.hasArg("plain"))
  {
    server.send(400, "application/json", "{\"error\":\"No body\"}");
    return;
  }
  StaticJsonDocument<1024> doc;
  DeserializationError err = deserializeJson(doc, server.arg("plain"));
  if (err)
  {
    server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
    return;
  }

  targetPaceKmH = doc["pace"] | 8.0f;
  waypoints.clear();
  currentWaypoint = 0;

  JsonArray wps = doc["waypoints"].as<JsonArray>();
  for (JsonObject wp : wps)
  {
    waypoints.push_back({wp["lat"].as<double>(), wp["lng"].as<double>()});
  }

  isPacing = waypoints.size() > 0;
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", "{\"status\":\"started\"}");
}

// POST /stop
void handleStop()
{
  isPacing = false;
  stopMotors();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", "{\"status\":\"stopped\"}");
}

// POST /command — manual control: {"cmd":"forward|backward|left|right|stop"}
void handleCommand()
{
  if (!server.hasArg("plain"))
  {
    server.send(400);
    return;
  }
  StaticJsonDocument<128> doc;
  deserializeJson(doc, server.arg("plain"));
  String cmd = doc["cmd"] | "stop";
  int spd = paceToMotorSpeed(targetPaceKmH);

  if (cmd == "forward")
    setMotors(spd, spd);
  else if (cmd == "backward")
    setMotors(-spd, -spd);
  else if (cmd == "left")
    setMotors(-spd, spd);
  else if (cmd == "right")
    setMotors(spd, -spd);
  else
    stopMotors();

  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", "{\"status\":\"ok\"}");
}

// GET /wifi-status — returns WiFi mode, IP, SSID
void handleWifiStatus()
{
  StaticJsonDocument<128> doc;
  doc["mode"] = inSetupMode ? "setup" : "sta";
  doc["connected"] = (WiFi.status() == WL_CONNECTED);
  doc["ip"] = inSetupMode ? WiFi.softAPIP().toString() : WiFi.localIP().toString();
  doc["ssid"] = inSetupMode ? String(SETUP_AP_SSID) : savedSsid;
  String json;
  serializeJson(doc, json);
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", json);
}

// POST /configure — save hotspot credentials to NVS and reboot
// Body: {"ssid":"MyHotspot","password":"mypassword"}
void handleConfigure()
{
  if (!server.hasArg("plain"))
  {
    server.send(400, "application/json", "{\"error\":\"No body\"}");
    return;
  }
  StaticJsonDocument<256> doc;
  if (deserializeJson(doc, server.arg("plain")))
  {
    server.send(400, "application/json", "{\"error\":\"Invalid JSON\"}");
    return;
  }
  String newSsid = doc["ssid"] | "";
  String newPass = doc["password"] | "";
  if (newSsid.length() == 0)
  {
    server.send(400, "application/json", "{\"error\":\"ssid required\"}");
    return;
  }
  // Save to NVS
  prefs.begin("wifi", false);
  prefs.putString("ssid", newSsid);
  prefs.putString("password", newPass);
  prefs.end();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", "{\"status\":\"saved\",\"rebooting\":true}");
  delay(1000);
  ESP.restart();
}

// POST /forget-wifi — clear saved credentials and reboot into setup mode
void handleForgetWifi()
{
  prefs.begin("wifi", false);
  prefs.remove("ssid");
  prefs.remove("password");
  prefs.end();
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", "{\"status\":\"cleared\",\"rebooting\":true}");
  delay(1000);
  ESP.restart();
}

// POST /pace — update target pace mid-run: {"pace":9.0}
void handleSetPace()
{
  if (!server.hasArg("plain"))
  {
    server.send(400);
    return;
  }
  StaticJsonDocument<64> doc;
  deserializeJson(doc, server.arg("plain"));
  targetPaceKmH = doc["pace"] | targetPaceKmH;
  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", "{\"status\":\"ok\"}");
}

// POST /runner_update  {"lat":51.0, "lng":-114.0, "speedKmh":9.5}
// Called by the phone app with the runner's live Garmin watch data.
// MONITORING ONLY — runner's speed is stored for display in /status.
// The robot's target pace is NOT changed here; the robot leads at the
// pace set by /start or /pace. The runner follows the robot (pacer).
void handleRunnerUpdate()
{
  if (!server.hasArg("plain"))
  {
    server.send(400);
    return;
  }
  StaticJsonDocument<128> doc;
  deserializeJson(doc, server.arg("plain"));

  runnerLat = doc["lat"] | runnerLat;
  runnerLng = doc["lng"] | runnerLng;
  runnerSpeedKmH = doc["speedKmh"] | runnerSpeedKmH;
  hasRunnerGps = true;
  lastRunnerUpdateMs = millis();

  // targetPaceKmH is NOT touched here — the robot is the pacer and leads
  // at its own set speed. Use /start or /pace to change the robot's speed.

  server.sendHeader("Access-Control-Allow-Origin", "*");
  server.send(200, "application/json", "{\"status\":\"ok\"}");
}

// ─── Pacing logic (called every loop) ─────────────────────────────
void runPacingLogic()
{
  if (!isPacing || waypoints.empty())
    return;
  if (currentWaypoint >= (int)waypoints.size())
  {
    stopMotors();
    isPacing = false;
    return;
  }

  int baseSpeed = paceToMotorSpeed(targetPaceKmH);

  // ── If already avoiding, continue avoidance ──────────────────────
  if (avoidState != NONE)
  {
    bool done = runAvoidance(baseSpeed);
    if (!done)
      return; // still going around obstacle
    // Avoidance complete — fall through to normal GPS nav
  }

  // ── Check for new obstacle ahead ─────────────────────────────────
  float frontDist = measureDistance(FRONT_TRIG, FRONT_ECHO);
  if (frontDist > 0 && frontDist < obstacleStopDist)
  {
    // Save current GPS bearing before starting avoidance
    if (gps.course.isValid())
      savedBearing = gps.course.deg();
    avoidState = SCANNING;
    avoidStartMs = millis();
    runAvoidance(baseSpeed);
    return;
  }

  // ── Check if runner is keeping up (back sensor) ───────────────────
  float backDist = measureDistance(BACK_TRIG, BACK_ECHO);
  float runnerBehindMetres = backDist / 100.0;

  // Runner-lost detection: if too far away for runnerLostTimeoutMs, stop
  if (backDist > 0 && runnerBehindMetres > runnerLostDist)
  {
    if (runnerOutOfRangeStartMs == 0)
    {
      runnerOutOfRangeStartMs = millis(); // start the timer
    }
    else if (millis() - runnerOutOfRangeStartMs > runnerLostTimeoutMs)
    {
      runnerLost = true;
      stopMotors();
      return; // stay stopped until runner catches up
    }
  }
  else
  {
    // Runner is within range — reset timer and lost flag
    runnerOutOfRangeStartMs = 0;
    runnerLost = false;
  }

  // If currently runner-lost, keep waiting (sensor may have missed a reading)
  if (runnerLost)
  {
    stopMotors();
    return;
  }

  // ── Adaptive pace: slow down if runner is falling behind ─────────
  //
  //  The robot is the pace-setter. Normally it leads at targetPaceKmH.
  //  If the runner can't keep up, the robot eases back so the runner
  //  doesn't get dropped — then resumes full pace once they catch up.
  //
  //  Two independent signals both cap effectivePace:
  //  [A] Back ultrasonic distance (primary — always available)
  //      0 – 2 m behind  →  100% of targetPaceKmH   (runner right there)
  //      2 – 5 m behind  →  linearly drops to 70%   (runner slipping back)
  //      5 – 8 m behind  →  holds at 70%             (giving them time)
  //      > 8 m (+ 3 s)   →  runnerLost → full stop  (wait for them)
  //
  //  [B] Garmin watch speed (secondary — only when fresh BLE data)
  //      If runner's actual pace is >1 km/h below the robot,
  //      cap robot speed to (runnerSpeed + 0.5 km/h) so it barely
  //      pulls ahead and gives the runner a target to chase.
  //
  float effectivePace = targetPaceKmH;

  // [A] Distance-based graduated slowdown (backDist/runnerBehindMetres already measured above)
  if (backDist > 0)
  {
    const float FULL_PACE_DIST = 2.0f;  // m — within this → full pace
    const float SLOW_PACE_DIST = 5.0f;  // m — start sliding toward 70%
    const float MIN_PACE_RATIO = 0.70f; // never drop below 70% via distance

    if (runnerBehindMetres > FULL_PACE_DIST)
    {
      float t = constrain(
          (runnerBehindMetres - FULL_PACE_DIST) / (SLOW_PACE_DIST - FULL_PACE_DIST),
          0.0f, 1.0f);
      float distRatio = 1.0f - (1.0f - MIN_PACE_RATIO) * t;
      effectivePace = targetPaceKmH * distRatio;
    }
  }

  // [B] Garmin watch speed — cap if runner is measurably slower
  bool runnerGpsSync = hasRunnerGps &&
                       (millis() - lastRunnerUpdateMs < RUNNER_GPS_STALE_MS);
  if (runnerGpsSync && runnerSpeedKmH > 0.5f)
  {
    // Allow robot to stay at most 0.5 km/h ahead of the runner.
    // This ensures the robot leads just enough to pull the runner
    // without leaving them behind.
    float watchCap = runnerSpeedKmH + 0.5f;
    if (watchCap < effectivePace)
    {
      effectivePace = watchCap;
    }
  }

  // Clamp to a sensible minimum so the robot doesn't crawl to a stop
  // unless runnerLost logic fires
  effectivePace = max(effectivePace, 0.5f);

  // ── Navigate to current GPS waypoint ─────────────────────────────
  if (gps.location.isValid())
  {
    Waypoint target = waypoints[currentWaypoint];
    double distToWaypoint = TinyGPSPlus::distanceBetween(
        gps.location.lat(), gps.location.lng(),
        target.lat, target.lng);
    if (distToWaypoint < 3.0)
    {
      currentWaypoint++;
      return;
    }
    double bearing = TinyGPSPlus::courseTo(
        gps.location.lat(), gps.location.lng(),
        target.lat, target.lng);
    float currentCourse = gps.course.isValid() ? gps.course.deg() : bearing;
    int spd = paceToMotorSpeed(effectivePace);
    steerToBearing(bearing, currentCourse, spd);
  }
  else
  {
    int spd = paceToMotorSpeed(effectivePace);
    setMotors(spd, spd);
  }
}

// ─── Setup ─────────────────────────────────────────────────────────
void setup()
{
  Serial.begin(115200);
  gpsSerial.begin(9600, SERIAL_8N1, 16, 17);

  // Motor pins
  pinMode(MOTOR_L_FWD, OUTPUT);
  pinMode(MOTOR_L_BWD, OUTPUT);
  pinMode(MOTOR_R_FWD, OUTPUT);
  pinMode(MOTOR_R_BWD, OUTPUT);
  // Ultrasonic
  pinMode(FRONT_TRIG, OUTPUT);
  pinMode(FRONT_ECHO, INPUT);
  pinMode(BACK_TRIG, OUTPUT);
  pinMode(BACK_ECHO, INPUT);
  // Servo (scan sensor)
  scanServo.attach(SERVO_PIN);
  scanServo.write(SERVO_CENTER);
  delay(500);

  // Load saved WiFi credentials from NVS
  prefs.begin("wifi", true); // read-only
  savedSsid = prefs.getString("ssid", "");
  savedPassword = prefs.getString("password", "");
  prefs.end();

  if (savedSsid.length() > 0)
  {
    // ── STA mode: connect to saved hotspot ───────────────────────────
    inSetupMode = false;
    WiFi.mode(WIFI_STA);
    WiFi.begin(savedSsid.c_str(), savedPassword.c_str());
    Serial.print("Connecting to: ");
    Serial.println(savedSsid);
    unsigned long connectStart = millis();
    while (WiFi.status() != WL_CONNECTED)
    {
      delay(500);
      Serial.print(".");
      if (millis() - connectStart > 20000)
      {
        Serial.println("\nCould not connect — falling back to setup mode.");
        inSetupMode = true;
        break;
      }
    }
    if (!inSetupMode)
    {
      Serial.println();
      Serial.println("Connected! Robot IP: " + WiFi.localIP().toString());
      if (MDNS.begin(MDNS_HOSTNAME))
      {
        MDNS.addService("http", "tcp", 80);
        Serial.println("Reachable at http://" + String(MDNS_HOSTNAME) + ".local");
      }
    }
  }
  else
  {
    inSetupMode = true;
  }

  if (inSetupMode)
  {
    // ── AP setup mode: create setup hotspot for initial config ────────
    WiFi.mode(WIFI_AP);
    WiFi.softAP(SETUP_AP_SSID, SETUP_AP_PASSWORD);
    Serial.println("No WiFi saved. Setup mode started.");
    Serial.println("Connect phone to: " + String(SETUP_AP_SSID));
    Serial.println("Password: " + String(SETUP_AP_PASSWORD));
    Serial.println("Then open app → Robot Setup to configure.");
  }

  // Register HTTP routes (always, in both modes)
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/wifi-status", HTTP_GET, handleWifiStatus);
  server.on("/start", HTTP_POST, handleStart);
  server.on("/stop", HTTP_POST, handleStop);
  server.on("/command", HTTP_POST, handleCommand);
  server.on("/pace", HTTP_POST, handleSetPace);
  server.on("/runner_update", HTTP_POST, handleRunnerUpdate);
  server.on("/configure", HTTP_POST, handleConfigure);
  server.on("/forget-wifi", HTTP_POST, handleForgetWifi);
  server.begin();

  // ── Camera: init OV2640 and start MJPEG streaming server on port 81 ───────────
  // Camera task runs on Core 0; motor/GPS loop() runs on Core 1.
  // Recording has zero impact on pacing performance.
  cameraEnabled = initCamera();
  if (cameraEnabled)
  {
    cameraServer.on("/camera", HTTP_GET, handleCameraStream);
    xTaskCreatePinnedToCore(
        cameraTask, // task function
        "cam_srv",  // name
        8192,       // stack (bytes) — camera needs ~6 KB
        NULL,       // parameter
        1,          // priority
        &cameraTaskHandle,
        0 // pin to Core 0
    );
    Serial.println("Camera streaming at http://runner-companion.local:81/camera");
  }
  else
  {
    Serial.println("Camera unavailable — check GPIO pins against FNK0053 PCB.");
  }

  if (inSetupMode)
  {
    Serial.println("Setup server at http://192.168.4.1");
  }
  else
  {
    Serial.println("Robot ready! Turn on your phone hotspot and run the app.");
  }
}

// ─── Loop ──────────────────────────────────────────────────────────
void loop()
{
  // In setup mode: just serve HTTP for /configure — no driving
  if (inSetupMode)
  {
    server.handleClient();
    delay(10);
    return;
  }

  // STA mode: reconnect if WiFi drops
  if (WiFi.status() != WL_CONNECTED)
  {
    stopMotors();
    isPacing = false;
    Serial.println("WiFi lost — reconnecting...");
    WiFi.reconnect();
    unsigned long t = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - t < 10000)
    {
      delay(500);
    }
    if (WiFi.status() == WL_CONNECTED)
    {
      Serial.println("Reconnected: " + WiFi.localIP().toString());
      MDNS.begin(MDNS_HOSTNAME);
    }
  }

  // Feed GPS data
  while (gpsSerial.available())
  {
    gps.encode(gpsSerial.read());
  }

  server.handleClient();
  runPacingLogic();
  delay(50); // 20Hz loop
}

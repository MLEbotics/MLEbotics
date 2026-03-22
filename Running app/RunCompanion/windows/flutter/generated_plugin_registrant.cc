//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <cloud_firestore/cloud_firestore_plugin_c_api.h>
#include <desktop_webview_window/desktop_webview_window_plugin.h>
#include <firebase_auth/firebase_auth_plugin_c_api.h>
#include <firebase_core/firebase_core_plugin_c_api.h>
#include <flutter_tts/flutter_tts_plugin.h>
#include <gal/gal_plugin_c_api.h>
#include <geolocator_windows/geolocator_windows.h>
#include <speech_to_text_windows/speech_to_text_windows.h>
#include <url_launcher_windows/url_launcher_windows.h>
#include <window_to_front/window_to_front_plugin.h>

void RegisterPlugins(flutter::PluginRegistry* registry) {
  CloudFirestorePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("CloudFirestorePluginCApi"));
  DesktopWebviewWindowPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("DesktopWebviewWindowPlugin"));
  FirebaseAuthPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FirebaseAuthPluginCApi"));
  FirebaseCorePluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FirebaseCorePluginCApi"));
  FlutterTtsPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterTtsPlugin"));
  GalPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("GalPluginCApi"));
  GeolocatorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("GeolocatorWindows"));
  SpeechToTextWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("SpeechToTextWindows"));
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
  WindowToFrontPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowToFrontPlugin"));
}

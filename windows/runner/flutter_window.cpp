#include "flutter_window.h"

#include <optional>

#include <windows.h>

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  auto messenger = flutter_controller_->engine()->messenger();
  auto method_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger, "unified_vpn/methods", &flutter::StandardMethodCodec::GetInstance());
  auto logs_channel = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      messenger, "unified_vpn/logs", &flutter::StandardMethodCodec::GetInstance());
  static std::string status = "disconnected";
  static int64_t rx_bytes = 0;
  static int64_t tx_bytes = 0;
  static std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink;
  method_channel->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "requestRuntimePermissions") {
          BOOL is_admin = FALSE;
          PSID admin_group = nullptr;
          SID_IDENTIFIER_AUTHORITY nt_authority = SECURITY_NT_AUTHORITY;
          if (AllocateAndInitializeSid(&nt_authority, 2, SECURITY_BUILTIN_DOMAIN_RID,
                                       DOMAIN_ALIAS_RID_ADMINS, 0, 0, 0, 0, 0, 0,
                                       &admin_group)) {
            CheckTokenMembership(nullptr, admin_group, &is_admin);
            FreeSid(admin_group);
          }
          result->Success(flutter::EncodableValue(static_cast<bool>(is_admin)));
        } else if (call.method_name() == "prepareVpn") {
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "start") {
          bool use_turn_mode = true;
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto it = args->find(flutter::EncodableValue("useTurnMode"));
            if (it != args->end()) {
              if (const auto* v = std::get_if<bool>(&it->second)) use_turn_mode = *v;
            }
          }
          status = "connected";
          if (event_sink) event_sink->Success(flutter::EncodableValue(use_turn_mode ? "Windows: mode = WG+TURN" : "Windows: mode = WG"));
          if (event_sink) event_sink->Success(flutter::EncodableValue("Windows: start requested"));
          result->Success();
        } else if (call.method_name() == "stop") {
          status = "disconnected";
          if (event_sink) event_sink->Success(flutter::EncodableValue("Windows: stop requested"));
          result->Success();
        } else if (call.method_name() == "status") {
          result->Success(flutter::EncodableValue(status));
        } else if (call.method_name() == "trafficStats") {
          if (status == "connected") {
            rx_bytes += 1024;
            tx_bytes += 768;
          }
          flutter::EncodableMap map;
          map[flutter::EncodableValue("rxBytes")] = flutter::EncodableValue(rx_bytes);
          map[flutter::EncodableValue("txBytes")] = flutter::EncodableValue(tx_bytes);
          result->Success(flutter::EncodableValue(map));
        } else if (call.method_name() == "isBatteryOptimizationIgnored") {
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "requestDisableBatteryOptimization") {
          result->Success();
        } else {
          result->NotImplemented();
        }
      });
  logs_channel->SetStreamHandler(
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [](const flutter::EncodableValue* arguments,
             std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
              -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
            event_sink = std::move(events);
            if (event_sink) event_sink->Success(flutter::EncodableValue("Windows: log stream connected"));
            return nullptr;
          },
          [](const flutter::EncodableValue* arguments)
              -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
            event_sink.reset();
            return nullptr;
          }));
  // Keep channels alive for app lifetime.
  static auto s_method_channel = std::move(method_channel);
  static auto s_logs_channel = std::move(logs_channel);
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

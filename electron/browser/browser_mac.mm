// Copyright (c) 2013 GitHub, Inc.
// Use of this source code is governed by the MIT license that can be
// found in the LICENSE file.

#include "electron/browser/browser.h"

#include "electron/browser/mac/atom_application.h"
#include "electron/browser/mac/atom_application_delegate.h"
#include "electron/browser/native_window.h"
#include "electron/browser/window_list.h"
#include "base/mac/bundle_locations.h"
#include "base/mac/foundation_util.h"
#include "base/strings/sys_string_conversions.h"
#include "brightray/common/application_info.h"

namespace electron {

void Browser::Focus() {
  [[ElectronApplication sharedApplication] activateIgnoringOtherApps:YES];
}

void Browser::Hide() {
  [[ElectronApplication sharedApplication] hide:nil];
}

void Browser::Show() {
  [[ElectronApplication sharedApplication] unhide:nil];
}

bool Browser::IsDarkMode() {
  NSString *mode = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
  return [mode isEqualToString: @"Dark"];
}

void Browser::AddRecentDocument(const base::FilePath& path) {
  NSString* path_string = base::mac::FilePathToNSString(path);
  if (!path_string)
    return;
  NSURL* u = [NSURL fileURLWithPath:path_string];
  if (!u)
    return;
  [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:u];
}

void Browser::ClearRecentDocuments() {
  [[NSDocumentController sharedDocumentController] clearRecentDocuments:nil];
}

bool Browser::RemoveAsDefaultProtocolClient(const std::string& protocol) {
  return false;
}

bool Browser::SetAsDefaultProtocolClient(const std::string& protocol) {
  if (protocol.empty())
    return false;

  NSString* identifier = [base::mac::MainBundle() bundleIdentifier];
  if (!identifier)
    return false;

  NSString* protocol_ns = [NSString stringWithUTF8String:protocol.c_str()];
  OSStatus return_code =
      LSSetDefaultHandlerForURLScheme(base::mac::NSToCFCast(protocol_ns),
                                      base::mac::NSToCFCast(identifier));
  return return_code == noErr;
}

void Browser::SetAppUserModelID(const base::string16& name) {
}

std::string Browser::GetExecutableFileVersion() const {
  return brightray::GetApplicationVersion();
}

std::string Browser::GetExecutableFileProductName() const {
  return brightray::GetApplicationName();
}

int Browser::DockBounce(BounceType type) {
  return [[ElectronApplication sharedApplication]
      requestUserAttention:(NSRequestUserAttentionType)type];
}

void Browser::DockCancelBounce(int request_id) {
  [[ElectronApplication sharedApplication] cancelUserAttentionRequest:request_id];
}

void Browser::DockSetBadgeText(const std::string& label) {
  NSDockTile *tile = [[ElectronApplication sharedApplication] dockTile];
  [tile setBadgeLabel:base::SysUTF8ToNSString(label)];
}

std::string Browser::DockGetBadgeText() {
  NSDockTile *tile = [[ElectronApplication sharedApplication] dockTile];
  return base::SysNSStringToUTF8([tile badgeLabel]);
}

void Browser::DockHide() {
  WindowList* list = WindowList::GetInstance();
  for (WindowList::iterator it = list->begin(); it != list->end(); ++it)
    [(*it)->GetNativeWindow() setCanHide:NO];

  ProcessSerialNumber psn = { 0, kCurrentProcess };
  TransformProcessType(&psn, kProcessTransformToUIElementApplication);
}

void Browser::DockShow() {
  BOOL active = [[NSRunningApplication currentApplication] isActive];
  ProcessSerialNumber psn = { 0, kCurrentProcess };
  if (active) {
    // Workaround buggy behavior of TransformProcessType.
    // http://stackoverflow.com/questions/7596643/
    NSArray* runningApps = [NSRunningApplication
        runningApplicationsWithBundleIdentifier:@"com.apple.dock"];
    for (NSRunningApplication* app in runningApps) {
      [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
      break;
    }
    dispatch_time_t one_ms = dispatch_time(DISPATCH_TIME_NOW, USEC_PER_SEC);
    dispatch_after(one_ms, dispatch_get_main_queue(), ^{
      TransformProcessType(&psn, kProcessTransformToForegroundApplication);
      dispatch_time_t one_ms = dispatch_time(DISPATCH_TIME_NOW, USEC_PER_SEC);
      dispatch_after(one_ms, dispatch_get_main_queue(), ^{
        [[NSRunningApplication currentApplication]
            activateWithOptions:NSApplicationActivateIgnoringOtherApps];
      });
    });
  } else {
    TransformProcessType(&psn, kProcessTransformToForegroundApplication);
  }
}

void Browser::DockSetMenu(ui::MenuModel* model) {
  ElectronApplicationDelegate* delegate = (ElectronApplicationDelegate*)[NSApp delegate];
  [delegate setApplicationDockMenu:model];
}

void Browser::DockSetIcon(const gfx::Image& image) {
  [[ElectronApplication sharedApplication]
      setApplicationIconImage:image.AsNSImage()];
}

}  // namespace electron
// Copyright (c) 2013 The Chromium Embedded Framework Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the CEF LICENSE file. Adapted for Oriel Helper subprocesses.

#include "include/cef_app.h"
#include "include/wrapper/cef_library_loader.h"

// Entry point for Oriel Engine (CEF) helper processes.
int main(int argc, char* argv[]) {
  CefScopedLibraryLoader library_loader;
  if (!library_loader.LoadInHelper()) {
    return 1;
  }

  CefMainArgs main_args(argc, argv);
  return CefExecuteProcess(main_args, nullptr, nullptr);
}

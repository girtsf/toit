// Copyright (C) 2022 Toitware ApS.
//
// This library is free software; you can redistribute it and/or
// modify it under the terms of the GNU Lesser General Public
// License as published by the Free Software Foundation; version
// 2.1 only.
//
// This library is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Lesser General Public License for more details.
//
// The license can be found in the file `LICENSE` in the top level
// directory of this repository.

#include "fs_protocol.h"

namespace toit {
namespace compiler {

const char* LspFsProtocol::sdk_path() {
  connection_->putline("SDK PATH");
  return Zone::current()->strdup(connection_->getline().c_str());
}

List<const char*> LspFsProtocol::package_cache_paths() {
  connection_->putline("PACKAGE CACHE PATHS");

  int count = atoi(connection_->getline().c_str());

  auto result = ListBuilder<const char*>::allocate(count);

  for (int i = 0; i < count; i++) {
    result[i] = Zone::current()->strdup(connection_->getline().c_str());
  }
  return result;
}

void LspFsProtocol::list_directory_entries(const char* path,
                                           const std::function<bool (const char*)>& callback) {
  connection_->putline("LIST DIRECTORY");
  connection_->putline(path);

  int count = atoi(connection_->getline().c_str());

  bool should_call_callback = true;
  for (int i = 0; i < count; i++) {
    std::string line = connection_->getline();
    if (should_call_callback) {
      // Even if the callback doesn't want to be called anymore, we still need to
      // read the remaining lines.
      should_call_callback = callback(line.c_str());
    }
  }
}

LspFsProtocol::PathInfo LspFsProtocol::fetch_info_for(const char* path) {
  connection_->putline("INFO");
  connection_->putline(path);
  bool exists = connection_->getline() == "true";
  bool is_regular = connection_->getline() == "true";
  bool is_directory = connection_->getline() == "true";
  int size = atoi(connection_->getline().c_str());
  uint8* content = null;
  if (size >= 0) {
    content = unvoid_cast<uint8*>(malloc(size + 1));
    int n = connection_->read_data(content, size);
    if (n == -1) {
      fprintf(stderr, "ERROR: Unable to read entire file '%s'\n", path);
      size = 0;
    }
    content[size] = '\0';
  }
  PathInfo info = {
    .exists = exists,
    .is_regular_file = is_regular,
    .is_directory = is_directory,
    .size = size,
    .content = content,
  };

  return info;
}

} // namespace toit::compiler
} // namespace toit

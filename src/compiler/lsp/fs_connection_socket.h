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

#pragma once

#include <vector>

#include "../../top.h"

#include "fs_protocol.h"

namespace toit {
namespace compiler {

class Diagnostics;

class LspFsConnectionSocket : public LspFsConnection {
 public:
  explicit LspFsConnectionSocket(const char* port) : port_(port) {}
  ~LspFsConnectionSocket();

  void initialize(Diagnostics* diagnostics);
  void putline(const char*);
  std::string getline();
  int read_data(uint8* content, int size);

 private:
  const char* port_;

  bool is_initialized_ = false;
  int64 socket_ = -1;
  // Bytes received but not yet consumed by getline or read_data.
  std::vector<uint8> buffered_;
};

} // namespace toit::compiler
} // namespace toit

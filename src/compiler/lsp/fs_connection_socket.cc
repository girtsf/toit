// Copyright (C) 2020 Toitware ApS.
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

#include "../../top.h"

#include <stdio.h>

#include <algorithm>

#ifdef TOIT_POSIX
#include <errno.h>
#include <string.h>
#include <sys/socket.h>
#endif
#ifdef TOIT_WINDOWS
#include <winsock.h>
#endif

#include "fs_connection_socket.h"
#include "../../utils.h"

namespace toit {
namespace compiler {

// Report a closed peer as a send error instead of dying from SIGPIPE.
// macOS has no MSG_NOSIGNAL and sets SO_NOSIGPIPE on the socket instead.
#ifdef MSG_NOSIGNAL
static const int SEND_FLAGS = MSG_NOSIGNAL;
#else
static const int SEND_FLAGS = 0;
#endif

static const char* last_socket_error() {
#ifdef TOIT_WINDOWS
  static char buffer[32];
  snprintf(buffer, sizeof(buffer), "error %d", WSAGetLastError());
  return buffer;
#else
  return strerror(errno);
#endif
}

void LspFsConnectionSocket::putline(const char* line) {
  std::string data(line);
  data += '\n';
  size_t offset = 0;
  while (offset < data.size()) {
    int n = send(socket_, data.data() + offset, data.size() - offset, SEND_FLAGS);
    if (n < 0) {
#ifdef TOIT_POSIX
      // Without MSG_NOSIGNAL, SIGPIPE ended the process quietly. Keep it that
      // way instead of dumping core, like a killed parent in
      // send_pipeline_result.
      if (errno == EPIPE) {
        fprintf(stderr, "Language server closed the connection, exiting\n");
        exit(EXIT_FAILURE);
      }
#endif
      FATAL("failed writing line: %s", last_socket_error());
    }
    offset += n;
  }
}

std::string LspFsConnectionSocket::getline() {
  size_t searched = 0;
  while (true) {
    auto newline = std::find(buffered_.begin() + searched, buffered_.end(), '\n');
    if (newline != buffered_.end()) {
      std::string result(buffered_.begin(), newline);
      buffered_.erase(buffered_.begin(), newline + 1);
      return result;
    }
    searched = buffered_.size();
    uint8 chunk[4096];
    int n = recv(socket_, char_cast(chunk), sizeof(chunk), 0);
    if (n == 0) {
      FATAL("failed reading line: peer closed the connection");
    }
    if (n < 0) {
      FATAL("failed reading line: %s", last_socket_error());
    }
    buffered_.insert(buffered_.end(), chunk, chunk + n);
  }
}

int LspFsConnectionSocket::read_data(uint8* content, int size) {
  // Use what getline read ahead first, then read the rest directly.
  int offset = std::min(static_cast<int>(buffered_.size()), size);
  memcpy(content, buffered_.data(), offset);
  buffered_.erase(buffered_.begin(), buffered_.begin() + offset);
  while (offset < size) {
    int n = recv(socket_, char_cast(content) + offset, size - offset, 0);
    // 0 means the peer closed the connection before sending everything.
    if (n <= 0) return -1;
    offset += n;
  }
  return 0;
}

} // namespace compiler
} // namespace toit

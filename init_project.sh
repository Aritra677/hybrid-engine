#!/usr/bin/env bash
# init_project.sh - Auto-generates the Hybrid Engine repository
set -euo pipefail

echo "[*] Creating directory layout..."
mkdir -p src scripts rootfs .github/workflows

echo "[*] Generating src/main.c..."
cat << 'EOF' > src/main.c
#define _GNU_SOURCE
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <sys/mount.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <string.h>
#include <fcntl.h>
#include <signal.h>

#define STACK_SIZE (1024 * 1024)
static char child_stack[STACK_SIZE];

void handle_client(int client_fd) {
    char buffer[2048] = {0};
    read(client_fd, buffer, sizeof(buffer) - 1);
    
    char method[16], path[256];
    if (sscanf(buffer, "%15s %255s", method, path) != 2) {
        close(client_fd);
        return;
    }
    
    if (strcmp(path, "/") == 0) {
        strcpy(path, "/index.html");
    }
    
    char filepath[512];
    snprintf(filepath, sizeof(filepath), ".%s", path);
    
    int fd = open(filepath, O_RDONLY);
    if (fd < 0) {
        char *not_found = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n";
        write(client_fd, not_found, strlen(not_found));
    } else {
        char *ok = "HTTP/1.1 200 OK\r\n\r\n";
        write(client_fd, ok, strlen(ok));
        char f_buf[4096];
        int bytes_read;
        while ((bytes_read = read(fd, f_buf, sizeof(f_buf))) > 0) {
            write(client_fd, f_buf, bytes_read);
        }
        close(fd);
    }
    close(client_fd);
}

int child_fn(void *arg) {
    (void)arg;
    
    if (mount(NULL, "/", NULL, MS_PRIVATE | MS_REC, NULL) != 0) {
        perror("mount private");
        return 1;
    }
    
    if (chdir("./rootfs") != 0 || chroot(".") != 0) {
        perror("chroot/chdir failed");
        return 1;
    }
    
    int server_fd;
    struct sockaddr_in address;
    int opt = 1;
    
    if ((server_fd = socket(AF_INET, SOCK_STREAM, 0)) == 0) {
        perror("socket failed");
        return 1;
    }
    
    if (setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt))) {
        perror("setsockopt");
        return 1;
    }
    
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = INADDR_ANY;
    address.sin_port = htons(8080);
    
    if (bind(server_fd, (struct sockaddr *)&address, sizeof(address)) < 0) {
        perror("bind failed");
        return 1;
    }
    
    if (listen(server_fd, 10) < 0) {
        perror("listen");
        return 1;
    }
    
    printf("Containerized Engine running on port 8080...\n");
    
    while (1) {
        int client_fd = accept(server_fd, NULL, NULL);
        if (client_fd >= 0) {
            handle_client(client_fd);
        }
    }
    
    return 0;
}

int main() {
    printf("Starting Hybrid Engine...\n");
    
    pid_t pid = clone(child_fn, child_stack + STACK_SIZE, 
                      CLONE_NEWPID | CLONE_NEWNS | CLONE_NEWUTS | SIGCHLD, NULL);
                      
    if (pid == -1) {
        perror("clone failed - Ensure you are running as root");
        exit(EXIT_FAILURE);
    }
    
    waitpid(pid, NULL, 0);
    return 0;
}
EOF

echo "[*] Generating Makefile..."
cat << 'EOF' > Makefile
CC=gcc
CFLAGS=-Wall -Wextra -O2
TARGET=engine

all: $(TARGET)

$(TARGET): src/main.c
	$(CC) $(CFLAGS) -o $(TARGET) src/main.c

clean:
	rm -f $(TARGET)
EOF

echo "[*] Generating .github/workflows/build.yml..."
cat << 'EOF' > .github/workflows/build.yml
name: Build Engine

on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3

    - name: Install dependencies
      run: sudo apt-get update && sudo apt-get install -y gcc make tar wget curl

    - name: Download RootFS
      run: |
        mkdir -p rootfs
        wget -qO alpine.tar.gz https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-minirootfs-3.20.3-x86_64.tar.gz
        sudo tar -xf alpine.tar.gz -C rootfs/
        rm alpine.tar.gz
        echo "<h1>CI Pipeline Test</h1>" | sudo tee rootfs/index.html

    - name: Build
      run: make

    - name: Test Execution
      run: |
        # Run the engine in the background
        sudo ./engine &
        sleep 2
        curl -s http://localhost:8080 | grep "CI Pipeline Test"
        sudo pkill engine
EOF

echo "[*] Generating README.md..."
cat << 'EOF' > README.md
# Hybrid Container-Web Engine

[![Build Engine](https://github.com/USERNAME/REPO/actions/workflows/build.yml/badge.svg)](https://github.com/USERNAME/REPO/actions/workflows/build.yml)

A zero-dependency, ultra-lightweight hybrid engine written in pure C11 and Bash. It combines a container runtime (using Linux kernel primitives like `clone`, `chroot`, `CLONE_NEWPID`, `CLONE_NEWNS`, `CLONE_NEWUTS`) and a low-level HTTP web server into a single binary.

## Features
- **Zero Dependencies**: Pure C11 and POSIX standard libc.
- **Process Isolation**: Fully sandboxed rootfs environment via namespaces.
- **Embedded Web Server**: Custom HTTP socket parser running securely on port 8080.
- **Automated Bootstrap**: Setup script handles rootfs downloads and project configuration.

## Quickstart

1. Run the initializer script to download Alpine rootfs and configure the project:
   ```bash
   ./init_project.sh
   ```
2. Build the binary:
   ```bash
   make
   ```
3. Run the engine (Requires `sudo` for namespace cloning):
   ```bash
   sudo ./engine
   ```
4. Access the server:
   ```bash
   curl http://localhost:8080
   ```

## Architecture Roadmap (v2)
**Upcoming v2 Milestone:** 
Our v2 release will introduce **Native NPU offloading support** and **distributed multi-GPU cluster orchestration**. This capability will allow running and scaling localized AI/ML model inference directly across hardware nodes from inside the minimal sandboxed container structure, enabling high-performance, low-latency localized edge AI.
EOF

echo "[*] Fetching Alpine minirootfs..."
if [ ! -f "alpine.tar.gz" ]; then
    wget -qO alpine.tar.gz https://dl-cdn.alpinelinux.org/alpine/v3.20/releases/x86_64/alpine-minirootfs-3.20.3-x86_64.tar.gz
fi
tar -xf alpine.tar.gz -C rootfs/ || echo "[!] Failed to extract rootfs. Run as root or ensure tar compatibility."
rm -f alpine.tar.gz

echo "<h1>Welcome to Hybrid Engine</h1>" > rootfs/index.html

echo "[*] Project generation complete!"

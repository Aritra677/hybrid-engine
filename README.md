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

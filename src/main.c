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

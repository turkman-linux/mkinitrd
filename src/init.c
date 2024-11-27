#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <dirent.h>
#include <sys/mount.h>
#include <sys/wait.h>
#include <signal.h>

void create_shell() {
    fprintf(stderr, "\033[31;1mBoot failed! Creating debug shell as PID: 1\033[;0m\n");

    // Redirect stdout, stderr, stdin to /dev/console
    freopen("/dev/console", "w", stdout);
    freopen("/dev/console", "w", stderr);
    freopen("/dev/console", "r", stdin);

    // Start a new shell (ash in this case)
    execlp("/bin/busybox", "ash", NULL);
    // If execlp fails, fall back to a manual shell
    perror("Failed to exec ash");
    exit(1);
}

void mount_root(const char *root) {
    struct stat st;
    if (stat("/rootfs", &st) == -1) {
        mkdir("/rootfs", 0755);
        char path[1024];
        if (root && strncmp(root, "UUID=", 5) == 0) {
            snprintf(path, sizeof(path), "/dev/disk/by-uuid/%s", root + 5);
            root = path;
        }
        pid_t pid = fork();
        int status = 0;
        if(pid == 0) {
            execlp("/bin/busybox", "mount", "-o", "rw", root, "/rootfs", NULL);
        }
        waitpid(pid, &status, 0);
        if (status){
            perror("Failed to mount root");
            create_shell();
        }
        symlink(root, "/dev/root");
    }
}

void create_dir_if_not_exists(const char *path) {
    struct stat st;
    if (stat(path, &st) == -1) {
        if (mkdir(path, 0755) == -1) {
            perror("Failed to create directory");
            create_shell();
        }
    }
}

void mount_virtual_filesystems() {
    create_dir_if_not_exists("/dev");
    create_dir_if_not_exists("/sys");
    create_dir_if_not_exists("/proc");
    
    if (mount("devtmpfs", "/dev", "devtmpfs", 0, NULL) == -1) {
        perror("Failed to mount devtmpfs");
    }
    if (mount("sysfs", "/sys", "sysfs", 0, NULL) == -1) {
        perror("Failed to mount sysfs");
    }
    if (mount("proc", "/proc", "proc", 0, NULL) == -1) {
        perror("Failed to mount proc");
    }
}

void move_virtual_filesystems() {
    if (mount("/dev", "/rootfs/dev", NULL, MS_MOVE, NULL) == -1) {
        perror("Failed to move mount /dev");
    }
    if (mount("/sys", "/rootfs/sys", NULL, MS_MOVE, NULL) == -1) {
        perror("Failed to move mount /sys");
    }
    if (mount("/proc", "/rootfs/proc", NULL, MS_MOVE, NULL) == -1) {
        perror("Failed to move mount /proc");
    }
    create_dir_if_not_exists("/rootfs/dev/pts");
    if (mount("devpts", "/rootfs/dev/pts", "devpts", 0, NULL) == -1) {
        perror("Failed to mount devpts");
    }
}

void parse_kernel_cmdline() {
    FILE *cmdline = fopen("/proc/cmdline", "r");
    if (cmdline) {
        char *line = NULL;
        size_t len = 0;
        while (getline(&line, &len, cmdline) != -1) {
            // strip newline
            while (line[strlen(line)-1] == '\n'){
                line[strlen(line)-1] = '\0';
                len--;
            }
            // split by " "
            char *token = strtok(line, " ");
            while (token != NULL) {
                // check = exists
                char* val = strstr(token, "=");
                if(val != NULL && val-token > 0){
                    token[val-token] = '\0';
                    setenv(strdup(token), strdup(val+1), 1);
                }
                token = strtok(NULL, " ");
            }
        }
        fclose(cmdline);
    } else {
        perror("Failed to read /proc/cmdline");
    }
}

void run_scripts(const char *script_dir, const char *script_phase) {
    DIR *dir = opendir(script_dir);
    if (dir) {
        char script[1024];
        int status;
        struct dirent *entry;
        while ((entry = readdir(dir)) != NULL) {
            if (entry->d_name[0] == '.') {
                continue;  // Skip hidden files
            }
            snprintf(script, sizeof(script), "source %s/%s ; %s", script_dir, entry->d_name, script_phase);
            printf("\033[33;1mRunning:\033[;0m %s\n", entry->d_name);
            pid_t pid = fork();
            if (pid == 0) {
                execlp("/bin/busybox", "busybox", "ash", "-c", script, NULL);
                perror("Failed to exec script");
                exit(1);
            } else if (pid < 0) {
                perror("Fork failed");
                create_shell();
            }
            waitpid(pid, &status, 0);
            if (WEXITSTATUS(status) != 0) {
                create_shell();
            }
        }
        closedir(dir);
    } else {
        perror("Failed to open /scripts directory");
    }
}

int main(int argc, char** argv) {
    // Get system info
    FILE *os_release = fopen("/etc/os-release", "r");
    if (os_release) {
        char line[256];
        while (fgets(line, sizeof(line), os_release)) {
            if (strncmp(line, "NAME=", 5) == 0) {
                char *distro = line + 5;
                distro[strcspn(distro, "\n")] = '\0';
                printf("Booting \033[33;1m%s\033[;0m\n", distro);
                break;
            }
        }
        fclose(os_release);
    }

    // Mount virtual filesystems
    mount_virtual_filesystems();

    // Parse kernel cmdline and set environment variables
    parse_kernel_cmdline();

    // Run init scripts (init_top)
    run_scripts("/scripts", "init_top");

    // Mount root filesystem
    mount_root(getenv("root"));

    // Run init scripts (init_bottom)
    run_scripts("/scripts", "init_bottom");

    // Move mountpoints    
    move_virtual_filesystems();

    // Switch root filesystem and start init
    if (chroot("/rootfs") == -1) {
        perror("Failed to chroot");
        create_shell();
    }
    if (chdir("/") == -1) {
        perror("Failed to chdir to root");
        create_shell();
    }

    char* init = "/sbin/init";
    if(getenv("init")){
        init = getenv("init");
    }
    char* args[] = {init,NULL};
    // Execute init
    execv(init, args);
    perror("Failed to exec /sbin/init");
    while(1);
    return 1;
}

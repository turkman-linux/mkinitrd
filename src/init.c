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
    fprintf(stderr, "\033[31;1mBoot failed!\033[;0m Creating debug shell as PID: 1\n");

    // Redirect stdout, stderr, stdin to /dev/console
    FILE *rc;
    rc = freopen("/dev/console", "w", stdout);
    rc = freopen("/dev/console", "w", stderr);
    rc = freopen("/dev/console", "r", stdin);
    (void)rc;

    // Start a new shell (ash in this case)
    execlp("/bin/busybox", "ash", NULL);
    // If execlp fails, stop and wait
    perror("Failed to exec ash");
    while(1);
}

void sigsegv_handler(int signum) {
    (void)signum;
    printf("\033[31;1mCaught SIGSEGV:\033[;0m Segmentation fault occurred!\n");
    create_shell();
}

void connect_signal(){
    struct sigaction sa;

    // Set up the signal handler
    sa.sa_handler = sigsegv_handler;
    sa.sa_flags = 0;
    sigemptyset(&sa.sa_mask);

    // Register the signal handler for SIGSEGV
    if (sigaction(SIGSEGV, &sa, NULL) == -1) {
        perror("sigaction");
        create_shell();
    }
}

void mount_root(const char *root) {
    struct stat st;
    if (stat("/rootfs", &st) == -1) {
        mkdir("/rootfs", 0755);
        pid_t pid = fork();
        char* rootfs_flags = "ro";
        if(getenv("rootflags") != NULL){
            rootfs_flags = getenv("rootflags");
        }
        char* rootfs_type = "auto";
        if(getenv("rootfstype") != NULL){
            rootfs_type = getenv("rootfstype");
        }
        // wait until ready for root
        int status = 0;
        while(lstat(root, &st) == -1){
            printf("Waiting for root: %s\n", root);
            sleep(1);
            status++;
            if(status > 10) {
                create_shell();
            }
        }
        status = 0;
        if(pid == 0) {
            execlp("/bin/busybox", "mount", "-o", rootfs_flags, "-t", rootfs_type ,root, "/rootfs", NULL);
        }
        waitpid(pid, &status, 0);
        if (status){
            perror("Failed to mount root");
            create_shell();
        }
        int rc = symlink(root, "/dev/root");
        (void)rc;
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

int is_mount_point(const char *dir) {
    // detect directory is a mountpoint
    struct stat mountpoint;
    struct stat parent;

    if (stat(dir, &mountpoint) == -1) {
        perror("failed to stat mountpoint:");
        return 1;
    }

    /* ... and its parent. */
    char parent_dir[1024];
    snprintf(parent_dir, sizeof(parent_dir), "%s/..", dir);
    if (stat(parent_dir, &parent) == -1) {
        perror("failed to stat parent:");
        return 1;
    }
    return (mountpoint.st_dev != parent.st_dev);
}

int remove_directory(const char *path) {
    // remove directory recursivelly
    // skip mountpoints
    if(is_mount_point(path)){
        return 0;
    }
    struct dirent *entry;
    DIR *dp = opendir(path);
    if (dp == NULL) {
        perror("opendir");
        return 0;
    }

    while ((entry = readdir(dp)) != NULL) {
        // Skip the special entries "." and ".."
        if (strcmp(entry->d_name, ".") == 0 ||
            strcmp(entry->d_name, "..") == 0){
            continue;
        } else {
            char new_path[1024];
            snprintf(new_path, sizeof(new_path), "%s/%s", path, entry->d_name);

            struct stat statbuf;
            if (lstat(new_path, &statbuf) == 0) {
                if (S_ISDIR(statbuf.st_mode)) {
                    // Recursively remove the directory
                    if(remove_directory(new_path)){
                        // Remove the directory itself
                        if (rmdir(new_path) != 0) {
                            puts(new_path);
                            perror("rmdir");
                        }
                    }
                } else {
                    // Remove the file
                    if (remove(new_path) != 0) {
                        puts(new_path);
                        perror("remove");
                    }
                }
            }
        }
    }

    closedir(dp);
    return 1;
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
                    if (strncmp(token, "root", 4) == 0 && strncmp(val, "UUID=", 5) == 0) {
                        char path[1024];
                        snprintf(path, sizeof(path), "/dev/disk/by-uuid/%s", val + 5);
                        setenv("root", path, 1);
                    }
                }
                token = strtok(NULL, " ");
            }
        }
        fclose(cmdline);
    } else {
        perror("Failed to read /proc/cmdline");
    }
}

int compare(const void *a, const void *b) {
    return strcmp(*(const char **)a, *(const char **)b);
}

void run_scripts(const char *script_dir, const char *script_phase) {
    DIR *dir = opendir(script_dir);
    if (dir) {
        char script[1024];
        char *modules[1024];
        int status;
        int count = 0;
        struct dirent *entry;
        while ((entry = readdir(dir)) != NULL) {
            if (entry->d_name[0] == '.') {
                continue;  // Skip hidden files
            }
            modules[count] = strdup(entry->d_name);
            count++;
        }
        closedir(dir);
        qsort(modules, count, sizeof(char *), compare);
        for(int i=0; i< count ; i++){
            snprintf(script, sizeof(script), "set -e ; source %s/%s ; %s", script_dir, modules[i], script_phase);
            printf("\033[32;1mRunning:\033[;0m %s\n", modules[i]);
            pid_t pid = fork();
            if (pid == 0) {
                execlp("/bin/busybox", "busybox", "ash", "-c", script, NULL);
                perror("Failed to exec script");
                create_shell();
            } else if (pid < 0) {
                perror("Fork failed");
                create_shell();
            }
            waitpid(pid, &status, 0);
            if (WEXITSTATUS(status) != 0) {
                create_shell();
            }
        }
        for (int i = 0; i < count; i++) {
            free(modules[i]);
        }
    } else {
        perror("Failed to open /scripts directory");
        create_shell();
    }
}

int main(int argc, char** argv) {
    (void)argc; (void)argv;
    // Clear screen
    printf("\033c");

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

    // Erase initramfs
    (void)remove_directory("/");

    // move rootfs to /
    if (chdir("/rootfs") < 0) {
        perror("Failed to chdir to new root");
        create_shell();
    }
    if(mount("/rootfs", "/", NULL, MS_MOVE, NULL) < 0){
        perror("Failed to mount moving to /");
        create_shell();
    }

    // Switch root filesystem and start init
    if (chroot(".") < 0) {
        perror("Failed to changer root");
        create_shell();
    }
    if (chdir("/") < 0) {
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

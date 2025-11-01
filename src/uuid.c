#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <limits.h>
#include <blkid.h>
#include <dirent.h>

static bool check_uuid(const char* devname, const char *fuuid) {
    blkid_probe pr;
    const char *uuid;

    pr = blkid_new_probe_from_filename(devname);
    if (!pr) {
        return false;
    }

    blkid_do_probe(pr);
    blkid_probe_lookup_value(pr, "UUID", &uuid, NULL);

    bool status = (uuid && strcmp(uuid, fuuid) == 0);
    blkid_free_probe(pr);
    return status;
}

char* find_uuid(const char* partition_uuid) {
    struct dirent *entry;
    DIR *dp = opendir("/sys/class/block/");
    
    if (dp == NULL) {
        perror("opendir");
        return NULL;
    }
    
    char* part = NULL;
    while ((entry = readdir(dp)) != NULL) {
        if (entry->d_name[0] == '.') {
            continue;
        }
        
        char devname[PATH_MAX];
        snprintf(devname, sizeof(devname), "/dev/%s", entry->d_name);
        
        if(check_uuid(devname, partition_uuid)){
            part = strdup(devname);
            break;
        }
    }

    closedir(dp);
    return part;
}

#ifdef UUIDTEST
int main(int argc, char** argv) {
    if(argc != 2) {
        fprintf(stderr, "Usage: %s <UUID>\n", argv[0]);
        return 1;
    }
    
    char* device_name = find_uuid(argv[1]);
    if(device_name) {
        printf("%s\n", device_name);
        free(device_name);
    } else {
        printf("Device not found for UUID: %s\n", argv[1]);
    }
    return 0;
}
#endif
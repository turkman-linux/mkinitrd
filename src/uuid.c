#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string.h>
#include <blkid.h>
#include <dirent.h>


static bool check_uuid(const char* devname, const char *fuuid) {
    blkid_probe pr;
    const char *uuid;

    pr = blkid_new_probe_from_filename(devname);
    if (!pr) {
        return NULL;
    }

    blkid_do_probe(pr);
    blkid_probe_lookup_value(pr, "UUID", &uuid, NULL);


    bool status = (strcmp(uuid, fuuid) == 0);
    blkid_free_probe(pr);
    return status;
}

char* find_uuid(const char* partition_uuid){
    struct dirent *entry;
    DIR *dp = opendir("/sys/class/block/");

    if (dp == NULL) {
        perror("opendir");
        return NULL;
    }
    char devname[PATH_MAX];
    char* part;
    while ((entry = readdir(dp)) != NULL) {
        if (entry->d_name[0] == '.') {
            continue;
        }
        strcpy(devname, "/dev/");
        strcat(devname, entry->d_name);
        if(check_uuid(devname, partition_uuid)){
            part = strdup(devname);
        }
    }

    closedir(dp);
    return part;
}


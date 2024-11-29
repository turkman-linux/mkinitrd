#!/bin/sh
# Hook order
hooks="base eudev ext4 storage"
# Module list
# * most = copy all storage and filesystem modules
# * dep = copy all modules used by current system
# * none = do not copy any modules
modules="most"
#!/bin/bash

TARGET_DIR=$1
# NEXUS_URL=$2
# NEXUS_CREDENTIAL_USERNAME=$3
# NEXUS_CREDENTIAL_PASSWORD=$4
NEXUS_URL=http://192.168.41.181:8081/repository/maven-releases
NEXUS_CREDENTIAL_USERNAME=admin
NEXUS_CREDENTIAL_PASSWORD=admin12341234

# Recursive Function
recursive_func() {
    shopt -s nullglob dotglob

    for PATHNAME in $1/*;
    do
        if [ -d $PATHNAME ];
        then
            recursive_func $PATHNAME
        else
            FILE_EXTENSION="${PATHNAME##*.}"

            if [ "$FILE_EXTENSION" != "repositories" ]
            then
                LIBRARY_PATH=$(echo $PATHNAME | sed "s/$TARGET_DIR\///g")
                LIBRARY_FILENAME=$(basename $LIBRARY_PATH)

                echo "Current Import Target Dependency : $LIBRARY_FILENAME"

                curl \
                    -X PUT \
                    -u $NEXUS_CREDENTIAL_USERNAME:$NEXUS_CREDENTIAL_PASSWORD \
                    --upload-file $PATHNAME \
                    $NEXUS_URL/$LIBRARY_PATH
            fi
        fi
    done
}

recursive_func $TARGET_DIR
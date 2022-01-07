# User-specific variables
REMOTE_HOST="arian@138.201.123.197"
REMOTE_HOST_ANDROID_ROOT="/home/arian/lineage-18.1/"
DEVICE="renoir"

PARTITIONS="boot dtbo odm product system_ext system vbmeta vbmeta_system vendor_boot vendor"

get_images () {
    for partition in ${PARTITIONS}; do
        echo "Downloading ${partition}"
        rsync -v ${REMOTE_HOST}:${REMOTE_HOST_ANDROID_ROOT}/out/target/product/${DEVICE}/${partition}.img ./
        echo "Downloaded ${partition}"
    done
}

flash_images () {
    for partition in ${PARTITIONS}; do
        until [[ -f ./${partition}.img ]]; do
            sleep 1
        done
        if [[ ! $(ssh ${REMOTE_HOST} 'sha1sum '${REMOTE_HOST_ANDROID_ROOT}'/out/target/product/'${DEVICE}'/'${partition}'.img' | awk '{print $1}') = $(sha1sum ./${partition}.img | awk '{print $1}') ]]; then
            echo "${partition} download is corrupt!"
            continue
        fi
        echo "Flashing ${partition}"
        fastboot flash ${partition} ${partition}.img
    done
}

get_images&
flash_images&
wait

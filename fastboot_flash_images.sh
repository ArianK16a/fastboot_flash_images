PARTITIONS="boot dtbo odm product system_ext system vbmeta vbmeta_system vendor_boot vendor"

get_images () {
    for partition in ${PARTITIONS}; do
        echo "Downloading ${partition}"
        rsync -v arian@138.201.123.197:/home/arian/lineage-18.1/out/target/product/renoir/${partition}.img ./
        echo "Downloaded ${partition}"
    done
}

flash_images () {
    for partition in ${PARTITIONS}; do
        until [[ -f ./${partition}.img ]]; do
            sleep 1
        done
        if [[ ! $(ssh arian@138.201.123.197 'sha1sum /home/arian/lineage-18.1/out/target/product/renoir/'${partition}'.img' | awk '{print $1}') = $(sha1sum ./${partition}.img | awk '{print $1}') ]]; then
            echo "${partition} download is corrupt!"
            continue
        fi
        echo "Flashing ${partition}"
        fastboot flash ${partition} ${partition}.img
    done
}

# Cleanup
rm ./*.img

get_images&
flash_images&
wait

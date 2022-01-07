# User-specific variables
REMOTE_HOST="arian@138.201.123.197"
REMOTE_HOST_ANDROID_ROOT="/home/arian/lineage-18.1/"
DEVICE="renoir"

# List of partitions which can be flashed. Only images existent in out will be flashed.
FASTBOOT_PARTITIONS="boot dtbo vbmeta vbmeta_system vendor_boot"
#FASTBOOT_PARTITIONS="dtbo"
FASTBOOTD_PARTITIONS="odm product system_ext system vendor"
#FASTBOOTD_PARTITIONS="odm"

# Function to print with colors
function colored_echo() {
    IFS=" "
    local color=$1;
    shift
    if ! [[ $color =~ '^[0-9]$' ]] ; then
        case $(echo $color | tr '[:upper:]' '[:lower:]') in
        black) color=0 ;;
        red) color=1 ;;
        green) color=2 ;;
        yellow) color=3 ;;
        blue) color=4 ;;
        magenta) color=5 ;;
        cyan) color=6 ;;
        white|*) color=7 ;; # white or invalid color
        esac
    fi
    if [ -t 1 ] ; then tput setaf $color; fi
    printf '%s\n' "$*"
    if [ -t 1 ] ; then tput sgr0; fi
}

# Strip not existent partitions
for partition in ${FASTBOOT_PARTITIONS}; do
    if ssh -q ${REMOTE_HOST} [[ -f ${REMOTE_HOST_ANDROID_ROOT}/out/target/product/${DEVICE}/${partition}.img ]]; then
        AVAILABLE_FASTBOOT_PARTITIONS="${AVAILABLE_FASTBOOT_PARTITIONS} ${partition}"
    fi
done
for partition in ${FASTBOOTD_PARTITIONS}; do
    if ssh -q ${REMOTE_HOST} [[ -f ${REMOTE_HOST_ANDROID_ROOT}/out/target/product/${DEVICE}/${partition}.img ]]; then
        AVAILABLE_FASTBOOTD_PARTITIONS="${AVAILABLE_FASTBOOTD_PARTITIONS} ${partition}"
    fi
done


get_images () {
    for partition in ${AVAILABLE_FASTBOOT_PARTITIONS}${AVAILABLE_FASTBOOTD_PARTITIONS}; do
        colored_echo magenta "[downloader] Downloading ${partition} image"
        rsync -vq ${REMOTE_HOST}:${REMOTE_HOST_ANDROID_ROOT}/out/target/product/${DEVICE}/${partition}.img ./ | sed "s|.*|[downloader][rsync] &|"
        if [[ $? = 0 ]]; then
            colored_echo magenta "[downloader] Downloaded ${partition} image"
        else
            colored_echo red "[downloader] Failed to download ${partition} image"
        fi
    done
    colored_echo green "[downloader] Finished downloading images"
}

flash_image () {
        colored_echo yellow "[flasher] Waiting until ${partition} is synced"
        until [[ $(ssh ${REMOTE_HOST} 'sha1sum '${REMOTE_HOST_ANDROID_ROOT}'/out/target/product/'${DEVICE}'/'${partition}'.img' | awk '{print $1}') = $(sha1sum ./${partition}.img | awk '{print $1}') ]]; do
            sleep 1
        done

        # Add the slot as suffix to the partition for ab devices
        partition_with_slot="${partition}"
        if [[ ${device_is_ab} == "1" ]]; then
            partition_with_slot="${partition_with_slot}_${fastboot_current_slot}"
        fi
           
        # Flash the image using fastboot
        colored_echo yellow "[flasher] Flashing ${partition_with_slot} image"
        fastboot flash ${partition_with_slot} ${partition}.img 2>&1 | sed "s|.*|[flasher][fastboot] &|"
        if [[ ${PIPESTATUS[0]} = 0 ]]; then
            colored_echo yellow "[flasher] Flashed ${partition_with_slot} image"
        else
            colored_echo red "[flasher] Failed to flash ${partition_with_slot} image"
        fi
}

flash_images () {
    # Flash partitions using fastboot
    for partition in ${AVAILABLE_FASTBOOT_PARTITIONS}; do
        flash_image
    done

    # Dynamic devices need to boot into userspace fastboot
    if [[ ${device_is_dynamic} = "1" ]]; then
        colored_echo yellow "[flasher] Dynamic device booting into userspace fastboot"
        fastboot reboot fastboot 2>&1 | sed "s|.*|[flasher][fastboot] &|"
        
        # Check if booting to userspace fastboot suceeded
        fastboot_is_userspace=$(fastboot getvar is-userspace 2>&1 | awk 'NR==1{print $2}')
        fastboot_is_userspace=${fastboot_is_userspace//[^a-zA-Z0-9_]/}
        if [[ ! ${fastboot_is_userspace} = "yes" ]]; then
            colored_echo red "[flasher] Dynamic device failed to boot into userspace fastboot"
            exit
        fi
    fi

    # Flash partitions using fastboot or fastbootd if necessary
    for partition in ${AVAILABLE_FASTBOOTD_PARTITIONS}; do
        flash_image
    done
    colored_echo green "[flasher] Finished flashing images"
}

prepare_fastboot () {
    # Check and wait until a device is connected
    if [[ $(fastboot devices) = "" ]]; then
        colored_echo red "[flasher] No device connected in fastboot mode"
    fi
    until [[ ! $(fastboot devices) = "" ]]; do
        if [[ ! $(adb devices | awk 'NR==2') = "" ]]; then
            adb reboot bootloader 2>&1 | sed "s|.*|[flasher][adb] &|"
        fi
        sleep 5
    done

    # Check if the correct device is connected
    fastboot_product=$(fastboot getvar product 2>&1 | awk 'NR==1{print $2}')
    fastboot_product=${fastboot_product//[^a-zA-Z0-9_]/}
    if [[ ! ${fastboot_product} = ${DEVICE} ]]; then
        colored_echo red "[flasher] Connected device is ${fastboot_product}, but should be ${DEVICE}"
        exit
    fi

    # Reboot to fastboot if device is in fastbootd
    fastboot_is_userspace=$(fastboot getvar is-userspace 2>&1 | awk 'NR==1{print $2}')
    fastboot_is_userspace=${fastboot_is_userspace//[^a-zA-Z0-9_]/}
    if [[ ${fastboot_is_userspace} = "yes" ]]; then
        fastboot reboot bootloader 2>&1 | sed "s|.*|[flasher][fastboot] &|"
        # Wait until device is in fastboot mode before proceeding
        until [[ ! $(fastboot devices) = "" ]]; do
            sleep 1
        done
    fi

    # Check if the device has a super partition and mark it as dynamic if so
    fastboot_partition_type_super=$(fastboot getvar partition-type:super 2>&1 | awk 'NR==1{print $2}')
    fastboot_partition_type_super=${fastboot_partition_type_super//[^a-zA-Z0-9_]/}
    device_is_dynamic=0
    if [[ ${fastboot_partition_type_super} = "raw" ]]; then
        device_is_dynamic=1
    fi

    # Check if the device has 2 slots and mark it as ab if so
    # If the device is ab get the current slot
    fastboot_slot_count=$(fastboot getvar slot-count 2>&1 | awk 'NR==1{print $2}')
    fastboot_slot_count=${fastboot_slot_count//[^a-zA-Z0-9_]/}
    device_is_ab=0
    if [[ ${fastboot_slot_count} = "2" ]]; then
        device_is_ab=1
        fastboot_current_slot=$(fastboot getvar current-slot 2>&1 | awk 'NR==1{print $2}')
        fastboot_current_slot=${fastboot_current_slot//[^a-zA-Z0-9_]/}
    fi

    colored_echo cyan "--- Device information ---"
    colored_echo cyan "product: ${fastboot_product}"
    colored_echo cyan "dynamic partitions: ${device_is_dynamic}"
    colored_echo cyan "ab partitions: ${device_is_ab}"
    if [[ ${device_is_ab} = "1" ]]; then
        colored_echo cyan "current slot: ${fastboot_current_slot}"
    fi
    echo ""
}

prepare_fastboot
get_images&
flash_images&
wait

# User-specific variables
REMOTE_HOST="arian@138.201.123.197"
REMOTE_HOST_ANDROID_ROOT="/home/arian/lineage-18.1/"
DEVICE="renoir"

# List of partitions which can be flashed. Only images existent in out will be flashed.
SUPPORTED_PARTITIONS="boot dtbo odm product system_ext system vbmeta vbmeta_system vendor_boot vendor"

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
for partition in ${SUPPORTED_PARTITIONS}; do
    if ssh -q ${REMOTE_HOST} [[ -f ${REMOTE_HOST_ANDROID_ROOT}/out/target/product/${DEVICE}/${partition}.img ]]; then
        AVAILABLE_PARTITIONS="${AVAILABLE_PARTITIONS} ${partition}"
    fi
done

get_images () {
    for partition in ${AVAILABLE_PARTITIONS}; do
        echo "Downloading ${partition}"
        rsync -v ${REMOTE_HOST}:${REMOTE_HOST_ANDROID_ROOT}/out/target/product/${DEVICE}/${partition}.img ./
        echo "Downloaded ${partition}"
    done
}

flash_images () {
    for partition in ${AVAILABLE_PARTITIONS}; do
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

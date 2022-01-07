This script is supposed to provide an efficient way to parallely download from a server and flash compiled images using fastboot.

Especially on virtual AB devices building OTA packages consumes a lot of time. We can skip that by just building the images using "m" instead of "brunch" or "m bacon".
When building on a server it can get annoying to transfer the images and flash them manually. This project tries to help in that scenario by downloading the images and parallely starting to flash the ones which are already downloaded. This script also takes care of switching between userspace fastboot and regular fastboot to flash partitions if used correctly.

Configuration
REMOTE_HOST: This is supposed to be username@serverip. You need to have access via ssh to this server.
REMOTE_HOST_ANDROID_ROOT: This should contain the absolute path to the root of the android environment on the server.
DEVICE: This is the device which should be flashed.

FASTBOOT_PARTITION: All images which are listed here will be downloaded and flashed via fastboot if they are existing in the out on the remote host.
FASTBOOTD_PARTITIONS: Images listed here will be flashed using userspace fastboot if the device has a super partition, otherwise they will be flashed in regular fastboot.

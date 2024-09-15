#!/bin/bash
#
# Script for building Android arm64 Kernel
#
# Copyright (c) 2021 Fiqri Ardyansyah <fiqri15072019@gmail.com>
# Based on Panchajanya1999 script.
#

# Set environment for directory
KERNEL_DIR=$PWD
IMG_DIR="$KERNEL_DIR/out/arch/arm64/boot"

# Get defconfig file
DEFCONFIG=nokia_defconfig

# Set environment for kernel build
export ARCH=arm64
export SUBARCH=arm64
export KBUILD_BUILD_VERSION="1"
export KBUILD_BUILD_USER="Rahul"
export KBUILD_BUILD_HOST="Linux"

# Set environment for telegram
export CHATID="-1001542481275"
export token="5389275341:AAFtB8oBu3KUO2_EY68XwQ-mEwBXPOEp64A"
export BOT_MSG_URL="https://api.telegram.org/bot$token/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot$token/sendDocument"

# Get distro name
DISTRO=$(lsb_release -ds 2>/dev/null || echo "Unknown")

# Get all cores of CPU
PROCS=$(nproc --all)
export PROCS

# Set date and time
DATE=$(TZ=Asia/Kolkata date +"%Y%m%d-%T")

# Get branch name
BRANCH=$(git rev-parse --abbrev-ref HEAD)
export BRANCH

# Check kernel version
KERVER=$(make kernelversion)

# Get last commit
COMMIT_HEAD=$(git log --oneline -1)

# Define the device name based on your kernel build
DEVICE="Nokia PL2"

# Function for telegram message
tg_post_msg() {
    curl -s -X POST "$BOT_MSG_URL" \
        -d chat_id="$CHATID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=html" \
        -d text="$1"
}

# Function for telegram file upload
tg_post_build() {
    MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)
    curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
        -F chat_id="$CHATID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$2 | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"
}

# Function to clone repositories
clone() {
    git clone --depth=1 https://github.com/RainySorcerer/AnyKernel3.git
    git clone --depth=1 https://github.com/kdrag0n/proton-clang.git clang

    # Set environment for clang
    TC_DIR=$KERNEL_DIR/clang
    KBUILD_COMPILER_STRING=$("$TC_DIR/bin/clang" --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
    export PATH=$TC_DIR/bin/:$PATH
    export KBUILD_COMPILER_STRING
}

# Function to set zip file naming
set_naming() {
    KERNEL_NAME="Tempest-PL2-personal-$DATE"
    export ZIP_NAME="$KERNEL_NAME.zip"
}

# Function to start compilation
compile() {
    echo -e "Kernel compilation starting"
    tg_post_msg "<b>Docker OS: </b><code>$DISTRO</code>%0A<b>Kernel Version: </b><code>$KERVER</code>%0A<b>Date: </b><code>$(date +"%A %d %B %Y %I:%M:%S %p %Z")</code>%0A<b>Device: </b><code>$DEVICE</code>%0A<b>Pipeline Host: </b><code>$KBUILD_BUILD_HOST</code>%0A<b>Host Core Count: </b><code>$PROCS</code>%0A<b>Compiler Used: </b><code>$KBUILD_COMPILER_STRING</code>%0A<b>Branch: </b><code>$BRANCH</code>%0A<b>Last Commit: </b><code>$COMMIT_HEAD</code>%0A<b>Status: </b>#Personal"
    
    make O=out "$DEFCONFIG"
    BUILD_START=$(date +"%s")

    make -j"$PROCS" O=out \
        CROSS_COMPILE=aarch64-linux-gnu- \
        CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
        CC=clang \
        AR=llvm-ar \
        NM=llvm-nm \
        LD=ld.lld \
        OBJDUMP=llvm-objdump \
        STRIP=llvm-strip

    BUILD_END=$(date +"%s")
    DIFF=$((BUILD_END - BUILD_START))

    if [ -f "$IMG_DIR/Image.gz-dtb" ]; then
        echo -e "Kernel successfully compiled"
    else
        echo -e "Kernel compilation failed"
        tg_post_msg "<b>Build failed to compile after $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds</b>"
        exit 1
    fi
}

# Function to create flashable zip
gen_zip() {
    mv "$IMG_DIR/Image.gz-dtb" AnyKernel3/Image.gz-dtb
    cd AnyKernel3 || exit

    zip -r9 "$ZIP_NAME" * -x .git README.md *.zip
    ZIP_FINAL="$ZIP_NAME"

    tg_post_build "$ZIP_FINAL" "Build took: $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds"
    cd ..
}

# Main execution
clone
set_naming
compile
gen_zip

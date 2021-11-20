#!/usr/bin/env bash
#
# Copyright (C) 2021 a xyzprjkt property
#

# Needed Secret Variable
# KERNEL_NAME | Your kernel name
# KERNEL_SOURCE | Your kernel link source
# KERNEL_BRANCH  | Your needed kernel branch if needed with -b. eg -b eleven_eas
# DEVICE_CODENAME | Your device codename
# DEVICE_DEFCONFIG | Your device defconfig eg. lavender_defconfig
# ANYKERNEL | Your Anykernel link repository
# TG_TOKEN | Your telegram bot token
# TG_CHAT_ID | Your telegram private ci chat id
# BUILD_USER | Your username
# BUILD_HOST | Your hostname

echo "Downloading few Dependecies . . ."
# Kernel Sources
cd ~
git clone --depth=1 $KERNEL_SOURCE $KERNEL_BRANCH $DEVICE_CODENAME
cd $DEVICE_CODENAME
mkdir out
mkdir $(pwd)/$DEVICE_CODENAME/out/clang-llvm
mkdir $(pwd)/$DEVICE_CODENAME/out/gcc64-aosp
mkdir $(pwd)/$DEVICE_CODENAME/out/gcc32-aosp
  wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/clang-r433403b.tar.gz -O "clang-r433403b.tar.gz"
  tar -xf clang-r433403b.tar.gz -C $(pwd)/$DEVICE_CODENAME/out/clang-llvm
  wget -q https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/refs/tags/android-11.0.0_r48.tar.gz -O "android-11.0.0_r48.tar.gz"
  tar -xf android-11.0.0_r48.tar.gz -C $(pwd)/$DEVICE_CODENAME/out/gcc64-aosp
  wget http://android.googlesource.com/platform/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/+archive/refs/tags/android-11.0.0_r48.tar.gz -O "android.tar.gz"
  tar -xf android.tar.gz -C $(pwd)/$DEVICE_CODENAME/out/gcc32-aosp

# Main Declaration
DEVICE_DEFCONFIG=$DEVICE_DEFCONFIG
export TZ="Asia/Jakarta"
KERNEL_ROOTDIR=$(pwd)/$DEVICE_CODENAME
export ZIPNAME="KucingKernel"
IMAGE=$(pwd)/$DEVICE_CODENAME/out/arch/arm64/boot/Image.gz-dtb
export DATE=$(date "+%m%d")
export BRANCH="$(git rev-parse --abbrev-ref HEAD)"
export PATH="$(pwd)/$DEVICE_CODENAME/out/clang-llvm/bin:$(pwd)/$DEVICE_CODENAME/out/gcc64-aosp/bin:$(pwd)/$DEVICE_CODENAME/out/gcc32-aosp/bin:${PATH}"
export KBUILD_COMPILER_STRING="$($(pwd)/$DEVICE_CODENAME/out/clang-llvm/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g')"
export KBUILD_BUILD_HOST=$(uname -a | awk '{print $2}')
export ARCH=arm64
export KBUILD_BUILD_USER=kucingabu
export HASH_HEAD=$(git rev-parse --short HEAD)
export COMMIT_HEAD=$(git log --oneline -1)
export PROCS=$(nproc --all)
export DISTRO=$(cat /etc/issue)
export KERVER=$(make kernelversion)

# Checking environtment
# Warning !! Dont Change anything there without known reason.
function check() {
echo ================================================
echo xKernelCompiler
echo version : rev1.5 - gaspoll
echo ================================================
echo BUILDER NAME = ${KBUILD_BUILD_USER}
echo BUILDER HOSTNAME = ${KBUILD_BUILD_HOST}
echo DEVICE_DEFCONFIG = ${DEVICE_DEFCONFIG}
echo TOOLCHAIN_VERSION = ${KBUILD_COMPILER_STRING}
echo CLANG_ROOTDIR = ${CLANG_ROOTDIR}
echo KERNEL_ROOTDIR = ${KERNEL_ROOTDIR}
echo ================================================
}

# Telegram
export BOT_MSG_URL="https://api.telegram.org/bot$TG_TOKEN/sendMessage"

tg_post_msg() {
  curl -s -X POST "$BOT_MSG_URL" -d chat_id="$TG_CHAT_ID" \
  -d "disable_web_page_preview=true" \
  -d "parse_mode=html" \
  -d text="$1"

}

# Post Main Information
tg_post_msg "<b>xKernelCompiler</b>%0ABuilder Name : <code>${KBUILD_BUILD_USER}</code>%0ABuilder Host : <code>${KBUILD_BUILD_HOST}</code>%0ADevice Defconfig: <code>${DEVICE_DEFCONFIG}</code>%0AClang Version : <code>${KBUILD_COMPILER_STRING}</code>%0AClang Rootdir : <code>${CLANG_ROOTDIR}</code>%0AKernel Rootdir : <code>${KERNEL_ROOTDIR}</code>"

# Compile
compile(){
tg_post_msg "<b>xKernelCompiler:</b><code>Compilation has started</code>"
cd ${KERNEL_ROOTDIR}
make -j$(nproc) O=out ARCH=arm64 ${DEVICE_DEFCONFIG}
make -j$(nproc) ARCH=arm64 O=out \
                  CC=clang \
                  CLANG_TRIPLE=aarch64-linux-gnu- \
                  CROSS_COMPILE=aarch64-linux-android- \
                  CROSS_COMPILE_ARM32=arm-linux-androideabi- \
                  LD=ld.lld \
                  NM=llvm-nm \
                  OBJCOPY=llvm-objcopy

   if ! [ -a "$IMAGE" ]; then
	finerr
	exit 1
   fi

  git clone --depth=1 $ANYKERNEL AnyKernel
	cp $IMAGE AnyKernel
}

# Push kernel to channel
function push() {
    cd AnyKernel
    ZIP=$(echo *.zip)
    curl -F document=@$ZIP "https://api.telegram.org/bot$TG_TOKEN/sendDocument" \
        -F chat_id="$TG_CHAT_ID" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="Compile took $(($DIFF / 60)) minute(s) and $(($DIFF % 60)) second(s). | For <b>$DEVICE_CODENAME</b> | <b>${KBUILD_COMPILER_STRING}</b>"
}
# Fin Error
function finerr() {
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d "disable_web_page_preview=true" \
        -d "parse_mode=markdown" \
        -d text="Build throw an error(s)"
    exit 1
}

# Zipping
function zipping() {
    cd AnyKernel || exit 1
    zip -r9 $KERNEL_NAME-$DEVICE_CODENAME-${DATE}.zip *
    cd ..
}
check
compile
zipping
END=$(date +"%s")
DIFF=$(($END - $START))
push

#!/usr/bin/env bash

THIS=$0
THIS_DIR=$(dirname $(readlink -f $0))
STAMP_DIR=${THIS_DIR}/.stamp
BUILD_DIR=${THIS_DIR}/build
BUILD_DIR_GUEST=${THIS_DIR}/build-guest
LOCAL_CONF=${BUILD_DIR}/conf/local.conf
BBLAYERS_CONF=${BUILD_DIR}/conf/bblayers.conf
LOCAL_CONF_GUEST=${BUILD_DIR_GUEST}/conf/local.conf
BBLAYERS_CONF_GUEST=${BUILD_DIR_GUEST}/conf/bblayers.conf
MACHINE="raspberrypi4-64"
MACHINE_GUEST="qemuarm64"
DL_DIR="/workdir/downloads"
SSTATE_DIR="/workdir/sstate-cache"

[ -d $STAMP_DIR ] || mkdir -p $STAMP_DIR

# utility
RED="\e[31m"
YELLOW="\e[33m"
GREEN="\e[32m"
BLUE="\e[34m"
END="\e[m"

err()     { echo -e "$RED""[ERROR] "$@"$END"; }
warn()    { echo -e "$YELLOW""[WARN] "$@"$END"; }
success() { echo -e "$GREEN""[SUCCESS] "$@"$END"; }
errexit() { err $@; exit 1; }
cmd() {
    echo -e "$BLUE""[EXEC] "$@"$END"
    eval $@
    case $? in
        0 )
      success "[EXEC] $@"
      ;;
  2 )
      warn "[EXEC] $@"
      ;;
        * )
      errexit "[EXEC] $@"
      ;;
    esac
}

# stamp functions
stamp() {
    local task=$1
    touch $STAMP_DIR/$task.stamp
    success "task \"$task\" is done"
}
stamp_check_else() {
    local task=$1
    shift
    local command=$@
    [ -n "$command" ] || local command=$task
    if [ -f $STAMP_DIR/$task.stamp ]; then
        success "task \"$task\" is already done. skip."
    else
        $command
    fi
}
stamp_clean() {
    local task=$1
    if [ -f $STAMP_DIR/$task.stamp ]; then
        rm $STAMP_DIR/$task.stamp
    else
        warn "$task.stamp is missing. start the task $task"
    fi
}

# Tasks
fetch() {
    #TODO: use repo
    stamp_clean fetch
    cd $THIS_DIR
    REPOS=(
        "git://git.yoctoproject.org/poky -b dunfell --depth 1"
        "git://git.openembedded.org/meta-openembedded -b dunfell --depth 1"
        "https://github.com/agherzan/meta-raspberrypi.git -b dunfell --depth 1"
        "https://github.com/KZYSAKYM/meta-rpi-qemuarm64.git -b main --depth 1"
    )
    for repo in "${REPOS[@]}"; do
        local stamp_name=$(basename `echo $repo | awk '{print $1}'`)-fetch
        subtask() {
            cmd "git clone $repo"
            stamp $stamp_name
        }
        stamp_check_else $stamp_name subtask
    done
    stamp fetch
}

configure() {
    POKY=$THIS_DIR/poky
    [ -d $POKY ] || errexit "Not Found $POKY"

    stamp_clean configure
    cd $THIS_DIR
    cmd "source $POKY/oe-init-build-env $BUILD_DIR"
    LAYERS=(
        "$THIS_DIR/meta-openembedded/meta-oe"
        "$THIS_DIR/meta-openembedded/meta-python"
        "$THIS_DIR/meta-openembedded/meta-multimedia"
        "$THIS_DIR/meta-openembedded/meta-networking"
        "$THIS_DIR/meta-raspberrypi"
        "$THIS_DIR/meta-rpi-qemuarm64"
    )
    for layer in "${LAYERS[@]}"; do
        local stamp_name=$(basename $layer)-layer-add
        subtask() {
            echo "BBLAYERS += \"$layer\"" >> $BBLAYERS_CONF
            stamp $stamp_name
        }
        stamp_check_else $stamp_name subtask
    done
    append_local_conf() {
        echo "MACHINE = \"$MACHINE\"" >> $LOCAL_CONF
        echo "DL_DIR = \"$DL_DIR\"" >> $LOCAL_CONF
        echo "SSTATE_DIR = \"$SSTATE_DIR\"" >> $LOCAL_CONF
        stamp append_local_conf
    }
    stamp_check_else append_local_conf
    stamp configure
}

configure_guest() {
    POKY=$THIS_DIR/poky
    [ -d $POKY ] || errexit "Not Found $POKY"

    stamp_clean configure_guest
    cd $THIS_DIR
    cmd "source $POKY/oe-init-build-env $BUILD_DIR_GUEST"
    LAYERS=(
        "$THIS_DIR/meta-openembedded/meta-oe"
        "$THIS_DIR/meta-openembedded/meta-python"
        "$THIS_DIR/meta-openembedded/meta-multimedia"
        "$THIS_DIR/meta-openembedded/meta-networking"
        "$THIS_DIR/meta-rpi-qemuarm64"
    )
    for layer in "${LAYERS[@]}"; do
        local stamp_name=$(basename $layer)-layer-add-guest
        subtask() {
            echo "BBLAYERS += \"$layer\"" >> $BBLAYERS_CONF_GUEST
            stamp $stamp_name
        }
        stamp_check_else $stamp_name subtask
    done
    append_local_conf_guest() {
        echo "MACHINE = \"$MACHINE_GUEST\"" >> $LOCAL_CONF_GUEST
        echo "DL_DIR = \"$DL_DIR\"" >> $LOCAL_CONF_GUEST
        echo "SSTATE_DIR = \"$SSTATE_DIR\"" >> $LOCAL_CONF_GUEST
        stamp append_local_conf_guest
    }
    stamp_check_else append_local_conf_guest
    stamp configure
}

build() {
    POKY=$THIS_DIR/poky
    [ -d $POKY ] || errexit "Not Found $POKY"

    stamp_clean build
    cd $THIS_DIR
    cmd "source $POKY/oe-init-build-env $BUILD_DIR"
    cmd "bitbake rpi-qemuarm64-host-image"
    success "build rpi-qemuarm64-host-image"
    stamp build
}

build_guest() {
    POKY=$THIS_DIR/poky
    [ -d $POKY ] || errexit "Not Found $POKY"

    stamp_clean build_guest
    cd $THIS_DIR
    cmd "source $POKY/oe-init-build-env $BUILD_DIR_GUEST"
    cmd "bitbake rpi-qemuarm64-guest-image"
    success "build rpi-qemuarm64-guest-image"
    stamp build_guest
}

# Workflow
stamp_check_else fetch
stamp_check_else configure
build
stamp_check_else configure_guest
build_guest

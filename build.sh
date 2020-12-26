#!/usr/bin/env bash

THIS=$0
THIS_DIR=$(dirname $(readlink -f $0))
STAMP_DIR=${THIS_DIR}/.stamp
BUILD_DIR=${THIS_DIR}/build
LOCAL_CONF=${BUILD_DIR}/conf/local.conf
BBLAYERS_CONF=${BUILD_DIR}/conf/bblayers.conf
MACHINE="raspberrypi4-64"
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
        echo "IMAGE_INSTALL_append = \" qemu weston\"" >> $LOCAL_CONF
        echo "VIDEO_CAMERA = \"1\"" >> $LOCAL_CONF
        echo "RASPBERRYPI_CAMERA_V2 = \"1\"" >> $LOCAL_CONF
        echo "ENABLE_I2C = \"1\"" >> $LOCAL_CONF
        stamp append_local_conf
    }
    stamp_check_else append_local_conf
    stamp configure
}

build() {
    POKY=$THIS_DIR/poky
    [ -d $POKY ] || errexit "Not Found $POKY"

    stamp_clean build
    cd $THIS_DIR
    cmd "source $POKY/oe-init-build-env $BUILD_DIR"
    cmd "bitbake rpi-test-image"
    success "build rpi-test-image"
    stamp build
}

# Workflow
stamp_check_else fetch
stamp_check_else configure
build

#!/bin/bash
set -e

function download() {
    os="$(uname)"
    case $os in
	Linux)
	    url="pypy-c-jit-latest-linux.tar.bz2"
	    cmd="tar xjf"
	    ;;
	Darwin)
	    url="pypy-c-jit-latest-osx64.tar.bz2"
	    cmd="tar xjf"
	    ;;
	CYGWIN*)
	    url="pypy-c-jit-latest-win32.zip"
	    cmd="unzip"
	    ;;
	*)
	    echo "Unsupported platform"
	    exit 1
    esac

    pushd ~/bin/
    curl -L -O "http://buildbot.pypy.org/nightly/trunk/$url"
    $cmd $url
    rm $url
    rsync -a pypy-c-jit*/* ~/bin/pypy/
    rm -rf pypy-c-jit*
    curl -L -O https://bootstrap.pypa.io/get-pip.py
    ~/bin/pypy/bin/pypy get-pip.py
    rm -f get-pip.py
    popd
}


if [ $# -eq 1 ]; then
    if [ "$1" == "download" ]; then
	download
	exit 0
    fi
fi

if [ ! -x ~/bin/pypy/bin/pypy ]; then
    download
fi

~/bin/pypy/bin/pypy $@

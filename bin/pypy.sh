#!/bin/bash

function download() {
    os="$(uname)"
    case $os in
	Linux)
	    url="pypy-c-jit-latest-linux64.tar.bz2"
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
    curl -O "http://buildbot.pypy.org/nightly/trunk/$url" || exit 1
    $cmd $url
    rm $url
    rsync -a pypy-c-jit* ~/bin/pypy/
    rm -rf pypy-c-jit*
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

#!/bin/bash

dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
installdir=/usr/local/bin

# basically run it like this
# ./builder clean
# ./builder init release
# ./builder build release 6

# clean any previous builkd output
# ./builder clean

# initialize the build (install deps, run cmake etc)
# ./builder init <release>
# where <release> is either 'debug' or 'release'

# build nerva
# ./builder build <release> <threads>
# where <release> is either 'debug' or 'release'
# Where <threads> is the number of threads to use with make

function checkdistro()
{
	if [[ -z "${NERVA_BUILD_DISTRO}" ]]; then
		if [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then

			local os_distro="unknown"
			local os_ver="unknown"

			if [ -f /etc/os-release ]; then
				source /etc/os-release
				os_distro=$ID
				os_ver=$VERSION_ID
			elif [ -f /etc/lsb-release ]; then
				source /etc/lsb-release
				os_distro=$DISTRIB_ID
				os_ver=$DISTRIB_RELEASE
			fi

			export NERVA_BUILD_DISTRO=${os_distro}
			export NERVA_BUILD_DISTRO_VERSION=${os_ver}

			echo Distro detected as ${NERVA_BUILD_DISTRO}
		fi
	else
		echo Distro manually defined as ${NERVA_BUILD_DISTRO}
	fi
}

function install()
{
	sudo cp ${dir}/build/release/bin/nerva* ${installdir}
}

function uninstall()
{
	sudo rm ${installdir}/nerva*
}

function clean()
{
	cd ${dir}
	rm -rf ${dir}/build
	find -name CMakeCache.txt | xargs rm
	find -name CMakeFiles | xargs rm -rf
	find -name *.a | xargs rm
	find -name *.o | xargs rm
	find -name *.so | xargs rm
}

function docker_build()
{
	make -j4
	zip -rj ${dir}/nerva-$1_$2.zip ${dir}/build/release/bin/*
	clean
}

function docker_build_dynamic_linux()
{
	checkdistro
	mkdir -p ${dir}/build/release
	cd ${dir}/build/release

	cmake -D CMAKE_BUILD_TYPE=release -D BUILD_SHARED_LIBS=OFF -D BUILD_TESTS=OFF \
	-D BUILD_TAG=${NERVA_BUILD_DISTRO}-${NERVA_BUILD_DISTRO_VERSION} ../..

	docker_build $1 ${NERVA_BUILD_DISTRO}-${NERVA_BUILD_DISTRO_VERSION}
}

function docker_build_static_linux()
{
	mkdir -p ${dir}/build/release
	cd ${dir}/build/release

	cmake -D BUILD_TESTS=OFF -D STATIC=ON -D BUILD_64=ON -D ARCH="x86-64" -D CMAKE_BUILD_TYPE=release \
	-D BUILD_TAG=$2 -D BUILD_SHARED_LIBS=OFF -D INSTALL_VENDORED_LIBUNBOUND=ON ../..

	docker_build $1 $2
}

function init()
{
	checkdistro

	if [ $NERVA_BUILD_DISTRO == "ubuntu" ] || [ $NERVA_BUILD_DISTRO == "debian" ]; then
		sudo apt install -y \
		git build-essential cmake pkg-config libboost-all-dev libssl-dev libzmq3-dev libunbound-dev libsodium-dev \
		libminiupnpc-dev libunwind8-dev liblzma-dev libreadline6-dev libldns-dev libexpat1-dev libgtest-dev doxygen graphviz
	elif [ $NERVA_BUILD_DISTRO == "fedora" ]; then
		sudo dnf install -y \
		git make automake cmake gcc-c++ boost-devel miniupnpc-devel graphviz \
    	doxygen unbound-devel libunwind-devel pkgconfig cppzmq-devel openssl-devel libcurl-devel --setopt=install_weak_deps=False
	else
		echo "Cannot install dependencies on your system. This distro is not officially supported"	
		exit 1
	fi

	mkdir -p ${dir}/build/$1

	cd ${dir}/build/$1
	cmake -D CMAKE_BUILD_TYPE=$1 -D BUILD_SHARED_LIBS=OFF -D BUILD_TESTS=OFF \
	-D BUILD_TAG=dev-$1 ../..
}

function build()
{
	cd ${dir}/build/$1
	make -j $2
}

$1 $2 $3

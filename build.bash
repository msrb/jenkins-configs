#!/bin/bash -ex

resultdir="/var/lib/mock/javapackages-rawhide/result/"

# download custom mock config
curl https://raw.githubusercontent.com/msrb/jenkins-configs/javapackages-tools/fedora-rawhide-x86_64.cfg > fedora-rawhide-x86_64.cfg
touch -d '01 Jan 2000' fedora-rawhide-x86_64.cfg

# download custom mock config
curl https://raw.githubusercontent.com/msrb/jenkins-configs/javapackages-tools/javapackages-tools.spec > javapackages-tools.spec

# create directories
repo=RPM/latest/
[[ ! -d ${repo} ]] && mkdir -p ${repo}

# update version and release tag in spec file
version=`sed 's/-SNAPSHOT//' VERSION`
release=$(git describe --match="[^(jenkins)].*" --tags | sed 's/[^-]*-/0./;s/-/./;s/g/git/')
sed -i "s/^Version:\s\+[0-9.]*$/Version: ${version}/" javapackages-tools.spec
sed -i "s/^Release:\s\+[0-9.]*%{?dist}$/Release: ${release}/" javapackages-tools.spec

# make tarball
git archive -v --prefix=javapackages-${version}/ HEAD | xz > javapackages-${version}.tar.xz

# print root.log and build.log in case of failure
trap "cat ${resultdir}/root.log | tail -30; cat ${resultdir}/build.log || :" 0

# crate srpm
rm -f SRPMS/*
rpmbuild -bs --clean --define "_topdir `pwd`" --define "_sourcedir `pwd`" javapackages-tools.spec

# build RPM with custom mock config
rm -Rf ${resultdir}/*
mock -r ../..$PWD/fedora-rawhide-x86_64 SRPMS/*.src.rpm

# remove unneeded stuff
rm -f javapackages-*.tar.xz

last_bn=`grep "Build number" ${repo}/info.log | awk '{ print $3 }'`
if [ -n "${last_bn}" ]; then
    mkdir -p RPM/${last_bn}
    mv ${repo}/* RPM/${last_bn}

    # we only want keep RPMs from last 10 builds
    blist=`find ./RPM/ -maxdepth 1 -name "[0-9]*"`
    for bn in $blist; do
        if [ `basename $bn` -lt `expr $last_bn - 10` ]; then
            rm -Rf $bn
        fi
    done
fi

# copy resulting RPMs to RPM/latest
cp ${resultdir}/* ${repo}

tail -n 50 ${resultdir}/build.log

createrepo ${repo}

# store current build number into the file
echo "Build number: $BUILD_NUMBER" >> ${repo}/info.log


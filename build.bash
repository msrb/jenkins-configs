#!/bin/bash -ex

JSTART=`date`

RPMDIR="/var/lib/mock/fedora-rawhide-x86_64/result"

VERSION=$(sed -n '/<version>/{s/.*>\(.*\)<.*/\1/;s/-SNAPSHOT$//;p;q}' pom.xml)
RELEASE=$(git describe --match="[^(jenkins)].*" --tags | sed 's/[^-]*-/0./;s/-/./;s/g/git/')
git archive -v --prefix=xmvn-${VERSION}/ HEAD | xz > xmvn-${VERSION}.tar.xz
sed -i "s/^Version:\s\+[0-9.]*$/Version: ${VERSION}/" xmvn.spec
sed -i "s/^Release:\s\+[0-9.]*%{?dist}$/Release: ${RELEASE}/" xmvn.spec

rm -f SRPMS/*
rpmbuild -bs --clean --define "_topdir `pwd`" --define "_sourcedir `pwd`" xmvn.spec

trap "cat ${RPMDIR}/build.log || :" 0
rm -rf ${RPMDIR}
mock -r fedora-rawhide-x86_64 SRPMS/*.src.rpm

LAST_BN=`grep "Build number" RPM/latest/info.log | awk '{ print $3 }'`
mkdir -p RPM/${LAST_BN}
mv RPM/latest/* RPM/${LAST_BN}
echo $LAST_BN

# we only want keep RPMs from last 10 builds
REMOVE_BN=`expr $LAST_BN - 10`
rm -Rf RPM/${REMOVE_BN}

# copy resulting RPMs to RPM/latest
rm -Rf RPM/latest
cp -a ${RPMDIR} RPM/latest

createrepo RPM/latest/

rm -f xmvn-*.tar.xz

JEND=`date`

echo "Job start: $JSTART" > RPM/latest/info.log
echo "Job end: $JEND" >> RPM/latest/info.log
echo "Build number: $BUILD_NUMBER" >> RPM/latest/info.log


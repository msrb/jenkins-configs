#!/bin/bash -ex

JSTART=`date`

REPO=RPM/latest/
RPMDIR="/var/lib/mock/fedora-rawhide-x86_64/result"

if [ ! -d ${REPO} ]; then
  mkdir -p ${REPO} 
fi

curl https://raw.githubusercontent.com/msrb/jenkins-configs/javapackages-tools/fedora-rawhide-x86_64.cfg > fedora-rawhide-x86_64.cfg

touch -d '01 Jan 2000' fedora-rawhide-x86_64.cfg

rm -f javapackages-tools.spec default.spec && curl https://raw.githubusercontent.com/msrb/jenkins-configs/javapackages-tools/javapackages-tools.spec > default.spec

cp default.spec javapackages-tools.spec

VERSION=`sed 's/-SNAPSHOT//' VERSION`
RELEASE=$(git describe --match="[^(jenkins)].*" --tags | sed 's/[^-]*-/0./;s/-/./;s/g/git/')
git archive -v --prefix=javapackages-${VERSION}/ HEAD | xz > javapackages-${VERSION}.tar.xz
sed -i "s/^Version:\s\+[0-9.]*$/Version: ${VERSION}/" javapackages-tools.spec
sed -i "s/^Release:\s\+[0-9.]*%{?dist}$/Release: ${RELEASE}/" javapackages-tools.spec

rm -f SRPMS/*
rpmbuild -bs --clean --define "_topdir `pwd`" --define "_sourcedir `pwd`" javapackages-tools.spec

#trap "cat ${RPMDIR}/root.log | tail -30; cat ${RPMDIR}/build.log || :" 0

mock -r ../..$PWD/fedora-rawhide-x86_64 SRPMS/*.src.rpm


LAST_BN=`grep "Build number" ${REPO}/info.log | awk '{ print $3 }'`
if [ -n "${LAST_BN}" ]; then
  mkdir -p RPM/${LAST_BN}
  mv ${REPO}/* RPM/${LAST_BN}

  # we only want keep RPMs from last 10 builds
  REMOVE_BN=`expr $LAST_BN - 10`
  rm -Rf RPM/${REMOVE_BN}
fi

# copy resulting RPMs to RPM/latest
RESULT="/var/lib/mock/javapackages-rawhide/result/"
for pkg in `ls -1 ${RESULT}/ | grep ".noarch.rpm"`; do
  cp ${RESULT}/$pkg ${REPO}/${pkg}
done
tail -n 50 ${RESULT}/build.log
rm -Rf ${RESULT}/*

createrepo ${REPO}

rm -f javapackages-*.tar.xz

JEND=`date`

echo "Job start: $JSTART" > ${REPO}/info.log
echo "Job end: $JEND" >> ${REPO}/info.log
echo "Build number: $BUILD_NUMBER" >> ${REPO}/info.log

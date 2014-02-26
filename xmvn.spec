Name:           xmvn
Version:        1.4.0
Release:        1%{?dist}
Summary:        Local Extensions for Apache Maven
License:        ASL 2.0
URL:            http://mizdebsk.fedorapeople.org/xmvn
BuildArch:      noarch
Source0:        %{name}-%{version}.tar.xz

BuildRequires:  maven >= 3.2.1-3
BuildRequires:  maven-local
BuildRequires:  beust-jcommander
BuildRequires:  cglib
BuildRequires:  maven-dependency-plugin
BuildRequires:  maven-plugin-build-helper
BuildRequires:  maven-assembly-plugin
BuildRequires:  maven-invoker-plugin
BuildRequires:  xmlunit
BuildRequires:  apache-ivy
BuildRequires:  sisu-mojos
BuildRequires:  junit

Requires:       maven >= 3.2.1-3

%description
This package provides extensions for Apache Maven that can be used to
manage system artifact repository and use it to resolve Maven
artifacts in offline mode, as well as Maven plugins to help with
creating RPM packages containing Maven artifacts.

%package        javadoc
Summary:        API documentation for %{name}

%description    javadoc
This package provides %{summary}.

%prep
%setup -q

# In XMvn 1.x xmvn-connector was renamed to xmvn-connector-aether
%mvn_alias :xmvn-connector-aether :xmvn-connector

# remove dependency plugin maven-binaries execution
# we provide apache-maven by symlink
%pom_xpath_remove "pom:executions/pom:execution[pom:id[text()='maven-binaries']]"

# get mavenVersion that is expected
mver=$(sed -n '/<mavenVersion>/{s/.*>\(.*\)<.*/\1/;p}' \
           xmvn-parent/pom.xml)
mkdir -p target/dependency/
ln -s %{_datadir}/maven target/dependency/apache-maven-$mver

# skip ITs for now (mix of old & new XMvn config causes issues
rm -rf src/it

# probably bug in configuration/modello?
sed -i 's|generated-site/resources/xsd/config|generated-site/xsd/config|' xmvn-core/pom.xml

%build
%mvn_build -X

tar --delay-directory-restore -xvf target/*tar.bz2
chmod -R +rwX %{name}-%{version}*


%install
%mvn_install

install -d -m 755 %{buildroot}%{_datadir}/%{name}
cp -r %{name}-%{version}*/* %{buildroot}%{_datadir}/%{name}/
ln -sf %{_datadir}/maven/bin/mvn %{buildroot}%{_datadir}/%{name}/bin/mvn
ln -sf %{_datadir}/maven/bin/mvnDebug %{buildroot}%{_datadir}/%{name}/bin/mvnDebug
ln -sf %{_datadir}/maven/bin/mvnyjp %{buildroot}%{_datadir}/%{name}/bin/mvnyjp


# helper scripts
install -d -m 755 %{buildroot}%{_bindir}
install -m 755 xmvn-tools/src/main/bin/tool-script \
               %{buildroot}%{_datadir}/%{name}/bin/

for tool in subst resolve bisect install;do
    rm %{buildroot}%{_datadir}/%{name}/bin/%{name}-$tool
    ln -s tool-script \
          %{buildroot}%{_datadir}/%{name}/bin/%{name}-$tool

    cat <<EOF >%{buildroot}%{_bindir}/%{name}-$tool
#!/bin/sh -e
exec %{_datadir}/%{name}/bin/%{name}-$tool "\${@}"
EOF
    chmod +x %{buildroot}%{_bindir}/%{name}-$tool

done

# copy over maven lib directory
cp -r %{_datadir}/maven/lib/* %{buildroot}%{_datadir}/%{name}/lib/

# possibly recreate symlinks that can be automated with xmvn-subst
%{name}-subst %{buildroot}%{_datadir}/%{name}/
#for jar in core connector;do
for jar in core connector-aether connector-ivy; do
    ln -sf %{_javadir}/%{name}/%{name}-$jar.jar %{buildroot}%{_datadir}/%{name}/lib
done

for tool in subst resolver bisect installer;do
    # sisu doesn't contain pom.properties. Manually replace with symlinks
    pushd %{buildroot}%{_datadir}/%{name}/lib/$tool
        rm org.eclipse.sisu*jar sisu-guice*jar
        build-jar-repository . org.eclipse.sisu.inject \
                               org.eclipse.sisu.plexus \
                               guice/google-guice-no_aop
    popd
done

# workaround for rhbz#1012982
rm %{buildroot}%{_datadir}/%{name}/lib/google-guice-no_aop.jar
build-jar-repository %{buildroot}%{_datadir}/%{name}/lib/ \
                     guice/google-guice-no_aop

if [[ `find %{buildroot}%{_datadir}/%{name}/lib -type f -name '*.jar' -not -name '*%{name}*' | wc -l` -ne 0 ]];then
    echo "Some jar files were not symlinked during build. Aborting"
    exit 1
fi


# /usr/bin/xmvn script
cat <<EOF >%{buildroot}%{_bindir}/%{name}
#!/bin/sh -e
export M2_HOME="\${M2_HOME:-%{_datadir}/%{name}}"
exec mvn "\${@}"
EOF

# make sure our conf is identical to maven so yum won't freak out
cp -P %{_datadir}/maven/conf/settings.xml %{buildroot}%{_datadir}/%{name}/conf/

%pretrans -p <lua>
-- we changed symlink to dir in 0.5.0-1, workaround RPM issues
for key, dir in pairs({"conf", "conf/logging", "boot"}) do
    path = "%{_datadir}/%{name}/" .. dir
    if posix.readlink(path) then
       os.remove(path)
    end
end

%files -f .mfiles
%dir %{_javadir}/%{name}
%doc LICENSE NOTICE
%doc AUTHORS README
%attr(755,-,-) %{_bindir}/*
%{_datadir}/%{name}

%files javadoc -f .mfiles-javadoc
%doc LICENSE NOTICE

%changelog
* Fri Feb 21 2014 Michal Srb <msrb@redhat.com> - 1.4.0-1
- Spec for Jenkins builds

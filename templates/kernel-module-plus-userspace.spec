%{!?kernel_mod_path: %define kernel_mod_path /lib/modules}
%if %{!?kernel_version:1}0
    %{expand: %%define kernel_version %( set -x ; KVER_CNT=`ls -1d %{kernel_mod_path}/???* 2>/dev/null | wc -l` ; if test "x$KVER_CNT" != "x" ; then if test $KVER_CNT -eq 1 ; then KVER=`basename %{kernel_mod_path}/???*` ; elif test -d %{kernel_mod_path}/`uname -r` ; then KVER=`uname -r` ; else KVER=`basename $(ls -1d %{kernel_mod_path}/???* 2>/dev/null | sort -r | head -1)` ; fi ; fi ; if test "x$KVER" = "x" ; then echo "NONE" ; else echo $KVER ; fi )}
%endif
%if %{!?kernel_source:1}0
    %{expand: %%define kernel_source %( set -x ; for DIR in %{kernel_mod_path}/%{kernel_version}/build /usr/src/{%{kernel_version},linux-2.6,linux}; do if test -d $DIR ; then KSRC="$DIR" ; break ; fi ; done ; if test "x$KSRC" = "x" ; then echo "NONE" ; else echo $KSRC ; fi )}
%endif
%{expand: %%define kernel_module_release_string %(echo "%{kernel_version}" | sed 's/-/./g')}

Summary: @SUMMARY@
Name: @NAME@
Version: @VERSION@
Release: @RELEASE@
License: @LICENSE@
Group: System Environment/Kernel
Source: @TARBALL_URL@
Packager: @PACKAGER@
Vendor: @VENDOR@
Distribution: @DISTRIBUTION@
Prefix: %{_prefix}
BuildRoot: /var/tmp/%{name}-%{version}-%{release}-root

%description
@DESCRIPTION@

%package kmod
Summary: @SUMMARY@
Release: @RELEASE@
License: @LICENSE@
Group: System Environment/Kernel
Requires: %{kernel_mod_path}/%{kernel_version}

%description kmod
@DESCRIPTION@

This package contains the %{name} kernel module for the
%{kernel_version} Linux kernel.

%prep
%setup -q @SETUP@

%build
%{__make} %{?mflags}

%install
%{__makeinstall} %{?mflags_install} MODDIR=$RPM_BUILD_ROOT/lib/modules/%{kernel_version}

%post kmod
/sbin/depmod -aq

%postun kmod
/sbin/depmod -aq

%clean
test "x$RPM_BUILD_ROOT" != "x/" && rm -rf $RPM_BUILD_ROOT

%files
%defattr(-, root, root)
%doc @DOCFILES@
@INSTFILES@

%files kmod
%defattr(0744, root, root)
/lib/modules/*/kernel/*

%changelog
@CHANGELOG@

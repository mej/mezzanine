%if %{!?kernel_version:1}0
%define kernel_version %( KVER=`uname -r` ; if test -d /lib/modules/$KVER ; then echo $KVER ; else KVER_CNT=`ls -1d /lib/modules/???* 2>/dev/null | wc -l` ; if test "x$KVER_CNT" != "x" -a $KVER_CNT -eq 1 ; then echo `basename /lib/modules/???*` ; else KVER=`ls -1d /lib/modules/???* 2>/dev/null | sort -r | head -1` ; fi ; fi ; if test "x$KVER" = "x" ; then echo "NONE" ; fi )
%endif

%define kernel_module_release_string %(echo "%{kernel_version}" | sed 's/-/./g')

Summary: @SUMMARY@
Name: @NAME@
Version: @VERSION@
Release: @RELEASE@
License: @LICENSE@
Group: System Environment/Kernel
Source: @TARBALL@
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
Requires: kernel = %{kernel_version}

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

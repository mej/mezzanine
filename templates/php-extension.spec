Summary: @SUMMARY@
Name: @NAME@
Version: @VERSION@
Release: @RELEASE@
License: @LICENSE@
Group: @GROUP@
Source: @TARBALL_URL@
Packager: @PACKAGER@
Vendor: @VENDOR@
Distribution: @DISTRIBUTION@
Prefix: %{_prefix}
BuildRoot: /var/tmp/%{name}-%{version}-%{release}-root

%description
@DESCRIPTION@

%prep
%setup -q @SETUP@

%build
CFLAGS="@CFLAGS@"
CXXFLAGS="@CXXFLAGS@"
export CFLAGS CXXFLAGS

phpize
%configure %{?acflags}
%{__make} %{?mflags}

%install
%{__make} install INSTALL_ROOT=$RPM_BUILD_ROOT %{?mflags_install}

%{__mkdir_p} $RPM_BUILD_ROOT%{_sysconfdir}/php.d
%{__cat} > $RPM_BUILD_ROOT%{_sysconfdir}/php.d/%{name}.ini <<EOF
; Enable %{name} extension module
extension=%{name}.so
EOF

%clean
test "x$RPM_BUILD_ROOT" != "x/" && rm -rf $RPM_BUILD_ROOT

%files
%defattr(-, root, root)
%doc @DOCFILES@
%config(noreplace) %{_sysconfdir}/php.d/%{name}.ini
%{_libdir}/php/modules/%{name}.so

%changelog
@CHANGELOG@

Summary: @SUMMARY@
Name: @NAME@
Version: @VERSION@
Release: @RELEASE@
Copyright: @LICENSE@
Group: @GROUP@
Source: @TARBALL@
Packager: @PACKAGER@
Vendor: @VENDOR@
Distribution: @DISTRIBUTION@
Prefix: %{_prefix}
BuildRoot: /var/tmp/%{name}-%{version}-%{release}-root

%description
@DESCRIPTION@

%prep
%setup -q -n @SRCDIR@

%build
CFLAGS="@CFLAGS@"
CXXFLAGS="@CXXFLAGS@"
export CFLAGS CXXFLAGS

%configure %{?acflags}
%{__make} %{?mflags}

%install
%{__make} install DESTDIR=$RPM_BUILD_ROOT %{?mflags_install}

%clean
test "x$RPM_BUILD_ROOT" != "x" && rm -rf $RPM_BUILD_ROOT

%files
%defattr(-, root, root)
%doc @DOCFILES@
@INSTFILES@

%changelog
@CHANGELOG@

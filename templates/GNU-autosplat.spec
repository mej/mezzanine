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
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
@DESCRIPTION@

%prep
%setup -q @SETUP@

%build
CFLAGS="@CFLAGS@"
CXXFLAGS="@CXXFLAGS@"
export CFLAGS CXXFLAGS

%configure %{?acflags}
%{__make} %{?mflags}

%install
%{__make} install DESTDIR=$RPM_BUILD_ROOT %{?mflags_install}

%clean
test "x$RPM_BUILD_ROOT" != "x/" && rm -rf $RPM_BUILD_ROOT

%files
%defattr(-, root, root)
%doc @DOCFILES@
@INSTFILES@

%changelog
@CHANGELOG@

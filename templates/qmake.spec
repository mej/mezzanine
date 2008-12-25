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
BuildRequires: qt-devel
Prefix: %{_prefix}
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
@DESCRIPTION@

%prep
%setup -q @SETUP@
qmake -o Makefile Makefile.pro

%build
%{__make} CFLAGS="@CFLAGS@" CXXFLAGS="@CXXFLAGS@" %{?mflags}

%install
%{makeinstall} %{?mflags_install}

%clean
test "x$RPM_BUILD_ROOT" != "x" && rm -rf $RPM_BUILD_ROOT

%files
%defattr(-, root, root)
%doc @DOCFILES@
@INSTFILES@

%changelog
@CHANGELOG@

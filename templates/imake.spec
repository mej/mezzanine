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
BuildRequires: imake
Prefix: %{_prefix}
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
@DESCRIPTION@

%prep
%setup -q @SETUP@

%build
xmkmf -a
make Makefiles || :
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

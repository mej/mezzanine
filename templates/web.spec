%{!?webroot: %define webroot /srv/www}

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
Prefix: %{webroot}
BuildArch: noarch
BuildRoot: /var/tmp/%{name}-%{version}-%{release}-root

%description
@DESCRIPTION@

%prep
%setup -q @SETUP@

%install
cd ..
%{__mkdir_p} $RPM_BUILD_ROOT%{webroot}/
%{__cp} -a %{name}* $RPM_BUILD_ROOT%{webroot}/%{name}
#(
#    cd $RPM_BUILD_ROOT%{webroot}/%{name}
#    find . -type d -print | xargs chmod 0550
#    find . \! -type d -print | xargs chmod 0440
#)

%clean
test "x$RPM_BUILD_ROOT" != "x" && rm -rf $RPM_BUILD_ROOT

%files
%defattr(0440, apache, apache, 0550)
%doc @DOCFILES@
@INSTFILES@

%changelog
@CHANGELOG@

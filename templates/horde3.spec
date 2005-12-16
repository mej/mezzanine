%{!?webroot: %define webroot /srv/www}

Summary: @SUMMARY@
Name: @NAME@
Version: @VERSION@
Release: @RELEASE@
License: @LICENSE@
Group: @GROUP@
URL: http://www.horde.org/
Source: @TARBALL_URL@
Packager: @PACKAGER@
Vendor: @VENDOR@
Distribution: @DISTRIBUTION@
Requires: horde >= 3
Prefix: %{webroot}
BuildArch: noarch
BuildRoot: /var/tmp/%{name}-%{version}-%{release}-root

%description
@DESCRIPTION@

%prep
%setup -q -n %{name}-h3-%{version} @SETUP@

%install
cd ..
%{__mkdir_p} $RPM_BUILD_ROOT%{webroot}/
%{__cp} -a %{name}-h3-%{version} $RPM_BUILD_ROOT%{webroot}/%{name}
(
    cd $RPM_BUILD_ROOT%{webroot}/%{name}
#    find . -type d -print | xargs chmod 0550
#    find . \! -type d -print | xargs chmod 0440
    %{__rm} -rf COPYING README docs
    for i in config/*.dist ; do
        %{__mv} -f "$i" "`echo $i | sed 's/\.dist$//'`"
    done
)

%clean
test "x$RPM_BUILD_ROOT" != "x/" && rm -rf $RPM_BUILD_ROOT

%files
%defattr(0440, apache, apache, 0550)
%doc @DOCFILES@
%dir %{webroot}/%{name}/config
%config(noreplace) %{webroot}/%{name}/config/.htaccess
%config(noreplace) %{webroot}/%{name}/config/*.php
%config(noreplace) %{webroot}/%{name}/config/*.xml
%{webroot}/%{name}/lib
%{webroot}/%{name}/locale
%{webroot}/%{name}/po
%{webroot}/%{name}/scripts
%{webroot}/%{name}/templates
%{webroot}/%{name}/themes
%{webroot}/%{name}/*.php

%changelog
@CHANGELOG@

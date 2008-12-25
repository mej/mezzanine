%{!?webroot: %define webroot /srv/www}

Summary: @SUMMARY@
Name: @NAME@
Version: @VERSION@
Release: @RELEASE@
License: @LICENSE@
Group: Applications/Internet
URL: http://www.horde.org/
Source: ftp://ftp.horde.org/pub/%{name}/%{name}-h3-%{version}.tar.gz
Packager: @PACKAGER@
Vendor: @VENDOR@
Distribution: @DISTRIBUTION@
Requires: horde >= 3
BuildArch: noarch
Prefix: %{webroot}
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

%description
@DESCRIPTION@

%prep
%setup -q -n %{name}-h3-%{version} @SETUP@
%{__perl} -pi -e 's,/usr/local/bin/php,/usr/bin/php,g' `%{__grep} -F -r -l /usr/local/bin/php .`

%install
cd ..
%{__mkdir_p} $RPM_BUILD_ROOT%{webroot}/horde $RPM_BUILD_ROOT%{_sysconfdir}/httpd/conf.d
%{__cp} -a %{name}-h3-%{version} $RPM_BUILD_ROOT%{webroot}/horde/%{name}
(
    cd $RPM_BUILD_ROOT%{webroot}/horde/%{name}
#    find . -type d -print | xargs chmod 0550
#    find . \! -type d -print | xargs chmod 0440
    %{__rm} -rf COPYING LICENSE README docs
    for i in config/*.dist ; do
        %{__mv} -f "$i" "`echo $i | sed 's/\.dist$//'`"
    done
)

# Create Apache config
%{__cat} > $RPM_BUILD_ROOT%{_sysconfdir}/httpd/conf.d/%{name}.conf <<EOF
# Configuration for %{name}

<Directory "%{webroot}/horde/%{name}">
    <Files "test*.php">
        order deny,allow
        deny from all
    </Files>
</Directory>
EOF
for DIR in config lib locale po scripts templates ; do
    echo "
<Directory \"%{webroot}/horde/%{name}/$DIR\">
    order deny,allow
    deny from all
</Directory>" >> $RPM_BUILD_ROOT%{_sysconfdir}/httpd/conf.d/%{name}.conf
done
%{__chmod} 0600 $RPM_BUILD_ROOT%{_sysconfdir}/httpd/conf.d/%{name}.conf

# Create backup config too.
touch $RPM_BUILD_ROOT%{webroot}/horde/%{name}/config/conf.php
%{__cp} -a $RPM_BUILD_ROOT%{webroot}/horde/%{name}/config/conf.php{,.bak}

%clean
test "x$RPM_BUILD_ROOT" != "x" && rm -rf $RPM_BUILD_ROOT

%files
%defattr(0440, apache, apache, 0550)
%doc @DOCFILES@
%dir %{webroot}/horde/%{name}/config
%config(noreplace) %{webroot}/horde/%{name}/config/.htaccess
%attr(0660, apache, apache) %config(noreplace) %{webroot}/horde/%{name}/config/conf.php
%attr(0660, apache, apache) %config(noreplace) %{webroot}/horde/%{name}/config/conf.php.bak
%config(noreplace) %{webroot}/horde/%{name}/config/conf.xml
%config(noreplace) %{webroot}/horde/%{name}/config/[abd-z]*.php
%config(noreplace) %{_sysconfdir}/httpd/conf.d/%{name}.conf
%{webroot}/horde/%{name}/js
%{webroot}/horde/%{name}/lib
%{webroot}/horde/%{name}/locale
%{webroot}/horde/%{name}/po
%{webroot}/horde/%{name}/scripts
%{webroot}/horde/%{name}/templates
%{webroot}/horde/%{name}/themes
%{webroot}/horde/%{name}/*.php
 
%changelog
@CHANGELOG@

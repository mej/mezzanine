Summary: @SUMMARY@
Name: @NAME@
Version: @VERSION@
Release: @RELEASE@
License: @LICENSE@
Group: @GROUP@
Source: @TARBALL@
Packager: @PACKAGER@
Vendor: @VENDOR@
Distribution: @DISTRIBUTION@
Prefix: %{_prefix}
BuildArch: noarch
BuildRoot: /var/tmp/%{name}-%{version}-%{release}-root

%description
@DESCRIPTION@

%install
test "x$RPM_BUILD_ROOT" != "x" && rm -rf $RPM_BUILD_ROOT
%{__mkdir_p} $RPM_BUILD_ROOT%{_libexecdir}/%{name} $RPM_BUILD_ROOT%{_bindir}
%{__install} -m 644 %{SOURCE0} $RPM_BUILD_ROOT%{_libexecdir}/%{name}/
%{__cat} > $RPM_BUILD_ROOT%{_bindir}/%{name} << EOF
#!/bin/sh
#
# Run program %{name} from jar file.
#

exec java -jar %{_libexecdir}/%{name}/`basename %{SOURCE0}`
EOF
%{__chmod} 0755 $RPM_BUILD_ROOT%{_bindir}/%{name}

%clean
test "x$RPM_BUILD_ROOT" != "x" && rm -rf $RPM_BUILD_ROOT

%files
%defattr(-, root, root)
@INSTFILES@

%changelog
@CHANGELOG@

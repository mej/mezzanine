%define name     avalon
%define ver      0.1
%define rel      1
%define prefix   /usr

Summary: Avalon -- The VA Software Engineering Build System
Name: %name
Version: %ver
Release: %rel
Copyright: BSD with Advertising Clause
Group: Development/Tools
Source0: buildtool
Source1: revtool
Source2: safetool
Source3: pkgtool
Source101: README
Source102: ChangeLog
BuildRoot: /tmp/%{name}-%{ver}-root
Packager: Michael Jennings <mej@valinux.com>
Vendor: VA Linux Systems (http://www.valinux.com/)
Docdir: %{prefix}/doc
URL: http://www.valinux.com/
Requires: 

%description

%changelog

%install
rm -rf $RPM_BUILD_ROOT

for i in %{SOURCE0} %{SOURCE1} %{SOURCE2} %{SOURCE3} ; do
  install -m 755 $RPM_SOURCE_DIR/$i $RPM_BUILD_ROOT%{prefix}/bin/
done

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-, root, root)
%doc README
%doc %config(missingok) ChangeLog
%{prefix}/bin/*

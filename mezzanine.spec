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
Source: %{name}.tar.gz
BuildRoot: /tmp/%{name}-%{ver}-root
Packager: Michael Jennings <mej@valinux.com>
Vendor: VA Linux Systems (http://www.valinux.com/)
Docdir: %{prefix}/doc
URL: http://www.valinux.com/
Requires: perl

%description

%changelog

%prep
%setup -n %{name} -c -a 0

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{prefix}/bin

for i in *tool ; do
  install -m 755 $i $RPM_BUILD_ROOT%{prefix}/bin/
done

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-, root, root)
%doc README ChangeLog
%{prefix}/bin/*

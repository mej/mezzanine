%define name     avalon
%define ver      1.2
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
%setup -n %{name} -T -c -a 0

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{prefix}/bin
mkdir -p $RPM_BUILD_ROOT%{prefix}/man/man1

for i in *tool ; do
  install -m 755 $i $RPM_BUILD_ROOT%{prefix}/bin/
done

for i in *.1 ; do
  install -m 644 $i $RPM_BUILD_ROOT%{prefix}/man/man1/
done

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-, root, root)
%doc README ChangeLog
%{prefix}/bin/*
%{prefix}/man/*

%define name     avalon
%define ver      2.0
%define rel      0.3
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
Avalon is a collection of tools, written primarily in Perl, which
automate and simplify many of the tasks associated with maintaining,
building, and releasing software products.

%changelog

%prep
%setup -n %{name} -T -c -a 0

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{prefix}/bin
mkdir -p $RPM_BUILD_ROOT%{prefix}/lib/perl5/5.6.0/Avalon
mkdir -p $RPM_BUILD_ROOT%{prefix}/man/man1

for i in *tool pkgsort ; do
  install -m 755 $i $RPM_BUILD_ROOT%{prefix}/bin/
done

for i in mod/*.pm ; do
  install -m 644 $i $RPM_BUILD_ROOT%{prefix}/lib/perl5/5.6.0/Avalon/
done

(
  cd $RPM_BUILD_ROOT%{prefix}/bin
  for i in get co put ci info add new rm purge rtag tag reset login ; do
    ln revtool av$i
  done
  for i in import prep mod merge ; do
    ln srctool av$i
  done
  for i in rpm pkg ; do
    ln pkgtool av$i
  done
  ln buildtool avbuild
)

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

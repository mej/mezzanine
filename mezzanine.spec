Summary: Avalon -- The VA Software Engineering Build System
Name: avalon
Version: 2.0
Release: 9.1
Copyright: BSD with Advertising Clause
Group: Development/Tools
Source: %{name}.tar.gz
BuildRoot: /tmp/%{name}-%{version}-root
Packager: Michael Jennings <mej@valinux.com>
Vendor: VA Linux Systems (http://www.valinux.com/)
URL: http://www.valinux.com/
Requires: perl, perl-libnet

%description
Avalon is a collection of tools, written primarily in Perl, which
automate and simplify many of the tasks associated with maintaining,
building, and releasing software products.

%changelog

%prep
%setup -n %{name} -T -c -a 0

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{_bindir}
mkdir -p $RPM_BUILD_ROOT%{_libdir}/perl5/site_perl/5.6.0/Avalon
mkdir -p $RPM_BUILD_ROOT%{_libdir}/perl5/site_perl/5.005/Avalon
mkdir -p $RPM_BUILD_ROOT%{_mandir}/man1

for i in *tool pkgsort ; do
  install -m 755 $i $RPM_BUILD_ROOT%{_bindir}/
done

for i in mod/*.pm ; do
  install -m 644 $i $RPM_BUILD_ROOT%{_libdir}/perl5/site_perl/5.6.0/Avalon/
  install -m 644 $i $RPM_BUILD_ROOT%{_libdir}/perl5/site_perl/5.005/Avalon/
done

for i in doc/man/*.1 ; do
  install -m 644 $i $RPM_BUILD_ROOT%{_mandir}/man1/
done

(
  cd $RPM_BUILD_ROOT%{_bindir}
  for i in get co put ci info add new rm purge rtag tag reset login diff stat status log ; do
    ln -s revtool av$i
    echo ".so revtool.1" > $RPM_BUILD_ROOT%{_mandir}/man1/av$i.1
  done
  for i in import prep mod merge patch clean ; do
    ln -s srctool av$i
    echo ".so srctool.1" > $RPM_BUILD_ROOT%{_mandir}/man1/av$i.1
  done
  for i in rpm pkg ; do
    ln -s pkgtool av$i
    echo ".so pkgtool.1" > $RPM_BUILD_ROOT%{_mandir}/man1/av$i.1
  done
  ln -s buildtool avbuild
  echo ".so buildtool.1" > $RPM_BUILD_ROOT%{_mandir}/man1/av$i.1
)

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-, root, root)
%doc README ChangeLog doc/*.txt doc/Makefile.avalon.sample
%{_bindir}/*
%{_libdir}/*
%{_mandir}/*

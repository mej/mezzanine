Summary: Mezzanine -- A Software Product Management System
Name: mezzanine
Version: 0.1
Release: 0.2
Copyright: BSD with Advertising Clause
Group: Development/Tools
Source: %{name}.tar.gz
BuildRoot: /tmp/%{name}-%{version}-root
Packager: Michael Jennings <mej@kainx.org>
Vendor: KainX.Org (http://www.kainx.org/)
URL: http://www.kainx.org/mezzanine/
Requires: perl, perl-libnet

%description
Mezzanine is a collection of tools, written primarily in Perl, which
automate and simplify many of the tasks associated with maintaining,
building, and releasing software products.

%changelog

%prep
%setup -n %{name} -T -c -a 0

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{_bindir}
mkdir -p $RPM_BUILD_ROOT%{_libdir}/perl5/site_perl/5.6.0/Mezzanine
mkdir -p $RPM_BUILD_ROOT%{_libdir}/perl5/site_perl/5.005/Mezzanine
mkdir -p $RPM_BUILD_ROOT%{_mandir}/man1

for i in *tool pkgsort ; do
  install -m 755 $i $RPM_BUILD_ROOT%{_bindir}/
done

for i in mod/*.pm ; do
  install -m 644 $i $RPM_BUILD_ROOT%{_libdir}/perl5/site_perl/5.6.0/Mezzanine/
  install -m 644 $i $RPM_BUILD_ROOT%{_libdir}/perl5/site_perl/5.005/Mezzanine/
done

for i in doc/man/*.1 ; do
  install -m 644 $i $RPM_BUILD_ROOT%{_mandir}/man1/
done

(
  cd $RPM_BUILD_ROOT%{_bindir}
  for i in get co put ci info add new rm purge rtag tag reset login diff stat status log ; do
    ln -s revtool mz$i
    echo ".so revtool.1" > $RPM_BUILD_ROOT%{_mandir}/man1/mz$i.1
  done
  for i in import prep mod merge patch clean ; do
    ln -s srctool mz$i
    echo ".so srctool.1" > $RPM_BUILD_ROOT%{_mandir}/man1/mz$i.1
  done
  for i in rpm pkg build inst ; do
    ln -s pkgtool mz$i
    echo ".so pkgtool.1" > $RPM_BUILD_ROOT%{_mandir}/man1/mz$i.1
  done
  for i in prod pbuild prodbuild ; do
    ln -s buildtool mz$i
    echo ".so buildtool.1" > $RPM_BUILD_ROOT%{_mandir}/man1/mz$i.1
  done
)

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-, root, root)
%{_bindir}/*
%{_libdir}/*
%{_mandir}/*

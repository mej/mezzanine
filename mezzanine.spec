Summary: Mezzanine -- A Software Product Management System
Name: mezzanine
Version: 1.8
Release: 0.5
Copyright: BSD
Group: Development/Tools
Source: %{name}.tar.gz
BuildRoot: /tmp/%{name}-%{version}-root
Packager: Michael Jennings <mezzanine@kainx.org>
Vendor: KainX.Org (http://www.kainx.org/)
URL: http://www.kainx.org/mezzanine/
Requires: perl, perl(Net::FTP), perl(Cwd), perl(POSIX), perl(File::Copy), perl(Getopt::Long), perl(File::Find)
#BuildSuggests: docbook-style-dsssl
BuildArch: noarch

%description
Mezzanine is a collection of tools, written primarily in Perl, which
automate and simplify many of the tasks associated with maintaining,
building, and releasing software products.

%changelog

%prep
%setup -n %{name} -T -c -a 0

%build
(
    cd doc
for i in *.sgml ; do
      FNAME=${i%%%%.sgml}
      jade -t sgml -i html -d mezzanine.dsl \
        -D /usr/share/sgml/docbook/dsssl-stylesheets \
        -V "%%stylesheet%%=${FNAME}.css" \
        -V "%%root-filename%%=${FNAME}" \
        -V nochunks -V rootchunk \
        $i
    done
) || :

%install
%define perl_vendorlib %(eval "`perl -V:installvendorlib`"; echo $installvendorlib)
%if "%{perl_vendorlib}" == "UNKNOWN"
%define perl_vendorlib %(eval "`perl -V:installsitelib`"; echo $installsitelib)
%endif

rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{_bindir}
mkdir -p $RPM_BUILD_ROOT%{perl_vendorlib}/Mezzanine/templates
mkdir -p $RPM_BUILD_ROOT%{_mandir}/man1

for i in *tool pkgsort perlpkg specgen ; do
  install -m 755 $i $RPM_BUILD_ROOT%{_bindir}/
done

for i in templates/* ; do
  install -m 644 $i $RPM_BUILD_ROOT%{perl_vendorlib}/Mezzanine/templates/
done

(cd mod ; tar -cf - *.pm */*.pm) | (cd $RPM_BUILD_ROOT%{perl_vendorlib}/Mezzanine ; tar -xf -)

for i in doc/man/*.1 ; do
  install -m 644 $i $RPM_BUILD_ROOT%{_mandir}/man1/
done

(
  cd $RPM_BUILD_ROOT%{_bindir}
  for i in get co put ci info add new rm purge rtag tag reset login ann annotate blame diff stat status log ; do
    ln -s revtool mz$i
    echo ".so revtool.1" > $RPM_BUILD_ROOT%{_mandir}/man1/mz$i.1
  done
  for i in import prep merge patch clean sync mv ; do
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
%doc doc/*ml
%{_bindir}/*
%{perl_vendorlib}/*
%{_mandir}/*

Summary: Mezzanine -- A Software Product Management System
Name: mezzanine
Version: 1.6
Release: 0.12
Copyright: BSD
Group: Development/Tools
Source: %{name}.tar.gz
BuildRoot: /tmp/%{name}-%{version}-root
Packager: Michael Jennings <mej@kainx.org>
Vendor: KainX.Org (http://www.kainx.org/)
URL: http://www.kainx.org/mezzanine/
Requires: perl, perl(Net::FTP), perl(Cwd), perl(POSIX), perl(File::Copy), perl(Getopt::Long)
BuildArch: noarch

%description
Mezzanine is a collection of tools, written primarily in Perl, which
automate and simplify many of the tasks associated with maintaining,
building, and releasing software products.

%changelog

%prep
%setup -n %{name} -T -c -a 0

%build
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

%install
PERL_DIR=`perl -V | perl -ne 'if (/\@INC/) {$inc = 1;}
                                  elsif ($inc && m!/site_perl/?$! && m!^\s*/usr/lib(.*)$!)
                                    {print "$1\n";}'`
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{_bindir}
mkdir -p $RPM_BUILD_ROOT%{_libdir}${PERL_DIR}/Mezzanine $RPM_BUILD_ROOT%{_libdir}/perl5/Mezzanine
mkdir -p $RPM_BUILD_ROOT%{_mandir}/man1

for i in *tool pkgsort ; do
  install -m 755 $i $RPM_BUILD_ROOT%{_bindir}/
done

for i in mod/*.pm ; do
  install -m 644 $i $RPM_BUILD_ROOT%{_libdir}${PERL_DIR}/Mezzanine/
done
ln -s %{_libdir}${PERL_DIR}/Mezzanine $RPM_BUILD_ROOT%{_libdir}/perl5/Mezzanine

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
%doc doc/*.html doc/*.sgml
%{_bindir}/*
%{_libdir}/*
%{_mandir}/*

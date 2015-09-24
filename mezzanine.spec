%define perl_vendorlib %(eval "`perl -V:installvendorlib 2>/dev/null`"; echo $installvendorlib)
%if "%{perl_vendorlib}" == "UNKNOWN"
%define perl_vendorlib %(eval "`perl -V:installsitelib 2>/dev/null`"; echo $installsitelib)
%endif

%define debug_package %{nil}

Summary: Mezzanine -- A Software Product Management System
Name: mezzanine
Version: 1.9
Release: 0.30
License: BSD
Group: Development/Tools
URL: http://www.kainx.org/mezzanine/
Source: http://www.kainx.org/mezzanine/%{name}.tar.gz
Packager: %{?_packager:%{_packager}}%{!?_packager:Michael Jennings <mezzanine@kainx.org>}
Vendor: %{?_vendorinfo:%{_vendorinfo}}%{!?_vendorinfo:KainX.Org (http://www.kainx.org/)}
Distribution: %{?_distribution:%{_distribution}}%{!?_distribution:%{_vendor}}
#BuildSuggests: docbook-style-dsssl openjade
Requires: perl, perl(Net::FTP), perl(Cwd), perl(POSIX), perl(File::Copy), perl(Getopt::Long), perl(File::Find)
BuildRoot: %{?_tmppath}%{!?_tmppath:/tmp}/%{name}-%{version}-root

%description
Mezzanine is a collection of tools, written primarily in Perl, which
automate and simplify many of the tasks associated with maintaining,
building, and releasing software products.

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

[ -f %{_includedir}/rpm/rpmlegacy.h ] && CPPFLAGS="$CPPFLAGS -DHAVE_RPM_RPMLEGACY_H"
${CC:-%{__cc}} $CPPFLAGS ${CFLAGS:-$RPM_OPT_FLAGS} -I%{_includedir}/rpm -o rpmeval rpmeval.c $LDFLAGS -lrpm -lrpmio -lpopt $LIBS || :
${CC:-%{__cc}} $CPPFLAGS ${CFLAGS:-$RPM_OPT_FLAGS} -I%{_includedir}/rpm -o rpmcmp rpmcmp.c $LDFLAGS -lrpm -lrpmio -lpopt $LIBS

%install
test "x$RPM_BUILD_ROOT" != "x" && %{__rm} -rf $RPM_BUILD_ROOT
%{__mkdir_p} $RPM_BUILD_ROOT%{_bindir}
%{__mkdir_p} $RPM_BUILD_ROOT%{perl_vendorlib}/Mezzanine/templates
%{__mkdir_p} $RPM_BUILD_ROOT%{_mandir}/man1

for i in abiscan autobuilder *tool pkgsort perlpkg specgen ; do
    %{__install} -m 755 $i $RPM_BUILD_ROOT%{_bindir}/
done

for i in templates/* ; do
    %{__install} -m 644 $i $RPM_BUILD_ROOT%{perl_vendorlib}/Mezzanine/templates/
done

(cd mod ; %{__tar} -cf - *.pm */*.pm) | (cd $RPM_BUILD_ROOT%{perl_vendorlib}/Mezzanine ; %{__tar} -xf -)

for i in doc/man/*.1 ; do
    %{__install} -m 644 $i $RPM_BUILD_ROOT%{_mandir}/man1/
done

(
    cd $RPM_BUILD_ROOT%{_bindir}
    for i in abi abiscan ; do
        %{__ln_s} abiscan mz$i
    done
    for i in builder autobuild autobuilder ; do
        %{__ln_s} autobuilder mz$i
    done
    for i in get co put ci info add new rm purge rtag tag reset login ann annotate blame diff stat status log init ; do
        %{__ln_s} revtool mz$i
        echo ".so revtool.1" > $RPM_BUILD_ROOT%{_mandir}/man1/mz$i.1
    done
    for i in import prep merge patch clean sync mv ; do
        %{__ln_s} srctool mz$i
        echo ".so srctool.1" > $RPM_BUILD_ROOT%{_mandir}/man1/mz$i.1
    done
    for i in rpm pkg build inst ; do
        %{__ln_s} pkgtool mz$i
        echo ".so pkgtool.1" > $RPM_BUILD_ROOT%{_mandir}/man1/mz$i.1
    done
    for i in prod pbuild prodbuild ; do
        %{__ln_s} buildtool mz$i
        echo ".so buildtool.1" > $RPM_BUILD_ROOT%{_mandir}/man1/mz$i.1
    done
    for i in repo repo{scan,closure,compare,comp,cmp,diff,add,rm,remove} ; do
        %{__ln_s} pkgrepotool mz$i
    done
)

test -f rpmeval && %{__install} -m 0755 rpmeval $RPM_BUILD_ROOT%{_bindir}/
test -f rpmcmp && %{__install} -m 0755 rpmcmp $RPM_BUILD_ROOT%{_bindir}/

%clean
test "x$RPM_BUILD_ROOT" != "x" && %{__rm} -rf $RPM_BUILD_ROOT

%files
%defattr(-, root, root)
%doc doc/*ml
%{_bindir}/*
%{perl_vendorlib}/*
%{_mandir}/*

%changelog

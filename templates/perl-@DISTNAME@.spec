Summary: @MODULENAME@ Perl module
Name: @MODULE@
Version: @VERSION@
Release: 1.@VENDORSUFFIX@
Group: Development/Libraries
License: Artistic
URL: http://search.cpan.org/search?mode=module&query=@MODULENAME@
Source: @DISTFILE@
Packager: @PACKAGER@
Vendor: @VENDOR@
Distribution: @DISTRIBUTION@
BuildArch: @BUILDARCH@
BuildRoot: %{_tmppath}/%{name}-%{version}-root

%description
This package contains the @MODULENAME@ Perl module.

%prep
%setup -q -n @DISTNAME@-%{version} 

%build
CFLAGS="$RPM_OPT_FLAGS" %{__perl} Makefile.PL PREFIX=$RPM_BUILD_ROOT%{_prefix} INSTALLDIRS=vendor
%{__make}
%{__make} test || :

%clean
rm -rf $RPM_BUILD_ROOT

%install
rm -rf $RPM_BUILD_ROOT
%{__mkdir_p} $RPM_BUILD_ROOT%{perl_archlib}
%{__make} install

find $RPM_BUILD_ROOT%{_prefix} -type f -print | \
        sed "s@^$RPM_BUILD_ROOT@@g" | \
        perl -pe 's@(%{_mandir}/man.*\.\d+(pm)?)$@$1*@g' | \
        grep -v perllocal.pod | \
        grep -v "\.packlist" > @MODULE@-filelist
find $RPM_BUILD_ROOT%{_prefix} -type f -name .packlist -exec rm -f {} \;
find $RPM_BUILD_ROOT%{_prefix} -type f -name perllocal.pod -exec rm -f {} \;
if [ "$(cat @MODULE@-filelist)X" = "X" ] ; then
    echo "ERROR: EMPTY FILE LIST"
    exit -1
fi

%files -f @MODULE@-filelist
%defattr(-, root, root)

%changelog
@CHANGELOG@

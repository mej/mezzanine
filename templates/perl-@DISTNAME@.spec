Summary: @MODULENAME@ Perl module
Name: @MODULE@
Version: @VERSION@
Release: 1.@VENDORSUFFIX@
Group: Development/Libraries
Packager: @PACKAGER@
Vendor: @VENDOR@
Distribution: @DISTRIBUTION@
URL: http://search.cpan.org/search?mode=module&query=@MODULENAME@
License: Artistic
BuildRoot: %{_tmppath}/%{name}-%{version}-root
Source: @DISTFILE@
BuildArch: @BUILDARCH@

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
        perl -pe 's@(\.\d+pm)$@$1*@g' | \
        grep -v perllocal.pod | \
        grep -v "\.packlist" > @MODULE@-filelist
if [ "$(cat @MODULE@-filelist)X" = "X" ] ; then
    echo "ERROR: EMPTY FILE LIST"
    exit -1
fi

%files -f @MODULE@-filelist
%defattr(-, root, root)

%changelog
@CHANGELOG@

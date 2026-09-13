# E — RPM spec (built in CI on ubuntu-latest with rpm-build).
# The flutter bundle is staged under %{buildroot}/usr/bin/e/.
Name:           e
Version:        %{_version}
Release:        %{_build}%{?dist}
Summary:        E — offline language learning
License:        MIT
URL:            https://example.com/e
Requires:       gtk3
BuildArch:      x86_64

%description
E — offline language learning.
Your language, your lessons, your pace.

%install
mkdir -p %{buildroot}/usr/bin %{buildroot}/usr/share/applications
cp -r %{_sourcedir}/bundle/* %{buildroot}/usr/bin/
cp %{_sourcedir}/e.desktop %{buildroot}/usr/share/applications/e.desktop

%files
/usr/bin/e
/usr/bin/lib/
/usr/bin/data/
/usr/share/applications/e.desktop

%changelog

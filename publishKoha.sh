#!/bin/bash

if [ $# -lt 1 ]; then
    echo "You have to specify version" 1>&2
    exit 1
fi

VERSION=$1
SERVER=192.168.1.113
USER=root

msgcat misc/translator/po/cs-CZ-opac-bootstrap-orig.po misc/translator/po/cs-CZ-opac-bootstrap-kohacz.po > misc/translator/po/cs-CZ-opac-bootstrap.po
msgcat misc/translator/po/cs-CZ-staff-prog-orig.po misc/translator/po/cs-CZ-staff-prog-kohacz.po > misc/translator/po/cs-CZ-staff-prog.po
msgcat misc/translator/po/cs-CZ-pref-orig.po misc/translator/po/cs-CZ-pref-kohacz.po > misc/translator/po/cs-CZ-pref.po

DEB_BUILD_OPTIONS=nocheck ./debian/build-git-snapshot -r ~/debian -v $VERSION -d --noautoversion

echo "Build finished, press any key to upload deb files to repository server..."
read -n 1 -s

scp "../debian/koha-deps_${VERSION}_all.deb" $USER@$SERVER:/root/kohadeb/
scp "../debian/koha-perldeps_${VERSION}_all.deb" $USER@$SERVER:/root/kohadeb/
scp "../debian/koha-common_${VERSION}_all.deb" $USER@$SERVER:/root/kohadeb/

ssh $USER@$SERVER <<ENDSSH
    cd /root/
    aptly repo add kohacz kohadeb/koha-deps_${VERSION}_all.deb
    aptly repo add kohacz kohadeb/koha-perldeps_${VERSION}_all.deb
    aptly repo add kohacz kohadeb/koha-common_${VERSION}_all.deb
    aptly snapshot create $VERSION from repo kohacz
ENDSSH

rm misc/translator/po/cs-CZ-opac-bootstrap.po
rm misc/translator/po/cs-CZ-staff-prog.po
rm misc/translator/po/cs-CZ-pref.po


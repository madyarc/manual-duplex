# Maintainer: madyarc <https://github.com/madyarc>
#
# Builds from this checkout: run `makepkg -si` in the repository root.

pkgname=manual-duplex
pkgver=0.2.1
pkgrel=1
pkgdesc="Manual two-sided printing for CUPS: a cups-pdf virtual printer that prints fronts and holds the backs"
arch=('any')
url="https://github.com/madyarc/manual-duplex"
license=('MIT')
depends=('bash' 'cups' 'cups-pdf' 'qpdf' 'poppler' 'systemd' 'util-linux')
optdepends=('libnotify: notifications with a "Print backs" button')
backup=('etc/cups/cups-pdf-Manual_Duplex.conf')
install=manual-duplex.install
source=()

pkgver() {
  sed -n 's/^VERSION=//p' "$startdir/bin/manual-duplex"
}

check() {
  bash -n "$startdir/bin/manual-duplex"
}

package() {
  make -C "$startdir" DESTDIR="$pkgdir" PREFIX=/usr install
}

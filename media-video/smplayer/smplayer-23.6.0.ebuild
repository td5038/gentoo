# Copyright 2007-2023 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

PLOCALES="am ar_SY ar bg ca cs da de el en_GB en en_US es et eu fa fi fr gl
he_IL hr hu id it ja ka ko ku lt mk ms_MY nl nn_NO pl pt_BR pt ro_RO ru_RU
sk sl_SI sq_AL sr sv th tr uk_UA uz vi_VN zh_CN zh_TW"
PLOCALE_BACKUP="en_US"

inherit plocale qmake-utils toolchain-funcs xdg

DESCRIPTION="Great Qt GUI front-end for mplayer/mpv"
HOMEPAGE="https://www.smplayer.info/"
SRC_URI="https://github.com/smplayer-dev/${PN}/releases/download/v${PV}/${P}.tar.bz2"

LICENSE="GPL-2+ BSD-2"
SLOT="0"
KEYWORDS="~amd64 ~arm ~hppa ~ppc ~ppc64 ~x86 ~amd64-linux"
IUSE="bidi debug"

DEPEND="
	dev-qt/qtcore:5
	dev-qt/qtdbus:5
	dev-qt/qtgui:5=
	dev-qt/qtnetwork:5[ssl]
	dev-qt/qtsingleapplication[X,qt5(+)]
	dev-qt/qtwidgets:5
	dev-qt/qtxml:5
	sys-libs/zlib
	x11-libs/libX11
"
RDEPEND="${DEPEND}
	|| (
		media-video/mpv[libass(+),X]
		media-video/mplayer[bidi?,libass,png,X]
	)
"
BDEPEND="dev-qt/linguist-tools:5"

PATCHES=(
	"${FILESDIR}/${PN}-14.9.0.6966-unbundle-qtsingleapplication.patch" # bug 487544
	"${FILESDIR}/${PN}-17.1.0-advertisement_crap.patch"
	"${FILESDIR}/${PN}-18.2.0-jobserver.patch"
	"${FILESDIR}/${PN}-18.3.0-disable-werror.patch"
)

src_prepare() {
	use bidi || PATCHES+=( "${FILESDIR}"/${PN}-16.4.0-zero-bidi.patch )

	default

	# Upstream Makefile sucks
	sed -i -e "/^PREFIX=/ s:/usr/local:${EPREFIX}/usr:" \
		-e "/^DOC_PATH=/ s:packages/smplayer:${PF}:" \
		-e '/\.\/get_svn_revision\.sh/,+2c\
	cd src && $(DEFS) $(MAKE)' \
		Makefile || die

	# Turn off online update checker, bug #479902
	sed -e 's:DEFINES += UPDATE_CHECKER:#&:' \
		-e 's:DEFINES += CHECK_UPGRADED:#&:' \
		-i src/smplayer.pro || die

	# Turn off intrusive share widget
	sed -e 's:DEFINES += SHARE_WIDGET:#&:' \
		-i src/smplayer.pro || die

	# Turn debug message flooding off
	if ! use debug ; then
		sed -e 's:#\(DEFINES += NO_DEBUG_ON_CONSOLE\):\1:' \
			-i src/smplayer.pro || die
	fi

	# Commented out because it gives false positives
	#plocale_find_changes "${S}"/src/translations ${PN}_ .ts

	# Do not default compress man page
	sed '/gzip -9.*\.1$/d' -i Makefile || die
	sed 's@\.gz$@@' -i smplayer.spec || die
}

src_configure() {
	cd src || die
	eqmake5 QT_MAJOR_VERSION=5
}

gen_translation() {
	local mydir="$(qt5_get_bindir)"

	ebegin "Generating $1 translation"
	"${mydir}"/lrelease ${PN}_${1}.ts
	eend $? || die "failed to generate $1 translation"
}

src_compile() {
	emake CC="$(tc-getCC)"

	cd src/translations || die
	plocale_for_each_locale gen_translation
}

src_install() {
	# remove unneeded copies of the GPL
	rm Copying* docs/*/gpl.html || die
	# don't install empty dirs
	rmdir --ignore-fail-on-non-empty docs/* || die

	default
}

pkg_preinst() {
	xdg_pkg_preinst
}

pkg_postinst() {
	xdg_pkg_postinst

	elog "If you want URL support with media-video/mpv, please install"
	elog "net-misc/yt-dlp."
}

pkg_postrm() {
	xdg_pkg_postrm
}

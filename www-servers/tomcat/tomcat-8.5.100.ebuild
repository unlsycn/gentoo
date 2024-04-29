# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

JAVA_PKG_IUSE="doc source test"

inherit java-pkg-2 java-ant-2 prefix verify-sig

MY_P="apache-${P}-src"

DESCRIPTION="Tomcat Servlet-3.1/JSP-2.3/EL-3.0/WebSocket-1.1/JASPIC-1.1 Container"
HOMEPAGE="https://tomcat.apache.org/"
SRC_URI="mirror://apache/${PN}/tomcat-8/v${PV}/src/${MY_P}.tar.gz
	verify-sig? ( https://downloads.apache.org/tomcat/tomcat-$(ver_cut 1)/v${PV}/src/apache-tomcat-${PV}-src.tar.gz.asc )"
S=${WORKDIR}/${MY_P}

LICENSE="Apache-2.0"
SLOT="8.5"
KEYWORDS="amd64 ~x86 ~amd64-linux ~x86-linux"
IUSE="extra-webapps"

RESTRICT="test" # can we run them on a production system?

ECJ_SLOT="4.15"

# we don't use ~ for el and jsp because the same implementation
# is also present in tomcat 9 and it would be impossible to install
# both tomcat 8.5 and 9 at the same time
COMMON_DEP="dev-java/eclipse-ecj:${ECJ_SLOT}"
RDEPEND="${COMMON_DEP}
	acct-group/tomcat
	acct-user/tomcat
	>=virtual/jre-1.8:*"
DEPEND="${COMMON_DEP}
	app-admin/pwgen
	>=dev-java/ant-1.10.14-r3:0
	>=virtual/jdk-11:*
	doc? (
		dev-java/jax-rpc-api:0
		dev-java/wsdl4j:0
	)
	test? (
		>=dev-java/ant-1.10.14-r3:0[junit]
		dev-java/easymock:3.2
	)"

BDEPEND="verify-sig? ( ~sec-keys/openpgp-keys-apache-tomcat-${PV}:${PV} )"
VERIFY_SIG_OPENPGP_KEY_PATH="/usr/share/openpgp-keys/tomcat-${PV}.apache.org.asc"

PATCHES=(
	"${FILESDIR}/${PN}-8.5.86-build.xml.patch"
	"${FILESDIR}/${PN}-8.5.95-min.java.patch"
)

src_prepare() {
	default

	find -name '*.jar' -type f -delete -print || die

	# For use of catalina.sh in netbeans
	sed -i -e "/^# ----- Execute The Requested Command/ a\
		CLASSPATH=\`java-config --with-dependencies --classpath ${PN}-${SLOT}\`" \
		bin/catalina.sh || die

	java-pkg-2_src_prepare
}

JAVA_ANT_REWRITE_CLASSPATH="true"

EANT_BUILD_TARGET="deploy"
EANT_GENTOO_CLASSPATH="eclipse-ecj-${ECJ_SLOT}"
EANT_TEST_GENTOO_CLASSPATH="easymock-3.2"
EANT_GENTOO_CLASSPATH_EXTRA="${S}/output/classes"
EANT_NEEDS_TOOLS="true"
EANT_EXTRA_ARGS="-Dversion=${PV}-gentoo -Dversion.number=${PV} -Dcompile.debug=false -Dexecute.validate=false"

# revisions of the scripts
IM_REV="-r2"
INIT_REV="-r1"

src_compile() {
	EANT_GENTOO_CLASSPATH_EXTRA+=":$(java-pkg_getjar --build-only ant ant.jar)"
	use doc && EANT_GENTOO_CLASSPATH_EXTRA+=":$(java-pkg_getjars --build-only jax-rpc-api):$(java-pkg_getjars --build-only wsdl4j)"
	LC_ALL=C java-pkg-2_src_compile
}

src_test() {
	java-pkg-2_src_test
}

src_install() {
	local dest="/usr/share/${PN}-${SLOT}"

	java-pkg_jarinto "${dest}"/bin
	java-pkg_dojar output/build/bin/*.jar
	exeinto "${dest}"/bin
	doexe output/build/bin/*.sh

	java-pkg_jarinto "${dest}"/lib
	java-pkg_dojar output/build/lib/*.jar

	dodoc RELEASE-NOTES RUNNING.txt
	use doc && java-pkg_dojavadoc output/dist/webapps/docs/api
	use source && java-pkg_dosrc java/*

	### Webapps ###

	# add missing docBase
	local apps="host-manager manager"
	for app in ${apps}; do
		sed -i -e "s|=\"true\" >|=\"true\" docBase=\"\$\{catalina.home\}/webapps/${app}\" >|" \
			output/build/webapps/${app}/META-INF/context.xml || die
	done

	insinto "${dest}"/webapps
	doins -r output/build/webapps/{host-manager,manager,ROOT}
	use extra-webapps && doins -r output/build/webapps/{docs,examples}

	### Config ###

	# create "logs" directory in $CATALINA_BASE
	# and set correct perms, see #458890
	dodir "${dest}"/logs
	fperms 0750 "${dest}"/logs

	# replace the default pw with a random one, see #92281
	local randpw="$(pwgen -s -B 15 1)"
	sed -i -e "s|SHUTDOWN|${randpw}|" output/build/conf/server.xml || die

	# prepend gentoo.classpath to common.loader, see #453212
	sed -i -e 's/^common\.loader=/\0${gentoo.classpath},/' output/build/conf/catalina.properties || die

	insinto "${dest}"
	doins -r output/build/conf

	### rc ###

	cp "${FILESDIR}"/tomcat{.conf,${INIT_REV}.init,-instance-manager${IM_REV}.bash} "${T}" || die
	eprefixify "${T}"/tomcat{.conf,${INIT_REV}.init,-instance-manager${IM_REV}.bash}
	sed -i -e "s|@SLOT@|${SLOT}|g" "${T}"/tomcat{.conf,${INIT_REV}.init,-instance-manager${IM_REV}.bash} || die

	insinto "${dest}"/gentoo
	doins "${T}"/tomcat.conf
	exeinto "${dest}"/gentoo
	newexe "${T}"/tomcat${INIT_REV}.init tomcat.init
	newexe "${T}"/tomcat-instance-manager${IM_REV}.bash tomcat-instance-manager.bash
}

pkg_postinst() {
	einfo "Ebuilds of Tomcat support running multiple instances. To manage Tomcat instances, run:"
	einfo "  ${EPREFIX}/usr/share/${PN}-${SLOT}/gentoo/tomcat-instance-manager.bash --help"

	einfo "Please read https://wiki.gentoo.org/wiki/Apache_Tomcat"
}

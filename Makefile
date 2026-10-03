PORTNAME=	freebsd-man-ru
DISTVERSION=	1.0
CATEGORIES=	russian docs
MASTER_SITES=	GH
DISTFILES=	${DISTNAME}-${GH_TAGNAME}.tar.gz

MAINTAINER=	freebsd-doc-ru@example.org
COMMENT=	Russian translations of FreeBSD manual pages
WWW=		https://github.com/freebsd-doc-ru/freebsd-man-ru

LICENSE=	BSD2CLAUSE
LICENSE_FILE=	${WRKSRC}/README.md

FLAVORS=	main releng_15_0 releng_15_1
FLAVOR?=	main

main_GH_ACCOUNT=	freebsd-doc-ru
main_GH_PROJECT=	freebsd-man-ru
main_GH_TAGNAME=	ru_main-1

releng_15_0_GH_ACCOUNT=	freebsd-doc-ru
releng_15_0_GH_PROJECT=	freebsd-man-ru
releng_15_0_GH_TAGNAME=	ru_releng/15.0-1

releng_15_1_GH_ACCOUNT=	freebsd-doc-ru
releng_15_1_GH_PROJECT=	freebsd-man-ru
releng_15_1_GH_TAGNAME=	ru_releng/15.1-1

main_PKGNAMESUFFIX=	-main
releng_15_0_PKGNAMESUFFIX=	-releng15_0
releng_15_1_PKGNAMESUFFIX=	-releng15_1

NO_BUILD=	yes
NO_ARCH=	yes

MANPREFIX=	${PREFIX}
MANLANG=	ru
MANCOMPRESSED=	no

do-install:
	${MKDIR} ${STAGEDIR}${MANPREFIX}/man/ru
	(cd ${WRKSRC}/man && \
	    ${COPYTREE_SHARE} . ${STAGEDIR}${MANPREFIX}/man/ru)
	(cd ${STAGEDIR}${MANPREFIX} && \
	    ${FIND} man/ru -type f | ${SORT} >> ${TMPPLIST})

.include <bsd.port.mk>

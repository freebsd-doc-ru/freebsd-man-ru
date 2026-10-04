PORTNAME=	freebsd-man-ru
DISTVERSION=	1.0
CATEGORIES=	russian docs

MAINTAINER=	vladlen@FreeBSD.org
COMMENT=	Russian translations of FreeBSD manual pages
WWW=		https://github.com/freebsd-doc-ru/freebsd-man-ru

LICENSE=	BSD2CLAUSE

FLAVORS=	main releng_15_0 releng_15_1
FLAVOR?=	main

# define suffix for every flavor
main_PKGNAMESUFFIX=		-main
releng_15_0_PKGNAMESUFFIX=	-releng15_0
releng_15_1_PKGNAMESUFFIX=	-releng15_1

USE_GITHUB=	yes
GH_ACCOUNT=	freebsd-doc-ru
GH_PROJECT=	freebsd-man-ru

# GH_TAGNAME assigned conditionally
.if ${FLAVOR:U} == main
GH_TAGNAME=	ru_main-1
.elif ${FLAVOR:U} == releng_15_0
GH_TAGNAME=	ru_releng/15.0-1
.elif ${FLAVOR:U} == releng_15_1
GH_TAGNAME=	ru_releng/15.1-1
.endif

NO_BUILD=	yes
NO_ARCH=	yes

MANPREFIX=	${PREFIX}
MANLANG=	ru.UTF-8
MANCOMPRESSED=	no

do-install:
	${MKDIR} ${STAGEDIR}${MANPREFIX}/man/ru.UTF-8
	(cd ${WRKSRC}/man && \
	    ${COPYTREE_SHARE} . ${STAGEDIR}${MANPREFIX}/man/ru.UTF-8)
	(cd ${STAGEDIR}${MANPREFIX} && \
	    ${FIND} man/ru.UTF-8 -type f | ${SORT} >> ${TMPPLIST})

.include <bsd.port.mk>

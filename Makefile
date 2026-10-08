PORTNAME=	freebsd-man-ru
DISTVERSION=	1.2
CATEGORIES=	russian docs

MAINTAINER=	vladlen@FreeBSD.org
COMMENT=	Russian translations of FreeBSD manual pages
WWW=		https://github.com/freebsd-doc-ru/freebsd-man-ru

LICENSE=	BSD2CLAUSE

FLAVORS=	current 15_0 15_1 15_2 stable15 
FLAVOR?=	current

# define suffix for every flavor
current_PKGNAMESUFFIX=		-current
15_0_PKGNAMESUFFIX=	-15_0
15_1_PKGNAMESUFFIX=	-15_1
15_2_PKGNAMESUFFIX=	-15_2
stable15_PKGNAMESUFFIX=	-stable15

USE_GITHUB=	yes
GH_ACCOUNT=	freebsd-doc-ru
GH_PROJECT=	freebsd-man-ru

# GH_TAGNAME assigned conditionally
.if ${FLAVOR:U} == current
GH_TAGNAME=	ru_main-3
.elif ${FLAVOR:U} == 15_0
GH_TAGNAME=	ru_releng/15.0-3
.elif ${FLAVOR:U} == 15_1
GH_TAGNAME=	ru_releng/15.1-3
.elif ${FLAVOR:U} == 15_2
GH_TAGNAME=	ru_releng/15.2-3
.elif ${FLAVOR:U} == stable15
GH_TAGNAME=	ru_stable/15-3
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

## If you need to set any of these, always set them when calling make.
# Set this if your ports dir is in a different place.
PORTSDIR?=	${.CURDIR}/../freebsd-ports
# Set this if e.g. you want to test against virtualbox-ose instead
PORTDIR?=	virtualbox-ose-additions
# Specify the location of your FreeBSD sources, if needed -- for more
# details see mount_vboxfs/Makefile, where this is actually used:
FREEBSD_SRC?=	${.CURDIR}/../freebsd


# Build invariants.
PORTPATH=	${PORTSDIR}/emulators/${PORTDIR}
MAINPORTPATH=	${PORTSDIR}/emulators/virtualbox-ose
ADDITIONS=	src/VBox/Additions/freebsd
VBOXVFS=	${ADDITIONS}/vboxvfs


# Set up the system.  This configures the ports, installs mount_vboxfs, and
# finally installs the dependencies required to build the port, from packages.
# This is primarily intended to speed up setup.
#
# NB: Most dependencies are for the main port, not the -additions port.
#     Install them anyway since testing will also need to be done on it.
syssetup:
	mkdir -p /var/db/ports/emulators_virtualbox-ose \
		/var/db/ports/emulators_virtualbox-ose-additions
	pwd
	cp -f ${.CURDIR}/main.options \
		/var/db/ports/emulators_virtualbox-ose/options
	cp -f ${.CURDIR}/additions.options \
		/var/db/ports/emulators_virtualbox-ose-additions/options
	pkg install -y \
		dbus \
		expat \
		gcc \
		gsoap \
		gtar \
		iconv \
		icu \
		kBuild \
		libidl \
		pkgconf \
		python \
		qt4-gui \
		qt4-moc \
		qt4-network \
		qt4-opengl \
		qt4-rcc \
		qt4-uic \
		sdl \
		yasm

PORTMAKE=	${MAKE} SRC_BASE=${FREEBSD_SRC} BATCH=1 \
		PATCH_DEBUG=1

# Set up the port directory so we can make changes here and have them be
# reflected in the port.  The port just serves as a scaffolding to do the
# full build, since this repository only has the work in progress code.
#
# Only do this step after syssetup is done.
portsetup:
	cp -f ${.CURDIR}/patch-* ${MAINPORTPATH}/files
	cd ${PORTPATH} && sudo ${PORTMAKE} clean && ${PORTMAKE} patch && \
		cp -R ${.CURDIR}/vboxvfs/ `${MAKE} -V WRKSRC`/${VBOXVFS} && \
		${PORTMAKE} build

# Re-run the port build, if needed.
portbuild:
	cd ${PORTPATH} && \
		rm -f `${MAKE} -V WRKDIR`/.build_done* && \
		${PORTMAKE} build

portinstall:
	cd ${PORTPATH} && rm -f `${MAKE} -V WRKDIR`/.{stage,install}_done* && \
		${PORTMAKE} deinstall install

# (Re-)Generate the cscope database, storing them in the source directory.
# This will include all of the relevant VirtualBox source code and headers.
cscope:
	cd ${PORTPATH} && WRKSRC=`${MAKE} -V WRKSRC` && \
		mkdir -p .cscope && cd .cscope && \
		cscope -bRq -s $$WRKSRC/src -s $$WRKSRC/include && \
		mv cscope.* ${.CURDIR}

# Do the build.  Only do this step after portsetup is done.
build:
	${MAKE} -C ${.CURDIR}/mount_vboxfs clean obj depend all
	cd ${PORTPATH} && \
		WRKSRC=`make -V WRKSRC` && \
		cp -R ${.CURDIR}/vboxvfs/ $$WRKSRC/${VBOXVFS} && \
		cd $$WRKSRC/${VBOXVFS} && kmk BUILD_TYPE=debug

# Load the module from the build.
ADDITIONS_KLDS=	./out/freebsd.amd64/debug/bin/additions
KLDS=	${ADDITIONS_KLDS}/vboxguest.ko \
	${ADDITIONS_KLDS}/vboxvfs.ko

install:
	${MAKE} -C ${.CURDIR}/mount_vboxfs install
	cd `${MAKE} -C ${PORTPATH} -V WRKSRC` && \
		cp ${KLDS} /boot/modules && sync -a && sync -a && sync -a

kldload: install
	kldload vboxvfs

portenv:
	-cd `${MAKE} -C ${PORTPATH} -V WRKSRC` && /bin/sh

testmount:
	/sbin/mount_vboxfs test0 /mnt

# Unload the module, for completeness' sake.
kldunload:
	-kldunload vboxvfs
	-service vboxservice stop
	-service vboxguest stop
	-kldunload vboxguest

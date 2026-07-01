FROM amazonlinux:2023 AS lobuild

ENV LC_CTYPE=C.utf8
ENV LC_ALL=C.utf8
ENV LIBREOFFICE_VERSION=26.2.4.2
ENV SOURCE_URL=https://download.documentfoundation.org/libreoffice/src/26.2.4/libreoffice-${LIBREOFFICE_VERSION}.tar.xz

# Install build dependencies
RUN dnf install -y dnf-plugins-core && \
    dnf install -y \
        autoconf \
        automake \
        bison \
        bzip2 \
        clang \
        expat-devel \
        diffutils \
        flex \
        fontconfig-devel \
        gcc14 \
        gcc14-c++ \
        gperf \
        gcc \
        gcc-c++ \
        gzip \
        harfbuzz-devel \
        meson \
        ninja-build \
        gmp-devel \
        graphite2-devel \
        icu \
        libcurl-devel \
        libffi-devel \
        libICE-devel \
        libicu-devel \
        libjpeg-turbo-devel \
        libpng-devel \
        libSM-devel \
        libthai-devel \
        libX11-devel \
        libXext-devel \
        libXinerama-devel \
        libXrandr-devel \
        libXrender-devel \
        libxslt-devel \
        libXt-devel \
        libXtst-devel \
        liberation-sans-fonts \
        liberation-serif-fonts \
        mesa-libEGL-devel \
        mesa-libGL-devel \
        patch \
        mesa-libGLU-devel \
        mpfr-devel \
        nasm \
        nspr-devel \
        nss-devel \
        openssl-devel \
        perl-Digest-MD5 \
        perl-Digest-SHA \
        perl-FindBin \
        perl-lib \
        perl-Time-Piece \
        pkgconfig \
        python3-devel \
        shadow-utils \
        tar \
        which \
        xz \
        zip \
        && dnf clean all

# Fetch source code
WORKDIR /tmp
RUN curl --retry 5 --retry-delay 5 -L -o lo.tar.xz ${SOURCE_URL} && \
    tar -xJf lo.tar.xz && \
    mv libreoffice-${LIBREOFFICE_VERSION} libreoffice && \
    rm -f lo.tar.xz

# Create non-root builder (early — caches across patch changes)
RUN useradd -m builder && chown -R builder:builder /tmp/libreoffice

USER builder
WORKDIR /tmp/libreoffice

# Apply source patches
COPY ./scripts/th-localedata.patch /tmp/libreoffice/
RUN cd /tmp/libreoffice && patch -p1 < th-localedata.patch && rm th-localedata.patch
COPY ./scripts/backupfilehelper-crash.patch /tmp/libreoffice/
RUN cd /tmp/libreoffice && patch -p1 < backupfilehelper-crash.patch && rm backupfilehelper-crash.patch
COPY ./scripts/officecfg-startup-crash.patch /tmp/libreoffice/
RUN cd /tmp/libreoffice && patch -p1 < officecfg-startup-crash.patch && rm officecfg-startup-crash.patch
COPY ./scripts/headless-error-dialog.patch /tmp/libreoffice/
RUN cd /tmp/libreoffice && patch -p1 < headless-error-dialog.patch && rm headless-error-dialog.patch
COPY ./scripts/configwrapper-nullsafe.patch /tmp/libreoffice/
RUN cd /tmp/libreoffice && patch -p1 < configwrapper-nullsafe.patch && rm configwrapper-nullsafe.patch
COPY ./scripts/configitem-nullsafe.patch /tmp/libreoffice/
RUN cd /tmp/libreoffice && patch -p1 < configitem-nullsafe.patch && rm configitem-nullsafe.patch
COPY ./scripts/localedatawrapper-nullsafe.patch /tmp/libreoffice/
RUN cd /tmp/libreoffice && patch -p1 < localedatawrapper-nullsafe.patch && rm localedatawrapper-nullsafe.patch

# Remove no-python.patch so ICU's Python data build tool can filter locales at build time
RUN sed -i '/no-python.patch/d' /tmp/libreoffice/external/icu/UnpackedTarball_icu.mk

# Extract full ICU data zip (locale .txt sources) so the Python data build tool runs
RUN sed -i '/ICU_DATA_TARBALL/ s/ data\/misc\/icudata\.rc/ -x "data\/Makefile.in" "data\/pkgdataMakefile.in"/' /tmp/libreoffice/external/icu/UnpackedTarball_icu.mk

# ICU data filter: only compile en + th locale data (saves ~16 MB in libicudata.so)
COPY ./scripts/icu-data-filter.json /tmp/icu-data-filter.json
ENV ICU_DATA_FILTER_FILE=/tmp/icu-data-filter.json

# Configure with disabled features

# Pre-download tarballs
RUN CC=gcc14-gcc CXX=gcc14-g++ ./configure \
    --disable-avahi \
    --disable-cairo-canvas \
    --disable-coinmp \
    --disable-cups \
    --disable-cve-tests \
    --disable-dbus \
    --disable-dconf \
    --disable-dependency-tracking \
    --disable-dbgutil \
    --disable-extensions \
    --disable-gen \
    --disable-gio \
    --disable-gstreamer-1-0 \
    --disable-gtk3 \
    --disable-gui \
    --disable-introspection \
    --disable-kf5 \
    --disable-kf6 \
    --disable-largefile \
    --disable-ldap \
    --disable-lotuswordpro \
    --disable-lpsolve \
    --disable-odk \
    --disable-ooenv \
    --disable-opencl \
    --disable-pch \
    --disable-qt5 \
    --disable-qt6 \
    --disable-randr \
    --disable-sdremote \
    --disable-sdremote-bluetooth \
    --disable-skia \
    --disable-mergelibs \
    --with-galleries="no" \
    --without-system-curl \
    --without-system-expat \
    --without-system-nss \
    --without-system-openssl \
    --with-theme="no" \
    --without-export-validation \
    --without-fonts \
    --without-system-freetype \
    --without-helppack-integration \
    --without-java \
    --without-junit \
    --without-krb5 \
    --without-myspell-dicts \
    --without-system-dicts \
    --without-webdav && \
    make download

# Build LibreOffice
RUN make -j$(nproc)

# Copy custom fonts for bundling
COPY ./fonts /tmp/fonts

# Run the post-build stripping script
COPY ./scripts/strip-libreoffice.sh /tmp/strip-libreoffice.sh
RUN bash /tmp/strip-libreoffice.sh /tmp/libreoffice/instdir && \
    tar -cf /tmp/lo.tar -C /tmp/libreoffice instdir/ && \
    echo "=== Largest .so files ===" && \
    du -sh /tmp/libreoffice/instdir/program/lib*.so 2>/dev/null | sort -rh | head -30 && \
    echo "=== Biggest non-.so files ===" && \
    find /tmp/libreoffice/instdir -not -name '*.so' -not -name '*.so.*' -type f -size +1M -exec du -h {} \; 2>/dev/null | sort -rh | head -20 && \
    echo "=== Diagnostics ===" && \
    ls -la /tmp/libreoffice/instdir/program/liblocaledata_th* 2>/dev/null || echo "localedata_th.so: MISSING" && \
    strings /tmp/libreoffice/instdir/program/services/services.rdb 2>/dev/null | grep -i localedata || echo "localedata in rdb: none found" && \
    ls -la /tmp/libreoffice/instdir/program/libskialo* 2>/dev/null || echo "libskialo.so: MISSING (expected with --disable-skia)"

# Stage 2: brotli compression + smoke test
FROM amazon/aws-lambda-nodejs:22 AS brotli

WORKDIR /tmp

RUN dnf install -y brotli pv tar && dnf clean all

COPY --from=lobuild /tmp/lo.tar .
COPY ./scripts/smoke-test.sh /tmp/smoke-test.sh

# Smoke test before compression
RUN tar -xf lo.tar && \
    bash /tmp/smoke-test.sh /tmp/instdir && \
    rm -rf /tmp/instdir

RUN pv -f -pterb -s "$(stat -c%s /tmp/lo.tar)" /tmp/lo.tar | brotli --best -o /tmp/lo.tar.br && rm /tmp/lo.tar



ARG VERSION=3.0.0

FROM docker.io/library/fedora:latest AS build
ARG VERSION

RUN dnf install -y cargo clang cmake rocksdb-devel

ADD https://github.com/mempool/electrs/archive/refs/tags/v${VERSION}.tar.gz .
RUN mkdir -p /source && tar -xzf v${VERSION}.tar.gz --strip-components 1 -C /source

WORKDIR /source
RUN cargo build --release --bin electrs

## Build a skelton for the scratch output image
RUN mkdir -p /build/etc /build/usr/bin /build/usr/lib /build/usr/lib64 /build/root
RUN ln -s /usr/bin /build/bin
RUN ln -s /usr/lib /build/lib
RUN ln -s /usr/lib64 /build/lib64

## Add build result to the output image
RUN cp -aLv target/release/electrs /build/usr/bin/

## Add dynamic loader and library dependencies to the output image
# $ ldd target/release/electrs
# linux-vdso.so.1 (0x00007fff62ebd000)
# libstdc++.so.6 => /lib64/libstdc++.so.6 (0x000075a239f0d000)
# libgcc_s.so.1 => /lib64/libgcc_s.so.1 (0x000075a239ee0000)
# libm.so.6 => /lib64/libm.so.6 (0x000075a239dfd000)
# libc.so.6 => /lib64/libc.so.6 (0x000075a239c10000)
# /lib64/ld-linux-x86-64.so.2 (0x000075a23ac17000)
RUN cp -aLv /usr/lib64/libstdc++.so.6 /usr/lib64/libgcc_s.so.1 /usr/lib64/libm.so.6 /usr/lib64/libc.so.6 /build/usr/lib64

## Location of the dynamic loader varies across architectures.
RUN cp /usr/lib64/ld-linux* /build/usr/lib64 && ln -s /usr/lib64/ld-linux-* /build/usr/bin/ld.so || true
RUN cp /usr/lib/ld-linux* /build/usr/lib && ln -s /usr/lib/ld-linux-* /build/usr/bin/ld.so || true
RUN [ -f /build/usr/bin/ld.so ] || (echo "Unable to find a dynamic loader library in /usr/lib or /usr/lib64" && exit 1)
RUN cp -av /etc/ld.so.* /build/etc

## Add sh and dependencies for entrypoint and health-check configurations to the output image. Docker et. al. will wrap
## commands in `/bin/sh -c` by default when string values are passed as entrypoint and health-cmd arguments. This is
## useful for inline environment variable expansion:
# $ ldd /usr/bin/sh
# linux-vdso.so.1 (0x00007ffe0ab98000)
# libtinfo.so.6 => /lib64/libtinfo.so.6 (0x00007f6c137ef000)
# libc.so.6 => /lib64/libc.so.6 (0x00007f6c13602000)
# /lib64/ld-linux-x86-64.so.2 (0x00007f6c1397f000)
RUN cp -aLv /usr/bin/bash /build/usr/bin/
RUN cp -aLv /usr/lib64/libtinfo.so.6 /build/usr/lib64

## Generate a final scratch image
FROM scratch

COPY --from=build /build /
COPY entrypoint.sh /usr/bin/entrypoint

ENV ELECTRS_ARGS="-vvv --jsonrpc-import"
ENV ELECTRS_DATA_DIR="/data"
ENV ELECTRS_BANNER="mempool/electrum server"
ENV ELECTRS_RPC_ADDR="0.0.0.0:50001"
ENV ELECTRS_HTTP_ADDR="0.0.0.0:3000"
ENV ELECTRS_MONITORING_ADDR="0.0.0.0:4224"
ENV ELECTRS_NETWORK="mainnet"
ENV BITCOIND_RPC_ADDR="127.0.0.1:8332"
ENV BITCOIND_RPC_USER="bitcoin"
ENV BITCOIND_RPC_PASS="bitcoin"

CMD [ "/usr/bin/entrypoint" ]

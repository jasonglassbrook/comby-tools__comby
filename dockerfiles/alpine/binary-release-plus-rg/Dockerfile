#######################################
### Source build for alpine release ###
#######################################
FROM comby/base-dependencies-alpine-3.14:latest AS source-build-alpine

WORKDIR /home/comby

COPY Makefile /home/comby/
COPY comby.opam /home/comby/
COPY comby-kernel.opam /home/comby/
COPY comby-semantic.opam /home/comby/
COPY dune-project /home/comby/
COPY dune /home/comby/
COPY docs /home/comby/docs
COPY src /home/comby/src
COPY lib /home/comby/lib
COPY test /home/comby/test
COPY push-coverage-report.sh /home/comby/

RUN sudo chown -R $(whoami) /home/comby
RUN opam exec -- make build
RUN opam exec -- dune runtest
RUN opam exec -- dune clean
# UGH. stop dune from complaining
RUN rm -rf comby
RUN opam exec -- dune build --profile release

###########################################################
### Binary distribution on minimal alpine image with rg ###
###########################################################
FROM alpine:3.14

LABEL maintainer="Rijnard van Tonder <rvantonder@gmail.com>"
LABEL name="comby"
LABEL org.opencontainers.image.source="https://github.com/comby-tools/comby"

RUN apk --no-cache add pcre libev sqlite-dev ripgrep tini gmp
COPY --from=source-build-alpine /home/comby/_build/default/src/main.exe /usr/local/bin/comby
COPY --from=source-build-alpine /home/comby/docs/third-party-licenses /usr/local/bin/comby-third-party-licenses

WORKDIR /
ENTRYPOINT ["/sbin/tini", "--", "/usr/local/bin/comby"]

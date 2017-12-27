FROM alpine:3.7

RUN apk add --no-cache sudo bash \
    && apk add --no-cache jq python py-pip \
    && pip install awscli \
    && apk --purge -v del py-pip

COPY ./assets/* /opt/resource/

ARG BUILD_FROM
FROM ${BUILD_FROM}

ENV LANG C.UTF-8

COPY run.sh /
RUN chmod a+x /run.sh

# add aws-cli and deps
RUN apk add -v --update --no-cache \
        coreutils \
        python3 \
        py3-pip \
        groff \
        less \
        jq
RUN python3 -m venv venv && \
    . ./venv/bin/activate && \
    pip3 install --upgrade awscli
    
    
CMD [ "/run.sh" ]  

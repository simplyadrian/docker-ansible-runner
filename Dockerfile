FROM mgage/docker-ansible:alpine3.4
USER root
ADD runner.sh /ansible/runner.sh
RUN apk add bash jq &&\
    chmod 700 /ansible/runner.sh
CMD /ansible/runner.sh

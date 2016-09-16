FROM mgage/docker-ansible:alpine3.4
USER ansible
ADD runner.sh /ansible/runner.sh
USER root
RUN apk add bash jq &&\
    chmod 700 /ansible/runner.sh && chown ansible:ansible /ansible/runner.sh
USER ansible
CMD /ansible/runner.sh

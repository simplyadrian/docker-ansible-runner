FROM mgage/docker-ansible:alpine3.4
USER ansible
ADD runner.sh /ansible/runner.sh
USER root
RUN apk update &&\
    apk add bash jq &&\
    pip install prettytable &&\
    chmod 700 /ansible/runner.sh && chown ansible:ansible /ansible/runner.sh
USER ansible
CMD /ansible/runner.sh

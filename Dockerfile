FROM mgage/docker-ansible:latest
ADD runner.sh /ansible/runner.sh
RUN apt-get update &&\
     apt-get install -y jq &&\
     pip install credstash==1.11.0 &&\
     chmod 700 /ansible/runner.sh &&\
     rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
CMD /ansible/runner.sh

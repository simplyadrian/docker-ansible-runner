#!/bin/bash
region=${AWS_REGION:-"us-west-2"}
queue=${SQS_QUEUE_URL:-null}
wait_time=${WAIT_TIME:-20}
playbook=${PLAYBOOK:-null}
extra_vars=${EXTRA_VARS:-null}
inventory=${INVENTORY:-null}
s3_path=${S3_PATH:-null}
role=${ROLE:-null}
credstash_ssh_key=${CREDSTASH_SSH_KEY:-null}
credstash_ssh_key_con=${CREDSTASH_SSH_KEY_CON:-null}

#if configured with queue
if [ "${queue}" != "null" ]
then
    receipt_handle="null"
    while [ "${receipt_handle}" = "null" ]; do
    # Fetch message and extract the s3_path, playbook, role, etc
        echo "attempting to fetch message from: ${queue}"
        result=$( \
            aws sqs receive-message \
                --output=json \
                --queue-url ${queue} \
                --region ${region} \
                --wait-time-seconds ${wait_time} \
                --query Messages[0].[Body,ReceiptHandle])
        if [ "$?" != 0 ]
        then
            exit 1
        fi

        receipt_handle=$(echo ${result} | jq -r '.[1]')
        if [ "${receipt_handle}" = "null" ]
        then
            echo "No Message Received"
        fi
    done

    playbook=$(echo ${result} | jq -r '.[0]|fromjson|.Message|fromjson|.playbook')
    s3_path=$(echo ${result} | jq -r '.[0]|fromjson|.Message|fromjson|.s3_path')
    role=$(echo ${result} | jq -r '.[0]|fromjson|.Message|fromjson|.role')
    extra_vars=$(echo ${result} | jq -r '.[0]|fromjson|.Message|fromjson|.extra_vars')
    inventory=$(echo ${result} | jq -r '.[0]|fromjson|.Message|fromjson|.inventory')
    credstash_ssh_key=$(echo ${result} | jq -r '.[0]|fromjson|.Message|fromjson|.credstash_ssh_key')
    credstash_ssh_key_con=$(echo ${result} | jq -r '.[0]|fromjson|.Message|fromjson|.credstash_ssh_key_con')
fi

#assume role
if [ "${role}" != "null" ]
then
    role_results=$(aws sts assume-role --role-arn ${role} --role-session-name `hostname` | jq '.Credentials')
    export AWS_ACCESS_KEY_ID=$(echo ${role_results} | jq -r '.AccessKeyId')
    export AWS_SECRET_ACCESS_KEY=$(echo ${role_results} | jq -r '.SecretAccessKey')
    export AWS_SESSION_TOKEN=$(echo ${role_results} | jq '.SessionToken')
    export AWS_SECURITY_TOKEN=$(echo ${role_results} | jq '.SessionToken')
fi

#download a playbook archive from s3 and unarchive it
if [ "${s3_path}" != "null" ]
then
    aws s3 cp ${s3_path} ./work.tgz --region ${region}
    if [ "$?" != 0 ]
    then
        echo "failed to download archive"
        exit 1
    fi

    #unarchive
    #tar --strip-components=1 -zxvf work.tgz
    tar -xvzf work.tgz >./.unarchive_log
fi

#build the playbook command
ansible_options=""
if [ "${inventory}" != "null" ]
then
    ansible_options+=" -i ${inventory}"
fi

ansible_options+=" ${playbook}"

if [ "${extra_vars}" != "null" ]
then
    ansible_options+=" --extra-vars ${extra_vars}"
fi

#download an ssh key to use from credstash
if [ "${credstash_ssh_key}" != "null" ]
then
    if [ "${credstash_ssh_key_con}" = "null" ]
    then
	      credstash_ssh_key_con=""
    fi
    credstash -r ${region} get -n ${credstash_ssh_key} ${credstash_ssh_key_con} > ./credstash_ssh_key
    chmod 600 ./credstash_ssh_key
    ansible_options+=" --key-file=./credstash_ssh_key"
fi

#run the playbook
ansible-playbook ${ansible_options}

#if configured with queue and successfully processed, delete message
if [[ "$?" = 0 ]] && [[ "${queue}" != "null" ]]
then
  echo "Finished Processing: Deleting message."
  aws sqs delete-message \
      --queue-url ${queue} \
      --region ${region} \
      --receipt-handle "${receipt_handle}"
fi

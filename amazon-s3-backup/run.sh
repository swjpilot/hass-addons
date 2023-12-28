#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Community Add-on: Amazon S3 Backup
# ==============================================================================
#bashio::log.level "debug"

bashio::log.info "Starting Amazon S3 Backup..."

bucket_name="$(bashio::config 'bucket_name')"
bucket_key="$(bashio::config 'bucket_key')"
storage_class="$(bashio::config 'storage_class' 'STANDARD')"
bucket_region="$(bashio::config 'bucket_region' 'us-east-1')"
delete_local_backups="$(bashio::config 'delete_local_backups' 'true')"
delete_remote_backups="$(bashio::config 'delete_remote_backups' 'true')"
local_backups_to_keep="$(bashio::config 'local_backups_to_keep' '7')"
remote_backups_to_keep="$(bashio::config 'remote_backups_to_keep' '31')"
monitor_path="/backup"
jq_filter=".backups|=sort_by(.date)|.backups|reverse|.[$local_backups_to_keep:]|.[].slug"
s3_filter="Contents[?LastModified<=$(date --iso-8601 -d  "-$remote_backups_to_keep days")].[Key] --output text"

export AWS_ACCESS_KEY_ID="$(bashio::config 'aws_access_key')"
export AWS_SECRET_ACCESS_KEY="$(bashio::config 'aws_secret_access_key')"
export AWS_REGION="$bucket_region"

bashio::log.debug "Using AWS CLI version: '$(aws --version)'"
bashio::log.debug "Command: 'aws s3 sync $monitor_path s3://$bucket_name/$bucket_key --no-progress --region $bucket_region --storage-class $storage_class'"
aws s3 sync $monitor_path s3://"$bucket_name"/"$bucket_key" --no-progress --region "$bucket_region" --storage-class "$storage_class"

if bashio::var.true "${delete_local_backups}"; then
    bashio::log.info "Will delete local backups except the '${local_backups_to_keep}' newest ones."
    backup_slugs="$(bashio::api.supervisor "GET" "/backups" "false" "$jq_filter")"
    bashio::log.debug "Backups to delete: '$backup_slugs'"

    for s in $backup_slugs; do
        bashio::log.info "Deleting Backup: '$s'"
        bashio::api.supervisor "DELETE" "/backups/$s"
    done
else
    bashio::log.info "Will not delete any local backups since 'delete_local_backups' is set to 'false'"
fi

if bashio::var.true "${delete_remote_backups}"; then
    bashio::log.info "Will delete remote backups except the '${remote_backups_to_keep}' newest ones."
    aws s3api list-objects --bucket s3://"$bucket_name"/"$bucket_key" --query $s3_filter > objects.txt
    bashio::log.debug "Backups to delete: "$(cat objects.txt)
    while read line; do aws s3api delete-object --bucket s3://"$bucket_name" --key "$line"; done < objects.txt
else
    bashio::log.info "Will not delete any remote backups since 'delete_remote_backups' is set to 'false'"
fi
bashio::log.info "Finished Amazon S3 Backup."
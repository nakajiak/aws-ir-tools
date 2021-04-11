# Incident Response Tools for AWS

## dump_cloudtrail_from_all_region.sh

1. Dump AWS CloudTrail as JSON format from all region
    * `cloudtrail_files/CloudTrail-<region>-<datetime>-<seq_number>.json`
1. sha1sum cloudtrail
    * `cloudtrail_files/CloudTrail-<region>-<datetime>-<seq_number>.json.sha1`
1. Convert json to S3 exported format and compress each dumped json
    * `cloudtrail_files/CloudTrail-<region>-<datetime>-<seq_number>.json.gz`
1. Archive all dumped json and sha1. Then delete json and sha1
    * `cloudtrail_files/dumped_cloudtrail-<datetime>.zip`

### Required

* awscli
* jq
* sha1sum or shasum

### Usage

Execute following command on CloudShell.

```shell
bash <(curl -s -o- https://raw.githubusercontent.com/nakajiak/aws-ir-tools/main/dump_cloudtrail_from_all_region.sh)
```

### Analysis CloudTrail with SIEM

If you setup [SIEM on Amazon Elasticsearch Service](https://github.com/aws-samples/siem-on-amazon-elasticsearch/), you can send CloudTrail logs to SIEM S3 bucket and analysis logs with SIEM.

```shell
ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
aws s3 cp cloudtrail_files/ s3://aes-siem-${ACCOUNT}-log/AWSLogs/CloudTrail/ --recursive --exclude "*" --include "*.gz"
```

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

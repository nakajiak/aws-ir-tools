# Incident Response Tools for AWS

## dump_cloudtrail_from_all_region.sh

1. Dump AWS CloudTrail as JSON format from all region
    * `CloudTrail-<region>-<datetime>-<seq_number>.json`
1. sha1sum cloudtrail
    * `CloudTrail-<region>-<datetime>-<seq_number>.json.sha1`
1. Convert json to S3 exported format and compress each dumped json
    * `CloudTrail-<region>-<datetime>-<seq_number>.json.gz`
1. Archive all dumped json and sha1. Then delete json and sha1
    * `dumped_cloudtrail-<datetime>.tgz`

### Required

* awscli
* jq
* sha1sum or shasum

### Usage

Execute following command on CloudShell or EC2 with admin privilege IAM Role.

```shell
bash <(curl -s -o- https://raw.githubusercontent.com/nakajiak/aws-ir-tools/main/dump_cloudtrail_from_all_region.sh)
```

OR

```shell
git clone https://github.com/nakajiak/aws-ir-tools.git
cd aws-ir-tools
./dump_cloudtrail_from_all_region.sh
```

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

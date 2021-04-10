#!/bin/bash
# Copyright Akihiro Nakajima. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# dump CloudTrail event from all region.

# check jq command
if ! jq --version; then
  echo "install jq command. exit..."
  exit
fi
# check sha1 command
shopt -s expand_aliases
cmd_sha1="$(which shasum 2>/dev/null || which sha1sum 2>/dev/null)"
if [[ "$cmd_sha1" ]]; then
  alias cmd_sha1='${cmd_sha1}'
else
  echo "install sha1sum command. exit..."
  exit
fi

max_item=50000

dt=$(date "+%Y%m%d_%H%M%S")
regions=$(aws ec2 describe-regions --output text | awk '{print $4}')
for region in $regions; do
  echo "$region"
  next_token=0
  iteration=0
  next_token=0

  outfile_json="CloudTrail-${region}-${dt}-${iteration}.json"
  aws cloudtrail lookup-events \
    --region "${region}" \
    --max-items ${max_item} \
    >"${outfile_json}"

  cmd_sha1 "${outfile_json}" >"${outfile_json}.sha1"
  cat "${outfile_json}" | jq -r '.Events[].CloudTrailEvent' | jq . -s | jq '{Records: .}' -c | gzip -c >"${outfile_json}.gz"

  next_token=$(grep '  "NextToken":' "${outfile_json}" | awk '{print $2}' | sed -e 's/"//g')
  echo "$next_token"

  while [[ -n $next_token ]]; do
    iteration=$((iteration + 1))
    outfile_json="CloudTrail-${region}-${dt}-${iteration}.json"
    aws cloudtrail lookup-events \
      --region "${region}" \
      --starting-token "${next_token}" \
      --max-items "${max_item}" \
      >"${outfile_json}"
    cmd_sha1 "${outfile_json}" >"${outfile_json}.sha1"
    cat "${outfile_json}" | jq -r '.Events[].CloudTrailEvent' | jq . -s | jq '{Records: .}' -c | gzip -c >"${outfile_json}.gz"

    next_token=$(grep '  "NextToken":' "${outfile_json}" | awk '{print $2}' | sed -e 's/"//g')
    echo "${next_token}"
  done
done

#tar -zcvf "dumped_cloudtrail-${dt}.tgz" CloudTrail-*.sha1 CloudTrail-*.json --remove-files
tar -zcvf "dumped_cloudtrail-${dt}.tgz" CloudTrail-*"${dt}"*.sha1 CloudTrail-*"${dt}"*.json
rm CloudTrail-*.sha1 CloudTrail-*"${dt}"*.json
cmd_sha1 "dumped_cloudtrail-${dt}.tgz" >"dumped_cloudtrail-${dt}.sha1"

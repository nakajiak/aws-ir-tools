#!/bin/bash
# Copyright Akihiro Nakajima. All Rights Reserved.
# SPDX-License-Identifier: MIT-0
#
# dump CloudTrail event from all region.

echo "Starting at $(date)"

export MAX_ITEMS=20000
export OUT_DIR="cloudtrail_files"
export DT
export ACCOUNT

DT=$(date "+%Y%m%d_%H%M%S")
ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)

if [[ "$AWS_EXECUTION_ENV" = "CloudShell" ]]; then
  export TASK_NUM=5
else
  export TASK_NUM=30
fi

while [ ! "$ACCOUNT" ]; do
  echo "Retry to get account"
  ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text)
  sleep 3
done

echo "MAX_ITEMS: ${MAX_ITEMS}"
echo "${ACCOUNT}"

# check jq command
if ! jq --version >/dev/null; then
  echo "install jq command. exit..."
  exit
fi
# check sha1 command
shopt -s expand_aliases
cmd_sha1="$(which shasum 2>/dev/null || which sha1sum 2>/dev/null)"
if [[ "$cmd_sha1" ]]; then
  export cmd_sha1
  alias cmd_sha1='${cmd_sha1}'
else
  echo "install sha1sum command. exit..."
  exit
fi
mkdir -p $OUT_DIR

#######################################
# hash and convert s3 exported cloudtrail format
# Globals:
#   OUT_DIR
#   cmd_sha1
# Arguments:
#   dumped cloudtrail json file name
#######################################
function hash_and_convert_trail() {
  local outfile_json="$1"
  cd "${OUT_DIR}" || echo "cat't find export dir"
  cmd_sha1 "${outfile_json}" >"${outfile_json}.sha1"
  cat "${outfile_json}" | jq -r '.Events[].CloudTrailEvent' | jq . -s | jq '{Records: .}' -c | gzip -c >"${outfile_json}.gz"
  zip "${outfile_json}.zip" "${outfile_json}"
  cd ..
}
export -f hash_and_convert_trail

#######################################
# Dump CloudTrail management events
# Globals:
#   OUT_DIR
#   MAX_ITEMS
#   DT
#   cmd_sha1
# Arguments:
#   region, aws region
#######################################
function dump_event() {
  local region="$1"
  local sleep_time="$(($2 * 3))"
  local next_token=0
  local iteration=0
  local outfile_json="CloudTrail-${ACCOUNT}-${region}-${DT}-${iteration}.json"
  echo "$region: sleep ${sleep_time}"
  sleep "${sleep_time}"

  while [ ! "$ACCOUNT" ]; do
    echo "Retry to get account"
    ACCOUNT=$(aws sts get-caller-identity --query 'Account' --output text --region "${region}")
  done

  aws cloudtrail lookup-events \
    --region "${region}" \
    --max-items "${MAX_ITEMS}" \
    --output json \
    >"${OUT_DIR}/${outfile_json}"

  hash_and_convert_trail "${outfile_json}"
  next_token=$(grep '  "NextToken":' "${OUT_DIR}/${outfile_json}" | awk '{print $2}' | sed -e 's/"//g')
  echo "${region} next token: ${next_token}"
  rm "${OUT_DIR}/${outfile_json}"

  while [[ -n $next_token ]]; do
    iteration=$((iteration + 1))
    outfile_json="CloudTrail-${ACCOUNT}-${region}-${DT}-${iteration}.json"
    aws cloudtrail lookup-events \
      --region "${region}" \
      --starting-token "${next_token}" \
      --max-items "${MAX_ITEMS}" \
      --output json \
      >"${OUT_DIR}/${outfile_json}"
    hash_and_convert_trail "${outfile_json}"
    next_token=$(grep '  "NextToken":' "${OUT_DIR}/${outfile_json}" | awk '{print $2}' | sed -e 's/"//g')
    echo "${region} next token: ${next_token}"
    rm "${OUT_DIR}/${outfile_json}"
  done

}
export -f dump_event

#############################################
# main func
#############################################
regions=$(aws ec2 describe-regions --output text | sort | awk '{print $4,NR}')
# execute in pallarel
echo "$regions" | xargs -P "${TASK_NUM}" -I% bash -c "dump_event %"

cd "${OUT_DIR}" || echo "cat't find export dir"
zip "dumped_cloudtrail-${ACCOUNT}-${DT}.zip" \
  CloudTrail-"${ACCOUNT}"-*"${DT}"*.sha1 &&
  rm CloudTrail-"${ACCOUNT}"-*"${DT}"*.sha1
zipfiles=$(ls CloudTrail-"${ACCOUNT}"-*"${DT}"*.json.zip)
for zipfile in $zipfiles; do
  unzip "$zipfile"
  zip -u "dumped_cloudtrail-${ACCOUNT}-${DT}.zip" \
    CloudTrail-"${ACCOUNT}"-*"${DT}"*.json &&
    rm "$zipfile" \
      CloudTrail-"${ACCOUNT}"-*"${DT}"*.json
done
cmd_sha1 "dumped_cloudtrail-${ACCOUNT}-${DT}.zip" \
  >"dumped_cloudtrail-${ACCOUNT}-${DT}.sha1"

echo "Ended at $(date)"

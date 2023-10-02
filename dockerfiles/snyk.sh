#!/bin/bash

echo "[" > summary.json
for image in $(cat tags.txt); do
  image_file=$(echo ${image} | tr '/' '-' | tr ':' '-')
  tag=$(echo ${image} | cut -f 2 -d '/' | cut -f 2 -d ':')  
  echo "Testing ${image}..."

  if [[ "$1" == "--no-cache" || ! -f snyk.${image_file}.json ]]; then
    DOCKER_CLI_HINTS=false docker pull ${image}
    snyk container test ${image} --exclude-app-vulns --json-file-output=snyk.${image_file}.json --group-issues > snyk.${image_file}.log
  fi
  node_version=$(echo $(docker run -it --rm --platform=linux/amd64 ${image} '--version')| tr -d '\r' | tr -d 'v')
  yarn_version=$(echo $(docker run -it --rm --entrypoint yarn --platform=linux/amd64 ${image} '--version')| tr -d '\r' | tr -d 'v')
  img_mbs=$(echo "scale=0; $(docker image inspect ${image} --format '{{ .Size }}') / (1024 * 1024)" | bc)
  summary=$(jq -c '.dependencyCount as $dependencies | [ .vulnerabilities[].severity] | reduce .[] as $sev ({}; .[$sev] +=1) | { image: "'${image}'", runtime: "'${node_version}'", yarn_version: "'${yarn_version}'", imageSize: "'${img_mbs}'MB", dependencies: $dependencies, low: (.low // 0), medium: (.medium // 0), high: (.high // 0), critical: (.critical // 0)} | .total = .low + .medium + .high + .critical ' snyk.${image_file}.json)
  echo "  ${summary}," >> summary.json
done
echo "]" >> summary.json

cat summary.json
# Functions originally from https://github.com/silinternational/ecs-deploy

function parseImageName() {
  # Define regex for image name
  # This regex will create groups for:
  # - domain
  # - port
  # - repo
  # - image
  # - tag
  # If a group is missing it will be an empty string
  imageRegex="^([a-zA-Z0-9\.\-]+):?([0-9]+)?/([a-zA-Z0-9\._\-]+)(/[\/a-zA-Z0-9\._\-]+)?:?([a-zA-Z0-9\._\-]+)?$"

  if [[ $IMAGE_WITH_TAG =~ $imageRegex ]]; then
    # Define variables from matching groups
    if [[ "x$TAGONLY" == "x" ]]; then
      domain=${BASH_REMATCH[1]}
      port=${BASH_REMATCH[2]}
      repo=${BASH_REMATCH[3]}
      img=${BASH_REMATCH[4]/#\//}
      tag=${BASH_REMATCH[5]}

      # Validate what we received to make sure we have the pieces needed
      if [[ "x$domain" == "x" ]]; then
        echo "Image name does not contain a domain or repo as expected. See usage for supported formats."
        exit 10;
      fi
      if [[ "x$repo" == "x" ]]; then
        echo "Image name is missing the actual image name. See usage for supported formats."
        exit 11;
      fi

      # When a match for image is not found, the image name was picked up by the repo group, so reset variables
      if [[ "x$img" == "x" ]]; then
        img=$repo
        repo=""
      fi
    else
      tag=${BASH_REMATCH[1]}
    fi
  else
    # check if using root level repo with format like mariadb or mariadb:latest
    rootRepoRegex="^([a-zA-Z0-9\-]+):?([a-zA-Z0-9\.\-]+)?$"
    if [[ $IMAGE_WITH_TAG =~ $rootRepoRegex ]]; then
      img=${BASH_REMATCH[1]}
      if [[ "x$img" == "x" ]]; then
        echo "Invalid image name. See usage for supported formats."
        exit 12
      fi
      tag=${BASH_REMATCH[2]}
    else
      echo "Unable to parse image name: $IMAGE_WITH_TAG, check the format and try again"
      exit 13
    fi
  fi

  # If tag is missing make sure we can get it from env var, or use latest as default
  if [[ "x$tag" == "x" ]]; then
    if [[ $TAGVAR == false ]]; then
      tag="latest"
    else
      tag=${!TAGVAR}
      if [[ "x$tag" == "x" ]]; then
        tag="latest"
      fi
    fi
  fi

  # Reassemble image name
  if [[ "x$TAGONLY" == "x" ]]; then

    if [[ ! -z ${domain+undefined-guard} ]]; then
      useImage="$domain"
    fi
    if [[ ! -z ${port} ]]; then
      useImage="$useImage:$port"
    fi
    if [[ ! -z ${repo+undefined-guard} ]]; then
      if [[ ! "x$repo" == "x" ]]; then
        useImage="$useImage/$repo"
      fi
    fi
    if [[ ! -z ${img+undefined-guard} ]]; then
      if [[ "x$useImage" == "x" ]]; then
        useImage="$img"
      else
        useImage="$useImage/$img"
      fi
    fi
    imageWithoutTag="$useImage"
    if [[ ! -z ${tag+undefined-guard} ]]; then
      useImage="$useImage:$tag"
    fi

  else
    useImage="$TAGONLY"
  fi
}

function getCurrentTaskDefinition() {
  # Get current task definition name from service
  TASK_DEFINITION_ARN=`$ECS describe-services --services $SERVICE_NAME --cluster $CLUSTER_NAME | jq -r .services[0].taskDefinition`
  TASK_DEFINITION=`$ECS describe-task-definition --task-def $TASK_DEFINITION_ARN`
}

function createNewTaskDefJson() {
  # Get a JSON representation of the current task definition
  # + Update definition to use new image name
  # + Filter the def
  DEF=$( echo "$TASK_DEFINITION" \
  | sed -e "s|\"image\": *\"${imageWithoutTag}:.*\"|\"image\": \"${useImage}\"|g" \
  | sed -e "s|\"image\": *\"${imageWithoutTag}\"|\"image\": \"${useImage}\"|g" \
  | jq '.taskDefinition' )

  # Default JQ filter for new task definition
  NEW_DEF_JQ_FILTER="family: .family, volumes: .volumes, containerDefinitions: .containerDefinitions, placementConstraints: .placementConstraints"

  # Some options in task definition should only be included in new definition if present in
  # current definition. If found in current definition, append to JQ filter.
  CONDITIONAL_OPTIONS=(networkMode taskRoleArn placementConstraints)
  for i in "${CONDITIONAL_OPTIONS[@]}"; do
    re=".*${i}.*"
    if [[ "$DEF" =~ $re ]]; then
      NEW_DEF_JQ_FILTER="${NEW_DEF_JQ_FILTER}, ${i}: .${i}"
    fi
  done

  # Build new DEF with jq filter
  NEW_DEF=$(echo $DEF | jq "{${NEW_DEF_JQ_FILTER}}")
}

function registerNewTaskDefinition() {
  # Register the new task definition, and store its ARN
  NEW_TASKDEF=`$ECS register-task-definition --cli-input-json "$NEW_DEF" | jq -r .taskDefinition.taskDefinitionArn`
}

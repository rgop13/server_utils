#!bin/bash

number_regex='[0-9]+'
while true
do
    echo -n "도커 컨테이너를 생성할 대상 서버를 입력하세요 (반드시 숫자만 입력, e.g., 14): "
    read TARGET_SERVER
    if [[ $TARGET_SERVER =~ $number_regex ]]; then
        break
    else
        echo "반드시 숫자만을 입력해야 합니다. 다시 입력하세요."
    fi
done

while true
do
    echo -n "대상 사용자 계정명을 입력하세요 (e.g., sjy): "
    read SET_USER_NAME
    # 입력값 검증: /etc/passwd에 존재하는 유저인지 검증함
    result=$(grep "$SET_USER_NAME" /etc/passwd)
    if [[ $result =~ $SET_USER_NAME ]]; then
        break
    else
        echo "현재 위치한 서버의 계정 정보에 존재하지 않는 사용자입니다. 다시 입력하세요."
    fi
done

while true
do
    echo "도커 이미지 경로를 입력하세요."
    echo "단, nvidia/cuda 이미지만을 지원합니다."
    echo "   e.g., 쿠다11: nvidia/cuda:11.1.1-cudnn8-devel-ubuntu20.04"
    echo "         쿠다12: nvidia/cuda:12.3.2-cudnn9-devel-ubuntu20.04"
    echo "          잘 모르시겠다면, 'https://hub.docker.com/r/nvidia/cuda/tags' 를 참조하세요."
    echo -n "CUDA HUB REPOSITORY: "
    read DOCKER_IMAGE_PATH
    if [[ $DOCKER_IMAGE_PATH =~ "nvidia/cuda" ]]; then
        break
    else
        echo "다른 이미지가 감지되었습니다. nvidia/cuda 이미지만을 지원합니다. 다시 입력하세요."
    fi
done

# 쿠다 버전이 몇인지 문자열 검색
REPO_CUDA_VERSION=$(echo $DOCKER_IMAGE_PATH | awk '{ split($1, a, ":"); split(a[2], b, "-"); print b[1]; }')

# 파일 및 디렉토리 경로 설정
DOCKERFILE_BASEDIR="/data/sjy/dockerfile"
DOCKERFILE_PATH="/data/sjy/dockerfile/dockerfile"
DOCKER_COMPOSE_DIR="/data/sjy/dockerfile/srv${TARGET_SERVER}"
DOCKER_COMPOSE_FILE="${DOCKER_COMPOSE_DIR}/docker-compose.yaml"
DEFAULT_SETTINGS_FILE="/data/sjy/dockerfile/default_container_settings.yaml"

# 디렉토리가 없으면 생성
if [ ! -d "$DOCKER_COMPOSE_DIR" ]; then
    mkdir -p "$DOCKER_COMPOSE_DIR"
fi

# docker-compose.yaml 파일이 없으면 기본 내용으로 생성
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    echo $(cat /data/sjy/dockerfile/version) > "$DOCKER_COMPOSE_FILE"
    echo "services:" >> "$DOCKER_COMPOSE_FILE"
fi

# SET_USER_NAME 서비스가 이미 있는지 검사
if grep -q " $SET_USER_NAME:" "$DOCKER_COMPOSE_FILE"; then
    echo "Error: Service $SET_USER_NAME already exists in $DOCKER_COMPOSE_FILE"
    exit 1
else
    # DOCKER IMAGE PATH로 새로운 dockerfile을 임시로 만듦
    DOCKERFILE_CONTENT=$(sed "s@FROM .*@FROM ${DOCKER_IMAGE_PATH}@g" "$DOCKERFILE_PATH")
    NEW_DOCKERFILE_NAME="dockerfile_cuda-$REPO_CUDA_VERSION"
    NEW_DOCKERFILE_PATH="$DOCKERFILE_BASEDIR/$NEW_DOCKERFILE_NAME"
    if [ ! -f "$NEW_DOCKERFILE_PATH" ]; then
        echo "$DOCKERFILE_CONTENT" >> $NEW_DOCKERFILE_PATH
        echo "A new dockerfile has been created: '$NEW_DOCKERFILE_PATH'"
    fi

    # default_container_settings.yaml에서 SET_USER_NAME으로 대체하고 추가할 서비스 내용 준비
    SERVICE_CONTENT=$(sed "s@\${SET_USER_NAME}@$SET_USER_NAME@g" "$DEFAULT_SETTINGS_FILE" | sed "s/dockerfile: dockerfile/dockerfile: $NEW_DOCKERFILE_NAME/g" | sed "s@image: .*@image: nlpai/cuda:$REPO_CUDA_VERSION@g")

    # TARGET_SERVER의 docker-compose.yaml 파일에 서비스 추가
    echo "$SERVICE_CONTENT" >> "$DOCKER_COMPOSE_FILE"
    result=$(grep " $SET_USER_NAME:" $DOCKER_COMPOSE_FILE)
    if [[ $result =~ $SET_USER_NAME ]]; then
        echo "Service $SET_USER_NAME has been added to $DOCKER_COMPOSE_FILE"

        # 이제 추가된 서비스를 컨테이너로 만들자.
        docker-compose -f $DOCKER_COMPOSE_FILE up -d $SET_USER_NAME
        docker-compose -f $DOCKER_COMPOSE_FILE ps
    else
        echo "뭔가 뭔가 문제 발생... 아마 sed와 같은 문자열 관련 이슈일 것 같음..! 관리자에게 문의 바람..!"
        exit 1
    fi
fi

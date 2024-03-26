#!/bin/bash

TARGET_SERVER=$(hostname | awk '{ split($1,a,"-"); print a[3]; }')
echo "현재 위치한 서버는 ${TARGET_SERVER}번 서버입니다."

SET_USER_NAME=$(whoami)
echo "현재 로그인한 계정은 '${SET_USER_NAME}'입니다."

while true
do
    echo "아래 번호(1 or 2) 혹은 도커 이미지 경로를 입력하세요."
    echo "   1. nvidia/cuda:11.1.1-cudnn8-devel-ubuntu20.04"
    echo "   2. nvidia/cuda:12.3.2-cudnn9-devel-ubuntu20.04"
    echo "     (nvidia/cuda 이미지 빌드만 지원합니다)"
    echo "      다른 버전은 'https://hub.docker.com/r/nvidia/cuda/tags'를 참고하세요."
    echo -n "번호 or 이미지 경로: "
    read DOCKER_IMAGE_PATH
    if [[ $DOCKER_IMAGE_PATH =~ ^[1]$ ]]; then
        DOCKER_IMAGE_PATH="nvidia/cuda:11.1.1-cudnn8-devel-ubuntu20.04"
        break
    elif [[ $DOCKER_IMAGE_PATH =~ ^[2]$ ]]; then
        DOCKER_IMAGE_PATH="nvidia/cuda:12.3.2-cudnn9-devel-ubuntu20.04"
        break
    elif [[ $DOCKER_IMAGE_PATH =~ "nvidia/cuda" ]]; then
        # 번호가 아닌 nvidia/cuda 이미지인 경우
        break
    else
        echo "다른 이미지가 감지되었습니다. nvidia/cuda 이미지만을 지원합니다. 다시 입력하세요."
    fi
done

while true
do
    echo "생성될 컨테이너 이름을 입력하세요. (현재 설정값: $SET_USER_NAME)"
    echo -n "  * 입력하지 않으실 경우 기본값으로 생성됩니다! 변경이 필요하신 경우에만 새롭게 입력하세요!: "
    read SET_CONTAINER_NAME

    if [ -z "$SET_CONTAINER_NAME" ]; then
        SET_CONTAINER_NAME=$SET_USER_NAME
    fi

    echo "  * 입력된 컨테이너 이름: $SET_CONTAINER_NAME"
    echo -n "  * 위 값으로 컨테이너를 생성하시겠습니까? [Yy/Nn]: "
    read CONFIRM_CONTAINER_NAME
    if [[ $CONFIRM_CONTAINER_NAME =~ ^[Yy]$ ]]; then
        break
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
USER_HOME_DIR=$(cat /etc/passwd | grep -o '^$SET_USER_NAME:x.*' | awk -F ':' '{print $6}')

# 디렉토리가 없으면 생성
if [ ! -d "$DOCKER_COMPOSE_DIR" ]; then
    mkdir -p "$DOCKER_COMPOSE_DIR"
fi

# docker-compose.yaml 파일이 없으면 기본 내용으로 생성
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    echo $(cat /data/sjy/dockerfile/version) > "$DOCKER_COMPOSE_FILE"
    # 생성된 docker_compose_file의 권한 설정: 모두가 접근 가능
    sleep 0.5
    chgrp users $DOCKER_COMPOSE_FILE & chmod 777 $DOCKER_COMPOSE_FILE
    echo "services:" >> "$DOCKER_COMPOSE_FILE"
    sleep 0.5
fi

# SET_CONTAINER_NAME 서비스가 이미 있는지 검사
if grep -q " $SET_CONTAINER_NAME:$" "$DOCKER_COMPOSE_FILE"; then
    echo -n "컨테이너 $SET_CONTAINER_NAME가 이미 존재합니다. 삭제하고 다시 만드시겠습니까? [Yy/Nn]"
    read CONFIRM_DELETE
    if [[ $CONFIRM_DELETE ~= ^[Yy]$ ]]; then
        # 실행 중이면 stop
        IS_RUNNING=$(docker ps -a | grep -o ' ${SET_CONTAINER_NAME}$' | awk '{ split($1,a," "); print a[1]; }')
        if [ ! -z "$IS_RUNNING" ]; then
            sudo docker stop $SET_CONTAINER_NAME
            sudo docker rm $SET_CONTAINER_NAME
        fi
        # docker-compose.yaml 파일에서 해당 부분 삭제..!
        
        sleep 0.5
    fi
    exit 0
else
    # DOCKER IMAGE PATH로 새로운 dockerfile을 임시로 만듦
    DOCKERFILE_CONTENT=$(sed "s@FROM .*@FROM ${DOCKER_IMAGE_PATH}@g" "$DOCKERFILE_PATH")
    NEW_DOCKERFILE_NAME="dockerfile_cuda-$REPO_CUDA_VERSION"
    NEW_DOCKERFILE_PATH="$DOCKERFILE_BASEDIR/$NEW_DOCKERFILE_NAME"
    if [ ! -f "$NEW_DOCKERFILE_PATH" ]; then
        echo "$DOCKERFILE_CONTENT" >> $NEW_DOCKERFILE_PATH
        sleep 0.5
        # 생성된 dockerfile의 권한 설정: 모두가 접근 가능
        chgrp users $NEW_DOCKERFILE_PATH & chmod 777 $NEW_DOCKERFILE_PATH
        echo "A new dockerfile has been created: '$NEW_DOCKERFILE_PATH'"
    fi

    # default_container_settings.yaml에서 SET_USER_NAME으로 대체하고 추가할 서비스 내용 준비
    SERVICE_CONTENT=$(sed "s@\${SET_USER_NAME}@$SET_USER_NAME@g" "$DEFAULT_SETTINGS_FILE" | sed "s/dockerfile: dockerfile/dockerfile: $NEW_DOCKERFILE_NAME/g" | sed "s@image: .*@image: nlpai/cuda:$REPO_CUDA_VERSION@g" | sed "s@SET_CONTAINER_NAME@$SET_CONTAINER_NAME@g" | sed "s@SET_USER_HOME_DIR@$USER_HOME_DIR@g")

    # TARGET_SERVER의 docker-compose.yaml 파일에 서비스 추가
    echo "$SERVICE_CONTENT5" >> "$DOCKER_COMPOSE_FILE"
    sleep 1
    # 생성된 docker_compose_file의 권한 설정: 모두가 접근 가능
    chgrp users $DOCKER_COMPOSE_FILE & chmod 777 $DOCKER_COMPOSE_FILE
    result=$(grep "$SET_USER_NAME" $DOCKER_COMPOSE_FILE)
    if [[ $result =~ $SET_USER_NAME ]]; then
        echo "Service $SET_USER_NAME has been added to $DOCKER_COMPOSE_FILE"

        # 이제 추가된 서비스를 컨테이너로 만들자.
        sudo docker compose -f $DOCKER_COMPOSE_FILE up -d $SET_CONTAINER_NAME
        sudo docker compose -f $DOCKER_COMPOSE_FILE ps
    else
        echo "뭔가 뭔가 문제 발생... 아마 sed와 같은 문자열 관련 이슈일 것 같음..! 관리자에게 문의 바람..!"
        exit 1
    fi
fi

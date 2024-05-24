#!/bin/bash
SET_USER_NAME=$1

# unique_user_ids 목록에 존재하는 계정인지 확인
CONFIRM_EXIST=$(cat /data/sjy/passwd/all_user_ids | grep '^${SET_USER_NAME}:')
if [[ "$CONFIRM_EXIST" =~ $SET_USER_NAME ]]; then
  # 계정이 존재하는 경우 ($SET_USER_NAME가 $CONFIRM_EXIST에 포함되어 있는가?)
  # 이 경우, unique_id를 추출해서 해당 unique_id로 계정을 생성한다.
  UNIQUE_UID=$(echo $CONFIRM_EXIST | awk -F ':' '{print $2}')
  sudo useradd $SET_USER_NAME -c $SET_USER_NAME -s /bin/bash -m -d /mnt/raid6/$SET_USER_NAME -u $UNIQUE_UID -g users
  sudo usermod -aG docker $SET_USER_NAME
  echo -e "1234\n1234\n" | sudo passwd $SET_USER_NAME
  sudo passwd -e $SET_USER_NAME
else
  # 존재하지 않는 계정인 경우, unique_id를 할당하고, 기록함
  UNIQUE_UID=$(tail /data/sjy/passwd/all_user_ids -n 1 | awk -F ':' '{print $2+1}')
  sudo useradd $SET_USER_NAME -c $SET_USER_NAME -s /bin/bash -m -d /mnt/raid6/$SET_USER_NAME -u $UNIQUE_UID -g users
  sudo usermod -aG docker $SET_USER_NAME
  echo -e "1234\n1234\n" | sudo passwd $SET_USER_NAME
  sudo passwd -e $SET_USER_NAME
  # unique ids 파일 업데이트
  echo "${SET_USER_NAME}:${UNIQUE_UID}" | tee -a /data/sjy/passwd/all_user_ids
fi

echo "[Process complete] User ${SET_USER_NAME} is added with unique id (${UNIQUE_UID})"
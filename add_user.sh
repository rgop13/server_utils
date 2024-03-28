#!/bin/bash
SET_USER_NAME=$1
SET_HOMEDIR=/mnt/raid6/$SET_USER_NAME

# unique uid를 설정한다. 
if [[ "$(hostname)" == "nlp-server-6" ]]; then
	echo "Server 6: Process Unique uid"
	ALL_USERS_FILE=/data/sjy/passwd/all_user_ids
	SET_UID=$(tail $ALL_USERS_FILE -n 1 | awk -F ':' '{print $2+1}')
	echo "@SET_USER_NAME:$SET_UID" | tee -a $ALL_USERS_FILE
	echo "Server 6: Set UID is Done!"
else
	echo "The others are waiting! (2s)"
	sleep 2s

	# get uid
	echo "The others: watting is Done! Let's read the new UID"
	SET_UID=$(tail $ALL_USERS_FILE -n 1 | awk -F ':' '{print $2}')
fi

# useradd
mkdir $SET_HOMEDIR -p -m 755
useradd -d $SET_HOMEDIR -g users -u $SET_UID
chown $SET_USER_NAME:users $SET_HOMEDIR
usermod -aG docker $SET_USER_NAME

# 마지막에 출력
cat /etc/passwd | grep $SET_USER_NAME
echo "Done! ($SET_USER_NAME:$SET_UID)"
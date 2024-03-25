#!/bin/bash

# 삭제 대상 파일/경로들을 저장할 배열입니다.
ARGS=("$@")
TARGET_TO_DELETE=()

# '-f'를 포함하는 인자가 있다면, 'f'를 제외한 모든 인자를 삭제 대상으로 간주합니다.
for ARG in "${ARGS[@]}"; do
    if [[ "$ARG" != -* ]]; then # 옵션이 아닌 인자들만을 대상으로 추가합니다.
        TARGET_TO_DELETE+=("$ARG")
    fi
done

CURRENT_PATH_VERIFY=$(pwd)
echo "NLP&AI 서버관리자: 정말로 지우시겠습니까?"
echo "  중요한 경로가 잘못 입력된 것은 아닌지, 아래 삭제 대상 목록을 다시 한 번 확인 부탁드립니다."
echo "  현재 위치한 경로는 '$CURRENT_PATH_VERIFY' 입니다. 절대 경로와 상대 경로를 다시 한 번 확인 부탁드립니다."
printf '    * 삭제 대상: %s\n' "${TARGET_TO_DELETE[@]}"
read -p "      -> 동의(Y/y) | 비동의(N/n)을 타이핑하세요: " CONFIRM_DELETE

if [[ $CONFIRM_DELETE =~ ^[Yy]$ ]]; then
	echo "다음 문장을 타이핑하세요: \"Yes, I confirm\""
	read CONFIRM_TEXT
	
	if [ "$CONFIRM_TEXT" == "Yes, I confirm" ]; then
		/bin/rm $*
	fi
fi

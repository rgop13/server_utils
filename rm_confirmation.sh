#!/bin/bash

# 사용자가 입력한 모든 인자를 저장합니다.
ARGS=("$@")

# '-f'를 포함하는 인자가 있는지 검사합니다.
FORCE_DELETE=0
for ARG in "${ARGS[@]}"; do
    if [[ "$ARG" == -*f* ]]; then
        FORCE_DELETE=1
        break
    fi
done

# '-f' 인자가 없다면 'rm -i'로 실행합니다.
if [ "$FORCE_DELETE" -eq 0 ]; then
    /bin/rm -i "${ARGS[@]}"
    exit $?
fi

# 삭제 대상 파일/경로들을 저장할 배열입니다.
PATH_TO_DELETE=()

# '-f'를 포함하는 인자가 있다면, 'f'를 제외한 모든 인자를 삭제 대상으로 간주합니다.
if [ "$FORCE_DELETE" -eq 1 ]; then
    for ARG in "${ARGS[@]}"; do
        if [[ "$ARG" != -* ]]; then # 옵션이 아닌 인자들만을 대상으로 추가합니다.
            PATH_TO_DELETE+=("$ARG")
        fi
    done
    
    echo "NLPAI 서버관리자: 아래의 항목을 진짜로 정말로 지우실 겁니까? 신중하게 검토하세요."
    printf '삭제 대상: %s\n' "${PATH_TO_DELETE[@]}"
    read -p "[Y/N]: " CONFIRM_DELETE

    if [[ $CONFIRM_DELETE =~ ^[Yy]$ ]]; then
        echo "오호라.. 그렇다면 다음의 문장을 타이핑하세요: \"Yes, I confirm\""
        read CONFIRM_TEXT

        if [ "$CONFIRM_TEXT" == "Yes, I confirm" ]; then
            /bin/rm "${ARGS[@]}"
            echo "The specified items have been deleted."
        else
            echo "Deletion cancelled."
        fi
    else
        echo "Deletion cancelled."
    fi
fi
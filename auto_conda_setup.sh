#!/bin/bash
# 도커 컨테이너 생성할 때 자동으로 conda configuration 하는 쉘 스크립트
# 20240323 (토) created by 손준영
# 이렇게 배려 넘치는 서버 관리자라니...

# 스크립트에 전달된 첫 번째와 두 번째 인자를 각각 USER_NAME과 USER_ID 변수에 할당
USER_NAME=$1

# ~/.bashrc 파일의 경로를 정의
BASHRC_PATH="$HOME/.bashrc"

# conda 경로를 확인하고 초기화 스크립트를 추가하는 함수
function initialize_conda() {
    CONDA_PATH=$1
    echo "Conda found at $CONDA_PATH, initializing..."

    # ~/.bashrc 파일에 conda 초기화 스크립트를 추가
    {
        echo "# >>> conda initialize >>>"
        echo "# !! Contents within this block are managed by 'conda init' !!"
        echo "__conda_setup=\"\$('$CONDA_PATH/conda' 'shell.bash' 'hook' 2> /dev/null)\""
        echo "if [ \$? -eq 0 ]; then"
        echo "    eval \"\$__conda_setup\""
        echo "else"
        echo "    if [ -f \"\$CONDA_PATH/etc/profile.d/conda.sh\" ]; then"
        echo "        . \"\$CONDA_PATH/etc/profile.d/conda.sh\""
        echo "    else"
        echo "        export PATH=\"\$CONDA_PATH/bin:\$PATH\""
        echo "    fi"
        echo "fi"
        echo "unset __conda_setup"
        echo "# <<< conda initialize <<<"
    } >> "$BASHRC_PATH"
}

# /data/$USER_NAME/miniconda3와 /data/$USER_NAME/anaconda3 경로의 존재 여부를 검사
if [ -d "/data/$USER_NAME/miniconda3/bin" ]; then
    initialize_conda "/data/$USER_NAME/miniconda3"
elif [ -d "/data/$USER_NAME/anaconda3/bin" ]; then
    initialize_conda "/data/$USER_NAME/anaconda3"
elif [ -d "/mnt/raid6/$USER_NAME/anaconda3/bin" ]; then
    initialize_conda "/mnt/raid6/$USER_NAME/anaconda3"
elif [ -d "/mnt/raid6/$USER_NAME/miniconda3/bin" ]; then
    initialize_conda "/mnt/raid6/$USER_NAME/miniconda3"
else
    # Miniconda가 설치되어 있지 않으면 설치를 진행
    echo "Conda not found, installing Miniconda..."
    bash <(curl -s https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh) -b -p "$HOME/miniconda3"

    # 새로 설치된 Miniconda를 초기화
    initialize_conda "$HOME/miniconda3"
fi

# 스크립트 실행 권한 및 소유권 설정
chown $USER_NAME:users "$BASHRC_PATH"
chmod 644 "$BASHRC_PATH"

echo "Conda environment setup completed for $USER_NAME."
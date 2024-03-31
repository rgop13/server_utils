#!/usr/bin/python
import os
import yaml
import socket
import getpass
import argparse
from typing import List


def set_container_name(user_name: str, container_name_list: List[str] = None) -> str:
    container_name = user_name
    break_point = False
    while True:
        print(f"생성할 컨테이너 이름을 입력하세요. (현재 설정값: {container_name})")
        temp_name = input(f"  * 입력하지 않으실 경우 기본값으로 생성됩니다! 변경이 필요하신 경우에만 새롭게 입력하세요!: ")
        if temp_name == '':
            temp_name = user_name
            break_point = True
        else:
            print(f"  * 입력된 컨테이너 이름: {temp_name}")
            conf = input(f"  * 위 값으로 컨테이너를 생성하시겠습니까? [Yy/Nn]: ")
            if conf in ["Y", "y"]:
                break_point = True
        if container_name_list is not None and temp_name in container_name_list:
            print(f"[ERROR] \'{container_name}\'은 이미 존재하는 컨테이너입니다.")
            break_point = False
        elif break_point is True:
            container_name = temp_name
            break
    return container_name


def set_image_path():
    print("도커 이미지 경로를 입력하세요. (아래 기입된 번호 or 도커 이미지 경로)")
    print("  1. nvidia/cuda:11.1.1-cudnn8-devel-ubuntu20.04")
    print("  2. nvidia/cuda:12.3.2-cudnn9-devel-ubuntu20.04")
    print("  혹은 도커 이미지 경로: nvidia/cuda:11.6.1-cudnn8-devel-ubuntu20.04 처럼 full path를 입력")
    choice = input("Choose or input full image path: ")
    if choice == '1':
        image_path = "nvidia/cuda:11.1.1-cudnn8-devel-ubuntu20.04"
    elif choice == '2':
        image_path = "nvidia/cuda:12.3.2-cudnn9-devel-ubuntu20.04"
    else:
        image_path = choice

    return image_path


if __name__ == '__main__':
    user_name = getpass.getuser()
    target_server = socket.gethostname()[-2:].replace('-', '')
    os.system("echo \"현재 위치한 서버는 \'$(hostname)\' 입니다.\"")
    os.system("echo \"현재 로그인한 계정은 \'$(whoami)\' 입니다.\"")

    target_yaml_path = f'/data/sjy/dockerfile/srv{target_server}/docker-compose.yaml'
    with open(target_yaml_path, 'r') as f:
        compose_config = yaml.load(f, Loader=yaml.FullLoader)

    services = compose_config['services']

    # 0. Docker image path 입력
    image_path = set_image_path()
    set_cname = set_container_name(user_name)

    # 1. 이미 존재하는 컨테이너라면? 삭제 혹은 이름 변경 요청
    if set_cname in services.keys():
        print(f"\'{set_cname}\'은 이미 존재하는 컨테이너입니다. 기존 컨테이너를 삭제하거나, 새롭게 만들 컨테이너 이름을 변경하세요.")
        print("1. 기존 컨테이너 정보를 삭제 후 새롭게 생성한다.")
        print("2. 컨테이너 이름을 변경한 뒤 변경한 이름으로 컨테이너를 생성한다.")
        select = input("삭제: 1 | 이름 변경: 2 를 입력하세요: ")
        if select == '1':
            # 1. 삭제
            services.pop(set_cname)
            os.system(f"sudo docker stop {set_cname}")
            os.system(f"sudo docker rm {set_cname}")
            with open(target_yaml_path, 'w') as f:
                yaml.dump({
                    'services': services,
                }, f)
            os.system(f"chmod 777 {target_yaml_path}")
            os.system("sudo docker image prune -af")
            print(f"Docker container {set_cname}가 stop, rm 처리 되었고, docker-compose.yaml 서비스 목록에서 제거되었습니다.")
        elif select == '2':
            # 2. 이름 변경
            set_cname = set_container_name(user_name, list(services.keys()))
        else:
            print("Error!")
            exit(0)

    # 2. 새롭게 만드는 단계
    # HOME DIRECTORY 찾기
    home_dir = f"/mnt/raid6/{user_name}"
    with open('/etc/passwd', 'r') as f:
        for line in f:
            u = line.split(':')
            uname = u[0]
            uid = u[2]
            home_dir = u[5]
            if uname == user_name:
                break
    # dockerfile 만들기
    with open('/data/sjy/dockerfile/dockerfile', 'r') as f:
        dockerfile = f.readlines()
        dockerfile[0] = f"FROM {image_path}"
    target_dockerfile_name = f"dockerfile-{image_path.replace('/', '-')}"
    with open(f"/data/sjy/dockerfile/{target_dockerfile_name}", 'w') as f:
        f.writelines(dockerfile)
    os.system(f"chmod 777 /data/sjy/dockerfile/{target_dockerfile_name}")
    os.system(f"chown root:users /data/sjy/dockerfile/{target_dockerfile_name}")
    service = {
        "image": image_path,
        "build": {
            "context": "/data/sjy/dockerfile",
            "dockerfile": target_dockerfile_name,
            "args": {"USER_NAME": user_name}
        },
        'container_name': set_cname,
        "network_mode": "host",
        "user": user_name,
        "environment": {
            "TRANSFORMERS_CACHE": f"/mnt/raid6/{user_name}/.cache",
            "PIP_CACHE_DIR": f"/mnt/raid6/{user_name}/.cache",
            "CACHE_DIR": f"/mnt/raid6/{user_name}/.cache",
            "HOME": home_dir,
        },
        "volumes": [
            '/data:/data:rw', '/mnt/raid6:/mnt/raid6:rw', '/home:/home:rw'
        ],
        "deploy": {
            "resources": {
                "reservations": {
                    "devices": [{'driver': 'nvidia', 'capabilities': ['gpu']}]
                }
            }
        },
        'stdin_open': True,
        'tty': True,
        'command': '/bin/bash'
    }
    services[set_cname] = service
    with open(target_yaml_path, 'w') as f:
        yaml.dump({
            'services': services
        }, f)
    os.system(f"chmod 777 {target_yaml_path}")

    # 도커 자동 실행
    os.system(f'sudo docker compose -f {target_yaml_path} up --build -d {set_cname}')
    os.system(f'sudo docker compose -f {target_yaml_path} ps')

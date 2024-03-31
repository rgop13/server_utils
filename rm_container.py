#!/usr/bin/python
import os
import yaml
import socket
import getpass
import argparse
from typing import List


if __name__ == '__main__':
    user_name = getpass.getuser()
    target_server = socket.gethostname()[-2:].replace('-', '')
    os.system("echo \"현재 위치한 서버는 \'$(hostname)\' 입니다.\"")
    os.system("echo \"현재 로그인한 계정은 \'$(whoami)\' 입니다.\"")

    target_yaml_path = f'/data/sjy/dockerfile/srv{target_server}/docker-compose.yaml'
    with open(target_yaml_path, 'r') as f:
        compose_config = yaml.load(f, Loader=yaml.FullLoader)

    services = compose_config['services']
    container_list = list(services.keys())
    target_yaml_path = f'/data/sjy/dockerfile/srv{target_server}/docker-compose.yaml'
    os.system(f"sudo docker compose -f {target_yaml_path} ps")
    print("현재 서버에 등록된 컨테이너 목록은 다음과 같습니다:", container_list)
    while True:
        to_delete_container = input("어떤 컨테이너를 지우시겠습니까? ")
        if to_delete_container in container_list:
            break
        else:
            print("컨테이너 이름이 잘못되었습니다. 다시 입력하세요.")
    services.pop(to_delete_container)
    os.system(f"sudo docker stop {to_delete_container}")
    os.system(f"sudo docker rm {to_delete_container}")
    with open(target_yaml_path, 'w') as f:
        yaml.dump({
            'services': services,
        }, f)
    print(f"Docker container {to_delete_container}가 stop, rm 처리 되었고, srv{target_server}/docker-compose.yaml 서비스 목록에서 제거되었습니다.")

#!/bin/bash

RUNNER_SUBNET=192.168.122.0/24

sudo apt update && sudo apt install tinyproxy -y

sudo sed -i "/Port/s/8888/8080/g" /etc/tinyproxy/tinyproxy.conf
sudo sed -i "/Allow ::1/a Allow $RUNNER_SUBNET" /etc/tinyproxy/tinyproxy.conf

sudo systemctl restart tinyproxy
sudo systemctl enable tinyproxy
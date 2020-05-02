#!/bin/bash

# Register QEMU virtualization extensions
sudo docker run --rm --privileged multiarch/qemu-user-static:register

kubectl_ver=${kubectl_ver:-$(curl "https://storage.googleapis.com/kubernetes-release/release/stable.txt")}
build_date=${build_date:-$(date +"%Y%m%dT%H%M%S")}

for docker_arch in amd64 arm32v7 arm64v8; do
    case ${docker_arch} in
        amd64   ) qemu_arch="x86_64"  kubectl_arch="amd64" ;;
        arm32v7 ) qemu_arch="arm"     kubectl_arch="arm"   ;;
        arm64v8 ) qemu_arch="aarch64" kubectl_arch="arm64" ;;    
    esac
    cp Dockerfile.cross Dockerfile.${docker_arch}
    sed -i "s|__BASEIMAGE_ARCH__|${docker_arch}|g" Dockerfile.${docker_arch}
    sed -i "s|__QEMU_ARCH__|${qemu_arch}|g" Dockerfile.${docker_arch}
    sed -i "s|__KUBECTL_VER__|${kubectl_ver}|g" Dockerfile.${docker_arch}
    sed -i "s|__KUBECTL_ARCH__|${kubectl_arch}|g" Dockerfile.${docker_arch}
    sed -i "s|__BUILD_DATE__|${build_date}|g" Dockerfile.${docker_arch}
    if [ ${docker_arch} == 'amd64' ]; then
        sed -i "/__CROSS__/d" Dockerfile.${docker_arch}
        cp Dockerfile.${docker_arch} Dockerfile
    else
        sed -i "s/__CROSS__//g" Dockerfile.${docker_arch}
    fi


    # Check for qemu static bins
    if [[ ! -f qemu-${qemu_arch}-static ]]; then
        echo "Downloading the qemu static binaries for ${docker_arch}"
        wget -q -N https://github.com/multiarch/qemu-user-static/releases/download/v4.0.0-4/x86_64_qemu-${qemu_arch}-static.tar.gz
        tar -xvf x86_64_qemu-${qemu_arch}-static.tar.gz
        rm x86_64_qemu-${qemu_arch}-static.tar.gz
    fi

    # Build
    if [ "$EUID" -ne 0 ]; then
        sudo docker build -f Dockerfile.${docker_arch} -t lucashalbert/kube-backup:${docker_arch}-${kube_backup_ver} .
        #sudo docker push lucashalbert/kube-backup:${docker_arch}
    else
        docker build -f Dockerfile.${docker_arch} -t lucashalbert/kube-backup:${docker_arch}-${kube_backup_ver} .
        #docker push lucashalbert/kube-backup:${docker_arch}
    fi
done

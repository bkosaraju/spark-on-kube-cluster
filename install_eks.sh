#!/bin/bash
echo "Starated deploying eks cluster at $(date +'%Y-%m-%d %H:%M:%S') "
terraform apply  -auto-approve eks-build || terraform apply -auto-approve eks-build
echo "Completed deploying eks cluster at $(date +'%Y-%m-%d %H:%M:%S') "
echo "Starated preparing cluster at $(date +'%Y-%m-%d %H:%M:%S') "
./post_install.sh
echo "completed preprating  cluster at $(date +'%Y-%m-%d %H:%M:%S') "
echo "Sleeping a minute for services to up for DNS entry creation"
sleep 60
cd post-build 
terraform  apply -auto-approve
cd ../

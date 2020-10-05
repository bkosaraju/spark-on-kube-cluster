#!/bin/bash
echo "Starated deploying eks cluster at $(date +'%Y-%m-%d %H:%M:%S') "
terraform apply -auto-approve
terraform apply -auto-approve 
echo "Completed deploying eks cluster at $(date +'%Y-%m-%d %H:%M:%S') "
echo "Starated preparing cluster at $(date +'%Y-%m-%d %H:%M:%S') "
./post_install.sh
echo "completed preprating  cluster at $(date +'%Y-%m-%d %H:%M:%S') "


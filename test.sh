#!/bin/bash

stack=k8sTestStack

echo "Creating stack ${stack}..."
aws-vault exec test.ben.scalefactory.net -- aws cloudformation create-stack --stack-name $stack --template-body file://./k8s_test_cf_template.json


echo "Waiting for ${stack}...."
stack_status=""
until [[ "$stack_status" == "CREATE_COMPLETE" ]]; do
  stack_status=$(aws-vault exec test.ben.scalefactory.net -- aws cloudformation describe-stacks --stack-name $stack --query "Stacks[?StackName=='${stack}'].StackStatus" --output text)
done

echo "Waiting a bit more..."
sleep 60

echo "copying down k8s config..."

until scp -o StrictHostKeyChecking=no centos@$(aws-vault exec test.ben.scalefactory.net -- aws cloudformation describe-stacks --stack-name $stack --query "Stacks[?StackName=='${stack}'].Outputs[] | [?OutputKey=='k8smasterDNS'].OutputValue" --output text):.kube/config ./config; do
  echo "Trying to copy-down k8s config."
done

echo "Testing k8s admin..." 
if kubectl --kubeconfig=config cluster-info; then
  echo "Deleting ${stack}..."
  aws-vault exec test.ben.scalefactory.net -- aws cloudformation delete-stack --stack-name $stack
  exit 0
else
  echo "Something went wrong"
  exit 1
fi

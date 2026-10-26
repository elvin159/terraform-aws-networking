# About

This directory will house a modular terraform module. It needs to be production quality. It must be used to assume that we will be using multiple AWS accounts for development staging and production. One AWS account per environment. It needs to abide by the keep it simple stupid principle of system administration. Terraform code needs to be clean. Versions need to be pinned. We will be using OIDC and DO NOT rely on AWS secrets 

# Function

This module will create Multi-AZ VPC subnets tagged for ALB auto-discovery ( kubernetes.io/role/elb & internal-elb ). For dev we only want one region us-east-1, for staging we want us-east-1 and us-west-1. Staging must mimic production as closely as possible. We want to make sure we have enough room for rfc1918 addresses for proper scaling in kubernetes. 

# README.md

this file will need to keep it simple stupid on how to source the module and use it for different envrionments. 

# github actions

 create a github workflow file in this folder. I want it simple. Seperate jobs to make sure terraform fmt is ran, validate, and a plan. It will OIDC to
  authenticate when planning. I want the terraform plan to only happen when there is a PR opened or when new commits are push to the branch that wants to be merged into main. I want a terraform apply to only happen when the merge happens with proper approvals. 




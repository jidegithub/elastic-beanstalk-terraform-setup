#!/bin/bash
# Cleans directory

rm -fr *.tfstate
rm -fr *.tfstate.*
rm -fr *.tfplan
rm -fr .terraform.lock.hcl
rm -fr .terraform
# rm -fr *.zip
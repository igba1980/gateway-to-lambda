# gateway-to-lambda

## Overview
This project sets up an AWS Lambda function with an API Gateway integration. It includes Terraform configurations to manage infrastructure and Python code for the Lambda function.

## Project Structure
. ├── lambda/ # Contains the Lambda function code and dependencies │ ├── converter.py # Main Python script for the Lambda function │ ├── requirements.txt # Python dependencies for the Lambda function │ └── converter.zip # Zipped Lambda function code (generated) ├── layer/ # Contains Lambda Layer dependencies ├── main.tf # Terraform configuration for resources ├── provider.tf # Terraform provider configuration ├── lambda-policy.json # IAM policy for the Lambda function ├── README.md # Project documentation └── all-files.txt # File hash records

## Prerequisites
- Terraform installed
- Python 3.x installed
- AWS CLI configured with appropriate permissions

## Setup Instructions
1. Install Python dependencies:
   ```sh
   python3 -m pip install -r lambda/requirements.txt -t layer/python


2. Initialize Terraform:
```
terraform init
```
3. Apply the Terraform configuration:

```
terraform apply
```

Lambda Function
The Lambda function is implemented in converter.py. It processes requests and integrates with the API Gateway.

API Gateway
The API Gateway is configured in Terraform to expose the Lambda function as a REST API.



#!/bin/sh

# This script checks that prerequisites exist to ensure that
# the Anthos Sample Deployment is successfully deployed.
#
# Example usage:
# ./asd-prereq-checker.sh

SERVICE_MANAGEMENT_API=servicemanagement.googleapis.com

PROJECT_ID=$(gcloud config get-value project)

DISABLED_SERVICE_MANAGEMENT_API="{
  'KnownIssueId': 'disabled_service_management_api',
  'Message': 'Service Management API is not enabled. You must enable this API in the current project. https://console.cloud.google.com/apis/api/servicemanagement.googleapis.com/overview?project=$PROJECT_ID '
}"

INVALID_ORG_POLICY_OSLOGIN="{
  'KnownIssueId': 'invalid_org_policy_requireOsLogin',
  'Message': 'An org policy (constraints/compute.requireOsLogin) exists that will prevent this deployment.  Please try this deployment in a project without this org policy.'
}"

INVALID_ORG_POLICY_IPFORWARD="{
  'KnownIssueId': 'invalid_org_policy_vmCanIpForward)',
  'Message': 'An org policy (constraints/compute.vmCanIpForward) exists that will prevent this deployment.  Please try this deployment in a project without this org policy.'
}"

DEPLOYMENT_ALREADY_EXISTS="{
  'KnownIssueId': 'deployment_already_exists',
  'Message': 'An instance of Anthos Sample Deployment already exists. You must delete the previous deployment before performing another deployment.  https://console.cloud.google.com/dm/deployments?project=$PROJECT_ID '
}"

INVALID_PROJECT_ID="{
  'KnownIssueId': 'invalid_project_id',
  'Message': 'There is a colon in the project id. Please try this deployment in a project without a colon in the project id.'
}"

function enable_compute_api {
  # This is needed to check on the network.
  {
    echo "Enabling Compute Engine API...this may take a few minutes."
    result=$(gcloud services enable compute.googleapis.com)
  } || {
    echo
    echo "FATAL: Please enable Compute API to complete the prerequisites checks.  https://console.cloud.google.com/apis/library/compute.googleapis.com?project=$PROJECT_ID "
    echo
    exit 1
  }
}

function check_iam_policy {
  # iam.serviceAccounts.create and iam.serviceAccounts.setIamPolicy are the
  # 2 permissions that need to be in place.  Sufficient to check them by
  # IAM roles.
  # the list default is unlimited, no paging
  result=$(gcloud iam roles list --format=json | grep "name")
  if [[ "$result" == *"roles/owner"* || "$result" == *"roles/editor"* || "$result" == *"roles/iam.serviceAccountAdmin"* ]]; then
    echo "PASS: User has permission to create service account with the required IAM policies."
  else
    echo
    echo "WARNING: Unable to verify if you have the necessary permission to create a service account with the required IAM policy. Please verify manually that you have iam.serviceAccounts.create and iam.serviceAccounts.setIamPolicy permissions, and then proceed with deployment.  https://console.cloud.google.com/iam-admin/iam?project=$PROJECT_ID  You can also disregard this warning, if you will be providing your own pre-existing service account."
    echo
  fi
}

function check_org_policy_is_valid {
  result=$(gcloud beta resource-manager org-policies describe compute.requireOsLogin --project=$PROJECT_ID --effective)
  if [[ "$result" == *"enforced: true"* ]]; then
    echo
    echo $INVALID_ORG_POLICY_OSLOGIN
    echo
    exit 1
  fi

  result=$(gcloud beta resource-manager org-policies describe compute.vmCanIpForward --project=$PROJECT_ID --effective)
  if [[ "$result" == *"DENY"* ]]; then
    echo
    echo $INVALID_ORG_POLICY_IPFORWARD
    echo
    exit 1
  fi

  echo "PASS: Org Policy will allow this deployment."
}

function check_service_management_api_is_enabled {
  # Getting json output removes an output of `Listed 0 items` that
  # goes to the terminal.
  result=$(gcloud services list --format=json --filter=name:$SERVICE_MANAGEMENT_API)
  if [[ "$result" != *"$SERVICE_MANAGEMENT_API"* ]]; then
    echo
    echo $DISABLED_SERVICE_MANAGEMENT_API
    echo
    exit 1
  else
    echo "PASS: Service Management API is enabled."
  fi
}

function check_deployment_does_not_exist {
  result=$(gcloud container clusters list --format=json --filter=name:anthos-sample-cluster1)
  if [[ "$result" == *"anthos-sample-cluster"* ]]; then
    echo
    echo $DEPLOYMENT_ALREADY_EXISTS
    echo
    exit 1
  else
    echo "PASS: Anthos Sample Deployment does not already exist."
  fi
}

function check_project_id_is_valid {
  if [[ "$PROJECT_ID" == *":"* ]]; then
    echo
    echo $INVALID_PROJECT_ID
    echo
    exit 1
  else
    echo "PASS: Project ID is valid, does not contain colon."
  fi
}

check_iam_policy
check_org_policy_is_valid
check_service_management_api_is_enabled
check_deployment_does_not_exist
check_project_id_is_valid
enable_compute_api

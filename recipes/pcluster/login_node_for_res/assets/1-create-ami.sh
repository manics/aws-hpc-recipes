#!/bin/bash

set -e

if [ $# -lt 2 ]; then
    echo "Usage: $0 <PC_CLUSTER_NAME> <RES_STACK_NAME>"
    exit 1
fi

DOCUMENT="EnableLoginNodeforRes"

# Execute the automation document
EXECUTION_ID=$(aws ssm start-automation-execution \
    --document-version \$DEFAULT \
    --parameters pcClusterName="$1",resStackName="$2" \
    --document-name "$DOCUMENT" \
    --query 'AutomationExecutionId' \
    --output text)

echo "[-] Automation execution started with ID: $EXECUTION_ID"

# Timeout after 15 minutes
TIMEOUT=900

# Set the initial start time
START_TIME=$(date +%s)
ELAPSED_TIME=0
WAITING_STATUS=("InProgress" "Pending" "Waiting")

while [[ $ELAPSED_TIME -le $TIMEOUT ]]; do
    AUTOMATION_STATUS=$(aws ssm get-automation-execution \
        --automation-execution-id "$EXECUTION_ID" \
        --query 'AutomationExecution.AutomationExecutionStatus' \
        --output text)

    # Check if automation status is not InProgress, Pending, Waiting

    if [[ ! "${WAITING_STATUS[@]}" =~ "$AUTOMATION_STATUS" ]]; then
        break
    fi

    echo "[-] Waiting for automation execution to complete... Retrying in 30s"
    sleep 30
    CURRENT_TIME=$(date +%s)
    ELAPSED_TIME=$((CURRENT_TIME - START_TIME))
done

if [ "$ELAPSED_TIME" -ge $TIMEOUT ]; then
    echo "[!] Maximum wait time reached!"  
    echo "[!] Check SSM Execution ID: '${EXECUTION_ID}' for more details."
    exit 1
fi

if [ "$AUTOMATION_STATUS" != "Success" ]; then
    echo "[!] Automation execution failed with status: '$AUTOMATION_STATUS'"
    FAILURE_MSG=$(aws ssm get-automation-execution \
        --automation-execution-id "$EXECUTION_ID" \
        --query 'AutomationExecution.FailureMessage' \
        --output text)
    echo "[!] Failure message: $FAILURE_MSG"
    exit 1
fi

OUTPUTS=$(aws ssm get-automation-execution \
    --automation-execution-id "$EXECUTION_ID" \
    --query 'AutomationExecution.Outputs."createAMI.AMIImageId"[0]' \
    --output text)

echo "[-] Automation execution completed successfully."
echo "[-] Outputs: $OUTPUTS"
echo "Done!"

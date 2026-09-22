#!/usr/bin/env bash

ORG_NAME="MUTUAL-DE-SERVICIOS-AL-POLICIA"
BASE_BRANCH="testing"
HEAD_BRANCH="dev"
MERGE_METHOD="--merge" # Puedes cambiar a --squash o --rebase si tu empresa lo requiere

echo "=================================================="
echo " Starting Bulk PR Auto-Merge: $HEAD_BRANCH -> $BASE_BRANCH"
echo "=================================================="

# Recorrer todos los subdirectorios
for dir in */; do
    if [ ! -d "$dir" ]; then
        continue
    fi

    SERVICE_NAME="${dir%/}"

    # Omitir carpetas ocultas
    if [[ "$SERVICE_NAME" == .* ]]; then
        continue
    fi

    REPO_FULL_NAME="$ORG_NAME/$SERVICE_NAME"

    echo ""
    echo "--------------------------------------------------"
    echo " Processing service: $SERVICE_NAME"
    echo " Repository: $REPO_FULL_NAME"
    echo "--------------------------------------------------"

    # 1. Buscar el número del PR abierto de dev a testing
    PR_NUMBER=$(gh pr list --repo "$REPO_FULL_NAME" --base "$BASE_BRANCH" --head "$HEAD_BRANCH" --state open --json number --jq '.[0].number' 2>/dev/null)

    if [ -z "$PR_NUMBER" ] || [ "$PR_NUMBER" == "null" ]; then
        echo " ℹ️  No open PR found for $SERVICE_NAME ($HEAD_BRANCH -> $BASE_BRANCH)."
        continue
    fi

    echo "[1/2] Found open PR #$PR_NUMBER in $SERVICE_NAME."

    # 2. Hacer merge del Pull Request
    echo "[2/2] Merging PR #$PR_NUMBER..."
    MERGE_RESULT=$(gh pr merge "$PR_NUMBER" --repo "$REPO_FULL_NAME" $MERGE_METHOD --auto 2>&1)

    if [ $? -eq 0 ]; then
        echo " ✅ PR #$PR_NUMBER merged successfully!"
    else
        # Intentar merge directo sin la bandera --auto si la rama no requiere checks
        MERGE_RESULT_DIRECT=$(gh pr merge "$PR_NUMBER" --repo "$REPO_FULL_NAME" $MERGE_METHOD 2>&1)
        if [ $? -eq 0 ]; then
            echo " ✅ PR #$PR_NUMBER merged successfully!"
        else
            echo " ❌ Could not merge PR #$PR_NUMBER:"
            echo "    $MERGE_RESULT_DIRECT"
        fi
    fi
done

echo ""
echo "=================================================="
echo " Finished merging all PRs."
echo "=================================================="
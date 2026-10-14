#!/usr/bin/env bash

ORG_NAME="MUTUAL-DE-SERVICIOS-AL-POLICIA"
BASE_BRANCH="testing"
HEAD_BRANCH="dev"
PR_TITLE="Merge dev into testing"
PR_BODY="Promoción de los cambios de dev hacia testing."

# Guardar la ruta raíz
ROOT_DIR=$(pwd)

echo "=================================================="
echo " Starting Bulk PR Creation: $HEAD_BRANCH -> $BASE_BRANCH"
echo "=================================================="

# Recorrer todos los subdirectorios dentro de la raíz
for dir in */; do
    # Omitir si no es un directorio válido
    if [ ! -d "$dir" ]; then
        continue
    fi

    # Limpiar el nombre de la carpeta (quitar la barra final)
    SERVICE_NAME="${dir%/}"

    # Omitir la carpeta .git u otras ocultas si existen
    if [[ "$SERVICE_NAME" == .* ]]; then
        continue
    fi

    REPO_FULL_NAME="$ORG_NAME/$SERVICE_NAME"

    echo ""
    echo "--------------------------------------------------"
    echo " Processing service: $SERVICE_NAME"
    echo " Target Repository: $REPO_FULL_NAME"
    echo "--------------------------------------------------"

    # 1. Configurar gh para usar el repositorio objetivo de la empresa
    echo "[1/3] Setting GitHub CLI default repo to $REPO_FULL_NAME..."
    gh repo set-default "$REPO_FULL_NAME" 2>/dev/null

    # 2. Comprobar si ya existe un PR abierto entre dev y testing en GitHub
    echo "[2/3] Checking for existing pull requests on GitHub..."
    EXISTING_PR=$(gh pr list --repo "$REPO_FULL_NAME" --base "$BASE_BRANCH" --head "$HEAD_BRANCH" --state open --json url --jq '.[0].url' 2>/dev/null)

    if [ -n "$EXISTING_PR" ]; then
        echo " ℹ️  A PR already exists for $SERVICE_NAME: $EXISTING_PR"
    else
        # 3. Crear el Pull Request directamente en la API de GitHub
        echo "[3/3] Creating Pull Request ($HEAD_BRANCH -> $BASE_BRANCH)..."
        NEW_PR=$(gh pr create \
            --repo "$REPO_FULL_NAME" \
            --base "$BASE_BRANCH" \
            --head "$HEAD_BRANCH" \
            --title "$PR_TITLE" \
            --body "$PR_BODY" 2>&1)

        if [ $? -eq 0 ]; then
            echo " ✅ PR created successfully!"
            echo "    $NEW_PR"
        else
            echo " ❌ Failed to create PR:"
            echo "    $NEW_PR"
        fi
    fi
done

echo ""
echo "=================================================="
echo " Finished processing all services."
echo "=================================================="
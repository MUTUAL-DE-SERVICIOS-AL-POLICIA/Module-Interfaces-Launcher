#!/bin/bash

set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================
# COLORES
# ============================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================
# FUNCIONES
# ============================================================

print_line() {
    echo "------------------------------------------------------------"
}

# ============================================================
# DETECTAR PROYECTOS GIT
# ============================================================

PROJECTS=()

echo
echo -e "${CYAN}Buscando proyectos Git en:${NC}"
echo "$ROOT_DIR"
echo

for directory in "$ROOT_DIR"/*; do

    [ -d "$directory" ] || continue

    PROJECT_NAME="$(basename "$directory")"

    if git -C "$directory" rev-parse --is-inside-work-tree >/dev/null 2>&1; then

        PROJECTS+=("$directory")

        echo -e "${GREEN}✓${NC} $PROJECT_NAME"

    fi

done

echo

# ============================================================
# VALIDAR PROYECTOS
# ============================================================

if [ ${#PROJECTS[@]} -eq 0 ]; then

    echo -e "${RED}No se encontraron proyectos Git.${NC}"
    exit 1

fi

# ============================================================
# SELECCIONAR OPERACIÓN
# ============================================================

echo
print_line

echo -e "${CYAN}¿Qué deseas hacer?${NC}"
echo
echo "  1) Bajar cambios"
echo "  2) Subir cambios"
echo "  3) Salir"
echo

read -rp "Opción [1-3]: " ACTION_OPTION

case "$ACTION_OPTION" in

    1)
        ACTION="pull"
        ;;

    2)
        ACTION="push"
        ;;

    3)
        echo
        echo "Operación cancelada."
        exit 0
        ;;

    *)
        echo -e "${RED}Opción inválida.${NC}"
        exit 1
        ;;

esac

# ============================================================
# SELECCIONAR RAMA
# ============================================================

echo
print_line

echo -e "${CYAN}Selecciona la rama:${NC}"
echo
echo "  1) dev"
echo "  2) test"
echo "  3) main"
echo

read -rp "Opción [1-3]: " BRANCH_OPTION

case "$BRANCH_OPTION" in

    1)
        BRANCH="dev"
        ;;

    2)
        BRANCH="test"
        ;;

    3)
        BRANCH="main"
        ;;

    *)
        echo -e "${RED}Opción inválida.${NC}"
        exit 1
        ;;

esac

# ============================================================
# SELECCIONAR REMOTO
# ============================================================

echo
print_line

echo -e "${CYAN}Selecciona el remoto:${NC}"
echo
echo "  1) origin"
echo "  2) upstream"
echo

read -rp "Opción [1-2]: " REMOTE_OPTION

case "$REMOTE_OPTION" in

    1)
        REMOTE="origin"
        ;;

    2)
        REMOTE="upstream"
        ;;

    *)
        echo -e "${RED}Opción inválida.${NC}"
        exit 1
        ;;

esac

# ============================================================
# SELECCIONAR PROYECTOS
# ============================================================

echo
print_line

echo -e "${CYAN}Proyectos encontrados:${NC}"
echo

echo "  0) Todos los proyectos"

for i in "${!PROJECTS[@]}"; do

    PROJECT_NAME="$(basename "${PROJECTS[$i]}")"

    echo "  $((i + 1))) $PROJECT_NAME"

done

echo

read -rp "Selecciona proyecto [0-${#PROJECTS[@]}]: " PROJECT_OPTION

SELECTED_PROJECTS=()

if [ "$PROJECT_OPTION" = "0" ]; then

    SELECTED_PROJECTS=("${PROJECTS[@]}")

else

    if ! [[ "$PROJECT_OPTION" =~ ^[0-9]+$ ]] ||
       [ "$PROJECT_OPTION" -lt 1 ] ||
       [ "$PROJECT_OPTION" -gt "${#PROJECTS[@]}" ]; then

        echo -e "${RED}Proyecto inválido.${NC}"
        exit 1

    fi

    SELECTED_PROJECTS=(
        "${PROJECTS[$((PROJECT_OPTION - 1))]}"
    )

fi

# ============================================================
# SI ES PUSH -> PEDIR MENSAJE DE COMMIT
# ============================================================

COMMIT_MESSAGE=""

if [ "$ACTION" = "push" ]; then

    echo
    print_line

    echo -e "${CYAN}Mensaje del commit:${NC}"
    echo

    read -rp "Mensaje: " COMMIT_MESSAGE

    if [ -z "$COMMIT_MESSAGE" ]; then

        echo -e "${RED}El mensaje del commit no puede estar vacío.${NC}"
        exit 1

    fi

fi

# ============================================================
# RESUMEN
# ============================================================

echo
print_line

echo -e "${CYAN}Configuración seleccionada:${NC}"
echo

if [ "$ACTION" = "pull" ]; then
    echo "  Operación : BAJAR CAMBIOS"
else
    echo "  Operación : SUBIR CAMBIOS"
fi

echo "  Rama      : $BRANCH"
echo "  Remoto    : $REMOTE"

if [ "$ACTION" = "push" ]; then
    echo "  Commit    : $COMMIT_MESSAGE"
fi

echo
echo -e "${CYAN}Proyectos:${NC}"

for PROJECT in "${SELECTED_PROJECTS[@]}"; do
    echo "  - $(basename "$PROJECT")"
done

print_line

echo

read -rp "¿Continuar? [s/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then

    echo
    echo "Operación cancelada."
    exit 0

fi

# ============================================================
# RESULTADOS
# ============================================================

SUCCESS=()
FAILED=()
SKIPPED=()

# ============================================================
# PROCESAR PROYECTOS
# ============================================================

for PROJECT in "${SELECTED_PROJECTS[@]}"; do

    PROJECT_NAME="$(basename "$PROJECT")"

    echo
    echo
    print_line
    echo -e "${BLUE}PROYECTO: $PROJECT_NAME${NC}"
    echo "Ruta: $PROJECT"
    print_line

    cd "$PROJECT" || {

        echo -e "${RED}✗ No se pudo entrar al proyecto.${NC}"

        FAILED+=("$PROJECT_NAME")

        continue
    }

    # ========================================================
    # VERIFICAR REMOTO
    # ========================================================

    if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then

        echo
        echo -e "${RED}✗ El remoto '$REMOTE' no existe.${NC}"
        echo
        echo "Remotos disponibles:"
        git remote -v

        FAILED+=("$PROJECT_NAME")

        continue
    fi

    echo
    echo -e "${CYAN}Remoto:${NC}"
    git remote get-url "$REMOTE"

    # ========================================================
    # FETCH
    # ========================================================

    echo
    echo -e "${CYAN}→ Actualizando información de $REMOTE...${NC}"

    if ! git fetch "$REMOTE" --prune; then

        echo -e "${RED}✗ Error durante git fetch.${NC}"

        FAILED+=("$PROJECT_NAME")

        continue

    fi

    echo -e "${GREEN}✓ Fetch completado.${NC}"

    # ========================================================
    # VERIFICAR RAMA REMOTA
    # ========================================================

    if ! git show-ref --verify --quiet \
        "refs/remotes/$REMOTE/$BRANCH"; then

        echo
        echo -e "${RED}✗ La rama '$BRANCH' no existe en '$REMOTE'.${NC}"
        echo

        echo "Ramas disponibles:"
        git branch -r

        FAILED+=("$PROJECT_NAME")

        continue
    fi

    # ========================================================
    # VERIFICAR CAMBIOS LOCALES
    # ========================================================

    if [ -n "$(git status --porcelain)" ]; then

        echo
        echo -e "${YELLOW}Cambios locales detectados:${NC}"
        echo

        git status --short

    fi

    # ========================================================
    # ASEGURAR RAMA LOCAL
    # ========================================================

    if git show-ref --verify --quiet "refs/heads/$BRANCH"; then

        echo
        echo -e "${CYAN}→ Cambiando a rama $BRANCH...${NC}"

        if ! git switch "$BRANCH"; then

            echo -e "${RED}✗ No se pudo cambiar a $BRANCH.${NC}"

            FAILED+=("$PROJECT_NAME")

            continue
        fi

    else

        echo
        echo -e "${CYAN}→ Creando rama local $BRANCH...${NC}"

        if ! git switch --track -c "$BRANCH" "$REMOTE/$BRANCH"; then

            echo -e "${RED}✗ No se pudo crear la rama $BRANCH.${NC}"

            FAILED+=("$PROJECT_NAME")

            continue
        fi

    fi

    # ========================================================
    # CONFIGURAR TRACKING
    # ========================================================

    git branch --set-upstream-to="$REMOTE/$BRANCH" "$BRANCH" \
        >/dev/null 2>&1 || true

    # ========================================================
    # OPERACIÓN: PULL
    # ========================================================

    if [ "$ACTION" = "pull" ]; then

        echo
        echo -e "${CYAN}→ Verificando cambios locales...${NC}"

        if [ -n "$(git status --porcelain)" ]; then

            echo
            echo -e "${YELLOW}⚠ El proyecto tiene cambios locales.${NC}"
            echo
            echo -e "${YELLOW}Se omitirá para proteger tus cambios.${NC}"

            SKIPPED+=("$PROJECT_NAME")

            continue
        fi

        echo
        echo -e "${CYAN}→ Bajando cambios desde $REMOTE/$BRANCH...${NC}"

        if git pull --ff-only "$REMOTE" "$BRANCH"; then

            echo
            echo -e "${GREEN}✓ $PROJECT_NAME actualizado correctamente.${NC}"

            SUCCESS+=("$PROJECT_NAME")

        else

            echo
            echo -e "${RED}✗ No se pudo actualizar $PROJECT_NAME.${NC}"

            FAILED+=("$PROJECT_NAME")

        fi

    fi

    # ========================================================
    # OPERACIÓN: PUSH
    # ========================================================

    if [ "$ACTION" = "push" ]; then

        # ----------------------------------------------------
        # DETECTAR CAMBIOS
        # ----------------------------------------------------

        if [ -n "$(git status --porcelain)" ]; then

            echo
            echo -e "${CYAN}→ Agregando cambios...${NC}"

            git add .

            # ------------------------------------------------
            # COMMIT
            # ------------------------------------------------

            echo
            echo -e "${CYAN}→ Creando commit...${NC}"

            if git commit -m "$COMMIT_MESSAGE"; then

                echo -e "${GREEN}✓ Commit creado.${NC}"

            else

                echo -e "${RED}✗ No se pudo crear el commit.${NC}"

                FAILED+=("$PROJECT_NAME")

                continue
            fi

        else

            echo
            echo -e "${YELLOW}No existen archivos modificados.${NC}"

        fi

        # ----------------------------------------------------
        # VERIFICAR COMMITS PENDIENTES
        # ----------------------------------------------------

        AHEAD_COUNT=$(git rev-list --count "$REMOTE/$BRANCH..$BRANCH")

        if [ "$AHEAD_COUNT" -eq 0 ]; then

            echo
            echo -e "${YELLOW}No existen commits pendientes para subir.${NC}"

            SKIPPED+=("$PROJECT_NAME")

            continue
        fi

        echo
        echo -e "${CYAN}Commits pendientes: $AHEAD_COUNT${NC}"

        echo
        echo -e "${CYAN}→ Subiendo cambios a $REMOTE/$BRANCH...${NC}"

        # ----------------------------------------------------
        # PUSH
        # ----------------------------------------------------

        if git push "$REMOTE" "$BRANCH"; then

            echo
            echo -e "${GREEN}✓ $PROJECT_NAME subido correctamente.${NC}"

            SUCCESS+=("$PROJECT_NAME")

        else

            echo
            echo -e "${RED}✗ No se pudo subir $PROJECT_NAME.${NC}"
            echo
            echo "Posibles causas:"
            echo "  - No tienes permisos en el remoto."
            echo "  - El remoto tiene commits que no tienes."
            echo "  - La rama está protegida."
            echo "  - Existe un conflicto con el remoto."

            FAILED+=("$PROJECT_NAME")

        fi

    fi

done

# ============================================================
# RESUMEN FINAL
# ============================================================

echo
echo
echo -e "${CYAN}============================================================${NC}"
echo -e "${CYAN}                     RESUMEN FINAL${NC}"
echo -e "${CYAN}============================================================${NC}"

echo

echo -e "${GREEN}✓ PROCESADOS CORRECTAMENTE:${NC}"

if [ ${#SUCCESS[@]} -eq 0 ]; then

    echo "  Ninguno"

else

    for PROJECT in "${SUCCESS[@]}"; do
        echo "  ✓ $PROJECT"
    done

fi

echo

echo -e "${YELLOW}⚠ OMITIDOS:${NC}"

if [ ${#SKIPPED[@]} -eq 0 ]; then

    echo "  Ninguno"

else

    for PROJECT in "${SKIPPED[@]}"; do
        echo "  ⚠ $PROJECT"
    done

fi

echo

echo -e "${RED}✗ CON ERRORES:${NC}"

if [ ${#FAILED[@]} -eq 0 ]; then

    echo "  Ninguno"

else

    for PROJECT in "${FAILED[@]}"; do
        echo "  ✗ $PROJECT"
    done

fi

echo
print_line

echo -e "${GREEN}Proceso terminado.${NC}"
echo
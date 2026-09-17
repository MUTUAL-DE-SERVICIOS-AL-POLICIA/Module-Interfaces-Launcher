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

pause() {
    read -rp "Presiona ENTER para continuar..."
}

# ============================================================
# BUSCAR PROYECTOS GIT
# ============================================================

PROJECTS=()

for directory in "$ROOT_DIR"/*/; do

    [ -d "$directory" ] || continue

    if [ -d "${directory}.git" ]; then
        PROJECTS+=("$directory")
    fi

done

if [ ${#PROJECTS[@]} -eq 0 ]; then
    echo -e "${RED}No se encontraron proyectos Git.${NC}"
    exit 1
fi

# ============================================================
# SELECCIONAR RAMA
# ============================================================

echo
echo -e "${CYAN}==============================================${NC}"
echo -e "${CYAN}       ACTUALIZAR PROYECTOS GIT${NC}"
echo -e "${CYAN}==============================================${NC}"
echo

echo "Selecciona la rama:"
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
echo "Selecciona el origen remoto:"
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
echo "Proyectos encontrados:"
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

    SELECTED_PROJECTS=("${PROJECTS[$((PROJECT_OPTION - 1))]}")

fi

# ============================================================
# RESUMEN
# ============================================================

echo
print_line

echo -e "${CYAN}Configuración:${NC}"
echo
echo "  Rama   : $BRANCH"
echo "  Remoto : $REMOTE"
echo

echo "Proyectos a actualizar:"

for PROJECT in "${SELECTED_PROJECTS[@]}"; do
    echo "  - $(basename "$PROJECT")"
done

print_line

echo
read -rp "¿Continuar? [s/N]: " CONFIRM

if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
    echo "Operación cancelada."
    exit 0
fi

# ============================================================
# ACTUALIZAR PROYECTOS
# ============================================================

SUCCESS=()
FAILED=()
SKIPPED=()

for PROJECT in "${SELECTED_PROJECTS[@]}"; do

    PROJECT_NAME="$(basename "$PROJECT")"

    echo
    print_line
    echo -e "${BLUE}Proyecto: ${PROJECT_NAME}${NC}"
    echo "Ruta: $PROJECT"
    print_line

    cd "$PROJECT" || {
        echo -e "${RED}No se pudo entrar al proyecto.${NC}"
        FAILED+=("$PROJECT_NAME")
        continue
    }

    # --------------------------------------------------------
    # Verificar remoto
    # --------------------------------------------------------

    if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then

        echo -e "${RED}El remoto '$REMOTE' no existe.${NC}"
        echo
        echo "Remotos disponibles:"

        git remote -v

        FAILED+=("$PROJECT_NAME")
        continue

    fi

    echo -e "${CYAN}Remoto:${NC}"
    git remote -v | grep -E "^${REMOTE}[[:space:]]"

    # --------------------------------------------------------
    # Verificar cambios locales
    # --------------------------------------------------------

    if [ -n "$(git status --porcelain)" ]; then

        echo
        echo -e "${YELLOW}⚠ El proyecto tiene cambios locales.${NC}"
        echo

        git status --short

        echo
        echo -e "${YELLOW}Se omitirá para evitar sobrescribir cambios.${NC}"

        SKIPPED+=("$PROJECT_NAME")
        continue

    fi

    # --------------------------------------------------------
    # FETCH
    # --------------------------------------------------------

    echo
    echo -e "${CYAN}→ Descargando cambios desde $REMOTE...${NC}"

    if ! git fetch "$REMOTE" --prune; then

        echo -e "${RED}✗ Error haciendo fetch.${NC}"
        FAILED+=("$PROJECT_NAME")
        continue

    fi

    # --------------------------------------------------------
    # Verificar rama remota
    # --------------------------------------------------------

    if ! git show-ref --verify --quiet \
        "refs/remotes/$REMOTE/$BRANCH"; then

        echo -e "${RED}✗ La rama '$BRANCH' no existe en '$REMOTE'.${NC}"

        echo
        echo "Ramas disponibles en $REMOTE:"
        git branch -r | grep "$REMOTE/"

        FAILED+=("$PROJECT_NAME")
        continue

    fi

    # --------------------------------------------------------
    # Verificar rama local
    # --------------------------------------------------------

    if git show-ref --verify --quiet "refs/heads/$BRANCH"; then

        echo -e "${CYAN}→ Cambiando a rama $BRANCH...${NC}"

        if ! git switch "$BRANCH"; then

            echo -e "${RED}✗ No se pudo cambiar a $BRANCH.${NC}"
            FAILED+=("$PROJECT_NAME")
            continue

        fi

    else

        echo -e "${CYAN}→ Creando rama local $BRANCH...${NC}"

        if ! git switch --track -c "$BRANCH" "$REMOTE/$BRANCH"; then

            echo -e "${RED}✗ No se pudo crear la rama $BRANCH.${NC}"
            FAILED+=("$PROJECT_NAME")
            continue

        fi

    fi

    # --------------------------------------------------------
    # Configurar tracking
    # --------------------------------------------------------

    CURRENT_REMOTE="$(git config --get "branch.$BRANCH.remote" || true)"
    CURRENT_MERGE="$(git config --get "branch.$BRANCH.merge" || true)"

    if [ "$CURRENT_REMOTE" != "$REMOTE" ] ||
       [ "$CURRENT_MERGE" != "refs/heads/$BRANCH" ]; then

        echo -e "${CYAN}→ Configurando tracking:${NC}"
        echo "   $BRANCH -> $REMOTE/$BRANCH"

        if ! git branch --set-upstream-to="$REMOTE/$BRANCH" "$BRANCH"; then

            echo -e "${RED}✗ No se pudo configurar tracking.${NC}"
            FAILED+=("$PROJECT_NAME")
            continue

        fi

    fi

    # --------------------------------------------------------
    # PULL
    # --------------------------------------------------------

    echo
    echo -e "${CYAN}→ Aplicando cambios...${NC}"

    if git pull --ff-only "$REMOTE" "$BRANCH"; then

        echo
        echo -e "${GREEN}✓ $PROJECT_NAME actualizado correctamente.${NC}"

        SUCCESS+=("$PROJECT_NAME")

    else

        echo
        echo -e "${RED}✗ No se pudo actualizar $PROJECT_NAME.${NC}"
        echo
        echo "Probablemente existen commits locales que no están"
        echo "en la rama remota."

        FAILED+=("$PROJECT_NAME")

    fi

done

# ============================================================
# RESUMEN FINAL
# ============================================================

echo
echo
echo -e "${CYAN}==============================================${NC}"
echo -e "${CYAN}              RESUMEN FINAL${NC}"
echo -e "${CYAN}==============================================${NC}"

echo
echo -e "${GREEN}Actualizados correctamente:${NC}"

if [ ${#SUCCESS[@]} -eq 0 ]; then
    echo "  Ninguno"
else
    for PROJECT in "${SUCCESS[@]}"; do
        echo "  ✓ $PROJECT"
    done
fi

echo
echo -e "${YELLOW}Omitidos por cambios locales:${NC}"

if [ ${#SKIPPED[@]} -eq 0 ]; then
    echo "  Ninguno"
else
    for PROJECT in "${SKIPPED[@]}"; do
        echo "  ⚠ $PROJECT"
    done
fi

echo
echo -e "${RED}Con errores:${NC}"

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
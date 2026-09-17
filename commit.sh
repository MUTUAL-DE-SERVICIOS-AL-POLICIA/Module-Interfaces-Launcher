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
# SELECCIONAR PROYECTOS
# ============================================================

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
        echo -e "${RED}Opción de proyecto inválida.${NC}"
        exit 1
    fi

    SELECTED_PROJECTS=("${PROJECTS[$((PROJECT_OPTION - 1))]}")
fi

# ============================================================
# PEDIR MENSAJE DE COMMIT
# ============================================================

echo
print_line
echo -e "${CYAN}Mensaje del commit para los proyectos seleccionados:${NC}"
echo

read -rp "Mensaje: " COMMIT_MESSAGE

if [ -z "$COMMIT_MESSAGE" ]; then
    echo -e "${RED}El mensaje del commit no puede estar vacío.${NC}"
    exit 1
fi

# ============================================================
# RESUMEN
# ============================================================

echo
print_line
echo -e "${CYAN}Configuración seleccionada:${NC}"
echo "  Operación : ADD + COMMIT"
echo "  Commit    : $COMMIT_MESSAGE"
echo
echo -e "${CYAN}Proyectos a procesar:${NC}"

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

    # Verificar si hay cambios modificados, borrados o no rastreados
    if [ -z "$(git status --porcelain)" ]; then
        echo -e "${YELLOW}⚠ No hay cambios locales para registrar.${NC}"
        SKIPPED+=("$PROJECT_NAME")
        continue
    fi

    echo -e "${CYAN}→ Añadiendo archivos (git add .)...${NC}"
    git add .

    echo -e "${CYAN}→ Creando commit...${NC}"
    if git commit -m "$COMMIT_MESSAGE"; then
        echo -e "${GREEN}✓ Commit creado exitosamente en $PROJECT_NAME.${NC}"
        SUCCESS+=("$PROJECT_NAME")
    else
        echo -e "${RED}✗ Error al crear el commit en $PROJECT_NAME.${NC}"
        FAILED+=("$PROJECT_NAME")
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

echo -e "${GREEN}✓ COMMITS REALIZADOS:${NC}"
if [ ${#SUCCESS[@]} -eq 0 ]; then
    echo "  Ninguno"
else
    for PROJECT in "${SUCCESS[@]}"; do
        echo "  ✓ $PROJECT"
    done
fi

echo
echo -e "${YELLOW}⚠ SIN CAMBIOS (OMITIDOS):${NC}"
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
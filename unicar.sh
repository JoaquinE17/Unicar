#!/usr/bin/env bash

# ------------------------------------------------------------
# CONFIGURACIÓN
# ------------------------------------------------------------

UNICAR_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/unicar"
UNICAR_RUTAS_FILE="$UNICAR_CONFIG_DIR/rutas"

# Arrays asociativos
declare -gA UNICAR_RUTAS=()
declare -gA UNICAR_DESCRIPCIONES=()

# ============================================================
# CONFIGURACIÓN
# ============================================================

_unicar_crear_config() {
    mkdir -p -- "$UNICAR_CONFIG_DIR"
}

# ============================================================
# CARGAR RUTAS (letra<TAB>nombre<TAB>ruta)
# ============================================================

_unicar_cargar_rutas() {

    [[ -f "$UNICAR_RUTAS_FILE" ]] || return 0

    local letra
    local nombre
    local ruta

    while IFS=$'\t' read -r letra nombre ruta; do

        # Ignorar líneas vacías
        [[ -z "$letra" ]] && continue

        # Ignorar comentarios
        [[ "$letra" == \#* ]] && continue

        # Validar letra
        [[ "$letra" =~ ^[a-zA-Z]$ ]] || continue

        # Validar ruta
        [[ -n "$ruta" ]] || continue

        letra="${letra,,}"

        UNICAR_RUTAS["-$letra"]="$ruta"
        UNICAR_DESCRIPCIONES["-$letra"]="$nombre"

    done < "$UNICAR_RUTAS_FILE"
}

# ============================================================
# NORMALIZAR RUTA
# ============================================================

_unicar_normalizar_ruta() {

    local ruta="$1"

    [[ -n "$ruta" ]] || return 1

    # Expandir "~"
    if [[ "$ruta" == "~" ]]; then

        ruta="$HOME"

    elif [[ "$ruta" == "~/"* ]]; then

        ruta="$HOME/${ruta:2}"

    fi

    # Convertir a ruta absoluta
    (
        cd -- "$ruta" 2>/dev/null || exit 1
        pwd -P
    )
}

# ============================================================
# COMPROBAR LETRA
# ============================================================

_unicar_letra_ocupada() {

    local letra="${1,,}"

    [[ -n "${UNICAR_RUTAS[-$letra]+x}" ]]
}

# ============================================================
# SUGERIR LETRA
# ============================================================

_unicar_sugerir_letra() {

    local nombre="$1"
    local letra
    local i

    # Primero intenta utilizar letras del nombre
    for ((i = 0; i < ${#nombre}; i++)); do

        letra="${nombre:i:1}"
        letra="${letra,,}"

        [[ "$letra" =~ ^[a-z]$ ]] || continue

        if ! _unicar_letra_ocupada "$letra"; then
            printf '%s\n' "$letra"
            return 0
        fi

    done

    # Si no encuentra ninguna, busca cualquier letra
    for letra in {a..z}; do

        if ! _unicar_letra_ocupada "$letra"; then
            printf '%s\n' "$letra"
            return 0
        fi

    done

    return 1
}

# ============================================================
# AGREGAR RUTA
# ============================================================

_unicar_agregar_ruta() {

    _unicar_crear_config || {
        echo "No se pudo crear el directorio de configuración."
        return 1
    }

    echo
    echo "Agregar ruta personal"
    echo "====================="
    echo

    local nombre
    local ruta_input
    local ruta
    local sugerida
    local letra

    # --------------------------------------------------------
    # Nombre
    # --------------------------------------------------------

    read -erp "Nombre de la ruta: " nombre

    if [[ -z "$nombre" ]]; then
        echo "No se especificó un nombre."
        return 1
    fi

    # --------------------------------------------------------
    # Ruta
    # --------------------------------------------------------

    read -erp "Ruta: " ruta_input

    if [[ -z "$ruta_input" ]]; then
        echo "No se especificó una ruta."
        return 1
    fi

    ruta="$(_unicar_normalizar_ruta "$ruta_input")"

    if [[ -z "$ruta" ]]; then

        echo
        echo "La ruta no existe o no se puede acceder."
        return 1

    fi

    # --------------------------------------------------------
    # Sugerir letra
    # --------------------------------------------------------

    sugerida="$(_unicar_sugerir_letra "$nombre")"

    if [[ -z "$sugerida" ]]; then

        echo
        echo "No quedan letras disponibles."
        return 1

    fi

    # --------------------------------------------------------
    # Pedir letra
    # --------------------------------------------------------

    read -erp "Letra [$sugerida]: " letra

    [[ -z "$letra" ]] && letra="$sugerida"

    letra="${letra,,}"

    # --------------------------------------------------------
    # Validar letra
    # --------------------------------------------------------

    if [[ ! "$letra" =~ ^[a-z]$ ]]; then

        echo
        echo "La opción debe ser una única letra."
        return 1

    fi

    # --------------------------------------------------------
    # Comprobar si ya existe
    # --------------------------------------------------------

    if _unicar_letra_ocupada "$letra"; then

        echo
        echo "La opción '-$letra' ya está ocupada."
        echo "  ${UNICAR_DESCRIPCIONES[-$letra]}"
        echo "  ${UNICAR_RUTAS[-$letra]}"

        return 1

    fi

    # --------------------------------------------------------
    # Guardar en memoria
    # --------------------------------------------------------

    UNICAR_RUTAS["-$letra"]="$ruta"
    UNICAR_DESCRIPCIONES["-$letra"]="$nombre"

    # --------------------------------------------------------
    # Guardar permanentemente
    # --------------------------------------------------------

    if ! printf '%s\t%s\t%s\n' \
        "$letra" \
        "$nombre" \
        "$ruta" >> "$UNICAR_RUTAS_FILE"; then

        unset 'UNICAR_RUTAS[-'"$letra"']'
        unset 'UNICAR_DESCRIPCIONES[-'"$letra"']'

        echo
        echo "No se pudo guardar la ruta."
        return 1
    fi

    echo
    echo "Ruta registrada correctamente."
    echo
    printf '  %-4s %s\n' "-$letra" "$nombre"
    printf '  %-4s %s\n' "" "$ruta"
    echo
}

# ============================================================
# ELIMINAR RUTA
# ============================================================

_unicar_eliminar_ruta() {

    local letra="$1"

    letra="${letra#-}"
    letra="${letra,,}"

    if [[ ! "$letra" =~ ^[a-z]$ ]]; then

        echo "Uso: unicar --eliminar <letra>"
        return 1

    fi

    # --------------------------------------------------------
    # Comprobar existencia
    # --------------------------------------------------------

    if [[ -z "${UNICAR_RUTAS[-$letra]+x}" ]]; then

        echo "La opción '-$letra' no existe."
        return 1

    fi

    # --------------------------------------------------------
    # Archivo
    # --------------------------------------------------------

    if [[ ! -f "$UNICAR_RUTAS_FILE" ]]; then

        echo "No se encontró el archivo de rutas guardadas."
        return 1

    fi

    local archivo_tmp
    archivo_tmp="${UNICAR_RUTAS_FILE}.tmp.$$"

    # --------------------------------------------------------
    # Eliminar del archivo
    # --------------------------------------------------------

    if ! awk -F '\t' -v letra="$letra" '
        $1 != letra
    ' "$UNICAR_RUTAS_FILE" > "$archivo_tmp"; then

        rm -f -- "$archivo_tmp"

        echo "No se pudo modificar el archivo de rutas."
        return 1

    fi

    if ! mv -- "$archivo_tmp" "$UNICAR_RUTAS_FILE"; then

        rm -f -- "$archivo_tmp"

        echo "No se pudo actualizar el archivo de rutas."
        return 1

    fi

    # --------------------------------------------------------
    # Eliminar de memoria
    # --------------------------------------------------------

    unset 'UNICAR_RUTAS[-'"$letra"']'
    unset 'UNICAR_DESCRIPCIONES[-'"$letra"']'

    echo "Ruta '-$letra' eliminada."
}

# ============================================================
# LISTAR RUTAS
# ============================================================

_unicar_listar_rutas() {

    echo
    echo "Rutas de UNICAR"
    echo "==============="
    echo

    if (( ${#UNICAR_RUTAS[@]} == 0 )); then

        echo "No hay rutas personales configuradas."
        echo
        return 0

    fi

    printf 'Rutas guardadas: %d\n' "${#UNICAR_RUTAS[@]}"
    echo

    local opcion

    # Ordenar las opciones
    while IFS= read -r opcion; do

        printf '  %-4s %s\n' \
            "$opcion" \
            "${UNICAR_DESCRIPCIONES[$opcion]}"

        printf '       %s\n' \
            "${UNICAR_RUTAS[$opcion]}"

    done < <(
        printf '%s\n' "${!UNICAR_RUTAS[@]}" |
        sort
    )

    echo
}

# ============================================================
# AUTOCOMPLETADO DE DIRECTORIOS
# ============================================================

_unicar_completar_directorios() {

    local ruta="$1"
    local cur="$2"

    COMPREPLY=()

    [[ -d "$ruta" ]] || return 0

    local dir
    local nombre

    while IFS= read -r -d '' dir; do

        nombre="${dir##*/}"

        if [[ -z "$cur" || "$nombre" == *"$cur"* ]]; then

            COMPREPLY+=("$nombre")

        fi

    done < <(
        find "$ruta" \
            -maxdepth 1 \
            -mindepth 1 \
            -type d \
            -print0 2>/dev/null
    )

    # Permitir que Bash complete con los resultados
    compopt -o filenames 2>/dev/null
}

# ============================================================
# AUTOCOMPLETADO PRINCIPAL
# ============================================================

_unicar_completions() {

    local cur="${COMP_WORDS[COMP_CWORD]}"
    local opcion="${COMP_WORDS[1]}"
    local ruta=""
    local i

    # --------------------------------------------------------
    # unicar <TAB>
    # --------------------------------------------------------

    if (( COMP_CWORD == 1 )); then

        COMPREPLY=(
            "${!UNICAR_RUTAS[@]}"
            "--agregar"
            "--listar"
            "--eliminar"
            "--ayuda"
        )

        # Eliminar duplicados y completar prefijo
        local opciones=()
        local item

        for item in "${COMPREPLY[@]}"; do

            [[ "$item" == "$cur"* ]] &&
                opciones+=("$item")

        done

        COMPREPLY=("${opciones[@]}")

        return 0
    fi

    # --------------------------------------------------------
    # Comandos administrativos
    # --------------------------------------------------------

    case "$opcion" in

        --agregar|--listar|--ayuda|-h|--help)
            COMPREPLY=()
            return 0
            ;;

        --eliminar)

            if (( COMP_CWORD == 2 )); then

                COMPREPLY=()

                for item in "${!UNICAR_RUTAS[@]}"; do

                    [[ "$item" == "$cur"* ]] &&
                        COMPREPLY+=("$item")

                done

            fi

            return 0
            ;;

    esac

    # --------------------------------------------------------
    # Obtener ruta inicial
    # --------------------------------------------------------

    ruta="${UNICAR_RUTAS[$opcion]}"

    [[ -n "$ruta" ]] || return 0
    [[ -d "$ruta" ]] || return 0

    # --------------------------------------------------------
    # Resolver niveles anteriores
    # --------------------------------------------------------

    for ((i = 2; i < COMP_CWORD; i++)); do

        local siguiente=""

        while IFS= read -r -d '' dir; do

            local nombre="${dir##*/}"

            if [[ "${nombre,,}" == *"${COMP_WORDS[i],,}"* ]]; then

                siguiente="$dir"
                break

            fi

        done < <(
            find "$ruta" \
                -maxdepth 1 \
                -mindepth 1 \
                -type d \
                -print0 2>/dev/null
        )

        [[ -n "$siguiente" ]] || return 0

        ruta="$siguiente"

    done

    # --------------------------------------------------------
    # Completar nivel actual
    # --------------------------------------------------------

    _unicar_completar_directorios "$ruta" "$cur"
}

# ============================================================
# NAVEGACIÓN
# ============================================================

_unicar_navegar() {

    local ruta="$1"
    local descripcion="$2"

    shift 2

    # --------------------------------------------------------
    # Sin argumentos
    # --------------------------------------------------------

    if (( $# == 0 )); then

        cd -- "$ruta" || return 1

        return 0

    fi

    local nombre
    local target

    # --------------------------------------------------------
    # Resolver cada nivel
    # --------------------------------------------------------

    for nombre in "$@"; do

        target=""

        while IFS= read -r -d '' dir; do

            local nombre_dir="${dir##*/}"

            if [[ "${nombre_dir,,}" == *"${nombre,,}"* ]]; then

                target="$dir"
                break

            fi

        done < <(
            find "$ruta" \
                -maxdepth 1 \
                -mindepth 1 \
                -type d \
                -print0 2>/dev/null
        )

        if [[ -z "$target" ]]; then

            echo
            echo "No se pudo resolver la operación."
            echo "  ✓ $descripcion"
            echo "  ✗ $nombre"
            echo
            echo "Nota: el directorio '$nombre' no fue encontrado."
            echo

            return 1

        fi

        ruta="$target"

    done

    # --------------------------------------------------------
    # Entrar al último directorio
    # --------------------------------------------------------

    cd -- "$ruta" || return 1
}

# ============================================================
# AYUDA
# ============================================================

_unicar_ayuda() {

    echo
    echo "UNICAR - Navegación rápida"
    echo "=========================="
    echo

    echo "Uso:"
    echo "  unicar <opción> [directorio...]"
    echo

    echo "Ejemplos:"
    echo "  unicar -r"
    echo "  unicar -r proyectos"
    echo "  unicar -r proyectos cliente"
    echo

    echo "Rutas disponibles:"
    echo

    if (( ${#UNICAR_RUTAS[@]} == 0 )); then

        echo "  No hay rutas configuradas."

    else

        local opcion

        while IFS= read -r opcion; do

            printf '  %-4s %s\n' \
                "$opcion" \
                "${UNICAR_DESCRIPCIONES[$opcion]}"

        done < <(
            printf '%s\n' "${!UNICAR_RUTAS[@]}" |
            sort
        )

    fi

    echo
    echo "Gestión de rutas:"
    echo
    echo "  unicar --agregar"
    echo "      Agregar una ruta personal."
    echo
    echo "  unicar --listar"
    echo "      Mostrar todas las rutas."
    echo
    echo "  unicar --eliminar <letra>"
    echo "      Eliminar una ruta personal."
    echo
    echo "  unicar --ayuda"
    echo "      Mostrar esta ayuda."
    echo
}

# ============================================================
# COMANDO PRINCIPAL
# ============================================================

unicar() {

    local opcion="${1:-}"

    # --------------------------------------------------------
    # Sin argumentos
    # --------------------------------------------------------

    if [[ -z "$opcion" ]]; then

        _unicar_ayuda
        return 0

    fi

    # --------------------------------------------------------
    # Comandos administrativos
    # --------------------------------------------------------

    case "$opcion" in

        --agregar)

            _unicar_agregar_ruta
            return
            ;;

        --listar)

            _unicar_listar_rutas
            return
            ;;

        --eliminar)

            _unicar_eliminar_ruta "$2"
            return
            ;;

        --ayuda|-h|--help)

            _unicar_ayuda
            return
            ;;

    esac

    # --------------------------------------------------------
    # Resolver ruta
    # --------------------------------------------------------

    local ruta="${UNICAR_RUTAS[$opcion]}"
    local descripcion="${UNICAR_DESCRIPCIONES[$opcion]}"

    # --------------------------------------------------------
    # Opción inválida
    # --------------------------------------------------------

    if [[ -z "$ruta" ]]; then

        echo "Opción desconocida: $opcion"
        echo
        echo "Usá 'unicar --ayuda' para ver las opciones."

        return 1

    fi

    # --------------------------------------------------------
    # Verificar que la ruta siga existiendo
    # --------------------------------------------------------

    if [[ ! -d "$ruta" ]]; then

        echo
        echo "La ruta ya no existe:"
        echo "  $ruta"
        echo
        echo "Podés eliminarla con:"
        echo "  unicar --eliminar ${opcion#-}"
        echo

        return 1

    fi

    # --------------------------------------------------------
    # Navegar
    # --------------------------------------------------------

    shift

    _unicar_navegar \
        "$ruta" \
        "$descripcion" \
        "$@"
}

# ============================================================
# ACTIVAR AUTOCOMPLETADO
# ============================================================

if [[ -n "${BASH_VERSION:-}" ]]; then
    complete -F _unicar_completions unicar
fi

# ============================================================
# CARGAR RUTAS
# ============================================================

_unicar_cargar_rutas
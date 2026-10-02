# UNICAR

**UNICAR** es una función para Bash que permite crear accesos rápidos a directorios frecuentes y navegar entre ellos usando comandos cortos.

## Características

* 📁 Guardar rutas frecuentes con una letra.
* 🚀 Acceder rápidamente a una ruta con `unicar -x`.
* 🔎 Navegar por subdirectorios sin escribir la ruta completa.
* ⌨️ Autocompletado con `Tab`.
* 💾 Mantener las rutas guardadas entre sesiones.
* ➕ Agregar nuevas rutas.
* 📋 Listar las rutas configuradas.
* 🗑️ Eliminar rutas.
* 🌱 Soporte para `~` y rutas absolutas.

## Instalación

### 1. Descargar el script

Cloná el repositorio:

```bash
git clone https://github.com/USUARIO/REPOSITORIO.git
cd REPOSITORIO
```

### 2. Copiar el script

Por ejemplo:

```bash
mkdir -p ~/.local/bin
cp unicar.sh ~/.local/bin/unicar.sh
```

### 3. Cargar UNICAR en Bash

Agregá al final de `~/.bashrc`:

```bash
source ~/.local/bin/unicar.sh
```

Luego recargá Bash:

```bash
source ~/.bashrc
```

> **Importante:** UNICAR debe cargarse como función de Bash mediante `source`; no se ejecuta como un programa independiente.

## Uso

### Agregar una ruta

```bash
unicar --agregar
```

El script solicitará:

* Nombre de la ruta.
* Ruta del directorio.
* Letra para identificarla.

Si no indicás una letra, UNICAR propone una automáticamente.

### Navegar

Por ejemplo, si una ruta está registrada como `-p`:

```bash
unicar -p
```

También podés navegar directamente a subdirectorios:

```bash
unicar -p proyectos cliente
```

UNICAR busca los directorios por coincidencia de nombre, por lo que no es necesario escribir la ruta completa.

### Listar rutas

```bash
unicar --listar
```

### Eliminar una ruta

```bash
unicar --eliminar p
```

### Ver ayuda

```bash
unicar --ayuda
```

También:

```bash
unicar -h
```

## Autocompletado

Después de cargar el script, Bash registra automáticamente el autocompletado para `unicar`.

Podés utilizar:

```bash
unicar <TAB>
```

para ver las rutas y comandos disponibles.

También funciona al navegar por los subdirectorios:

```bash
unicar -p pro<TAB>
```

## Configuración

Las rutas se almacenan automáticamente en:

```text
~/.config/unicar/rutas
```

Si `XDG_CONFIG_HOME` está definido, se utiliza esa ubicación en su lugar.

## Comandos

| Comando               | Función                    |
| --------------------- | -------------------------- |
| `unicar -x`           | Ir a una ruta guardada     |
| `unicar -x dir`       | Navegar a un subdirectorio |
| `unicar --agregar`    | Agregar una ruta           |
| `unicar --listar`     | Listar rutas guardadas     |
| `unicar --eliminar x` | Eliminar una ruta          |
| `unicar --ayuda`      | Mostrar ayuda              |

## Requisitos

* Bash
* `find`
* `awk`
* `sort`

---

Hecho para simplificar la navegación por directorios frecuentes desde la terminal.

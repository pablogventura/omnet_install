# Scripts de instalación de OMNeT++

Este repositorio contiene scripts para instalar OMNeT++ 6.0.1 en sistemas Linux basados en Debian/Ubuntu.

## Opción 1: Instalación directa (script clásico)

### Requisitos

- Sistema operativo Linux (Debian/Ubuntu)
- Conexión a Internet

### Instrucciones

1. Ejecute el siguiente comando en la terminal para descargar y ejecutar el script:

   ```bash
   wget -qO- https://raw.githubusercontent.com/pablogventura/omnet_install/main/install_omnet.sh | bash
   ```

   Tenga en cuenta que al utilizar este método, debe confiar en la fuente del script.

   Durante la ejecución, **se le pedirá que ingrese su contraseña de superusuario**. Proporcione la contraseña cuando se solicite.

2. El script instalará las dependencias y configurará OMNeT++ 6.0.1. El proceso puede llevar un tiempo según su conexión y equipo.

3. Compruebe la instalación: los iconos de OMNeT++ estarán en el menú de aplicaciones o ejecutando en terminal:
   ```bash
   omnetpp
   ```

---

## Opción 2: Generar un paquete .deb instalable

El script `build_omnet_deb.sh` genera un paquete `.deb` que puedes instalar con `dpkg` o distribuir.

### Requisitos para construir el .deb

- Herramientas de empaquetado: `dpkg-deb`
- Dependencias de compilación de OMNeT++ (el script puede instalarlas con `-d`)

### Uso

```bash
# Dar permisos de ejecución
chmod +x build_omnet_deb.sh

# Generar el .deb (en el directorio actual)
./build_omnet_deb.sh

# Generar el .deb en una carpeta concreta
./build_omnet_deb.sh ./dist

# Instalar dependencias de compilación y luego generar el .deb
./build_omnet_deb.sh -d ./dist
```

### Instalar el paquete generado

```bash
sudo dpkg -i omnetpp_6.0.1-1_amd64.deb
# Si faltan dependencias:
sudo apt-get install -f
```

OMNeT++ quedará instalado en `/opt/omnetpp-6.0.1`. Para usarlo en una terminal:

```bash
source /opt/omnetpp-6.0.1/setenv
# o ejecutar directamente los binarios en /opt/omnetpp-6.0.1/bin/
```

### Variables de entorno

- `OMNET_VERSION`: versión de OMNeT++ (por defecto: 6.0.1)
- `BUILD_DIR`: directorio temporal de compilación (por defecto: se crea uno automáticamente)


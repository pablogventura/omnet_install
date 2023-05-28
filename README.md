# Script de instalación de OMNeT++

Este script automatiza la instalación de OMNeT++ 6.0.1 en un sistema Linux basado en Debian/Ubuntu. Siga las instrucciones a continuación para utilizar el script.

## Requisitos

- Sistema operativo Linux (Debian/Ubuntu)
- Conexión a Internet

## Instrucciones

1. Ejecute el siguiente comando en la terminal para descargar y ejecutar el script:

   ```bash
   wget -qO- https://raw.githubusercontent.com/pablogventura/omnet_install/main/install_omnet.sh | bash
   ```

    Tenga en cuenta que al utilizar este método, debe confiar en la fuente del script.

    Durante la ejecución, **se le pedirá que ingrese su contraseña de superusuario**. Proporcione la contraseña cuando se solicite.

2. Siga las instrucciones

    El script realizará automáticamente la instalación de las dependencias y configurará OMNeT++ 6.0.1 en su sistema. Siga las instrucciones que aparezcan en la terminal y responda a las preguntas que se le presenten.

    El proceso de instalación puede llevar algún tiempo, dependiendo de la velocidad de su conexión a Internet y la capacidad de su sistema.

3. Compruebe la instalación

    Una vez que el script haya finalizado, los iconos de Omnet++ estarán disponibles en el menu de aplicaciones o por terminal ejecutando el siguiente comando:
    ```bash
    omnetpp
    ```


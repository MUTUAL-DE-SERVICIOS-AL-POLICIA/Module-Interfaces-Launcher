## LEVANTAR PROYECTOS CON DOCKER COMPOSE

## PASOS PARA LEVANTAR EL PROYECTO

1. Clonar el repositorio forkeado e ingresar a la misma

```
cd Module-Interfaces-Launcher
```

2. Crear un .env basado en el .env.example y llenar las variables de entorno correspondientes

```
cp .env.example .env
```

3. Ejecutar el siguiente comando para reconstruir los sub-modulos

```
git submodule update --init --recursive
```

## CONFIGURACIÓN DE LOS FRONTENDS

4. El `.env` raíz pertenece únicamente al launcher y conserva la responsabilidad original de definir los puertos publicados:

```env
LOGIN_HUB_PORT=3001
BENEFICIARY_PORT=3002
SALES_PORT=3003
COLLECTIONS_PORT=3004
```

Cada frontend administra su propio `.env` con las variables que necesita. Esto permite ejecutar un proyecto desde el launcher o de manera independiente con la misma configuración. Antes de levantar el launcher, crear los archivos locales a partir de sus plantillas:

```sh
cp Login-Hub-Interface/.env.example Login-Hub-Interface/.env
cp Beneficiary-Interface/.env.example Beneficiary-Interface/.env
cp Sales-Interface/.env.example Sales-Interface/.env
cp Collections-Interface/.env.example Collections-Interface/.env
```

En desarrollo, las carpetas de los proyectos se montan en `/app` y Next.js carga directamente el `.env` de cada frontend. El Compose no duplica esas variables.

Las variables compartidas, como `GATEWAY_INTERNAL_URL` y `HUB_PUBLIC_ORIGIN`, se repiten intencionalmente. Así cada repositorio puede apuntar a un backend diferente y continúa siendo autónomo. Las variables específicas permanecen solamente donde corresponden:

- Hub configura cookies, binding OIDC y los orígenes de las herramientas.
- Beneficiary configura el puerto del servicio biométrico.
- Cada frontend declara su propia `AUTH_TOOL_KEY` y `NEXT_PUBLIC_DEPLOY_ENV`.
- `AUTH_PENDING_TTL_SECONDS` es opcional y usa `600` segundos si se omite. Si se define, debe coincidir con `WEB_PENDING_TTL_SECONDS` en Auth-Service.

### Dependencias para trabajar por proyecto

No es necesario levantar todos los frontends:

- Para desarrollar un frontend con autenticación y datos reales se requieren el Hub, el frontend objetivo, Gateway, Auth-Service, Redis, Keycloak, NATS y los microservicios funcionales consumidos por esa herramienta.
- Para trabajar solamente en el Hub se requieren Gateway, Auth-Service, Redis, Keycloak y NATS. Los demás frontends solo son necesarios al probar el ingreso efectivo a sus herramientas.
- Para trabajar en componentes visuales sin autenticación ni datos reales puede ejecutarse solamente el frontend.

Tampoco es obligatorio levantar todos los backends:

- Las pruebas unitarias o de lógica interna pueden ejecutarse dentro del microservicio correspondiente.
- Para probar un microservicio mediante NATS se requieren NATS y sus dependencias concretas.
- Para probar rutas web mediante Gateway se añaden Gateway, Auth-Service, Redis y Keycloak.
- Para una prueba desde navegador se añaden el Hub y el frontend que consume esas rutas.

El backend y el frontend pueden ser levantados por personas distintas si son alcanzables por red. En ese caso, cada frontend configura `GATEWAY_INTERNAL_URL` y sus orígenes públicos en su propio `.env`.

## DESPUÉS DE CONFIGURAR TODAS LOS .ENVS LEVANTAR CON DOCKER PARA VERSIÓN DEV - DESARROLLO

5. Comando para construir las imágenes y levantar los contenedores

```
docker compose build --no-cache && docker compose up
```

## PRODUCCIÓN

El launcher utiliza el mismo `.env` raíz para los cuatro puertos:

```sh
docker compose -f docker-compose.prod.yml config --quiet
docker compose -f docker-compose.prod.yml build --no-cache
docker compose -f docker-compose.prod.yml up -d
```

No se requiere un archivo `.env.production` en el launcher. Cada frontend debe tener su propio `.env` configurado para el ambiente antes de construir:

- `NEXT_PUBLIC_DEPLOY_ENV=prod`;
- URLs públicas HTTPS correspondientes al entorno;
- `AUTH_COOKIE_SECURE=true` en el Hub;
- `GATEWAY_INTERNAL_URL` alcanzable desde el contenedor;
- `NEXT_PUBLIC_BIOMETRIC_PORT` explícito en Beneficiary.

El `dockerfile.prod` copia el proyecto y Next.js usa su `.env` durante la compilación. El Compose de producción también declara ese archivo mediante `env_file` para que las variables server side estén disponibles cuando se ejecuta el servidor standalone. Las variables `NODE_ENV`, `PORT` y `HOSTNAME` conservan el tratamiento que ya tenía `upstream/dev`.

## ////////////////////////////////////

## PARA EMPEZAR A COLABORAR

Cuando ya se tiene el los sub módulos se debe ingresar a cada uno y realizar lo siguiente

```
cd Beneficiary-Interface
```

```
checkout main
```

```
git remote add origin https://github.com/{nombre_colaborador}/Beneficiary-Interface.git
git remote add upstream https://github.com/MUTUAL-DE-SERVICIOS-AL-POLICIA/Beneficiary-Interface.git
```

Para redirigir a la rama principal `cd ..`

```
cd Login-Hub-Interface
```

```
checkout main
```

```
git remote add origin https://github.com/{nombre_colaborador}/Login-Hub-Interface.git
git remote add upstream https://github.com/MUTUAL-DE-SERVICIOS-AL-POLICIA/Login-Hub-Interface.git
```

Y PODRÁN REALIZAR LOS PULL REQUEST COMO SE HACE REGULARMENTE DE LOCAL -> REPOSITORIO PERSONAL -> REPOSITORIO PRINCIPAL

## /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

## CUANDO SE CREA UN NUEVO PROYECTO FRONTEND Y SE REQUIERA AÑADIR AL REPOSITORIO PRINCIPAL COMO SUB MÓDULO REALIZAR LO SIGUIENTE

## Pasos para añadir/crear los Git Submodules (un nuevo frontend)

1. Copiar el URL del nuevo repositorio y añadir en el clonado del repositorio padre MUSERPOL-MS local ejecutar:

```
git submodule add <enlace_del_nuevo_repositorio> <nombre_de_carpeta>
```

2. Añadir los cambios al repositorio MUSERPOL-MF (git add, git commit, git push) Ej:

git add .
git commit -m "Add submodule"
git push

3. Realizar un pull request

## ///////////////////////////////////////

INSTALACIÓN INDEPENDIENTE

Para levantar los proyectos de forma independiente sin docker compose
revisar los README de cada sub módulo ubicados en su repositorio.

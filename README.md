# Inversiones D'Caro

Sistema web de punto de venta para **Inversiones D'Caro**, papelería y tienda de variedades en Las Vegas. Permite gestionar productos, ventas, clientes, gastos y reportes desde una misma aplicación.

## Funciones

- Punto de venta con carrito, búsqueda de productos y cálculo en USD y bolívares.
- Inventario de productos y control de stock.
- Registro de compras y gastos.
- Gestión de clientes.
- Dashboard con resumen de la operación.
- Reportes semanal, mensual y por períodos.
- Cierre diario de caja.
- Configuración de la tasa BCV y datos del negocio.
- Inicio de sesión y control de acceso con Firebase Authentication.

## Tecnología

- Flutter Web y Dart.
- Firebase Authentication.
- Cloud Firestore.
- Provider para el estado de la aplicación.
- Firebase Hosting para publicación.

## Requisitos

- Flutter con Dart SDK compatible con `^3.5.4`.
- Un proyecto de Firebase configurado para la aplicación web.
- Firebase CLI autenticado para desplegar.

## Ejecutar localmente

```bash
flutter pub get
flutter run -d chrome
```

Para comprobar el proyecto antes de publicar:

```bash
flutter analyze
flutter build web
```

## Configuración de Firebase

La configuración de la aplicación web se encuentra en `lib/firebase_options.dart`. Las reglas de Firestore están en `firestore.rules` y Firebase Hosting sirve el contenido generado en `build/web`.

Antes de usar datos reales, revisa las reglas y confirma que el proyecto activo de Firebase sea el correcto.

## Publicar

```bash
flutter build web
firebase deploy --only hosting
```

Aplicación publicada: [inversiones-dcaro.web.app](https://inversiones-dcaro.web.app)

## Estructura principal

```text
lib/
	models/       Modelos de clientes, productos, ventas y roles
	screens/      Vistas del POS, inventario, reportes y configuración
	services/     Integración con Firebase y lógica de negocio
	theme/        Colores y estilos compartidos
	widgets/      Componentes reutilizables
web/            Archivos base y recursos de Flutter Web
```

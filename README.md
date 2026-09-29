# Proyecto de Base de Datos para un E-commerce

## Descripción breve

Este proyecto implementa una base de datos relacional avanzada en MySQL para un sistema de comercio electrónico (`EcommerceDB`). El modelo cubre el ciclo completo del negocio: catálogo de productos, proveedores, clientes, carritos, ventas, reseñas, promociones y reportes. Sobre esa estructura se construye lógica de servidor con funciones, procedimientos almacenados, triggers, eventos programados, roles de seguridad, vistas y 20 consultas analíticas de negocio (ventas, inventario, RFM, cohortes, rotación, abandono de carrito, entre otras).

El objetivo es demostrar un diseño de base de datos profesional: integridad referencial, auditoría, control de stock, segmentación de clientes, automatización de tareas y acceso diferenciado por roles.

## Integrantes

- Andrés Felipe Rojas Avendaño

## Requisitos previos

- MySQL 8.0 o superior (se usan `JSON_TABLE`, ventanas `NTILE`/`RANK`/`LAG`, roles y el programador de eventos).
- Cliente SQL: MySQL Workbench, DBeaver, HeidiSQL o la consola `mysql`.
- Privilegio de administrador para crear la base de datos, roles, usuarios y activar `event_scheduler`.

## Instrucciones de ejecución

Todos los scripts se encuentran en la **raíz del repositorio** y deben ejecutarse **en este orden**, sobre la misma instancia de MySQL:

1. **`01_Esquema_y_Datos.sql`**  
   Crea la base de datos `EcommerceDB`, define todas las tablas, índices y restricciones, e inserta los datos iniciales (categorías, proveedores, productos, clientes, ventas, detalles, promociones, carritos, vistas y reseñas).

2. **`02_Consultas_Avanzadas.sql`**  
   Ejecuta las 20 consultas de negocio. No modifica el esquema; solo consulta.

3. **`03_Funciones.sql`**  
   Crea las funciones reutilizables (`fn_CalcularTotalVenta`, `fn_VerificarDisponibilidadStock`, `fn_AplicarDescuento`, etc.). Varios triggers y procedimientos de los scripts siguientes dependen de estas funciones.

4. **`04_Seguridad.sql`**  
   Crea roles, usuarios, privilegios, política de contraseñas, vistas de acceso restringido y la función `fn_SucursalActual`.

5. **`05_Triggers.sql`**  
   Implementa los disparadores de auditoría, stock, totales de venta, validaciones y conteo de productos por categoría.

6. **`06_Eventos.sql`**  
   Activa el programador de eventos y registra las tareas automáticas (reportes, limpieza, lealtad, rankings, copias, etc.).

7. **`07_Procedimientos_Almacenados.sql`**  
   Crea los procedimientos de negocio (nueva venta, devoluciones, registro de clientes, dashboard, reseñas, etc.).

### Ejemplo desde la consola

```bash
mysql -u root -p < 01_Esquema_y_Datos.sql
mysql -u root -p < 02_Consultas_Avanzadas.sql
mysql -u root -p < 03_Funciones.sql
mysql -u root -p < 04_Seguridad.sql
mysql -u root -p < 05_Triggers.sql
mysql -u root -p < 06_Eventos.sql
mysql -u root -p < 07_Procedimientos_Almacenados.sql
```

O, dentro de MySQL Workbench / consola interactiva:

```sql
SOURCE 01_Esquema_y_Datos.sql;
SOURCE 02_Consultas_Avanzadas.sql;
SOURCE 03_Funciones.sql;
SOURCE 04_Seguridad.sql;
SOURCE 05_Triggers.sql;
SOURCE 06_Eventos.sql;
SOURCE 07_Procedimientos_Almacenados.sql;
```

> **Nota:** el script `04_Seguridad.sql` incluye sentencias `SET GLOBAL` (política de contraseñas y limpieza de cuentas `root` remotas). Ejecútelo con un usuario administrador y revise esas líneas si está trabajando en un entorno compartido.

## Archivos SQL individuales

| Archivo | Contenido |
| --- | --- |
| `01_Esquema_y_Datos.sql` | `CREATE DATABASE`, todas las sentencias `CREATE TABLE`, claves foráneas, `CHECK`, índices e `INSERT` de datos de prueba. |
| `02_Consultas_Avanzadas.sql` | 20 consultas de negocio: top productos, decil inferior de ventas, LTV, cohortes, RFM, pares comprados juntos, carritos abandonados, etc. |
| `03_Funciones.sql` | 20 funciones (`fn_*`) para totales, stock, edad, lealtad, SKU, IVA, envío, validación de email y contraseña, entre otras. |
| `04_Seguridad.sql` | Roles, usuarios, `GRANT`, vistas (`v_info_clientes_basica`, `v_ventas_por_sucursal`), política de contraseñas y función de sucursal. |
| `05_Triggers.sql` | Triggers de stock, precios, auditoría, capitalización de nombres, recálculo de totales, alertas y conteo por categoría. También el procedimiento `sp_LogPermissionChange`. |
| `06_Eventos.sql` | Eventos programados: reporte semanal, archivo de logs, lealtad, rankings, limpieza de carritos, KPIs, detección de actividad sospechosa, etc. |
| `07_Procedimientos_Almacenados.sql` | Procedimientos de operación diaria: `sp_RealizarNuevaVenta`, `sp_ProcesarDevolucion`, `sp_RegistrarNuevoCliente`, `sp_ObtenerDashboardAdmin`, etc. |

## Usuarios y contraseñas

Definidos en `04_Seguridad.sql`. Host de conexión: `localhost`.

| Usuario | Contraseña | Rol asignado | Uso sugerido |
| --- | --- | --- | --- |
| `admin_user` | `12345` | `Administrador_Sistema` | Administración total de `EcommerceDB`. |
| `marketing_user` | `1234fel` | `Gerente_Marketing` | Consulta de ventas y clientes; ejecución de `sp_GenerarReporteMensualVentas`. |
| `inventory_user` | `1234xd` | `Empleado_Inventario` | Consulta de productos y actualización de la columna `stock`. |
| `support_user` | `porterojuanma` | `Atencion_Cliente` | Consulta de clientes, ventas y la vista `v_info_clientes_basica`. |
| `analista_user` | `CambiarEstaClave!2026` | `Analista_Datos` | Solo lectura sobre tablas analíticas. Límite: 500 consultas por hora. |

### Roles adicionales

- **`Auditor_Financiero`**: lectura de `ventas`, `productos` y `auditoria` (rol creado; sin usuario asociado en el script).
- **`Visitante`**: lectura de `productos` (rol creado; sin usuario asociado en el script).

### Ejemplo de conexión

```bash
mysql -u admin_user -p12345 -h localhost EcommerceDB
mysql -u marketing_user -p1234fel -h localhost EcommerceDB
mysql -u inventory_user -p1234xd -h localhost EcommerceDB
mysql -u support_user -pporterojuanma -h localhost EcommerceDB
mysql -u analista_user -p'CambiarEstaClave!2026' -h localhost EcommerceDB
```

## Modelo de datos (resumen)

Tablas principales:

- **Catálogo:** `categorias`, `proveedores`, `productos`, `promociones`, `rankings_productos`
- **Clientes:** `clientes`, `referidos`, `carritos`, `carrito_items`, `reseñas`
- **Ventas:** `ventas`, `detalle_ventas`, `ventas_archivadas`
- **Operación y auditoría:** `auditoria`, `auditoria_historica`, `alertas_stock`, `productos_vistas`, `reportes_generados`, `resumen_ventas_categoria`, `reporte_ventas_semanales`, `log_cambios_precio`

Reglas destacadas:

- Precio > 0, costo ≥ 0, stock ≥ 0.
- El detalle de venta no se inserta si no hay stock suficiente (trigger).
- Al vender se descuenta stock y se recalcula el total de la venta.
- Al entregar un pedido se actualiza `total_gastado` y `fecha_ultimo_pedido` del cliente.
- Stock por debajo de 5 unidades genera alerta en `alertas_stock`.

## Cómo probar rápidamente

Después de cargar los 7 scripts:

```sql
USE EcommerceDB;

-- Dashboard
CALL sp_ObtenerDashboardAdmin();

-- Nueva venta de ejemplo (cliente 1, 1 unidad del producto 3)
CALL sp_RealizarNuevaVenta(1, '[{"id_producto": 3, "cantidad": 1}]');

-- Consultas de negocio
-- (abrir 02_Consultas_Avanzadas.sql y ejecutar cada bloque)

-- Verificar roles
SHOW GRANTS FOR 'admin_user'@'localhost';
SHOW GRANTS FOR 'inventory_user'@'localhost';
```

## Entrega en GitHub

- Repositorio privado con el formato: `Proyecto_BD_Avanzada_[NombreEquipo]`.
- Invitar al trainer como colaborador con acceso de lectura.
- Todos los scripts `.sql` y este `README.md` en la **raíz** del repositorio.

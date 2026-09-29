# Proyecto de Base de Datos para un E-commerce

## Descripción
Este proyecto implementa el núcleo de una base de datos relacional en MySQL para una tienda en línea. Cubre el diseño del esquema (con integridad referencial y restricciones de negocio), carga de datos de ejemplo, consultas analíticas, funciones definidas por el usuario, un esquema de seguridad basado en roles, triggers de integridad/auditoría, eventos programados de mantenimiento y reporteo, y procedimientos almacenados transaccionales.

## Integrantes
- Andrés Felipe Rojas Avendaño

## Requisitos previos
- MySQL **8.0 o superior** (el proyecto usa `CREATE ROLE`, `JSON_TABLE`, `WITH ... AS` (CTEs) y funciones de ventana como `NTILE`/`RANK`/`LAG`, que no existen en MySQL 5.7).
- Un cliente SQL (DBeaver, MySQL Workbench, etc.) conectado con un usuario **con privilegios administrativos**, porque el proyecto crea bases de datos, roles y usuarios.

## Instrucciones de Ejecución
Ejecutar los scripts **en este orden**, cada uno completo antes de pasar al siguiente:

1. **`01_Esquema_y_Datos.sql`** — Crea la base de datos `EcommerceDB`, todas las tablas y carga los datos de ejemplo.
2. **`02_Consultas_Avanzadas.sql`** — Las 20 consultas de análisis y reporteo (ejecutar cada una por separado para ver su resultado).
3. **`03_Funciones.sql`** — Las 20 funciones definidas por el usuario (UDFs).
4. **`04_Seguridad.sql`** — Roles, usuarios y permisos. **Cambiar las contraseñas de ejemplo (`CambiarEstaClave!2026`) antes de usar en un entorno real.**
5. **`05_Triggers.sql`** — Tabla `log_cambios_precio` y los 20 triggers.
6. **`06_Eventos.sql`** — Tabla `reporte_ventas_semanales`, activación del `event_scheduler` y los 20 eventos programados (frecuencias reales de negocio: hora/día/semana/mes).
7. **`07_Procedimientos_Almacenados.sql`** — Los 20 procedimientos almacenados.

> Los archivos 05 y 06 requieren que 01 y 03 ya se hayan ejecutado (usan tablas y funciones definidas ahí).

---

## Explicación detallada de cada script

### 01_Esquema_y_Datos.sql — El modelo de datos
Define las **6 entidades del negocio**:
- `categorias`, `proveedores`, `productos`, `clientes`, `ventas`, `detalle_ventas`.

`ventas` es el encabezado de la transacción y `detalle_ventas` es la tabla puente que resuelve la relación **muchos a muchos** entre ventas y productos (una venta incluye varios productos, un producto aparece en varias ventas). La columna `precio_unitario_congelado` guarda el precio pagado en el momento exacto de la compra, para que el historial de ventas no cambie si el precio del producto se actualiza después.

Se aplican restricciones de integridad a nivel de base de datos (no solo en la aplicación): `CHECK` (precio > 0, costo ≥ 0, stock ≥ 0, cantidad > 0), `UNIQUE` (nombre, SKU, email), `FOREIGN KEY` entre todas las tablas relacionadas, y `ON DELETE CASCADE` en `detalle_ventas`.

También se crean **tablas de soporte** necesarias para que la lógica de consultas, triggers y eventos funcione de verdad: `auditoria`, `alertas_stock`, `ventas_archivadas`, `carritos`/`carrito_items`, `promociones`, `reseñas`, `productos_vistas`, `referidos`, `reportes_generados`, `rankings_productos`, `resumen_ventas_categoria`. Al final se insertan datos de ejemplo (categorías, proveedores, productos, clientes, ventas con su detalle) y se recalcula el total de cada venta.

### 02_Consultas_Avanzadas.sql — 20 preguntas de negocio
Consultas de solo lectura (`SELECT`), agrupadas por tipo de análisis:
- **Rankings:** top 10 productos por ingresos, productos en el 10% inferior de ventas (`NTILE`), top 5 clientes VIP por LTV.
- **Series de tiempo:** ventas por mes/año, nuevos clientes por trimestre, ventas por hora del día.
- **Comportamiento del cliente:** tasa de compra repetida, análisis de cohortes, tiempo promedio entre compras (`LAG`), segmentación RFM (Recencia/Frecuencia/Monetario).
- **Inventario y catálogo:** rotación de inventario por categoría, productos a reabastecer, margen de beneficio, productos vistos vs. comprados, productos comprados juntos (self-join).
- **Otros:** carritos abandonados, rendimiento de proveedores, ventas por ciudad, impacto de promociones, predicción simple de demanda.

### 03_Funciones.sql — 20 funciones definidas por el usuario
Funciones (`CREATE FUNCTION`) que devuelven un único valor y se pueden usar dentro de un `SELECT`. Incluyen cálculos de ventas (`fn_CalcularTotalVenta`, `fn_CalcularIVA`, `fn_CalcularCostoEnvio`, `fn_AplicarDescuento`), de clientes (`fn_CalcularEdadCliente`, `fn_EsClienteNuevo`, `fn_DeterminarEstadoLealtad`, `fn_EstimarFechaEntrega`), de productos (`fn_VerificarDisponibilidadStock`, `fn_GenerarSKU`, `fn_ObtenerStockTotalPorCategoria`) y de validación (`fn_ValidarFormatoEmail`, `fn_ValidarComplejidadContraseña`). Se reutilizan dentro de los triggers y procedimientos para no duplicar lógica.

### 04_Seguridad.sql — Roles, usuarios y permisos
Aplica el **principio de mínimo privilegio**: 7 roles (`Administrador_Sistema`, `Gerente_Marketing`, `Analista_Datos`, `Empleado_Inventario`, `Atencion_Cliente`, `Auditor_Financiero`, `Visitante`), cada uno con solo los permisos que necesita, y usuarios asignados a esos roles. Incluye permisos a **nivel de columna** (Inventario solo puede modificar `stock`, nunca `precio`), una vista que oculta datos sensibles de clientes (`v_info_clientes_basica`), una vista filtrada por sucursal (`v_ventas_por_sucursal`, resuelta con una función puente porque MySQL no permite variables de sesión directamente en una vista), límite de consultas por hora, política de contraseñas y restricción de conexión remota para `root`.

### 05_Triggers.sql — 20 disparadores automáticos
Código que MySQL ejecuta solo ante un `INSERT`, `UPDATE` o `DELETE`. Incluye la tabla `log_cambios_precio` (auditoría de precios). Los `BEFORE` validan antes de guardar y pueden cancelar la operación con `SIGNAL` (verificación de stock, precio > 0, formato de email); los `AFTER` reaccionan después del cambio (descontar stock, recalcular el total de la venta, actualizar el gasto total del cliente, generar alertas de stock bajo, archivar ventas eliminadas, auditar cambios de estado y de precio, mantener el contador de productos por categoría).

### 06_Eventos.sql — 20 tareas programadas por tiempo
Incluye la tabla `reporte_ventas_semanales` y activa `event_scheduler = ON`. A diferencia de los triggers, los eventos no reaccionan a un cambio de datos sino al reloj (`ON SCHEDULE EVERY ...`): reportes (ventas semanales, resumen diario, KPIs mensuales, rendimiento de proveedores, tamaño de la base de datos), mantenimiento (limpieza de datos temporales, archivo de auditoría antigua, reconstrucción de índices, respaldo interno, purga de registros eliminados) y lógica de negocio (desactivar promociones vencidas, recalcular nivel de lealtad, suspender cuentas inactivas, vaciar carritos abandonados, actualizar ranking de productos, detectar actividad sospechosa).

### 07_Procedimientos_Almacenados.sql — 20 operaciones invocables
Procedimientos (`CREATE PROCEDURE`) que se ejecutan con `CALL` y pueden agrupar varias operaciones en una transacción. El más representativo es `sp_RealizarNuevaVenta`: usa `START TRANSACTION`/`COMMIT` y un manejador de errores (`EXIT HANDLER FOR SQLEXCEPTION` con `ROLLBACK`) para garantizar que la venta se registre completa o no se registre nada si algo falla. Incluye también gestión de devoluciones, fusión de cuentas de cliente duplicadas, búsqueda avanzada de productos, generación de reportes, dashboard administrativo, y anonimización segura de un cliente (en lugar de borrarlo, para no romper integridad referencial).

---

## Notas técnicas y limitaciones conocidas
- El requisito de seguridad #12 (`GRANT EXECUTE` sobre `sp_GenerarReporteMensualVentas`) se otorga al final de `07_Procedimientos_Almacenados.sql`, no en `04_Seguridad.sql`, porque el procedimiento no existe hasta ese punto.
- El permiso de lectura sobre `reporte_ventas_semanales` para el rol `Analista_Datos` se otorga al final de `06_Eventos.sql`, por la misma razón.
- En MySQL, un `REVOKE` debe coincidir exactamente con el nivel en que se otorgó el `GRANT` correspondiente (base de datos, tabla o columna); mezclar niveles, o revocar un permiso que nunca se otorgó, produce el error 1147. Por eso el rol `Analista_Datos` recibe `SELECT` tabla por tabla en vez de `EcommerceDB.*` seguido de `REVOKE` sobre las tablas de auditoría.
- MySQL no permite usar una variable de sesión (`@variable`) directamente dentro de una `VIEW`. El requisito #19 de `04_Seguridad.sql` (ventas por sucursal) usa una función puente (`fn_SucursalActual()`) para resolverlo.
- El respaldo real de la base de datos (`evt_backup_critical_tables_daily`) y la auditoría de intentos de login fallidos requieren herramientas externas a SQL puro (`mysqldump`, plugins del servidor como `connection_control`); esto se documenta en los comentarios de `06_Eventos.sql` y `04_Seguridad.sql`.
- La política de contraseñas seguras (`validate_password`, requisito #15 de `04_Seguridad.sql`) requiere que el componente correspondiente esté instalado en el servidor (`INSTALL COMPONENT 'file://component_validate_password'`); si el servidor no lo trae disponible, esas líneas pueden omitirse sin afectar el resto del proyecto.
- Las tablas de soporte (`carritos`, `carrito_items`, `alertas_stock`, `referidos`, `promociones`, `reseñas`, `productos_vistas`, `rankings_productos`, `log_cambios_precio`, `resumen_ventas_categoria`) tienen `FOREIGN KEY` hacia `clientes`/`productos`/`categorias`/`carritos` según corresponda. **No** tienen FK, a propósito: `auditoria`/`auditoria_historica` (su `referencia_id` es polimórfico, apunta a distintas tablas según el `tipo`), `ventas_archivadas` (archivo histórico que debe sobrevivir aunque el registro original se borre) y `reportes_generados`/`reporte_ventas_semanales` (reportes agregados, no apuntan a una fila puntual).

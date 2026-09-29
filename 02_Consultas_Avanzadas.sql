-- =====================================================================
--  02. CONSULTAS AVANZADAS (20 preguntas de negocio)
-- =====================================================================
USE EcommerceDB;

-- 1. Top 10 productos más vendidos (por ingresos)
SELECT p.id_producto, p.nombre,
       SUM(dv.cantidad * dv.precio_unitario_congelado) AS ingresos_totales
FROM detalle_ventas dv
JOIN productos p ON p.id_producto = dv.id_producto
GROUP BY p.id_producto, p.nombre
ORDER BY ingresos_totales DESC
LIMIT 10;

-- 2. Productos en el 10% inferior de ventas (candidatos a descontinuar)
WITH ventas_producto AS (
    SELECT p.id_producto, p.nombre, COALESCE(SUM(dv.cantidad),0) AS unidades_vendidas
    FROM productos p
    LEFT JOIN detalle_ventas dv ON dv.id_producto = p.id_producto
    GROUP BY p.id_producto, p.nombre
),
ranked AS (
    SELECT *, NTILE(10) OVER (ORDER BY unidades_vendidas ASC) AS decil
    FROM ventas_producto
)
SELECT id_producto, nombre, unidades_vendidas
FROM ranked
WHERE decil = 1;

-- 3. Top 5 clientes VIP por LTV (gasto total histórico)
SELECT c.id_cliente, CONCAT(c.nombre,' ',c.apellido) AS cliente,
       SUM(v.total) AS ltv
FROM clientes c
JOIN ventas v ON v.id_cliente = c.id_cliente
GROUP BY c.id_cliente, cliente
ORDER BY ltv DESC
LIMIT 5;

-- 4. Ventas totales agrupadas por mes y año
SELECT YEAR(fecha_venta) AS anio, MONTH(fecha_venta) AS mes,
       SUM(total) AS total_ventas
FROM ventas
WHERE estado <> 'Cancelado'
GROUP BY anio, mes
ORDER BY anio, mes;

-- 5. Nuevos clientes registrados por trimestre
SELECT YEAR(fecha_registro) AS anio, QUARTER(fecha_registro) AS trimestre,
       COUNT(*) AS nuevos_clientes
FROM clientes
GROUP BY anio, trimestre
ORDER BY anio, trimestre;

-- 6. Tasa de compra repetida (% de clientes con más de 1 compra)
SELECT ROUND(100 * SUM(CASE WHEN num_compras > 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_repetidores
FROM (
    SELECT id_cliente, COUNT(*) AS num_compras
    FROM ventas
    WHERE estado <> 'Cancelado'
    GROUP BY id_cliente
) t;

-- 7. Pares de productos comprados juntos frecuentemente
SELECT d1.id_producto AS producto_a, d2.id_producto AS producto_b,
       COUNT(*) AS veces_juntos
FROM detalle_ventas d1
JOIN detalle_ventas d2 ON d1.id_venta = d2.id_venta AND d1.id_producto < d2.id_producto
GROUP BY producto_a, producto_b
ORDER BY veces_juntos DESC
LIMIT 20;

-- 8. Rotación de inventario por categoría
SELECT cat.id_categoria, cat.nombre,
       SUM(dv.cantidad) AS unidades_vendidas,
       AVG(p.stock) AS stock_promedio,
       ROUND(SUM(dv.cantidad) / NULLIF(AVG(p.stock),0), 2) AS rotacion
FROM categorias cat
JOIN productos p ON p.id_categoria = cat.id_categoria
LEFT JOIN detalle_ventas dv ON dv.id_producto = p.id_producto
GROUP BY cat.id_categoria, cat.nombre;

-- 9. Productos que necesitan reabastecimiento (umbral = 10 unidades)
SELECT id_producto, nombre, stock
FROM productos
WHERE stock < 10 AND activo = TRUE;

-- 10. Carritos abandonados: clientes con carrito sin compra posterior en 24h
SELECT DISTINCT c.id_cliente, cl.email, c.fecha_creado
FROM carritos c
JOIN clientes cl ON cl.id_cliente = c.id_cliente
WHERE c.fecha_creado < NOW() - INTERVAL 24 HOUR
  AND NOT EXISTS (
      SELECT 1 FROM ventas v
      WHERE v.id_cliente = c.id_cliente AND v.fecha_venta > c.fecha_creado
  );

-- 11. Rendimiento de proveedores por volumen de ventas de sus productos
SELECT prov.id_proveedor, prov.nombre,
       SUM(dv.cantidad * dv.precio_unitario_congelado) AS ingresos_generados
FROM proveedores prov
JOIN productos p ON p.id_proveedor = prov.id_proveedor
JOIN detalle_ventas dv ON dv.id_producto = p.id_producto
GROUP BY prov.id_proveedor, prov.nombre
ORDER BY ingresos_generados DESC;

-- 12. Análisis geográfico de ventas (por ciudad del cliente)
SELECT cl.ciudad, COUNT(v.id_venta) AS num_ventas, SUM(v.total) AS total_vendido
FROM ventas v
JOIN clientes cl ON cl.id_cliente = v.id_cliente
GROUP BY cl.ciudad
ORDER BY total_vendido DESC;

-- 13. Horas pico de compra
SELECT HOUR(fecha_venta) AS hora, COUNT(*) AS num_ventas, SUM(total) AS total
FROM ventas
GROUP BY hora
ORDER BY hora;

-- 14. Impacto de promociones: unidades antes / durante / después
SELECT pr.id_producto, pr.fecha_inicio, pr.fecha_fin,
       SUM(CASE WHEN v.fecha_venta < pr.fecha_inicio THEN dv.cantidad ELSE 0 END) AS unidades_antes,
       SUM(CASE WHEN v.fecha_venta BETWEEN pr.fecha_inicio AND pr.fecha_fin THEN dv.cantidad ELSE 0 END) AS unidades_durante,
       SUM(CASE WHEN v.fecha_venta > pr.fecha_fin THEN dv.cantidad ELSE 0 END) AS unidades_despues
FROM promociones pr
JOIN detalle_ventas dv ON dv.id_producto = pr.id_producto
JOIN ventas v ON v.id_venta = dv.id_venta
GROUP BY pr.id_producto, pr.fecha_inicio, pr.fecha_fin;

-- 15. Análisis de cohortes: retención mes a mes desde la primera compra
WITH primera_compra AS (
    SELECT id_cliente, MIN(DATE_FORMAT(fecha_venta,'%Y-%m-01')) AS mes_cohorte
    FROM ventas
    GROUP BY id_cliente
)
SELECT pc.mes_cohorte,
       TIMESTAMPDIFF(MONTH, pc.mes_cohorte, DATE_FORMAT(v.fecha_venta,'%Y-%m-01')) AS mes_desde_cohorte,
       COUNT(DISTINCT v.id_cliente) AS clientes_activos
FROM primera_compra pc
JOIN ventas v ON v.id_cliente = pc.id_cliente
GROUP BY pc.mes_cohorte, mes_desde_cohorte
ORDER BY pc.mes_cohorte, mes_desde_cohorte;

-- 16. Margen de beneficio por producto
SELECT id_producto, nombre, precio, costo,
       ROUND(((precio - costo) / precio) * 100, 2) AS margen_pct
FROM productos
ORDER BY margen_pct DESC;

-- 17. Tiempo promedio entre compras por cliente
WITH compras AS (
    SELECT id_cliente, fecha_venta,
           LAG(fecha_venta) OVER (PARTITION BY id_cliente ORDER BY fecha_venta) AS compra_anterior
    FROM ventas
)
SELECT id_cliente, AVG(DATEDIFF(fecha_venta, compra_anterior)) AS dias_promedio_entre_compras
FROM compras
WHERE compra_anterior IS NOT NULL
GROUP BY id_cliente;

-- 18. Productos más vistos vs. más comprados
SELECT p.id_producto, p.nombre,
       COALESCE(pv.total_vistas,0) AS vistas,
       COALESCE(vc.total_comprados,0) AS comprados
FROM productos p
LEFT JOIN (SELECT id_producto, COUNT(*) AS total_vistas FROM productos_vistas GROUP BY id_producto) pv
       ON pv.id_producto = p.id_producto
LEFT JOIN (SELECT id_producto, SUM(cantidad) AS total_comprados FROM detalle_ventas GROUP BY id_producto) vc
       ON vc.id_producto = p.id_producto
ORDER BY vistas DESC;

-- 19. Segmentación RFM (Recencia, Frecuencia, Monetario)
WITH rfm AS (
    SELECT c.id_cliente,
           DATEDIFF(CURDATE(), MAX(v.fecha_venta)) AS recencia,
           COUNT(v.id_venta) AS frecuencia,
           SUM(v.total) AS monetario
    FROM clientes c
    JOIN ventas v ON v.id_cliente = c.id_cliente
    GROUP BY c.id_cliente
)
SELECT *,
       NTILE(4) OVER (ORDER BY recencia DESC)  AS score_r,
       NTILE(4) OVER (ORDER BY frecuencia ASC) AS score_f,
       NTILE(4) OVER (ORDER BY monetario ASC)  AS score_m
FROM rfm;

-- 20. Predicción simple de demanda por categoría (promedio últimos 3 meses)
SELECT cat.id_categoria, cat.nombre,
       AVG(mensual.unidades) AS pronostico_prox_mes
FROM categorias cat
JOIN productos p ON p.id_categoria = cat.id_categoria
JOIN (
    SELECT p2.id_producto, DATE_FORMAT(v.fecha_venta,'%Y-%m') AS mes, SUM(dv.cantidad) AS unidades
    FROM detalle_ventas dv
    JOIN ventas v ON v.id_venta = dv.id_venta
    JOIN productos p2 ON p2.id_producto = dv.id_producto
    WHERE v.fecha_venta >= CURDATE() - INTERVAL 3 MONTH
    GROUP BY p2.id_producto, mes
) mensual ON mensual.id_producto = p.id_producto
GROUP BY cat.id_categoria, cat.nombre;

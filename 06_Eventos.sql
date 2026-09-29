USE EcommerceDB;
CREATE TABLE reporte_ventas_semanales (
    id_reporte      INT AUTO_INCREMENT PRIMARY KEY,
    fecha_inicio    DATE NOT NULL,
    fecha_fin       DATE NOT NULL,
    total_ventas    DECIMAL(14,2) NOT NULL,
    num_ventas      INT NOT NULL,
    fecha_generado  DATETIME DEFAULT CURRENT_TIMESTAMP
);
SET GLOBAL event_scheduler = ON;
DELIMITER $$
CREATE EVENT evt_generate_weekly_sales_report
ON SCHEDULE EVERY 1 WEEK STARTS CURRENT_TIMESTAMP
DO
    INSERT INTO reporte_ventas_semanales(fecha_inicio, fecha_fin, total_ventas, num_ventas)
    SELECT CURDATE()-INTERVAL 7 DAY, CURDATE(), COALESCE(SUM(total),0), COUNT(*)
    FROM ventas WHERE fecha_venta >= CURDATE()-INTERVAL 7 DAY$$
CREATE EVENT evt_cleanup_temp_tables_daily
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
DO
    DELETE FROM productos_vistas WHERE fecha_vista < NOW() - INTERVAL 90 DAY$$
CREATE EVENT evt_archive_old_logs_monthly
ON SCHEDULE EVERY 1 MONTH STARTS CURRENT_TIMESTAMP
DO
BEGIN
    INSERT INTO auditoria_historica SELECT * FROM auditoria WHERE fecha < NOW() - INTERVAL 6 MONTH;
    DELETE FROM auditoria WHERE fecha < NOW() - INTERVAL 6 MONTH;
END$$
CREATE EVENT evt_deactivate_expired_promotions_hourly
ON SCHEDULE EVERY 1 HOUR STARTS CURRENT_TIMESTAMP
DO
    UPDATE promociones SET activo = FALSE WHERE fecha_fin < CURDATE() AND activo = TRUE$$
CREATE EVENT evt_recalculate_customer_loyalty_tiers_nightly
ON SCHEDULE EVERY 1 DAY STARTS (TIMESTAMP(CURDATE()) + INTERVAL 1 DAY + INTERVAL 2 HOUR)
DO
    UPDATE clientes
       SET nivel_lealtad = CASE WHEN total_gastado >= 5000000 THEN 'Oro'
                                 WHEN total_gastado >= 1500000 THEN 'Plata'
                                 ELSE 'Bronce' END$$
CREATE EVENT evt_generate_reorder_list_daily
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
DO
    INSERT INTO reportes_generados(tipo_reporte, contenido)
    SELECT 'REABASTECIMIENTO', JSON_ARRAYAGG(JSON_OBJECT('id_producto', id_producto, 'stock', stock))
    FROM productos WHERE stock < 10 AND activo = TRUE$$
CREATE EVENT evt_rebuild_indexes_weekly
ON SCHEDULE EVERY 1 WEEK STARTS CURRENT_TIMESTAMP
DO
    OPTIMIZE TABLE productos, ventas, detalle_ventas, clientes$$
CREATE EVENT evt_suspend_inactive_accounts_quarterly
ON SCHEDULE EVERY 3 MONTH STARTS CURRENT_TIMESTAMP
DO
    UPDATE clientes SET cuenta_activa = FALSE
     WHERE fecha_ultimo_pedido IS NOT NULL AND fecha_ultimo_pedido < NOW() - INTERVAL 1 YEAR$$
CREATE EVENT evt_aggregate_daily_sales_data
ON SCHEDULE EVERY 1 DAY STARTS (TIMESTAMP(CURDATE()) + INTERVAL 1 DAY + INTERVAL 1 HOUR)
DO
    INSERT INTO reportes_generados(tipo_reporte, contenido)
    SELECT 'RESUMEN_DIARIO', JSON_OBJECT('fecha', CURDATE()-INTERVAL 1 DAY,
           'total', COALESCE(SUM(total),0), 'num_ventas', COUNT(*))
    FROM ventas WHERE DATE(fecha_venta) = CURDATE()-INTERVAL 1 DAY$$
CREATE EVENT evt_check_data_consistency_nightly
ON SCHEDULE EVERY 1 DAY STARTS (TIMESTAMP(CURDATE()) + INTERVAL 1 DAY + INTERVAL 3 HOUR)
DO
    INSERT INTO auditoria(tipo, referencia_id, detalle)
    SELECT 'INCONSISTENCIA', v.id_venta, 'Venta sin líneas de detalle'
    FROM ventas v LEFT JOIN detalle_ventas d ON d.id_venta = v.id_venta
    WHERE d.id_detalle IS NULL$$
CREATE EVENT evt_send_birthday_greetings_daily
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
DO
    INSERT INTO reportes_generados(tipo_reporte, contenido)
    SELECT 'CUMPLEANOS_HOY', JSON_ARRAYAGG(JSON_OBJECT('id_cliente', id_cliente, 'email', email))
    FROM clientes
    WHERE fecha_nacimiento IS NOT NULL
      AND MONTH(fecha_nacimiento) = MONTH(CURDATE()) AND DAY(fecha_nacimiento) = DAY(CURDATE())$$
CREATE EVENT evt_update_product_rankings_hourly
ON SCHEDULE EVERY 1 HOUR STARTS CURRENT_TIMESTAMP
DO
    INSERT INTO rankings_productos(id_producto, ranking, fecha_calculo)
    SELECT id_producto, RANK() OVER (ORDER BY ingresos DESC), NOW()
    FROM (
        SELECT p.id_producto, SUM(dv.cantidad*dv.precio_unitario_congelado) AS ingresos
        FROM productos p JOIN detalle_ventas dv ON dv.id_producto = p.id_producto
        JOIN ventas v ON v.id_venta = dv.id_venta
        WHERE v.fecha_venta >= NOW() - INTERVAL 30 DAY
        GROUP BY p.id_producto
    ) t$$
CREATE EVENT evt_backup_critical_tables_daily
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
DO
BEGIN
    SET @tabla = CONCAT('productos_backup_', DATE_FORMAT(NOW(), '%Y%m%d'));
    SET @sql = CONCAT('CREATE TABLE IF NOT EXISTS ', @tabla, ' AS SELECT * FROM productos');
    PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;
END$$
CREATE EVENT evt_clear_abandoned_carts_daily
ON SCHEDULE EVERY 1 DAY STARTS CURRENT_TIMESTAMP
DO
BEGIN
    DELETE ci FROM carrito_items ci
    JOIN carritos c ON c.id_carrito = ci.id_carrito
    WHERE c.fecha_creado < NOW() - INTERVAL 72 HOUR;
    DELETE FROM carritos WHERE fecha_creado < NOW() - INTERVAL 72 HOUR;
END$$
CREATE EVENT evt_calculate_monthly_kpis
ON SCHEDULE EVERY 1 MONTH STARTS CURRENT_TIMESTAMP
DO
    INSERT INTO reportes_generados(tipo_reporte, contenido)
    SELECT 'KPIS_MENSUAL',
           JSON_OBJECT('mes', MONTH(CURDATE()-INTERVAL 1 MONTH), 'anio', YEAR(CURDATE()-INTERVAL 1 MONTH),
                       'total_ventas', (SELECT COALESCE(SUM(total),0) FROM ventas
                                        WHERE fecha_venta >= (CURDATE()-INTERVAL 1 MONTH) - INTERVAL 1 DAY),
                       'nuevos_clientes', (SELECT COUNT(*) FROM clientes
                                           WHERE fecha_registro >= (CURDATE()-INTERVAL 1 MONTH) - INTERVAL 1 DAY))$$
CREATE EVENT evt_refresh_materialized_views_nightly
ON SCHEDULE EVERY 1 DAY STARTS (TIMESTAMP(CURDATE()) + INTERVAL 1 DAY + INTERVAL 4 HOUR)
DO
BEGIN
    TRUNCATE TABLE resumen_ventas_categoria;
    INSERT INTO resumen_ventas_categoria
    SELECT cat.id_categoria, COALESCE(SUM(dv.cantidad),0), COALESCE(SUM(dv.cantidad*dv.precio_unitario_congelado),0), NOW()
    FROM categorias cat
    JOIN productos p ON p.id_categoria = cat.id_categoria
    LEFT JOIN detalle_ventas dv ON dv.id_producto = p.id_producto
    GROUP BY cat.id_categoria;
END$$
CREATE EVENT evt_log_database_size_weekly
ON SCHEDULE EVERY 1 WEEK STARTS CURRENT_TIMESTAMP
DO
    INSERT INTO reportes_generados(tipo_reporte, contenido)
    SELECT 'TAMANO_BD', JSON_OBJECT('mb', ROUND(SUM(data_length+index_length)/1024/1024,2))
    FROM information_schema.tables WHERE table_schema = 'EcommerceDB'$$
CREATE EVENT evt_detect_fraudulent_activity_hourly
ON SCHEDULE EVERY 1 HOUR STARTS CURRENT_TIMESTAMP
DO
    INSERT INTO auditoria(tipo, referencia_id, detalle)
    SELECT 'ACTIVIDAD_SOSPECHOSA', id_cliente, CONCAT(COUNT(*), ' pedidos cancelados en la última hora')
    FROM ventas
    WHERE estado = 'Cancelado' AND fecha_venta >= NOW() - INTERVAL 1 HOUR
    GROUP BY id_cliente HAVING COUNT(*) >= 5$$
CREATE EVENT evt_generate_supplier_performance_report_monthly
ON SCHEDULE EVERY 1 MONTH STARTS CURRENT_TIMESTAMP
DO
    INSERT INTO reportes_generados(tipo_reporte, contenido)
    SELECT 'PROVEEDORES_MENSUAL',
           JSON_ARRAYAGG(JSON_OBJECT('id_proveedor', id_proveedor, 'ingresos', ingresos))
    FROM (
        SELECT prov.id_proveedor, SUM(dv.cantidad*dv.precio_unitario_congelado) AS ingresos
        FROM proveedores prov
        JOIN productos p ON p.id_proveedor = prov.id_proveedor
        JOIN detalle_ventas dv ON dv.id_producto = p.id_producto
        JOIN ventas v ON v.id_venta = dv.id_venta
        WHERE v.fecha_venta >= CURDATE() - INTERVAL 1 MONTH
        GROUP BY prov.id_proveedor
    ) t$$
CREATE EVENT evt_purge_soft_deleted_records_weekly
ON SCHEDULE EVERY 1 WEEK STARTS CURRENT_TIMESTAMP
DO
    DELETE FROM productos WHERE eliminado_en IS NOT NULL AND eliminado_en < NOW() - INTERVAL 30 DAY$$
DELIMITER ;
GRANT SELECT ON EcommerceDB.reporte_ventas_semanales TO 'Analista_Datos';

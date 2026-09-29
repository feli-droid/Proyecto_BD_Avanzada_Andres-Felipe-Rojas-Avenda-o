USE EcommerceDB;
CREATE ROLE 'Administrador_Sistema';
GRANT ALL PRIVILEGES ON EcommerceDB.* TO 'Administrador_Sistema';
CREATE ROLE 'Gerente_Marketing';
GRANT SELECT ON EcommerceDB.ventas   TO 'Gerente_Marketing';
GRANT SELECT ON EcommerceDB.clientes TO 'Gerente_Marketing';
CREATE ROLE 'Analista_Datos';
GRANT SELECT ON EcommerceDB.categorias            TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.proveedores           TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.productos             TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.clientes              TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.ventas                TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.detalle_ventas        TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.alertas_stock         TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.ventas_archivadas     TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.referidos             TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.carritos              TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.carrito_items         TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.productos_vistas      TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.promociones           TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.reseñas               TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.reportes_generados    TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.rankings_productos    TO 'Analista_Datos';
GRANT SELECT ON EcommerceDB.resumen_ventas_categoria TO 'Analista_Datos';
CREATE ROLE 'Empleado_Inventario';
GRANT SELECT ON EcommerceDB.productos TO 'Empleado_Inventario';
GRANT UPDATE (stock) ON EcommerceDB.productos TO 'Empleado_Inventario';
CREATE ROLE 'Atencion_Cliente';
GRANT SELECT ON EcommerceDB.clientes TO 'Atencion_Cliente';
GRANT SELECT ON EcommerceDB.ventas   TO 'Atencion_Cliente';
CREATE ROLE 'Auditor_Financiero';
GRANT SELECT ON EcommerceDB.ventas    TO 'Auditor_Financiero';
GRANT SELECT ON EcommerceDB.productos TO 'Auditor_Financiero';
GRANT SELECT ON EcommerceDB.auditoria TO 'Auditor_Financiero';
CREATE USER 'admin_user'@'localhost'     IDENTIFIED BY 'CambiarEstaClave!2026';
CREATE USER 'marketing_user'@'localhost' IDENTIFIED BY 'CambiarEstaClave!2026';
CREATE USER 'inventory_user'@'localhost' IDENTIFIED BY 'CambiarEstaClave!2026';
CREATE USER 'support_user'@'localhost'   IDENTIFIED BY 'CambiarEstaClave!2026';
GRANT 'Administrador_Sistema' TO 'admin_user'@'localhost';
GRANT 'Gerente_Marketing'     TO 'marketing_user'@'localhost';
GRANT 'Empleado_Inventario'   TO 'inventory_user'@'localhost';
GRANT 'Atencion_Cliente'      TO 'support_user'@'localhost';
SET DEFAULT ROLE ALL TO
    'admin_user'@'localhost', 'marketing_user'@'localhost',
    'inventory_user'@'localhost', 'support_user'@'localhost';
CREATE VIEW v_info_clientes_basica AS
SELECT id_cliente, nombre, apellido, ciudad FROM clientes;
GRANT SELECT ON EcommerceDB.v_info_clientes_basica TO 'Atencion_Cliente';
SET GLOBAL validate_password.policy = 'STRONG';
SET GLOBAL validate_password.length = 12;
DELETE FROM mysql.user WHERE user = 'root' AND host NOT IN ('localhost','127.0.0.1','::1');
FLUSH PRIVILEGES;
CREATE ROLE 'Visitante';
GRANT SELECT ON EcommerceDB.productos TO 'Visitante';
CREATE USER 'analista_user'@'localhost' IDENTIFIED BY 'CambiarEstaClave!2026'
    WITH MAX_QUERIES_PER_HOUR 500;
GRANT 'Analista_Datos' TO 'analista_user'@'localhost';
SET DEFAULT ROLE ALL TO 'analista_user'@'localhost';
DELIMITER $$
CREATE FUNCTION fn_SucursalActual()
RETURNS INT DETERMINISTIC
BEGIN
    RETURN @sucursal_actual;
END$$
DELIMITER ;
CREATE VIEW v_ventas_por_sucursal AS
SELECT * FROM ventas WHERE id_sucursal = fn_SucursalActual();

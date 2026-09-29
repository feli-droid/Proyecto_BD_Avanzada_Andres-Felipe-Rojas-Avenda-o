USE EcommerceDB;
CREATE TABLE log_cambios_precio (
    id_log          INT AUTO_INCREMENT PRIMARY KEY,
    id_producto     INT NOT NULL,
    precio_anterior DECIMAL(10,2) NOT NULL,
    precio_nuevo    DECIMAL(10,2) NOT NULL,
    fecha_cambio    DATETIME DEFAULT CURRENT_TIMESTAMP
);
DELIMITER $$
CREATE TRIGGER trg_audit_precio_producto_after_update
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF OLD.precio <> NEW.precio THEN
        INSERT INTO log_cambios_precio(id_producto, precio_anterior, precio_nuevo)
        VALUES (NEW.id_producto, OLD.precio, NEW.precio);
    END IF;
END$$
CREATE TRIGGER trg_check_stock_before_insert_venta
BEFORE INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    DECLARE v_stock INT;
    SELECT stock INTO v_stock FROM productos WHERE id_producto = NEW.id_producto;
    IF v_stock IS NULL OR v_stock < NEW.cantidad THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock insuficiente para el producto.';
    END IF;
END$$
CREATE TRIGGER trg_update_stock_after_insert_venta
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE productos SET stock = stock - NEW.cantidad WHERE id_producto = NEW.id_producto;
END$$
CREATE TRIGGER trg_prevent_delete_categoria_with_products
BEFORE DELETE ON categorias
FOR EACH ROW
BEGIN
    IF (SELECT COUNT(*) FROM productos WHERE id_categoria = OLD.id_categoria) > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede eliminar: la categoría tiene productos asociados.';
    END IF;
END$$
CREATE TRIGGER trg_log_new_customer_after_insert
AFTER INSERT ON clientes
FOR EACH ROW
BEGIN
    INSERT INTO auditoria(tipo, referencia_id, detalle)
    VALUES ('CLIENTE_NUEVO', NEW.id_cliente, CONCAT('Nuevo cliente: ', NEW.email));
END$$
CREATE TRIGGER trg_update_total_gastado_cliente
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF NEW.estado = 'Entregado' AND OLD.estado <> 'Entregado' THEN
        UPDATE clientes
           SET total_gastado = total_gastado + NEW.total,
               fecha_ultimo_pedido = NEW.fecha_venta
         WHERE id_cliente = NEW.id_cliente;
    END IF;
END$$
CREATE TRIGGER trg_set_fecha_modificacion_producto
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    SET NEW.fecha_modificacion = NOW();
END$$
CREATE TRIGGER trg_prevent_negative_stock
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El stock no puede ser negativo.';
    END IF;
END$$
CREATE TRIGGER trg_capitalize_nombre_cliente
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    SET NEW.nombre   = CONCAT(UCASE(LEFT(NEW.nombre,1)),   LCASE(SUBSTRING(NEW.nombre,2)));
    SET NEW.apellido = CONCAT(UCASE(LEFT(NEW.apellido,1)), LCASE(SUBSTRING(NEW.apellido,2)));
END$$
CREATE TRIGGER trg_recalculate_total_venta_on_detalle_insert
AFTER INSERT ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE ventas SET total = fn_CalcularTotalVenta(NEW.id_venta) WHERE id_venta = NEW.id_venta;
END$$
CREATE TRIGGER trg_recalculate_total_venta_on_detalle_delete
AFTER DELETE ON detalle_ventas
FOR EACH ROW
BEGIN
    UPDATE ventas SET total = fn_CalcularTotalVenta(OLD.id_venta) WHERE id_venta = OLD.id_venta;
END$$
CREATE TRIGGER trg_log_order_status_change
AFTER UPDATE ON ventas
FOR EACH ROW
BEGIN
    IF OLD.estado <> NEW.estado THEN
        INSERT INTO auditoria(tipo, referencia_id, detalle)
        VALUES ('ESTADO_PEDIDO', NEW.id_venta, CONCAT(OLD.estado, ' -> ', NEW.estado));
    END IF;
END$$
CREATE TRIGGER trg_prevent_price_zero_or_less_ins
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.precio <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El precio debe ser mayor que cero.';
    END IF;
END$$
CREATE TRIGGER trg_prevent_price_zero_or_less_upd
BEFORE UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.precio <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El precio debe ser mayor que cero.';
    END IF;
END$$
CREATE TRIGGER trg_send_stock_alert_on_low_stock
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF NEW.stock < 5 AND OLD.stock >= 5 THEN
        INSERT INTO alertas_stock(id_producto, stock_actual) VALUES (NEW.id_producto, NEW.stock);
    END IF;
END$$
CREATE TRIGGER trg_archive_deleted_venta
BEFORE DELETE ON ventas
FOR EACH ROW
BEGIN
    INSERT INTO ventas_archivadas(id_venta, id_cliente, fecha_venta, estado, total, id_sucursal, fecha_archivo)
    VALUES (OLD.id_venta, OLD.id_cliente, OLD.fecha_venta, OLD.estado, OLD.total, OLD.id_sucursal, NOW());
END$$
CREATE TRIGGER trg_validate_email_format_on_customer_ins
BEFORE INSERT ON clientes
FOR EACH ROW
BEGIN
    IF NOT (NEW.email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Formato de email inválido.';
    END IF;
END$$
CREATE TRIGGER trg_validate_email_format_on_customer_upd
BEFORE UPDATE ON clientes
FOR EACH ROW
BEGIN
    IF NOT (NEW.email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Formato de email inválido.';
    END IF;
END$$
CREATE TRIGGER trg_update_last_order_date_customer
AFTER INSERT ON ventas
FOR EACH ROW
BEGIN
    UPDATE clientes SET fecha_ultimo_pedido = NEW.fecha_venta WHERE id_cliente = NEW.id_cliente;
END$$
CREATE TRIGGER trg_prevent_self_referral
BEFORE INSERT ON referidos
FOR EACH ROW
BEGIN
    IF NEW.id_cliente = NEW.id_cliente_referido THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Un cliente no puede autoreferirse.';
    END IF;
END$$
CREATE PROCEDURE sp_LogPermissionChange(IN p_usuario VARCHAR(100), IN p_accion VARCHAR(255))
BEGIN
    INSERT INTO auditoria(tipo, detalle) VALUES ('PERMISO', CONCAT(p_usuario, ': ', p_accion));
END$$
CREATE TRIGGER trg_assign_default_category_on_null
BEFORE INSERT ON productos
FOR EACH ROW
BEGIN
    IF NEW.id_categoria IS NULL THEN
        SET NEW.id_categoria = (SELECT id_categoria FROM categorias WHERE nombre = 'General' LIMIT 1);
    END IF;
END$$
CREATE TRIGGER trg_update_producto_count_in_categoria_ins
AFTER INSERT ON productos
FOR EACH ROW
BEGIN
    UPDATE categorias SET total_productos = total_productos + 1 WHERE id_categoria = NEW.id_categoria;
END$$
CREATE TRIGGER trg_update_producto_count_in_categoria_del
AFTER DELETE ON productos
FOR EACH ROW
BEGIN
    UPDATE categorias SET total_productos = total_productos - 1 WHERE id_categoria = OLD.id_categoria;
END$$
CREATE TRIGGER trg_update_producto_count_in_categoria_upd
AFTER UPDATE ON productos
FOR EACH ROW
BEGIN
    IF OLD.id_categoria <> NEW.id_categoria THEN
        UPDATE categorias SET total_productos = total_productos - 1 WHERE id_categoria = OLD.id_categoria;
        UPDATE categorias SET total_productos = total_productos + 1 WHERE id_categoria = NEW.id_categoria;
    END IF;
END$$
DELIMITER ;

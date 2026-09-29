USE EcommerceDB;
DELIMITER $$
CREATE PROCEDURE sp_RealizarNuevaVenta(IN p_id_cliente INT, IN p_items_json JSON)
BEGIN
    DECLARE v_id_venta INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;
    START TRANSACTION;
    INSERT INTO ventas(id_cliente, estado) VALUES (p_id_cliente, 'Pendiente de Pago');
    SET v_id_venta = LAST_INSERT_ID();
    INSERT INTO detalle_ventas(id_venta, id_producto, cantidad, precio_unitario_congelado)
    SELECT v_id_venta, jt.id_producto, jt.cantidad, p.precio
    FROM JSON_TABLE(p_items_json, '$[*]' COLUMNS(
            id_producto INT PATH '$.id_producto',
            cantidad    INT PATH '$.cantidad'
         )) AS jt
    JOIN productos p ON p.id_producto = jt.id_producto;
    UPDATE ventas SET total = fn_CalcularTotalVenta(v_id_venta) WHERE id_venta = v_id_venta;
    COMMIT;
    SELECT v_id_venta AS id_venta_generada;
END$$
CREATE PROCEDURE sp_AgregarNuevoProducto(
    IN p_nombre VARCHAR(150), IN p_descripcion TEXT, IN p_precio DECIMAL(10,2),
    IN p_costo DECIMAL(10,2), IN p_stock INT, IN p_sku VARCHAR(50),
    IN p_id_categoria INT, IN p_id_proveedor INT)
BEGIN
    INSERT INTO productos(nombre, descripcion, precio, costo, stock, sku, id_categoria, id_proveedor)
    VALUES (p_nombre, p_descripcion, p_precio, p_costo, p_stock, p_sku, p_id_categoria, p_id_proveedor);
    SELECT LAST_INSERT_ID() AS id_producto_generado;
END$$
CREATE PROCEDURE sp_ActualizarDireccionCliente(IN p_id_cliente INT, IN p_nueva_direccion TEXT)
BEGIN
    UPDATE clientes SET direccion_envio = p_nueva_direccion WHERE id_cliente = p_id_cliente;
END$$
CREATE PROCEDURE sp_ProcesarDevolucion(IN p_id_detalle INT, IN p_motivo VARCHAR(255))
BEGIN
    DECLARE v_id_producto INT;
    DECLARE v_cantidad INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    START TRANSACTION;
    SELECT id_producto, cantidad INTO v_id_producto, v_cantidad
    FROM detalle_ventas WHERE id_detalle = p_id_detalle;
    UPDATE productos SET stock = stock + v_cantidad WHERE id_producto = v_id_producto;
    INSERT INTO auditoria(tipo, referencia_id, detalle)
    VALUES ('DEVOLUCION', p_id_detalle, CONCAT('Motivo: ', p_motivo));
    COMMIT;
END$$
CREATE PROCEDURE sp_ObtenerHistorialComprasCliente(IN p_id_cliente INT)
BEGIN
    SELECT v.id_venta, v.fecha_venta, v.estado, v.total
    FROM ventas v WHERE v.id_cliente = p_id_cliente
    ORDER BY v.fecha_venta DESC;
END$$
CREATE PROCEDURE sp_AjustarNivelStock(IN p_id_producto INT, IN p_nueva_cantidad INT, IN p_motivo VARCHAR(255))
BEGIN
    UPDATE productos SET stock = p_nueva_cantidad WHERE id_producto = p_id_producto;
    INSERT INTO auditoria(tipo, referencia_id, detalle)
    VALUES ('AJUSTE_STOCK', p_id_producto, CONCAT('Nuevo stock: ', p_nueva_cantidad, '. Motivo: ', p_motivo));
END$$
CREATE PROCEDURE sp_EliminarClienteDeFormaSegura(IN p_id_cliente INT)
BEGIN
    UPDATE clientes
       SET nombre = 'Anónimo', apellido = 'Anónimo',
           email = CONCAT('eliminado_', p_id_cliente, '@anon.local'),
           contraseña = '', direccion_envio = NULL, cuenta_activa = FALSE
     WHERE id_cliente = p_id_cliente;
END$$
CREATE PROCEDURE sp_AplicarDescuentoPorCategoria(IN p_id_categoria INT, IN p_porcentaje DECIMAL(5,2))
BEGIN
    UPDATE productos
       SET precio = fn_AplicarDescuento(precio, p_porcentaje)
     WHERE id_categoria = p_id_categoria;
END$$
CREATE PROCEDURE sp_GenerarReporteMensualVentas(IN p_mes INT, IN p_anio INT)
BEGIN
    SELECT COUNT(*) AS num_ventas, COALESCE(SUM(total),0) AS total_vendido,
           COALESCE(AVG(total),0) AS ticket_promedio
    FROM ventas
    WHERE MONTH(fecha_venta) = p_mes AND YEAR(fecha_venta) = p_anio AND estado <> 'Cancelado';
END$$
CREATE PROCEDURE sp_CambiarEstadoPedido(IN p_id_venta INT, IN p_nuevo_estado VARCHAR(30))
BEGIN
    UPDATE ventas SET estado = p_nuevo_estado WHERE id_venta = p_id_venta;
END$$
CREATE PROCEDURE sp_RegistrarNuevoCliente(
    IN p_nombre VARCHAR(100), IN p_apellido VARCHAR(100), IN p_email VARCHAR(150),
    IN p_password_hash VARCHAR(255), IN p_direccion TEXT)
BEGIN
    IF EXISTS (SELECT 1 FROM clientes WHERE email = p_email) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ya existe un cliente registrado con ese email.';
    ELSE
        INSERT INTO clientes(nombre, apellido, email, contraseña, direccion_envio)
        VALUES (p_nombre, p_apellido, p_email, p_password_hash, p_direccion);
        SELECT LAST_INSERT_ID() AS id_cliente_generado;
    END IF;
END$$
CREATE PROCEDURE sp_ObtenerDetallesProductoCompleto(IN p_id_producto INT)
BEGIN
    SELECT p.*, c.nombre AS categoria, pr.nombre AS proveedor
    FROM productos p
    JOIN categorias c ON c.id_categoria = p.id_categoria
    JOIN proveedores pr ON pr.id_proveedor = p.id_proveedor
    WHERE p.id_producto = p_id_producto;
END$$
CREATE PROCEDURE sp_FusionarCuentasCliente(IN p_id_principal INT, IN p_id_duplicado INT)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    START TRANSACTION;
    UPDATE ventas SET id_cliente = p_id_principal WHERE id_cliente = p_id_duplicado;
    UPDATE clientes c1
       JOIN clientes c2 ON c2.id_cliente = p_id_duplicado
       SET c1.total_gastado = c1.total_gastado + c2.total_gastado
     WHERE c1.id_cliente = p_id_principal;
    DELETE FROM clientes WHERE id_cliente = p_id_duplicado;
    COMMIT;
END$$
CREATE PROCEDURE sp_AsignarProductoAProveedor(IN p_id_producto INT, IN p_id_proveedor INT)
BEGIN
    UPDATE productos SET id_proveedor = p_id_proveedor WHERE id_producto = p_id_producto;
END$$
CREATE PROCEDURE sp_BuscarProductos(
    IN p_nombre VARCHAR(150), IN p_id_categoria INT,
    IN p_precio_min DECIMAL(10,2), IN p_precio_max DECIMAL(10,2))
BEGIN
    SELECT * FROM productos
    WHERE (p_nombre IS NULL OR nombre LIKE CONCAT('%', p_nombre, '%'))
      AND (p_id_categoria IS NULL OR id_categoria = p_id_categoria)
      AND (p_precio_min IS NULL OR precio >= p_precio_min)
      AND (p_precio_max IS NULL OR precio <= p_precio_max)
      AND activo = TRUE;
END$$
CREATE PROCEDURE sp_ObtenerDashboardAdmin()
BEGIN
    SELECT
        (SELECT COUNT(*) FROM ventas WHERE DATE(fecha_venta) = CURDATE()) AS ventas_hoy,
        (SELECT COALESCE(SUM(total),0) FROM ventas WHERE DATE(fecha_venta) = CURDATE()) AS ingresos_hoy,
        (SELECT COUNT(*) FROM clientes WHERE DATE(fecha_registro) = CURDATE()) AS nuevos_clientes_hoy,
        (SELECT COUNT(*) FROM productos WHERE stock < 10 AND activo = TRUE) AS productos_bajo_stock;
END$$
CREATE PROCEDURE sp_ProcesarPago(IN p_id_venta INT)
BEGIN
    UPDATE ventas SET estado = 'Procesando'
     WHERE id_venta = p_id_venta AND estado = 'Pendiente de Pago';
END$$
CREATE PROCEDURE sp_AñadirReseñaProducto(
    IN p_id_cliente INT, IN p_id_producto INT, IN p_calificacion TINYINT, IN p_comentario TEXT)
BEGIN
    IF EXISTS (
        SELECT 1 FROM detalle_ventas dv JOIN ventas v ON v.id_venta = dv.id_venta
        WHERE v.id_cliente = p_id_cliente AND dv.id_producto = p_id_producto
    ) THEN
        INSERT INTO reseñas(id_cliente, id_producto, calificacion, comentario)
        VALUES (p_id_cliente, p_id_producto, p_calificacion, p_comentario);
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El cliente no ha comprado este producto.';
    END IF;
END$$
CREATE PROCEDURE sp_ObtenerProductosRelacionados(IN p_id_producto INT)
BEGIN
    SELECT d2.id_producto, p.nombre, COUNT(*) AS veces_comprado_junto
    FROM detalle_ventas d1
    JOIN detalle_ventas d2 ON d1.id_venta = d2.id_venta AND d1.id_producto <> d2.id_producto
    JOIN productos p ON p.id_producto = d2.id_producto
    WHERE d1.id_producto = p_id_producto
    GROUP BY d2.id_producto, p.nombre
    ORDER BY veces_comprado_junto DESC
    LIMIT 5;
END$$
CREATE PROCEDURE sp_MoverProductosEntreCategorias(IN p_id_categoria_origen INT, IN p_id_categoria_destino INT)
BEGIN
    UPDATE productos SET id_categoria = p_id_categoria_destino WHERE id_categoria = p_id_categoria_origen;
END$$
DELIMITER ;
GRANT EXECUTE ON PROCEDURE EcommerceDB.sp_GenerarReporteMensualVentas TO 'Gerente_Marketing';

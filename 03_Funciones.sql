USE EcommerceDB;
DELIMITER $$
CREATE FUNCTION fn_CalcularTotalVenta(p_id_venta INT)
RETURNS DECIMAL(12,2) DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2);
    SELECT SUM(cantidad * precio_unitario_congelado) INTO v_total
    FROM detalle_ventas WHERE id_venta = p_id_venta;
    RETURN COALESCE(v_total, 0);
END$$
CREATE FUNCTION fn_VerificarDisponibilidadStock(p_id_producto INT, p_cantidad INT)
RETURNS BOOLEAN DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_stock INT;
    SELECT stock INTO v_stock FROM productos WHERE id_producto = p_id_producto;
    RETURN COALESCE(v_stock,0) >= p_cantidad;
END$$
CREATE FUNCTION fn_ObtenerPrecioProducto(p_id_producto INT)
RETURNS DECIMAL(10,2) DETERMINISTIC READS SQL DATA
BEGIN
    RETURN (SELECT precio FROM productos WHERE id_producto = p_id_producto);
END$$
CREATE FUNCTION fn_CalcularEdadCliente(p_id_cliente INT)
RETURNS INT DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_fecha_nac DATE;
    SELECT fecha_nacimiento INTO v_fecha_nac FROM clientes WHERE id_cliente = p_id_cliente;
    IF v_fecha_nac IS NULL THEN RETURN NULL; END IF;
    RETURN TIMESTAMPDIFF(YEAR, v_fecha_nac, CURDATE());
END$$
CREATE FUNCTION fn_FormatearNombreCompleto(p_id_cliente INT)
RETURNS VARCHAR(200) DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_nombre VARCHAR(100);
    DECLARE v_apellido VARCHAR(100);
    SELECT nombre, apellido INTO v_nombre, v_apellido FROM clientes WHERE id_cliente = p_id_cliente;
    RETURN CONCAT(UCASE(LEFT(v_apellido,1)), LCASE(SUBSTRING(v_apellido,2)), ', ',
                  UCASE(LEFT(v_nombre,1)), LCASE(SUBSTRING(v_nombre,2)));
END$$
CREATE FUNCTION fn_EsClienteNuevo(p_id_cliente INT)
RETURNS BOOLEAN DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_primera DATETIME;
    SELECT MIN(fecha_venta) INTO v_primera FROM ventas WHERE id_cliente = p_id_cliente;
    RETURN v_primera IS NOT NULL AND v_primera >= NOW() - INTERVAL 30 DAY;
END$$
CREATE FUNCTION fn_CalcularCostoEnvio(p_id_venta INT)
RETURNS DECIMAL(10,2) DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_peso DECIMAL(10,2);
    SELECT SUM(p.peso_kg * dv.cantidad) INTO v_peso
    FROM detalle_ventas dv JOIN productos p ON p.id_producto = dv.id_producto
    WHERE dv.id_venta = p_id_venta;
    RETURN ROUND(COALESCE(v_peso,0) * 2.5, 2);
END$$
CREATE FUNCTION fn_AplicarDescuento(p_monto DECIMAL(10,2), p_porcentaje DECIMAL(5,2))
RETURNS DECIMAL(10,2) DETERMINISTIC
BEGIN
    RETURN ROUND(p_monto - (p_monto * p_porcentaje / 100), 2);
END$$
CREATE FUNCTION fn_ObtenerUltimaFechaCompra(p_id_cliente INT)
RETURNS DATETIME DETERMINISTIC READS SQL DATA
BEGIN
    RETURN (SELECT MAX(fecha_venta) FROM ventas WHERE id_cliente = p_id_cliente);
END$$
CREATE FUNCTION fn_ValidarFormatoEmail(p_email VARCHAR(150))
RETURNS BOOLEAN DETERMINISTIC
BEGIN
    RETURN p_email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$';
END$$
CREATE FUNCTION fn_ObtenerNombreCategoria(p_id_producto INT)
RETURNS VARCHAR(100) DETERMINISTIC READS SQL DATA
BEGIN
    RETURN (SELECT c.nombre FROM productos p JOIN categorias c ON c.id_categoria = p.id_categoria
            WHERE p.id_producto = p_id_producto);
END$$
CREATE FUNCTION fn_ContarVentasCliente(p_id_cliente INT)
RETURNS INT DETERMINISTIC READS SQL DATA
BEGIN
    RETURN (SELECT COUNT(*) FROM ventas WHERE id_cliente = p_id_cliente);
END$$
CREATE FUNCTION fn_CalcularDiasDesdeUltimaCompra(p_id_cliente INT)
RETURNS INT DETERMINISTIC READS SQL DATA
BEGIN
    RETURN DATEDIFF(CURDATE(), (SELECT MAX(fecha_venta) FROM ventas WHERE id_cliente = p_id_cliente));
END$$
CREATE FUNCTION fn_DeterminarEstadoLealtad(p_id_cliente INT)
RETURNS VARCHAR(10) DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_total DECIMAL(12,2);
    SELECT total_gastado INTO v_total FROM clientes WHERE id_cliente = p_id_cliente;
    IF v_total >= 5000000 THEN RETURN 'Oro';
    ELSEIF v_total >= 1500000 THEN RETURN 'Plata';
    ELSE RETURN 'Bronce';
    END IF;
END$$
CREATE FUNCTION fn_GenerarSKU(p_nombre VARCHAR(150), p_id_categoria INT)
RETURNS VARCHAR(50) READS SQL DATA
BEGIN
    DECLARE v_cat VARCHAR(10);
    SELECT UPPER(LEFT(nombre,3)) INTO v_cat FROM categorias WHERE id_categoria = p_id_categoria;
    RETURN CONCAT(COALESCE(v_cat,'GEN'), '-', UPPER(LEFT(REPLACE(p_nombre,' ',''),4)), '-', FLOOR(RAND()*9000+1000));
END$$
CREATE FUNCTION fn_CalcularIVA(p_id_venta INT)
RETURNS DECIMAL(10,2) DETERMINISTIC READS SQL DATA
BEGIN
    RETURN ROUND((SELECT total FROM ventas WHERE id_venta = p_id_venta) * 0.19, 2);
END$$
CREATE FUNCTION fn_ObtenerStockTotalPorCategoria(p_id_categoria INT)
RETURNS INT DETERMINISTIC READS SQL DATA
BEGIN
    RETURN (SELECT SUM(stock) FROM productos WHERE id_categoria = p_id_categoria);
END$$
CREATE FUNCTION fn_EstimarFechaEntrega(p_id_cliente INT)
RETURNS DATE DETERMINISTIC READS SQL DATA
BEGIN
    DECLARE v_ciudad VARCHAR(100);
    SELECT ciudad INTO v_ciudad FROM clientes WHERE id_cliente = p_id_cliente;
    IF v_ciudad = 'Bucaramanga' THEN RETURN CURDATE() + INTERVAL 2 DAY;
    ELSE RETURN CURDATE() + INTERVAL 5 DAY;
    END IF;
END$$
CREATE FUNCTION fn_ConvertirMoneda(p_monto DECIMAL(12,2), p_tasa DECIMAL(10,4))
RETURNS DECIMAL(12,2) DETERMINISTIC
BEGIN
    RETURN ROUND(p_monto * p_tasa, 2);
END$$
CREATE FUNCTION fn_ValidarComplejidadContraseña(p_password VARCHAR(255))
RETURNS BOOLEAN DETERMINISTIC
BEGIN
    RETURN LENGTH(p_password) >= 8
       AND p_password REGEXP '[A-Z]'
       AND p_password REGEXP '[a-z]'
       AND p_password REGEXP '[0-9]'
       AND p_password REGEXP '[^A-Za-z0-9]';
END$$
DELIMITER ;

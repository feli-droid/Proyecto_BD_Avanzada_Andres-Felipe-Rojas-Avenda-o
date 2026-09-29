DROP DATABASE IF EXISTS EcommerceDB;
CREATE DATABASE EcommerceDB CHARACTER SET utf8mb4;
USE EcommerceDB;
CREATE TABLE categorias (
    id_categoria    INT AUTO_INCREMENT PRIMARY KEY,
    nombre          VARCHAR(100) NOT NULL UNIQUE,
    descripcion     TEXT NULL,
    total_productos INT NOT NULL DEFAULT 0
);
CREATE TABLE proveedores (
    id_proveedor       INT AUTO_INCREMENT PRIMARY KEY,
    nombre             VARCHAR(150) NOT NULL,
    email_contacto     VARCHAR(150) UNIQUE NULL,
    telefono_contacto  VARCHAR(30) NULL
);
CREATE TABLE productos (
    id_producto         INT AUTO_INCREMENT PRIMARY KEY,
    nombre              VARCHAR(150) NOT NULL UNIQUE,
    descripcion         TEXT NULL,
    precio              DECIMAL(10,2) NOT NULL,
    costo               DECIMAL(10,2) NOT NULL,
    stock               INT NOT NULL DEFAULT 0,
    sku                 VARCHAR(50) NOT NULL UNIQUE,
    peso_kg             DECIMAL(6,2) NOT NULL DEFAULT 1.00,
    fecha_creacion      DATETIME DEFAULT CURRENT_TIMESTAMP,
    fecha_modificacion  DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    activo              BOOLEAN DEFAULT TRUE,
    eliminado_en        DATETIME NULL,
    id_categoria        INT NOT NULL,
    id_proveedor        INT NOT NULL,
    CONSTRAINT chk_precio_positivo   CHECK (precio > 0),
    CONSTRAINT chk_costo_no_negativo CHECK (costo >= 0),
    CONSTRAINT chk_stock_no_negativo CHECK (stock >= 0),
    CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria),
    CONSTRAINT fk_producto_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor)
);
CREATE TABLE clientes (
    id_cliente          INT AUTO_INCREMENT PRIMARY KEY,
    nombre              VARCHAR(100) NOT NULL,
    apellido            VARCHAR(100) NOT NULL,
    email               VARCHAR(150) NOT NULL UNIQUE,
    contraseña          VARCHAR(255) NOT NULL,
    direccion_envio     TEXT NULL,
    ciudad              VARCHAR(100) NULL,
    fecha_nacimiento    DATE NULL,
    fecha_registro      DATETIME DEFAULT CURRENT_TIMESTAMP,
    total_gastado       DECIMAL(12,2) NOT NULL DEFAULT 0,
    fecha_ultimo_pedido DATETIME NULL,
    nivel_lealtad       ENUM('Bronce','Plata','Oro') NOT NULL DEFAULT 'Bronce',
    cuenta_activa       BOOLEAN NOT NULL DEFAULT TRUE,
    id_sucursal         INT NOT NULL DEFAULT 1
);
CREATE TABLE ventas (
    id_venta     INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente   INT NOT NULL,
    fecha_venta  DATETIME DEFAULT CURRENT_TIMESTAMP,
    estado       ENUM('Pendiente de Pago','Procesando','Enviado','Entregado','Cancelado')
                 NOT NULL DEFAULT 'Pendiente de Pago',
    total        DECIMAL(12,2) NOT NULL DEFAULT 0,
    id_sucursal  INT NOT NULL DEFAULT 1,
    CONSTRAINT fk_venta_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
);
CREATE TABLE detalle_ventas (
    id_detalle                 INT AUTO_INCREMENT PRIMARY KEY,
    id_venta                   INT NOT NULL,
    id_producto                INT NOT NULL,
    cantidad                   INT NOT NULL,
    precio_unitario_congelado  DECIMAL(10,2) NOT NULL,
    CONSTRAINT chk_cantidad_positiva CHECK (cantidad > 0),
    CONSTRAINT fk_detalle_venta    FOREIGN KEY (id_venta) REFERENCES ventas(id_venta) ON DELETE CASCADE,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);
CREATE TABLE auditoria (
    id_auditoria    INT AUTO_INCREMENT PRIMARY KEY,
    tipo            VARCHAR(60) NOT NULL,
    referencia_id   INT NULL,
    detalle         TEXT NULL,
    fecha           DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE auditoria_historica LIKE auditoria;
CREATE TABLE alertas_stock (
    id_alerta     INT AUTO_INCREMENT PRIMARY KEY,
    id_producto   INT NOT NULL,
    stock_actual  INT NOT NULL,
    fecha_alerta  DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_alerta_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);
CREATE TABLE ventas_archivadas LIKE ventas;
ALTER TABLE ventas_archivadas ADD COLUMN fecha_archivo DATETIME DEFAULT CURRENT_TIMESTAMP;
CREATE TABLE referidos (
    id_referido         INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente          INT NOT NULL,
    id_cliente_referido INT NOT NULL,
    CONSTRAINT fk_referido_cliente     FOREIGN KEY (id_cliente)          REFERENCES clientes(id_cliente),
    CONSTRAINT fk_referido_cliente_ref FOREIGN KEY (id_cliente_referido) REFERENCES clientes(id_cliente)
);
CREATE TABLE carritos (
    id_carrito    INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente    INT NOT NULL,
    fecha_creado  DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_carrito_cliente FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente)
);
CREATE TABLE carrito_items (
    id_item      INT AUTO_INCREMENT PRIMARY KEY,
    id_carrito   INT NOT NULL,
    id_producto  INT NOT NULL,
    cantidad     INT NOT NULL DEFAULT 1,
    CONSTRAINT fk_carritoitem_carrito  FOREIGN KEY (id_carrito)  REFERENCES carritos(id_carrito) ON DELETE CASCADE,
    CONSTRAINT fk_carritoitem_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);
CREATE TABLE productos_vistas (
    id_vista     INT AUTO_INCREMENT PRIMARY KEY,
    id_producto  INT NOT NULL,
    fecha_vista  DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_vista_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);
CREATE TABLE promociones (
    id_promocion   INT AUTO_INCREMENT PRIMARY KEY,
    id_producto    INT NOT NULL,
    descuento_pct  DECIMAL(5,2) NOT NULL,
    fecha_inicio   DATE NOT NULL,
    fecha_fin      DATE NOT NULL,
    activo         BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_promocion_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);
CREATE TABLE reseñas (
    id_reseña     INT AUTO_INCREMENT PRIMARY KEY,
    id_cliente    INT NOT NULL,
    id_producto   INT NOT NULL,
    calificacion  TINYINT NOT NULL,
    comentario    TEXT NULL,
    fecha         DATETIME DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_calificacion CHECK (calificacion BETWEEN 1 AND 5),
    CONSTRAINT fk_resena_cliente  FOREIGN KEY (id_cliente)  REFERENCES clientes(id_cliente),
    CONSTRAINT fk_resena_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);
CREATE TABLE reportes_generados (
    id_reporte      INT AUTO_INCREMENT PRIMARY KEY,
    tipo_reporte    VARCHAR(60) NOT NULL,
    contenido       JSON NULL,
    fecha_generado  DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE rankings_productos (
    id_producto     INT NOT NULL,
    ranking         INT NOT NULL,
    fecha_calculo   DATETIME DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id_producto, fecha_calculo),
    CONSTRAINT fk_ranking_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);
CREATE TABLE resumen_ventas_categoria (
    id_categoria      INT PRIMARY KEY,
    unidades_vendidas INT,
    ingresos_totales  DECIMAL(14,2),
    fecha_actualizado DATETIME,
    CONSTRAINT fk_resumen_categoria FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria)
);
CREATE INDEX idx_detalle_producto      ON detalle_ventas(id_producto);
CREATE INDEX idx_ventas_cliente_fecha  ON ventas(id_cliente, fecha_venta);
CREATE INDEX idx_productos_categoria   ON productos(id_categoria);
INSERT INTO categorias (nombre, descripcion) VALUES
('Electrónica', 'Dispositivos y gadgets electrónicos'),
('Ropa', 'Prendas de vestir para todas las edades'),
('Hogar', 'Artículos para el hogar y la cocina'),
('Deportes', 'Equipamiento e indumentaria deportiva'),
('General', 'Categoría por defecto para productos sin clasificar');
INSERT INTO proveedores (nombre, email_contacto, telefono_contacto) VALUES
('TechImport S.A.S.', 'ventas@techimport.com', '6017001122'),
('Moda Total Ltda.', 'contacto@modatotal.com', '6017003344'),
('Hogar y Cia', 'pedidos@hogarycia.com', '6017005566'),
('DeporMax', 'info@depormax.com', '6017007788');
INSERT INTO productos (nombre, descripcion, precio, costo, stock, sku, peso_kg, id_categoria, id_proveedor) VALUES
('Audífonos Bluetooth X200', 'Audífonos inalámbricos con cancelación de ruido', 189900, 95000, 40, 'ELE-AUD-0001', 0.30, 1, 1),
('Smartwatch FitPro',       'Reloj inteligente con monitor de ritmo cardíaco', 349900, 180000, 25, 'ELE-SMW-0002', 0.15, 1, 1),
('Cargador Rápido USB-C',   'Cargador de pared 30W',                            59900,  22000, 80, 'ELE-CAR-0003', 0.10, 1, 1),
('Camiseta Deportiva Dry',  'Camiseta transpirable para entrenamiento',         49900,  18000, 60, 'ROP-CAM-0004', 0.20, 2, 2),
('Jean Clásico Azul',       'Jean de corte recto en denim',                     129900,  55000, 35, 'ROP-JEA-0005', 0.60, 2, 2),
('Chaqueta Impermeable',    'Chaqueta resistente al agua',                      219900,  90000, 20, 'ROP-CHA-0006', 0.80, 2, 2),
('Juego de Ollas 5 Piezas', 'Set de ollas antiadherentes',                      289900, 130000, 15, 'HOG-OLL-0007', 4.50, 3, 3),
('Licuadora 900W',          'Licuadora de alto rendimiento',                    159900,  70000, 22, 'HOG-LIC-0008', 2.10, 3, 3),
('Juego de Sábanas Queen',  'Sábanas 100% algodón',                              99900,  40000, 30, 'HOG-SAB-0009', 1.20, 3, 3),
('Balón de Fútbol Pro',     'Balón oficial talla 5',                             79900,  30000, 50, 'DEP-BAL-0010', 0.45, 4, 4),
('Mancuernas 10kg (par)',   'Mancuernas de hierro fundido',                     149900,  65000, 18, 'DEP-MAN-0011', 10.00, 4, 4),
('Colchoneta de Yoga',      'Colchoneta antideslizante',                         69900,  25000, 45, 'DEP-COL-0012', 1.00, 4, 4);
INSERT INTO clientes (nombre, apellido, email, contraseña, direccion_envio, ciudad, fecha_nacimiento) VALUES
('Laura',    'Gómez',    'laura.gomez@correo.com',    '$2y$hash1', 'Cra 10 # 20-30', 'Bucaramanga', '1994-03-12'),
('Andrés',   'Ramírez',  'andres.ramirez@correo.com', '$2y$hash2', 'Cll 45 # 12-08', 'Bogotá',      '1988-07-25'),
('Camila',   'Torres',   'camila.torres@correo.com',  '$2y$hash3', 'Av 30 # 5-15',   'Medellín',    '1996-11-02'),
('Santiago', 'Pérez',    'santiago.perez@correo.com', '$2y$hash4', 'Cra 7 # 8-90',   'Bucaramanga', '1990-05-18'),
('Valentina','Suárez',   'valentina.suarez@correo.com','$2y$hash5','Cll 100 # 15-40','Cali',        '1999-01-30'),
('Miguel',   'Castro',   'miguel.castro@correo.com',  '$2y$hash6', 'Cra 15 # 22-11', 'Bogotá',      '1985-09-09');
INSERT INTO ventas (id_cliente, estado, id_sucursal) VALUES
(1, 'Entregado', 1),
(1, 'Procesando', 1),
(2, 'Entregado', 1),
(3, 'Enviado', 1),
(4, 'Entregado', 1),
(5, 'Cancelado', 1),
(6, 'Pendiente de Pago', 1);
INSERT INTO detalle_ventas (id_venta, id_producto, cantidad, precio_unitario_congelado) VALUES
(1, 1, 1, 189900),
(1, 3, 2, 59900),
(2, 2, 1, 349900),
(3, 4, 3, 49900),
(3, 10, 1, 79900),
(4, 7, 1, 289900),
(5, 5, 2, 129900),
(6, 11, 1, 149900),
(7, 12, 2, 69900);
UPDATE ventas v
JOIN (SELECT id_venta, SUM(cantidad*precio_unitario_congelado) AS t FROM detalle_ventas GROUP BY id_venta) d
  ON d.id_venta = v.id_venta
SET v.total = d.t;
INSERT INTO promociones (id_producto, descuento_pct, fecha_inicio, fecha_fin, activo) VALUES
(2, 15.00, CURDATE()-INTERVAL 10 DAY, CURDATE()+INTERVAL 5 DAY, TRUE),
(7, 10.00, CURDATE()-INTERVAL 30 DAY, CURDATE()-INTERVAL 15 DAY, FALSE);
INSERT INTO carritos (id_cliente, fecha_creado) VALUES
(3, NOW() - INTERVAL 2 DAY),
(6, NOW() - INTERVAL 5 HOUR);
INSERT INTO carrito_items (id_carrito, id_producto, cantidad) VALUES
(1, 6, 1),
(2, 9, 2);
INSERT INTO productos_vistas (id_producto, fecha_vista) VALUES
(1, NOW()-INTERVAL 1 DAY), (1, NOW()-INTERVAL 2 DAY), (2, NOW()-INTERVAL 1 DAY),
(7, NOW()-INTERVAL 3 DAY), (10, NOW()-INTERVAL 1 DAY);
INSERT INTO reseñas (id_cliente, id_producto, calificacion, comentario) VALUES
(1, 1, 5, 'Excelente calidad de sonido'),
(2, 2, 4, 'Buena batería, cómodo de usar');

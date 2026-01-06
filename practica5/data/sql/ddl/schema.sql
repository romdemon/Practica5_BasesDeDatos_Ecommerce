-- Eliminar tablas si existen (para reinicialización)
DROP TABLE IF EXISTS Pago CASCADE;
DROP TABLE IF EXISTS Envio CASCADE;
DROP TABLE IF EXISTS DetallePedido CASCADE;
DROP TABLE IF EXISTS Pedido CASCADE;
DROP TABLE IF EXISTS Producto CASCADE;
DROP TABLE IF EXISTS Categoria CASCADE;
DROP TABLE IF EXISTS Cliente CASCADE;

-- ============================================================================
-- TABLA: Cliente
-- Descripción: Almacena información de clientes del e-commerce
-- ============================================================================
CREATE TABLE Cliente (
    Id_Cliente SERIAL PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Email VARCHAR(150) NOT NULL UNIQUE,
    Telefono VARCHAR(20),
    Fecha_Registro TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Activo BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Restricciones
    CONSTRAINT chk_email_formato CHECK (Email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}$'),
    CONSTRAINT chk_nombre_longitud CHECK (LENGTH(Nombre) >= 3)
);

-- Índices para Cliente
CREATE INDEX idx_cliente_email ON Cliente(Email);
CREATE INDEX idx_cliente_activo ON Cliente(Activo);
CREATE INDEX idx_cliente_fecha_registro ON Cliente(Fecha_Registro DESC);

-- Comentarios
COMMENT ON TABLE Cliente IS 'Tabla de clientes registrados en el sistema';
COMMENT ON COLUMN Cliente.Id_Cliente IS 'Identificador único del cliente';
COMMENT ON COLUMN Cliente.Activo IS 'Indica si el cliente está activo (TRUE) o inactivo (FALSE)';

-- ============================================================================
-- TABLA: Categoria
-- Descripción: Categorías de productos
-- ============================================================================
CREATE TABLE Categoria (
    Id_Categoria SERIAL PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL UNIQUE,
    Descripcion TEXT,
    Activo BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Restricciones
    CONSTRAINT chk_categoria_nombre CHECK (LENGTH(Nombre) >= 2)
);

-- Índices para Categoria
CREATE INDEX idx_categoria_activo ON Categoria(Activo);

-- Comentarios
COMMENT ON TABLE Categoria IS 'Categorías para clasificar productos';
COMMENT ON COLUMN Categoria.Id_Categoria IS 'Identificador único de la categoría';

-- ============================================================================
-- TABLA: Producto
-- Descripción: Catálogo de productos disponibles
-- ============================================================================
CREATE TABLE Producto (
    Id_Producto SERIAL PRIMARY KEY,
    Id_Categoria INTEGER NOT NULL,
    Nombre VARCHAR(200) NOT NULL,
    Descripcion TEXT,
    Precio DECIMAL(10,2) NOT NULL,
    Stock INTEGER NOT NULL DEFAULT 0,
    Activo BOOLEAN NOT NULL DEFAULT TRUE,
    
    -- Claves foráneas
    CONSTRAINT fk_producto_categoria FOREIGN KEY (Id_Categoria) 
        REFERENCES Categoria(Id_Categoria) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    
    -- Restricciones
    CONSTRAINT chk_precio_positivo CHECK (Precio > 0),
    CONSTRAINT chk_stock_no_negativo CHECK (Stock >= 0),
    CONSTRAINT chk_nombre_longitud CHECK (LENGTH(Nombre) >= 3)
);

-- Índices para Producto
CREATE INDEX idx_producto_categoria ON Producto(Id_Categoria);
CREATE INDEX idx_producto_precio ON Producto(Precio);
CREATE INDEX idx_producto_stock ON Producto(Stock);
CREATE INDEX idx_producto_activo ON Producto(Activo);
CREATE INDEX idx_producto_nombre ON Producto(Nombre);

-- Comentarios
COMMENT ON TABLE Producto IS 'Catálogo de productos del e-commerce';
COMMENT ON COLUMN Producto.Stock IS 'Cantidad disponible en inventario';
COMMENT ON COLUMN Producto.Precio IS 'Precio unitario del producto en moneda local';

-- ============================================================================
-- TABLA: Pedido
-- Descripción: Órdenes de compra realizadas por clientes
-- ============================================================================
CREATE TABLE Pedido (
    Id_Pedido SERIAL PRIMARY KEY,
    Id_Cliente INTEGER NOT NULL,
    Fecha_Pedido TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Estado VARCHAR(20) NOT NULL DEFAULT 'Pendiente',
    Total DECIMAL(10,2) NOT NULL DEFAULT 0,
    
    -- Claves foráneas
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (Id_Cliente) 
        REFERENCES Cliente(Id_Cliente) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    
    -- Restricciones
    CONSTRAINT chk_estado_valido CHECK (Estado IN ('Pendiente', 'Procesando', 'Enviado', 'Entregado', 'Cancelado')),
    CONSTRAINT chk_total_no_negativo CHECK (Total >= 0)
);

-- Índices para Pedido
CREATE INDEX idx_pedido_cliente ON Pedido(Id_Cliente);
CREATE INDEX idx_pedido_fecha ON Pedido(Fecha_Pedido DESC);
CREATE INDEX idx_pedido_estado ON Pedido(Estado);
CREATE INDEX idx_pedido_total ON Pedido(Total DESC);

-- Comentarios
COMMENT ON TABLE Pedido IS 'Órdenes de compra del sistema';
COMMENT ON COLUMN Pedido.Estado IS 'Estado actual del pedido: Pendiente, Procesando, Enviado, Entregado, Cancelado';
COMMENT ON COLUMN Pedido.Total IS 'Monto total del pedido calculado automáticamente';

-- ============================================================================
-- TABLA: DetallePedido
-- Descripción: Productos incluidos en cada pedido
-- ============================================================================
CREATE TABLE DetallePedido (
    Id_Detalle SERIAL PRIMARY KEY,
    Id_Pedido INTEGER NOT NULL,
    Id_Producto INTEGER NOT NULL,
    Cantidad INTEGER NOT NULL,
    Precio_Unitario DECIMAL(10,2) NOT NULL,
    
    -- Claves foráneas
    CONSTRAINT fk_detalle_pedido FOREIGN KEY (Id_Pedido) 
        REFERENCES Pedido(Id_Pedido) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (Id_Producto) 
        REFERENCES Producto(Id_Producto) 
        ON DELETE RESTRICT 
        ON UPDATE CASCADE,
    
    -- Restricciones
    CONSTRAINT chk_cantidad_positiva CHECK (Cantidad > 0),
    CONSTRAINT chk_precio_unitario_positivo CHECK (Precio_Unitario > 0),
    CONSTRAINT uk_pedido_producto UNIQUE (Id_Pedido, Id_Producto)
);

-- Índices para DetallePedido
CREATE INDEX idx_detalle_pedido ON DetallePedido(Id_Pedido);
CREATE INDEX idx_detalle_producto ON DetallePedido(Id_Producto);

-- Comentarios
COMMENT ON TABLE DetallePedido IS 'Detalle de productos en cada pedido';
COMMENT ON COLUMN DetallePedido.Precio_Unitario IS 'Precio del producto al momento de la compra';
COMMENT ON COLUMN DetallePedido.Cantidad IS 'Cantidad de unidades del producto en este pedido';

-- ============================================================================
-- TABLA: Pago
-- Descripción: Pagos realizados por los pedidos
-- ============================================================================
CREATE TABLE Pago (
    Id_Pago SERIAL PRIMARY KEY,
    Id_Pedido INTEGER NOT NULL,
    Fecha_Pago TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Metodo VARCHAR(50) NOT NULL,
    Monto DECIMAL(10,2) NOT NULL,
    
    -- Claves foráneas
    CONSTRAINT fk_pago_pedido FOREIGN KEY (Id_Pedido) 
        REFERENCES Pedido(Id_Pedido) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    
    -- Restricciones
    CONSTRAINT chk_metodo_valido CHECK (Metodo IN ('Tarjeta', 'PayPal', 'Transferencia', 'Efectivo', 'Criptomoneda')),
    CONSTRAINT chk_monto_positivo CHECK (Monto > 0)
);

-- Índices para Pago
CREATE INDEX idx_pago_pedido ON Pago(Id_Pedido);
CREATE INDEX idx_pago_fecha ON Pago(Fecha_Pago DESC);
CREATE INDEX idx_pago_metodo ON Pago(Metodo);

-- Comentarios
COMMENT ON TABLE Pago IS 'Registro de pagos realizados';
COMMENT ON COLUMN Pago.Metodo IS 'Método de pago utilizado';
COMMENT ON COLUMN Pago.Monto IS 'Monto pagado';

-- ============================================================================
-- TABLA: Envio
-- Descripción: Información de envíos de pedidos
-- ============================================================================
CREATE TABLE Envio (
    Id_Envio SERIAL PRIMARY KEY,
    Id_Pedido INTEGER NOT NULL UNIQUE,
    Direccion VARCHAR(255) NOT NULL,
    Ciudad VARCHAR(100) NOT NULL,
    Fecha_Envio TIMESTAMP,
    
    -- Claves foráneas
    CONSTRAINT fk_envio_pedido FOREIGN KEY (Id_Pedido) 
        REFERENCES Pedido(Id_Pedido) 
        ON DELETE CASCADE 
        ON UPDATE CASCADE,
    
    -- Restricciones
    CONSTRAINT chk_direccion_longitud CHECK (LENGTH(Direccion) >= 10),
    CONSTRAINT chk_ciudad_longitud CHECK (LENGTH(Ciudad) >= 3)
);

-- Índices para Envio
CREATE INDEX idx_envio_pedido ON Envio(Id_Pedido);
CREATE INDEX idx_envio_ciudad ON Envio(Ciudad);
CREATE INDEX idx_envio_fecha ON Envio(Fecha_Envio DESC);

-- Comentarios
COMMENT ON TABLE Envio IS 'Información de envíos de pedidos';
COMMENT ON COLUMN Envio.Fecha_Envio IS 'Fecha en que se realizó el envío (NULL si aún no se ha enviado)';

-- ============================================================================
-- TRIGGERS Y FUNCIONES
-- ============================================================================

-- Función: Actualizar total del pedido automáticamente
CREATE OR REPLACE FUNCTION actualizar_total_pedido()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Pedido
    SET Total = (
        SELECT COALESCE(SUM(Cantidad * Precio_Unitario), 0)
        FROM DetallePedido
        WHERE Id_Pedido = COALESCE(NEW.Id_Pedido, OLD.Id_Pedido)
    )
    WHERE Id_Pedido = COALESCE(NEW.Id_Pedido, OLD.Id_Pedido);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger: Actualizar total al insertar detalle
CREATE TRIGGER trg_actualizar_total_insert
AFTER INSERT ON DetallePedido
FOR EACH ROW
EXECUTE FUNCTION actualizar_total_pedido();

-- Trigger: Actualizar total al modificar detalle
CREATE TRIGGER trg_actualizar_total_update
AFTER UPDATE ON DetallePedido
FOR EACH ROW
EXECUTE FUNCTION actualizar_total_pedido();

-- Trigger: Actualizar total al eliminar detalle
CREATE TRIGGER trg_actualizar_total_delete
AFTER DELETE ON DetallePedido
FOR EACH ROW
EXECUTE FUNCTION actualizar_total_pedido();

-- Función: Validar stock antes de insertar detalle
CREATE OR REPLACE FUNCTION validar_stock_producto()
RETURNS TRIGGER AS $$
DECLARE
    stock_actual INTEGER;
BEGIN
    SELECT Stock INTO stock_actual
    FROM Producto
    WHERE Id_Producto = NEW.Id_Producto;
    
    IF stock_actual < NEW.Cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente. Disponible: %, Solicitado: %', stock_actual, NEW.Cantidad;
    END IF;
    
    -- Reducir stock
    UPDATE Producto
    SET Stock = Stock - NEW.Cantidad
    WHERE Id_Producto = NEW.Id_Producto;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Validar stock antes de insertar
CREATE TRIGGER trg_validar_stock
BEFORE INSERT ON DetallePedido
FOR EACH ROW
EXECUTE FUNCTION validar_stock_producto();

-- ============================================================================
-- VISTAS ÚTILES
-- ============================================================================

-- Vista: Resumen de ventas por producto
CREATE OR REPLACE VIEW vista_ventas_producto AS
SELECT 
    p.Id_Producto,
    p.Nombre,
    c.Nombre as Categoria,
    COUNT(dp.Id_Detalle) as Total_Ventas,
    SUM(dp.Cantidad) as Unidades_Vendidas,
    SUM(dp.Cantidad * dp.Precio_Unitario) as Ingreso_Total,
    AVG(dp.Precio_Unitario) as Precio_Promedio
FROM Producto p
JOIN Categoria c ON p.Id_Categoria = c.Id_Categoria
LEFT JOIN DetallePedido dp ON p.Id_Producto = dp.Id_Producto
GROUP BY p.Id_Producto, p.Nombre, c.Nombre;

-- Vista: Resumen de pedidos por cliente
CREATE OR REPLACE VIEW vista_pedidos_cliente AS
SELECT 
    c.Id_Cliente,
    c.Nombre,
    c.Email,
    COUNT(p.Id_Pedido) as Total_Pedidos,
    SUM(p.Total) as Total_Gastado,
    AVG(p.Total) as Promedio_Pedido,
    MAX(p.Fecha_Pedido) as Ultima_Compra
FROM Cliente c
LEFT JOIN Pedido p ON c.Id_Cliente = p.Id_Cliente
GROUP BY c.Id_Cliente, c.Nombre, c.Email;

-- ============================================================================
-- DATOS INICIALES (SEEDS)
-- ============================================================================

-- Categorías iniciales
INSERT INTO Categoria (Nombre, Descripcion) VALUES
('Electrónica', 'Dispositivos electrónicos y gadgets'),
('Ropa', 'Prendas de vestir y accesorios'),
('Hogar', 'Artículos para el hogar'),
('Deportes', 'Equipamiento deportivo'),
('Libros', 'Libros físicos y digitales');

-- ============================================================================
-- ANÁLISIS Y ESTADÍSTICAS
-- ============================================================================

-- Analizar tablas para optimizar consultas
ANALYZE Cliente;
ANALYZE Categoria;
ANALYZE Producto;
ANALYZE Pedido;
ANALYZE DetallePedido;
ANALYZE Pago;
ANALYZE Envio;

-- ============================================================================
-- FIN DEL SCRIPT DDL
-- ============================================================================

COMMENT ON DATABASE ecommerce_db IS 'Sistema E-Commerce - Práctica 5 Bases de Datos';

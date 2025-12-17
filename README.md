# Practica5_BasesDeDatos_Ecommerce
Proyecto de Bases de Datos - Práctica 5 (E-Commerce con Docker y PostgreSQL)

# ERD
```
Cliente (1) ──────< (N) Pedido (1) ──────< (N) DetallePedido (N) >────── (1) Producto (N) >────── (1) Categoria
                        │                                                        
                        ├──────< (N) Pago                                        
                        │                                                        
                        └──────< (1) Envio                                       
```
<img width="1531" height="518" alt="image" src="https://github.com/user-attachments/assets/1b0b3fe8-163e-4884-896c-6cf0be5c4336" />

### Cardinalidades

1. **Cliente - Pedido**: 1:N (Un cliente puede tener múltiples pedidos)
2. **Pedido - DetallePedido**: 1:N (Un pedido tiene múltiples productos)
3. **Producto - DetallePedido**: 1:N (Un producto puede estar en múltiples pedidos)
4. **Categoria - Producto**: 1:N (Una categoría contiene múltiples productos)
5. **Pedido - Pago**: 1:N (Un pedido puede tener múltiples pagos)
6. **Pedido - Envio**: 1:1 (Un pedido tiene un único envío)

---

# DICCIONARIO DE DATOS

## 📊 Tabla: Cliente

**Descripción**: Almacena información de los clientes registrados en el sistema e-commerce.

**Tipo**: Tabla principal (Entidad fuerte)

| Campo | Tipo | Restricción | Descripción |
|-------|------|-------------|-------------|
| Id_Cliente | SERIAL | PRIMARY KEY | Identificador único autoincremental del cliente |
| Nombre | VARCHAR(100) | NOT NULL | Nombre completo del cliente. Mínimo 3 caracteres |
| Email | VARCHAR(150) | NOT NULL, UNIQUE | Correo electrónico único. Validado con formato |
| Telefono | VARCHAR(20) | NULL | Número telefónico de contacto |
| Fecha_Registro | TIMESTAMP | NOT NULL, DEFAULT NOW() | Fecha y hora de registro del cliente |
| Activo | BOOLEAN | NOT NULL, DEFAULT TRUE | Estado del cliente (activo/inactivo) |

**Restricciones**:
- `chk_email_formato`: Valida formato de email con expresión regular
- `chk_nombre_longitud`: Nombre debe tener al menos 3 caracteres

**Índices**:
- `idx_cliente_email`: Búsqueda rápida por email
- `idx_cliente_activo`: Filtrado por estado
- `idx_cliente_fecha_registro`: Ordenamiento por fecha

**Relaciones**:
- 1:N con Pedido (Un cliente puede tener múltiples pedidos)

---

## 📊 Tabla: Categoria

**Descripción**: Categorías para clasificar productos en el catálogo.

**Tipo**: Tabla de clasificación

| Campo | Tipo | Restricción | Descripción |
|-------|------|-------------|-------------|
| Id_Categoria | SERIAL | PRIMARY KEY | Identificador único de la categoría |
| Nombre | VARCHAR(100) | NOT NULL, UNIQUE | Nombre de la categoría (único) |
| Descripcion | TEXT | NULL | Descripción detallada de la categoría |
| Activo | BOOLEAN | NOT NULL, DEFAULT TRUE | Indica si la categoría está activa |

**Restricciones**:
- `chk_categoria_nombre`: Nombre debe tener al menos 2 caracteres

**Índices**:
- `idx_categoria_activo`: Filtrado por estado

**Relaciones**:
- 1:N con Producto (Una categoría puede tener múltiples productos)

**Valores iniciales**:
- Electrónica
- Ropa
- Hogar
- Deportes
- Libros

---

## 📊 Tabla: Producto

**Descripción**: Catálogo completo de productos disponibles para la venta.

**Tipo**: Tabla principal (Entidad fuerte)

| Campo | Tipo | Restricción | Descripción |
|-------|------|-------------|-------------|
| Id_Producto | SERIAL | PRIMARY KEY | Identificador único del producto |
| Id_Categoria | INTEGER | NOT NULL, FK | Referencia a la categoría del producto |
| Nombre | VARCHAR(200) | NOT NULL | Nombre del producto. Mínimo 3 caracteres |
| Descripcion | TEXT | NULL | Descripción detallada del producto |
| Precio | DECIMAL(10,2) | NOT NULL | Precio unitario (debe ser > 0) |
| Stock | INTEGER | NOT NULL, DEFAULT 0 | Cantidad disponible en inventario |
| Activo | BOOLEAN | NOT NULL, DEFAULT TRUE | Indica si el producto está disponible |

**Restricciones**:
- `fk_producto_categoria`: Clave foránea a Categoria (RESTRICT on DELETE)
- `chk_precio_positivo`: El precio debe ser mayor que 0
- `chk_stock_no_negativo`: El stock no puede ser negativo
- `chk_nombre_longitud`: Nombre debe tener al menos 3 caracteres

**Índices**:
- `idx_producto_categoria`: Búsqueda por categoría
- `idx_producto_precio`: Ordenamiento por precio
- `idx_producto_stock`: Filtrado por disponibilidad
- `idx_producto_activo`: Productos activos/inactivos
- `idx_producto_nombre`: Búsqueda por nombre

**Relaciones**:
- N:1 con Categoria (Muchos productos pertenecen a una categoría)
- 1:N con DetallePedido (Un producto puede estar en múltiples detalles)

---

## 📊 Tabla: Pedido

**Descripción**: Órdenes de compra realizadas por los clientes.

**Tipo**: Tabla transaccional principal

| Campo | Tipo | Restricción | Descripción |
|-------|------|-------------|-------------|
| Id_Pedido | SERIAL | PRIMARY KEY | Identificador único del pedido |
| Id_Cliente | INTEGER | NOT NULL, FK | Referencia al cliente que realizó el pedido |
| Fecha_Pedido | TIMESTAMP | NOT NULL, DEFAULT NOW() | Fecha y hora de creación del pedido |
| Estado | VARCHAR(20) | NOT NULL, DEFAULT 'Pendiente' | Estado actual del pedido |
| Total | DECIMAL(10,2) | NOT NULL, DEFAULT 0 | Monto total del pedido |

**Restricciones**:
- `fk_pedido_cliente`: Clave foránea a Cliente (RESTRICT on DELETE)
- `chk_estado_valido`: Estado debe ser Pendiente, Procesando, Enviado, Entregado o Cancelado
- `chk_total_no_negativo`: El total no puede ser negativo

**Índices**:
- `idx_pedido_cliente`: Pedidos por cliente
- `idx_pedido_fecha`: Ordenamiento por fecha (DESC)
- `idx_pedido_estado`: Filtrado por estado
- `idx_pedido_total`: Ordenamiento por monto

**Estados válidos**:
1. **Pendiente**: Pedido creado, esperando procesamiento
2. **Procesando**: Pedido en preparación
3. **Enviado**: Pedido despachado
4. **Entregado**: Pedido recibido por el cliente
5. **Cancelado**: Pedido cancelado

**Triggers**:
- El campo Total se actualiza automáticamente al insertar/modificar/eliminar detalles

**Relaciones**:
- N:1 con Cliente (Muchos pedidos pertenecen a un cliente)
- 1:N con DetallePedido (Un pedido tiene múltiples detalles)
- 1:N con Pago (Un pedido puede tener múltiples pagos)
- 1:1 con Envio (Un pedido tiene un envío)

---

## 📊 Tabla: DetallePedido

**Descripción**: Productos específicos incluidos en cada pedido con sus cantidades y precios.

**Tipo**: Tabla de relación (Entidad débil)

| Campo | Tipo | Restricción | Descripción |
|-------|------|-------------|-------------|
| Id_Detalle | SERIAL | PRIMARY KEY | Identificador único del detalle |
| Id_Pedido | INTEGER | NOT NULL, FK | Referencia al pedido |
| Id_Producto | INTEGER | NOT NULL, FK | Referencia al producto |
| Cantidad | INTEGER | NOT NULL | Cantidad de unidades (debe ser > 0) |
| Precio_Unitario | DECIMAL(10,2) | NOT NULL | Precio del producto al momento de la compra |

**Restricciones**:
- `fk_detalle_pedido`: Clave foránea a Pedido (CASCADE on DELETE)
- `fk_detalle_producto`: Clave foránea a Producto (RESTRICT on DELETE)
- `chk_cantidad_positiva`: La cantidad debe ser mayor que 0
- `chk_precio_unitario_positivo`: El precio debe ser mayor que 0
- `uk_pedido_producto`: Un producto solo puede aparecer una vez por pedido

**Índices**:
- `idx_detalle_pedido`: Detalles por pedido
- `idx_detalle_producto`: Ventas por producto

**Triggers**:
- `trg_validar_stock`: Valida stock disponible antes de insertar
- `trg_actualizar_total_*`: Actualiza el total del pedido automáticamente

**Relaciones**:
- N:1 con Pedido (Muchos detalles pertenecen a un pedido)
- N:1 con Producto (Muchos detalles referencian a un producto)

**Nota importante**: El campo Precio_Unitario almacena el precio histórico del producto al momento de la compra, no el precio actual.

---

## 📊 Tabla: Pago

**Descripción**: Registro de pagos realizados para los pedidos.

**Tipo**: Tabla transaccional

| Campo | Tipo | Restricción | Descripción |
|-------|------|-------------|-------------|
| Id_Pago | SERIAL | PRIMARY KEY | Identificador único del pago |
| Id_Pedido | INTEGER | NOT NULL, FK | Referencia al pedido pagado |
| Fecha_Pago | TIMESTAMP | NOT NULL, DEFAULT NOW() | Fecha y hora del pago |
| Metodo | VARCHAR(50) | NOT NULL | Método de pago utilizado |
| Monto | DECIMAL(10,2) | NOT NULL | Monto pagado (debe ser > 0) |

**Restricciones**:
- `fk_pago_pedido`: Clave foránea a Pedido (CASCADE on DELETE)
- `chk_metodo_valido`: Método debe ser Tarjeta, PayPal, Transferencia, Efectivo o Criptomoneda
- `chk_monto_positivo`: El monto debe ser mayor que 0

**Índices**:
- `idx_pago_pedido`: Pagos por pedido
- `idx_pago_fecha`: Ordenamiento por fecha (DESC)
- `idx_pago_metodo`: Análisis por método de pago

**Métodos de pago válidos**:
1. **Tarjeta**: Tarjeta de crédito/débito
2. **PayPal**: Pago electrónico
3. **Transferencia**: Transferencia bancaria
4. **Efectivo**: Pago en efectivo (contra entrega)
5. **Criptomoneda**: Bitcoin, Ethereum, etc.

**Relaciones**:
- N:1 con Pedido (Múltiples pagos pueden aplicarse a un pedido)

**Nota**: Un pedido puede tener múltiples pagos (pagos parciales).

---

## 📊 Tabla: Envio

**Descripción**: Información de envío y entrega de pedidos.

**Tipo**: Tabla complementaria

| Campo | Tipo | Restricción | Descripción |
|-------|------|-------------|-------------|
| Id_Envio | SERIAL | PRIMARY KEY | Identificador único del envío |
| Id_Pedido | INTEGER | NOT NULL, FK, UNIQUE | Referencia única al pedido |
| Direccion | VARCHAR(255) | NOT NULL | Dirección de entrega completa |
| Ciudad | VARCHAR(100) | NOT NULL | Ciudad de entrega |
| Fecha_Envio | TIMESTAMP | NULL | Fecha y hora del envío (NULL si no enviado) |

**Restricciones**:
- `fk_envio_pedido`: Clave foránea a Pedido (CASCADE on DELETE)
- `chk_direccion_longitud`: Dirección debe tener al menos 10 caracteres
- `chk_ciudad_longitud`: Ciudad debe tener al menos 3 caracteres
- UNIQUE en Id_Pedido: Un pedido solo tiene un envío

**Índices**:
- `idx_envio_pedido`: Búsqueda por pedido
- `idx_envio_ciudad`: Análisis por ciudad
- `idx_envio_fecha`: Ordenamiento por fecha de envío

**Relaciones**:
- 1:1 con Pedido (Un envío corresponde a un pedido)

**Nota**: Fecha_Envio es NULL hasta que el pedido sea efectivamente enviado.

---

# DDL
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

---

# POBLADO LEVE

| MÉTRICA | NIVEL 1 | NIVEL 2 | NIVEL 3 |
|---------|---------|---------|---------|
| Total de registros |  |  |  |
| Tiempo de ejecución |  | |  |
| Registros/segundo |  |  | |
| Uso de memoria (MB) |  |  |  |
| Tamaño BD (MB) |  |  | |




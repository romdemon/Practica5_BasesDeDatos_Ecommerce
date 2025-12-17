# Practica5_BasesDeDatos_Ecommerce
Proyecto de Bases de Datos - Práctica 5 (E-Commerce con Docker y PostgreSQL)

## ERD


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

## 🔄 Relaciones Entre Tablas

### Diagrama de Relaciones

```
Cliente (1) ──────< (N) Pedido (1) ──────< (N) DetallePedido (N) >────── (1) Producto (N) >────── (1) Categoria
                        │                                                        
                        ├──────< (N) Pago                                        
                        │                                                        
                        └──────< (1) Envio                                       
```

### Cardinalidades

1. **Cliente - Pedido**: 1:N (Un cliente puede tener múltiples pedidos)
2. **Pedido - DetallePedido**: 1:N (Un pedido tiene múltiples productos)
3. **Producto - DetallePedido**: 1:N (Un producto puede estar en múltiples pedidos)
4. **Categoria - Producto**: 1:N (Una categoría contiene múltiples productos)
5. **Pedido - Pago**: 1:N (Un pedido puede tener múltiples pagos)
6. **Pedido - Envio**: 1:1 (Un pedido tiene un único envío)

---

## 🔐 Reglas de Integridad Referencial

### ON DELETE Policies

| Tabla Hija | Tabla Padre | Acción |
|------------|-------------|---------|
| Producto | Categoria | RESTRICT (No permite eliminar categoría con productos) |
| Pedido | Cliente | RESTRICT (No permite eliminar cliente con pedidos) |
| DetallePedido | Pedido | CASCADE (Elimina detalles al eliminar pedido) |
| DetallePedido | Producto | RESTRICT (No permite eliminar producto con ventas) |
| Pago | Pedido | CASCADE (Elimina pagos al eliminar pedido) |
| Envio | Pedido | CASCADE (Elimina envío al eliminar pedido) |

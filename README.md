# Practica5_BasesDeDatos_Ecommerce
Proyecto de Bases de Datos - Práctica 5 (E-Commerce con Docker y PostgreSQL)

## ERD


## DICCIONARIO DE DATOS


## DDL
CREATE TABLE Mesero (
    id_trabajador SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    fecha_ingreso DATE NOT NULL DEFAULT CURRENT_DATE,
    turno VARCHAR(20) NOT NULL,
    correo VARCHAR(100) UNIQUE NOT NULL, 
    numero_Mesas_asignadas INT NOT NULL CHECK (numero_Mesas_asignadas >= 0),
    experiencia VARCHAR(50)
);

CREATE TABLE Cocinero (
    id_trabajador SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    fecha_ingreso DATE NOT NULL DEFAULT CURRENT_DATE,
    turno VARCHAR(20) NOT NULL, -- Corregido: Es NOT NULL
    correo VARCHAR(100) UNIQUE NOT NULL,
    especialidad VARCHAR(100) NOT NULL,
    años_experiencia INT NOT NULL CHECK (años_experiencia >= 0)
);

CREATE TABLE Cajero (
    id_trabajador SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    fecha_ingreso DATE NOT NULL DEFAULT CURRENT_DATE,
    turno VARCHAR(20) NOT NULL,
    correo VARCHAR(100) UNIQUE NOT NULL,
    turno_caja VARCHAR(50) NOT NULL,
    nivel_acceso INT NOT NULL
);

CREATE TABLE Repartidor (
    id_trabajador SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    fecha_ingreso DATE NOT NULL DEFAULT CURRENT_DATE,
    turno VARCHAR(20) NOT NULL,
    correo VARCHAR(100) UNIQUE NOT NULL,
    zona_reparto VARCHAR(100) NOT NULL,
    transporte VARCHAR (50) NOT NULL
);

CREATE TABLE Clientes (
    id_cliente SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    correo VARCHAR(100) UNIQUE NOT NULL,
    telefono VARCHAR(15) NOT NULL,
    contrasena VARCHAR(200) NOT NULL,
    calle VARCHAR(50) NOT NULL,
    numero VARCHAR(10) NOT NULL,
    colonia VARCHAR(50) NOT NULL,
    ciudad VARCHAR(50) NOT NULL
);


CREATE TABLE Mesa (
    id_Mesa SERIAL PRIMARY KEY,
    numero INT NOT NULL UNIQUE,
    capacidad INT NOT NULL CHECK (capacidad > 0),
    disponible BOOLEAN NOT NULL DEFAULT TRUE,
    ubicacion VARCHAR(50)
);

CREATE TABLE Platillo (
    id_Platillo SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    precio NUMERIC(10,2) NOT NULL CHECK (precio > 0),
    categoria VARCHAR(50) NOT NULL,
    descripcion VARCHAR(255)
);

-- 3. CREACIÓN DE TABLAS HIJAS (CON FK y Acciones Referenciales)
CREATE TABLE Cliente_telefono (
    id_Cliente INT NOT NULL,
    telefono VARCHAR(20) NOT NULL,
    CONSTRAINT pk_Cliente_telefono PRIMARY KEY (id_Cliente, telefono),
    CONSTRAINT fk_telefono_Cliente FOREIGN KEY (id_Cliente)
        REFERENCES CLIENTE(id_Cliente)
        ON DELETE CASCADE ON UPDATE CASCADE -- ON DELETE CASCADE
);

CREATE TABLE Pedido (
    id_Pedido SERIAL PRIMARY KEY,
    fecha TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total NUMERIC (10,2) NOT NULL CHECK (total >= 0),
    tipo_Pedido VARCHAR (20) NOT NULL CHECK (tipo_Pedido IN ('Mesa', 'Domicilio')),
    estado VARCHAR (30) NOT NULL DEFAULT 'PENDIENTE' CHECK (estado IN ('PENDIENTE', 'PREPARANDO', 'LISTO', 'ENTREGADO', 'PAGADO', 'CANCELADO')),
    descripcion VARCHAR (255),
    id_Cliente INT NOT NULL,
    CONSTRAINT fk_Pedido_Cliente FOREIGN KEY (id_Cliente)
        REFERENCES Cliente(id_Cliente)
        ON DELETE RESTRICT ON UPDATE CASCADE -- ON DELETE RESTRICT
);

CREATE TABLE Detalle_pedido (
    id_Pedido INT NOT NULL,
    id_Platillo INT NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    notas_especiales TEXT,
    precio_unitario NUMERIC(10,2) NOT NULL,
    CONSTRAINT pk_Detalle_pedido PRIMARY KEY (id_Pedido, id_Platillo),
    CONSTRAINT fk_Detalle_pedido_Pedido FOREIGN KEY (id_Pedido)
        REFERENCES Pedido(id_Pedido)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_Detalle_pedido_Platillo FOREIGN KEY (id_Platillo)
        REFERENCES Platillo(id_Platillo)
        ON DELETE RESTRICT ON UPDATE CASCADE -- ON DELETE RESTRICT
);

CREATE TABLE Atencion_Pedido (
    id_atencion SERIAL PRIMARY KEY, 
    id_Pedido INT NOT NULL UNIQUE,
    id_Mesa INT NOT NULL,
    id_mesero INT NOT NULL,
    fecha_hora TIMESTAMP WITHOUT TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_atencion_Pedido_Pedido FOREIGN KEY (id_Pedido)
        REFERENCES Pedido (id_Pedido) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_atencion_Pedido_Mesa FOREIGN KEY (id_Mesa)
        REFERENCES Mesa (id_Mesa) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_atencion_Pedido_mesero FOREIGN KEY (id_mesero)
        REFERENCES Mesero (id_trabajador) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Entrega_domicilio  (
    id_entrega SERIAL PRIMARY KEY,
    id_Pedido INT NOT NULL UNIQUE,
    id_Repartidor INT NOT NULL,
    hora_salida TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    hora_llegada TIMESTAMP CHECK (hora_llegada > hora_salida),
    tarifa_entrega NUMERIC(10,2) NOT NULL CHECK (tarifa_entrega > 0),
    estado_entrega VARCHAR(30) NOT NULL,
    CONSTRAINT fk_entrega_Pedido FOREIGN KEY (id_Pedido)
        REFERENCES Pedido(id_Pedido) ON DELETE CASCADE ON UPDATE CASCADE, 
    CONSTRAINT fk_entrega_Repartidor FOREIGN KEY (id_Repartidor)
        REFERENCES Repartidor (id_trabajador) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Asignacion_cocina (
    id_asignacion SERIAL PRIMARY KEY,
    id_pedido INT NOT NULL,
    id_platillo INT NOT NULL,
    id_cocinero INT NOT NULL,
    hora_inicio TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    hora_fin TIMESTAMP CHECK (hora_fin > hora_inicio),
    estado_preparacion VARCHAR(30) NOT NULL DEFAULT 'ASIGNADO',
    CONSTRAINT uk_asignacion UNIQUE (id_pedido, id_platillo),
    CONSTRAINT fk_asignacion_detalle FOREIGN KEY (id_pedido, id_platillo)
        REFERENCES Detalle_pedido(id_pedido, id_platillo) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_asignacion_cocinero FOREIGN KEY (id_cocinero)
        REFERENCES Cocinero(id_trabajador) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Pago_transaccion (
    id_transaccion SERIAL PRIMARY KEY,
    id_pedido INT NOT NULL UNIQUE,
    id_cajero INT NOT NULL,
    fecha_pago TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto_final NUMERIC(10,2) NOT NULL CHECK (monto_final > 0),
    tipo_pago VARCHAR(30) NOT NULL,
    CONSTRAINT fk_pago_pedido FOREIGN KEY (id_pedido)
        REFERENCES Pedido(id_pedido) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pago_cajero FOREIGN KEY (id_cajero)
        REFERENCES Cajero(id_trabajador) ON DELETE RESTRICT ON UPDATE CASCADE
);

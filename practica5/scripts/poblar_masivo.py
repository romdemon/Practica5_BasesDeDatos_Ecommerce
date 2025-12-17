#!/usr/bin/env python3
"""
Práctica 5 - Poblado Moderado (Pre-producción)
Sistema E-Commerce

Nivel 2:
- 10,000 clientes
- 5,000 productos
- 15,000 pedidos
- ~50,000 detalles
- Técnicas: Batch insert, desactivación de índices
- Tiempo estimado: 2-5 minutos
"""

import os
import sys
import time
import random
from datetime import datetime, timedelta
from decimal import Decimal
import psycopg2
from psycopg2.extras import execute_batch
from faker import Faker
from tqdm import tqdm
import psutil

# Configuración
fake = Faker(['es_MX', 'es_ES'])
Faker.seed(42)
random.seed(42)

DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'postgres'),
    'port': os.getenv('DB_PORT', '5432'),
    'database': os.getenv('DB_NAME', 'ecommerce_db'),
    'user': os.getenv('DB_USER', 'ecommerce_user'),
    'password': os.getenv('DB_PASSWORD', 'ecommerce_pass')
}

# Cantidades para nivel moderado
CLIENTES = 10000
PRODUCTOS = 5000
PEDIDOS = 15000
MIN_DETALLES = 1
MAX_DETALLES = 6

# Tamaño de batch para inserts
BATCH_SIZE = 1000

CATEGORIAS = [
    'Electrónica', 'Ropa', 'Hogar', 'Deportes', 'Libros',
    'Juguetes', 'Alimentos', 'Belleza', 'Automotriz', 'Jardinería',
    'Música', 'Cine', 'Gaming', 'Oficina', 'Mascotas'
]

METODOS_PAGO = ['Tarjeta', 'PayPal', 'Transferencia', 'Efectivo', 'Criptomoneda']
ESTADOS_PEDIDO = ['Pendiente', 'Procesando', 'Enviado', 'Entregado', 'Cancelado']


def conectar_db():
    """Establece conexión con PostgreSQL"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = False
        return conn
    except Exception as e:
        print(f"❌ Error conectando a la base de datos: {e}")
        sys.exit(1)


def desactivar_indices(conn):
    """Desactiva índices no esenciales para acelerar inserts"""
    print("\n🔧 Desactivando índices temporalmente...")
    cursor = conn.cursor()
    
    indices_desactivar = [
        'idx_cliente_email', 'idx_cliente_activo', 'idx_cliente_fecha_registro',
        'idx_categoria_activo',
        'idx_producto_categoria', 'idx_producto_precio', 'idx_producto_stock',
        'idx_producto_activo', 'idx_producto_nombre',
        'idx_pedido_cliente', 'idx_pedido_fecha', 'idx_pedido_estado', 'idx_pedido_total',
        'idx_detalle_pedido', 'idx_detalle_producto',
        'idx_pago_pedido', 'idx_pago_fecha', 'idx_pago_metodo',
        'idx_envio_pedido', 'idx_envio_ciudad', 'idx_envio_fecha'
    ]
    
    for indice in indices_desactivar:
        try:
            cursor.execute(f"DROP INDEX IF EXISTS {indice}")
        except Exception as e:
            print(f"⚠️  No se pudo eliminar {indice}: {e}")
    
    conn.commit()
    print("✓ Índices desactivados")


def reactivar_indices(conn):
    """Reactiva índices después del poblado"""
    print("\n🔧 Reactivando índices...")
    cursor = conn.cursor()
    
    indices = [
        "CREATE INDEX idx_cliente_email ON Cliente(Email)",
        "CREATE INDEX idx_cliente_activo ON Cliente(Activo)",
        "CREATE INDEX idx_cliente_fecha_registro ON Cliente(Fecha_Registro DESC)",
        "CREATE INDEX idx_categoria_activo ON Categoria(Activo)",
        "CREATE INDEX idx_producto_categoria ON Producto(Id_Categoria)",
        "CREATE INDEX idx_producto_precio ON Producto(Precio)",
        "CREATE INDEX idx_producto_stock ON Producto(Stock)",
        "CREATE INDEX idx_producto_activo ON Producto(Activo)",
        "CREATE INDEX idx_producto_nombre ON Producto(Nombre)",
        "CREATE INDEX idx_pedido_cliente ON Pedido(Id_Cliente)",
        "CREATE INDEX idx_pedido_fecha ON Pedido(Fecha_Pedido DESC)",
        "CREATE INDEX idx_pedido_estado ON Pedido(Estado)",
        "CREATE INDEX idx_pedido_total ON Pedido(Total DESC)",
        "CREATE INDEX idx_detalle_pedido ON DetallePedido(Id_Pedido)",
        "CREATE INDEX idx_detalle_producto ON DetallePedido(Id_Producto)",
        "CREATE INDEX idx_pago_pedido ON Pago(Id_Pedido)",
        "CREATE INDEX idx_pago_fecha ON Pago(Fecha_Pago DESC)",
        "CREATE INDEX idx_pago_metodo ON Pago(Metodo)",
        "CREATE INDEX idx_envio_pedido ON Envio(Id_Pedido)",
        "CREATE INDEX idx_envio_ciudad ON Envio(Ciudad)",
        "CREATE INDEX idx_envio_fecha ON Envio(Fecha_Envio DESC)"
    ]
    
    for create_query in tqdm(indices, desc="Creando índices"):
        try:
            cursor.execute(create_query)
        except Exception as e:
            print(f"⚠️  Error creando índice: {e}")
    
    conn.commit()
    print("✓ Índices reactivados")


def limpiar_datos(conn):
    """Limpia todos los datos"""
    print("\n🗑️  Limpiando datos existentes...")
    cursor = conn.cursor()
    
    tablas = ['Pago', 'Envio', 'DetallePedido', 'Pedido', 'Producto', 'Categoria', 'Cliente']
    for tabla in tablas:
        cursor.execute(f"TRUNCATE TABLE {tabla} RESTART IDENTITY CASCADE")
    
    conn.commit()
    print("✓ Datos limpiados")


def poblar_clientes(conn):
    """Poblar clientes en batches"""
    print(f"\n👥 Poblando {CLIENTES:,} clientes...")
    cursor = conn.cursor()
    
    query = """
        INSERT INTO Cliente (Nombre, Email, Telefono, Fecha_Registro, Activo)
        VALUES (%s, %s, %s, %s, %s)
    """
    
    emails_usados = set()
    batch = []
    
    with tqdm(total=CLIENTES, desc="Clientes") as pbar:
        for i in range(CLIENTES):
            while True:
                email = fake.email()
                if email not in emails_usados:
                    emails_usados.add(email)
                    break
            
            nombre = fake.name()
            telefono = fake.phone_number()[:20]
            fecha = fake.date_time_between(start_date='-3y', end_date='now')
            activo = random.choice([True] * 8 + [False] * 2)
            
            batch.append((nombre, email, telefono, fecha, activo))
            
            if len(batch) >= BATCH_SIZE:
                execute_batch(cursor, query, batch, page_size=BATCH_SIZE)
                conn.commit()
                batch = []
                pbar.update(BATCH_SIZE)
        
        # Insertar restantes
        if batch:
            execute_batch(cursor, query, batch, page_size=len(batch))
            conn.commit()
            pbar.update(len(batch))
    
    print(f"✓ {CLIENTES:,} clientes insertados")


def poblar_categorias(conn):
    """Poblar categorías"""
    print(f"\n📂 Poblando {len(CATEGORIAS)} categorías...")
    cursor = conn.cursor()
    
    categorias = [(cat, f"Productos de {cat.lower()}", True) for cat in CATEGORIAS]
    
    query = "INSERT INTO Categoria (Nombre, Descripcion, Activo) VALUES (%s, %s, %s)"
    execute_batch(cursor, query, categorias)
    conn.commit()
    
    print(f"✓ {len(CATEGORIAS)} categorías insertadas")


def poblar_productos(conn):
    """Poblar productos en batches"""
    print(f"\n📦 Poblando {PRODUCTOS:,} productos...")
    cursor = conn.cursor()
    
    cursor.execute("SELECT Id_Categoria FROM Categoria")
    categoria_ids = [row[0] for row in cursor.fetchall()]
    
    query = """
        INSERT INTO Producto (Id_Categoria, Nombre, Descripcion, Precio, Stock, Activo)
        VALUES (%s, %s, %s, %s, %s, %s)
    """
    
    batch = []
    
    with tqdm(total=PRODUCTOS, desc="Productos") as pbar:
        for i in range(PRODUCTOS):
            id_cat = random.choice(categoria_ids)
            nombre = f"{fake.catch_phrase()} {fake.color_name()}"[:200]
            desc = fake.text(max_nb_chars=300)
            precio = Decimal(random.uniform(5, 10000)).quantize(Decimal('0.01'))
            stock = random.randint(0, 2000)
            activo = random.choice([True] * 9 + [False])
            
            batch.append((id_cat, nombre, desc, precio, stock, activo))
            
            if len(batch) >= BATCH_SIZE:
                execute_batch(cursor, query, batch, page_size=BATCH_SIZE)
                conn.commit()
                batch = []
                pbar.update(BATCH_SIZE)
        
        if batch:
            execute_batch(cursor, query, batch)
            conn.commit()
            pbar.update(len(batch))
    
    print(f"✓ {PRODUCTOS:,} productos insertados")


def poblar_pedidos_y_detalles(conn):
    """Poblar pedidos con detalles"""
    print(f"\n🛒 Poblando {PEDIDOS:,} pedidos con detalles...")
    cursor = conn.cursor()
    
    cursor.execute("SELECT Id_Cliente FROM Cliente WHERE Activo = TRUE")
    clientes = [r[0] for r in cursor.fetchall()]
    
    cursor.execute("SELECT Id_Producto, Precio FROM Producto WHERE Activo = TRUE AND Stock > 0")
    productos = cursor.fetchall()
    
    total_detalles = 0
    total_pagos = 0
    total_envios = 0
    
    with tqdm(total=PEDIDOS, desc="Pedidos") as pbar:
        for _ in range(PEDIDOS):
            try:
                id_cliente = random.choice(clientes)
                fecha_pedido = fake.date_time_between(start_date='-1y', end_date='now')
                estado = random.choice(ESTADOS_PEDIDO)
                
                cursor.execute("""
                    INSERT INTO Pedido (Id_Cliente, Fecha_Pedido, Estado, Total)
                    VALUES (%s, %s, %s, 0) RETURNING Id_Pedido
                """, (id_cliente, fecha_pedido, estado))
                
                id_pedido = cursor.fetchone()[0]
                
                # Detalles
                num_det = random.randint(MIN_DETALLES, MAX_DETALLES)
                prods_pedido = random.sample(productos, min(num_det, len(productos)))
                
                for id_prod, precio in prods_pedido:
                    cant = random.randint(1, 10)
                    precio_unit = Decimal(float(precio) * random.uniform(0.9, 1.1)).quantize(Decimal('0.01'))
                    
                    cursor.execute("""
                        INSERT INTO DetallePedido (Id_Pedido, Id_Producto, Cantidad, Precio_Unitario)
                        VALUES (%s, %s, %s, %s)
                    """, (id_pedido, id_prod, cant, precio_unit))
                    total_detalles += 1
                
                # Pago
                if estado in ['Procesando', 'Enviado', 'Entregado']:
                    cursor.execute("SELECT Total FROM Pedido WHERE Id_Pedido = %s", (id_pedido,))
                    total = cursor.fetchone()[0]
                    metodo = random.choice(METODOS_PAGO)
                    fecha_pago = fecha_pedido + timedelta(hours=random.randint(1, 72))
                    
                    cursor.execute("""
                        INSERT INTO Pago (Id_Pedido, Fecha_Pago, Metodo, Monto)
                        VALUES (%s, %s, %s, %s)
                    """, (id_pedido, fecha_pago, metodo, total))
                    total_pagos += 1
                
                # Envío
                if estado in ['Enviado', 'Entregado']:
                    direccion = fake.street_address()
                    ciudad = fake.city()
                    fecha_envio = fecha_pedido + timedelta(days=random.randint(1, 5))
                    
                    cursor.execute("""
                        INSERT INTO Envio (Id_Pedido, Direccion, Ciudad, Fecha_Envio)
                        VALUES (%s, %s, %s, %s)
                    """, (id_pedido, direccion, ciudad, fecha_envio))
                    total_envios += 1
                
                if (_ + 1) % 100 == 0:
                    conn.commit()
                
                pbar.update(1)
                
            except Exception as e:
                continue
        
        conn.commit()
    
    print(f"✓ {PEDIDOS:,} pedidos, {total_detalles:,} detalles, {total_pagos:,} pagos, {total_envios:,} envíos")


def mostrar_estadisticas(conn):
    """Muestra estadísticas"""
    print("\n📊 Estadísticas:")
    cursor = conn.cursor()
    
    tablas = ['Cliente', 'Categoria', 'Producto', 'Pedido', 'DetallePedido', 'Pago', 'Envio']
    total = 0
    
    for tabla in tablas:
        cursor.execute(f"SELECT COUNT(*) FROM {tabla}")
        count = cursor.fetchone()[0]
        total += count
        print(f"   {tabla:15} {count:>12,} registros")
    
    print(f"   {'TOTAL':15} {total:>12,} registros")


def main():
    """Función principal"""
    print("\n" + "="*80)
    print("  POBLADO MODERADO - NIVEL 2 (PRE-PRODUCCIÓN)")
    print("="*80)
    
    inicio = time.time()
    proceso = psutil.Process()
    mem_inicio = proceso.memory_info().rss / 1024 / 1024
    
    conn = conectar_db()
    print(f"✓ Conectado a {DB_CONFIG['database']}")
    
    try:
        limpiar_datos(conn)
        desactivar_indices(conn)
        
        poblar_clientes(conn)
        poblar_categorias(conn)
        poblar_productos(conn)
        poblar_pedidos_y_detalles(conn)
        
        reactivar_indices(conn)
        
        # VACUUM y ANALYZE
        print("\n🔧 Optimizando base de datos...")
        conn.autocommit = True
        cursor = conn.cursor()
        cursor.execute("VACUUM ANALYZE")
        conn.autocommit = False
        print("✓ Optimización completada")
        
        mostrar_estadisticas(conn)
        
        # Métricas
        fin = time.time()
        duracion = fin - inicio
        mem_fin = proceso.memory_info().rss / 1024 / 1024
        mem_usada = mem_fin - mem_inicio
        
        cursor = conn.cursor()
        cursor.execute("""
            SELECT (SELECT COUNT(*) FROM Cliente) + (SELECT COUNT(*) FROM Producto) +
                   (SELECT COUNT(*) FROM Pedido) + (SELECT COUNT(*) FROM DetallePedido) +
                   (SELECT COUNT(*) FROM Pago) + (SELECT COUNT(*) FROM Envio)
        """)
        total_reg = cursor.fetchone()[0]
        
        cursor.execute("SELECT pg_size_pretty(pg_database_size(%s))", (DB_CONFIG['database'],))
        tamano = cursor.fetchone()[0]
        
        print(f"\n⏱️  Tiempo: {duracion:.2f} segundos")
        print(f"💾 Memoria: {mem_usada:.2f} MB")
        print(f"🚀 Velocidad: {total_reg/duracion:.2f} registros/segundo")
        print(f"💿 Tamaño BD: {tamano}")
        
        print("\n✅ Poblado moderado completado")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        conn.rollback()
        sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
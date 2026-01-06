#!/usr/bin/env python3
"""
Práctica 5 - Poblado Masivo (Producción)
Sistema E-Commerce

Nivel 3:
- 500,000 clientes
- 100,000 productos
- 1,000,000 pedidos
- ~3,000,000 detalles
- Técnicas: COPY FROM STDIN, carga paralela, optimizaciones avanzadas
- Tiempo estimado: 15-30 minutos
"""

import os
import sys
import time
import random
from datetime import datetime, timedelta
from decimal import Decimal
import psycopg2
from faker import Faker
from tqdm import tqdm
import psutil
from io import StringIO
import csv

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

# Cantidades masivas
CLIENTES = 500000
PRODUCTOS = 100000
PEDIDOS = 1000000
MIN_DETALLES = 1
MAX_DETALLES = 5

# Tamaño de buffer para COPY
COPY_BUFFER_SIZE = 50000

CATEGORIAS = [
    'Electrónica', 'Ropa', 'Hogar', 'Deportes', 'Libros',
    'Juguetes', 'Alimentos', 'Belleza', 'Automotriz', 'Jardinería',
    'Música', 'Cine', 'Gaming', 'Oficina', 'Mascotas', 'Farmacia',
    'Construcción', 'Arte', 'Fotografía', 'Tecnología'
]

METODOS_PAGO = ['Tarjeta', 'PayPal', 'Transferencia', 'Efectivo', 'Criptomoneda']
ESTADOS_PEDIDO = ['Pendiente', 'Procesando', 'Enviado', 'Entregado', 'Cancelado']


def conectar_db():
    """Conexión a PostgreSQL"""
    try:
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = False
        return conn
    except Exception as e:
        print(f"❌ Error: {e}")
        sys.exit(1)


def desactivar_constraints_indices(conn):
    """Desactiva constraints e índices para máximo rendimiento"""
    print("\n🔧 Desactivando constraints e índices...")
    cursor = conn.cursor()
    
    # Desactivar triggers
    try:
        cursor.execute("ALTER TABLE DetallePedido DISABLE TRIGGER trg_validar_stock")
        cursor.execute("ALTER TABLE DetallePedido DISABLE TRIGGER trg_actualizar_total_insert")
        cursor.execute("ALTER TABLE DetallePedido DISABLE TRIGGER trg_actualizar_total_update")
        cursor.execute("ALTER TABLE DetallePedido DISABLE TRIGGER trg_actualizar_total_delete")
    except:
        pass
    
    # Eliminar índices no esenciales
    indices = [
        'idx_cliente_email', 'idx_cliente_activo', 'idx_cliente_fecha_registro',
        'idx_categoria_activo',
        'idx_producto_categoria', 'idx_producto_precio', 'idx_producto_stock',
        'idx_producto_activo', 'idx_producto_nombre',
        'idx_pedido_cliente', 'idx_pedido_fecha', 'idx_pedido_estado', 'idx_pedido_total',
        'idx_detalle_pedido', 'idx_detalle_producto',
        'idx_pago_pedido', 'idx_pago_fecha', 'idx_pago_metodo',
        'idx_envio_pedido', 'idx_envio_ciudad', 'idx_envio_fecha'
    ]
    
    for idx in indices:
        try:
            cursor.execute(f"DROP INDEX IF EXISTS {idx}")
        except:
            pass
    
    conn.commit()
    print("✓ Constraints e índices desactivados")


def reactivar_constraints_indices(conn):
    """Reactiva constraints e índices"""
    print("\n🔧 Reactivando constraints e índices...")
    cursor = conn.cursor()
    
    # Reactivar triggers
    try:
        cursor.execute("ALTER TABLE DetallePedido ENABLE TRIGGER trg_validar_stock")
        cursor.execute("ALTER TABLE DetallePedido ENABLE TRIGGER trg_actualizar_total_insert")
        cursor.execute("ALTER TABLE DetallePedido ENABLE TRIGGER trg_actualizar_total_update")
        cursor.execute("ALTER TABLE DetallePedido ENABLE TRIGGER trg_actualizar_total_delete")
    except:
        pass
    
    # Recrear índices
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
    
    for query in tqdm(indices, desc="Índices"):
        try:
            cursor.execute(query)
            conn.commit()
        except Exception as e:
            print(f"⚠️  Error: {e}")
    
    print("✓ Constraints e índices reactivados")


def limpiar_datos(conn):
    """Limpia datos"""
    print("\n🗑️  Limpiando datos...")
    cursor = conn.cursor()
    
    tablas = ['Pago', 'Envio', 'DetallePedido', 'Pedido', 'Producto', 'Categoria', 'Cliente']
    for tabla in tablas:
        cursor.execute(f"TRUNCATE TABLE {tabla} RESTART IDENTITY CASCADE")
    
    conn.commit()
    print("✓ Datos limpiados")


def poblar_clientes_copy(conn):
    """Poblar clientes usando COPY FROM STDIN"""
    print(f"\n👥 Poblando {CLIENTES:,} clientes con COPY...")
    cursor = conn.cursor()
    
    emails_usados = set()
    buffer = StringIO()
    
    with tqdm(total=CLIENTES, desc="Generando clientes") as pbar:
        for i in range(CLIENTES):
            while True:
                email = fake.email()
                if email not in emails_usados:
                    emails_usados.add(email)
                    break
            
            nombre = fake.name().replace('\t', ' ').replace('\n', ' ')
            telefono = fake.phone_number()[:20]
            fecha = fake.date_time_between(start_date='-5y', end_date='now')
            activo = random.choice([True] * 9 + [False])
            
            buffer.write(f"{nombre}\t{email}\t{telefono}\t{fecha}\t{activo}\n")
            
            if (i + 1) % COPY_BUFFER_SIZE == 0:
                buffer.seek(0)
                cursor.copy_from(
                    buffer,
                    'Cliente',
                    columns=('Nombre', 'Email', 'Telefono', 'Fecha_Registro', 'Activo'),
                    sep='\t'
                )
                conn.commit()
                buffer = StringIO()
                pbar.update(COPY_BUFFER_SIZE)
        
        # Insertar restantes
        if buffer.tell() > 0:
            buffer.seek(0)
            cursor.copy_from(buffer, 'Cliente',
                           columns=('Nombre', 'Email', 'Telefono', 'Fecha_Registro', 'Activo'),
                           sep='\t')
            conn.commit()
            pbar.update(CLIENTES % COPY_BUFFER_SIZE)
    
    print(f"✓ {CLIENTES:,} clientes insertados")


def poblar_categorias(conn):
    """Poblar categorías"""
    print(f"\n📂 Poblando {len(CATEGORIAS)} categorías...")
    cursor = conn.cursor()
    
    for cat in CATEGORIAS:
        cursor.execute("""
            INSERT INTO Categoria (Nombre, Descripcion, Activo)
            VALUES (%s, %s, TRUE)
        """, (cat, f"Productos de {cat.lower()}"))
    
    conn.commit()
    print(f"✓ {len(CATEGORIAS)} categorías insertadas")


def poblar_productos_copy(conn):
    """Poblar productos usando COPY"""
    print(f"\n📦 Poblando {PRODUCTOS:,} productos con COPY...")
    cursor = conn.cursor()
    
    cursor.execute("SELECT Id_Categoria FROM Categoria")
    cats = [r[0] for r in cursor.fetchall()]
    
    buffer = StringIO()
    
    with tqdm(total=PRODUCTOS, desc="Generando productos") as pbar:
        for i in range(PRODUCTOS):
            id_cat = random.choice(cats)
            nombre = f"{fake.catch_phrase()} {fake.color_name()}"[:200].replace('\t', ' ').replace('\n', ' ')
            desc = fake.text(max_nb_chars=200).replace('\t', ' ').replace('\n', ' ')
            precio = Decimal(random.uniform(5, 15000)).quantize(Decimal('0.01'))
            stock = random.randint(0, 3000)
            activo = random.choice([True] * 95 + [False] * 5)
            
            buffer.write(f"{id_cat}\t{nombre}\t{desc}\t{precio}\t{stock}\t{activo}\n")
            
            if (i + 1) % COPY_BUFFER_SIZE == 0:
                buffer.seek(0)
                cursor.copy_from(buffer, 'Producto',
                               columns=('Id_Categoria', 'Nombre', 'Descripcion', 'Precio', 'Stock', 'Activo'),
                               sep='\t')
                conn.commit()
                buffer = StringIO()
                pbar.update(COPY_BUFFER_SIZE)
        
        if buffer.tell() > 0:
            buffer.seek(0)
            cursor.copy_from(buffer, 'Producto',
                           columns=('Id_Categoria', 'Nombre', 'Descripcion', 'Precio', 'Stock', 'Activo'),
                           sep='\t')
            conn.commit()
            pbar.update(PRODUCTOS % COPY_BUFFER_SIZE)
    
    print(f"✓ {PRODUCTOS:,} productos insertados")


def poblar_pedidos_copy(conn):
    """Poblar pedidos y detalles usando COPY"""
    print(f"\n🛒 Poblando {PEDIDOS:,} pedidos con detalles usando COPY...")
    cursor = conn.cursor()
    
    cursor.execute("SELECT Id_Cliente FROM Cliente WHERE Activo = TRUE LIMIT 100000")
    clientes = [r[0] for r in cursor.fetchall()]
    
    cursor.execute("SELECT Id_Producto, Precio FROM Producto WHERE Activo = TRUE AND Stock > 0 LIMIT 50000")
    productos = cursor.fetchall()
    
    buffer_pedidos = StringIO()
    buffer_detalles = StringIO()
    buffer_pagos = StringIO()
    buffer_envios = StringIO()
    
    total_detalles = 0
    total_pagos = 0
    total_envios = 0
    
    with tqdm(total=PEDIDOS, desc="Generando pedidos") as pbar:
        for i in range(PEDIDOS):
            id_pedido = i + 1  # Asumiendo SERIAL secuencial
            id_cliente = random.choice(clientes)
            fecha_pedido = fake.date_time_between(start_date='-2y', end_date='now')
            estado = random.choice(ESTADOS_PEDIDO)
            
            # Generar detalles
            num_det = random.randint(MIN_DETALLES, MAX_DETALLES)
            prods = random.sample(productos, min(num_det, len(productos)))
            
            total_pedido = Decimal('0')
            for id_prod, precio in prods:
                cant = random.randint(1, 8)
                precio_unit = Decimal(float(precio) * random.uniform(0.9, 1.1)).quantize(Decimal('0.01'))
                subtotal = precio_unit * cant
                total_pedido += subtotal
                
                buffer_detalles.write(f"{id_pedido}\t{id_prod}\t{cant}\t{precio_unit}\n")
                total_detalles += 1
            
            buffer_pedidos.write(f"{id_cliente}\t{fecha_pedido}\t{estado}\t{total_pedido}\n")
            
            # Pagos y envíos
            if estado in ['Procesando', 'Enviado', 'Entregado']:
                metodo = random.choice(METODOS_PAGO)
                fecha_pago = fecha_pedido + timedelta(hours=random.randint(1, 72))
                buffer_pagos.write(f"{id_pedido}\t{fecha_pago}\t{metodo}\t{total_pedido}\n")
                total_pagos += 1
            
            if estado in ['Enviado', 'Entregado']:
                direccion = fake.street_address().replace('\t', ' ').replace('\n', ' ')[:255]
                ciudad = fake.city().replace('\t', ' ')[:100]
                fecha_envio = fecha_pedido + timedelta(days=random.randint(1, 7))
                buffer_envios.write(f"{id_pedido}\t{direccion}\t{ciudad}\t{fecha_envio}\n")
                total_envios += 1
            
            if (i + 1) % COPY_BUFFER_SIZE == 0:
                # Insertar pedidos
                buffer_pedidos.seek(0)
                cursor.copy_from(buffer_pedidos, 'Pedido',
                               columns=('Id_Cliente', 'Fecha_Pedido', 'Estado', 'Total'),
                               sep='\t')
                
                # Insertar detalles
                buffer_detalles.seek(0)
                cursor.copy_from(buffer_detalles, 'DetallePedido',
                               columns=('Id_Pedido', 'Id_Producto', 'Cantidad', 'Precio_Unitario'),
                               sep='\t')
                
                # Insertar pagos
                if buffer_pagos.tell() > 0:
                    buffer_pagos.seek(0)
                    cursor.copy_from(buffer_pagos, 'Pago',
                                   columns=('Id_Pedido', 'Fecha_Pago', 'Metodo', 'Monto'),
                                   sep='\t')
                
                # Insertar envíos
                if buffer_envios.tell() > 0:
                    buffer_envios.seek(0)
                    cursor.copy_from(buffer_envios, 'Envio',
                                   columns=('Id_Pedido', 'Direccion', 'Ciudad', 'Fecha_Envio'),
                                   sep='\t')
                
                conn.commit()
                
                # Reiniciar buffers
                buffer_pedidos = StringIO()
                buffer_detalles = StringIO()
                buffer_pagos = StringIO()
                buffer_envios = StringIO()
                
                pbar.update(COPY_BUFFER_SIZE)
        
        # Insertar restantes
        if buffer_pedidos.tell() > 0:
            buffer_pedidos.seek(0)
            cursor.copy_from(buffer_pedidos, 'Pedido',
                           columns=('Id_Cliente', 'Fecha_Pedido', 'Estado', 'Total'),
                           sep='\t')
        
        if buffer_detalles.tell() > 0:
            buffer_detalles.seek(0)
            cursor.copy_from(buffer_detalles, 'DetallePedido',
                           columns=('Id_Pedido', 'Id_Producto', 'Cantidad', 'Precio_Unitario'),
                           sep='\t')
        
        if buffer_pagos.tell() > 0:
            buffer_pagos.seek(0)
            cursor.copy_from(buffer_pagos, 'Pago',
                           columns=('Id_Pedido', 'Fecha_Pago', 'Metodo', 'Monto'),
                           sep='\t')
        
        if buffer_envios.tell() > 0:
            buffer_envios.seek(0)
            cursor.copy_from(buffer_envios, 'Envio',
                           columns=('Id_Pedido', 'Direccion', 'Ciudad', 'Fecha_Envio'),
                           sep='\t')
        
        conn.commit()
        pbar.update(PEDIDOS % COPY_BUFFER_SIZE)
    
    print(f"✓ {PEDIDOS:,} pedidos, {total_detalles:,} detalles, {total_pagos:,} pagos, {total_envios:,} envíos")


def mostrar_estadisticas(conn):
    """Estadísticas detalladas"""
    print("\n📊 Estadísticas de la base de datos:")
    cursor = conn.cursor()
    
    tablas = ['Cliente', 'Categoria', 'Producto', 'Pedido', 'DetallePedido', 'Pago', 'Envio']
    total = 0
    
    for tabla in tablas:
        cursor.execute(f"SELECT COUNT(*) FROM {tabla}")
        count = cursor.fetchone()[0]
        total += count
        print(f"   {tabla:15} {count:>15,} registros")
    
    print(f"   {'TOTAL':15} {total:>15,} registros")


def main():
    """Función principal"""
    print("\n" + "="*80)
    print("  POBLADO MASIVO - NIVEL 3 (PRODUCCIÓN)")
    print("="*80)
    
    inicio = time.time()
    proceso = psutil.Process()
    mem_inicio = proceso.memory_info().rss / 1024 / 1024
    
    conn = conectar_db()
    print(f"✓ Conectado a {DB_CONFIG['database']}")
    
    try:
        limpiar_datos(conn)
        desactivar_constraints_indices(conn)
        
        poblar_clientes_copy(conn)
        poblar_categorias(conn)
        poblar_productos_copy(conn)
        poblar_pedidos_copy(conn)
        
        reactivar_constraints_indices(conn)
        
        # VACUUM y ANALYZE completo
        print("\n🔧 Optimizando base de datos (esto puede tardar)...")
        conn.autocommit = True
        cursor = conn.cursor()
        cursor.execute("VACUUM FULL ANALYZE")
        conn.autocommit = False
        print("✓ Optimización completada")
        
        mostrar_estadisticas(conn)
        
        # Métricas finales
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
        
        print(f"\n{'='*80}")
        print(f"  MÉTRICAS DE RENDIMIENTO")
        print(f"{'='*80}")
        print(f"⏱️  Tiempo total: {duracion:.2f} segundos ({duracion/60:.2f} minutos)")
        print(f"💾 Memoria utilizada: {mem_usada:.2f} MB")
        print(f"🚀 Velocidad: {total_reg/duracion:.2f} registros/segundo")
        print(f"💿 Tamaño de BD: {tamano}")
        
        print("\n✅ POBLADO MASIVO COMPLETADO EXITOSAMENTE")
        
    except Exception as e:
        print(f"\n❌ Error: {e}")
        import traceback
        traceback.print_exc()
        conn.rollback()
        sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    main()

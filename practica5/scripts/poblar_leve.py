#!/usr/bin/env python3
"""
Práctica 5 - Poblado Leve (Desarrollo)
Sistema E-Commerce

Nivel 1: 
- 100 clientes
- 50 productos  
- 200 pedidos
- ~500 detalles de pedido
- Tiempo estimado: 5-10 segundos
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

# Inicializar Faker con locale español
fake = Faker(['es_MX', 'es_ES'])
Faker.seed(42)
random.seed(42)

# Configuración de conexión
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'postgres'),
    'port': os.getenv('DB_PORT', '5432'),
    'database': os.getenv('DB_NAME', 'ecommerce_db'),
    'user': os.getenv('DB_USER', 'ecommerce_user'),
    'password': os.getenv('DB_PASSWORD', 'ecommerce_pass')
}

# Configuración de datos
CLIENTES = 100
PRODUCTOS = 50
PEDIDOS = 200
MIN_DETALLES_POR_PEDIDO = 1
MAX_DETALLES_POR_PEDIDO = 5

# Categorías predefinidas
CATEGORIAS = [
    'Electrónica', 'Ropa', 'Hogar', 'Deportes', 'Libros',
    'Juguetes', 'Alimentos', 'Belleza', 'Automotriz', 'Jardinería'
]

# Métodos de pago
METODOS_PAGO = ['Tarjeta', 'PayPal', 'Transferencia', 'Efectivo', 'Criptomoneda']

# Estados de pedido
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


def limpiar_datos(conn):
    """Limpia todos los datos de las tablas"""
    print("\n🗑️  Limpiando datos existentes...")
    cursor = conn.cursor()
    
    try:
        # Orden importante por dependencias
        tablas = ['Pago', 'Envio', 'DetallePedido', 'Pedido', 'Producto', 'Categoria', 'Cliente']
        for tabla in tablas:
            cursor.execute(f"TRUNCATE TABLE {tabla} RESTART IDENTITY CASCADE")
        
        conn.commit()
        print("✓ Datos limpiados correctamente")
    except Exception as e:
        conn.rollback()
        print(f"❌ Error limpiando datos: {e}")
        raise


def poblar_clientes(conn):
    """Poblar tabla Cliente"""
    print(f"\n👥 Poblando {CLIENTES} clientes...")
    cursor = conn.cursor()
    
    clientes = []
    emails_usados = set()
    
    for _ in tqdm(range(CLIENTES), desc="Clientes"):
        # Generar email único
        while True:
            email = fake.email()
            if email not in emails_usados:
                emails_usados.add(email)
                break
        
        nombre = fake.name()
        telefono = fake.phone_number()[:20]
        fecha_registro = fake.date_time_between(start_date='-2y', end_date='now')
        activo = random.choice([True, True, True, False])  # 75% activos
        
        clientes.append((nombre, email, telefono, fecha_registro, activo))
    
    # Insert batch
    query = """
        INSERT INTO Cliente (Nombre, Email, Telefono, Fecha_Registro, Activo)
        VALUES (%s, %s, %s, %s, %s)
    """
    
    try:
        execute_batch(cursor, query, clientes, page_size=100)
        conn.commit()
        print(f"✓ {CLIENTES} clientes insertados")
    except Exception as e:
        conn.rollback()
        print(f"❌ Error insertando clientes: {e}")
        raise


def poblar_categorias(conn):
    """Poblar tabla Categoria"""
    print(f"\n📂 Poblando {len(CATEGORIAS)} categorías...")
    cursor = conn.cursor()
    
    categorias = []
    for cat in CATEGORIAS:
        descripcion = f"Productos de {cat.lower()}"
        activo = True
        categorias.append((cat, descripcion, activo))
    
    query = """
        INSERT INTO Categoria (Nombre, Descripcion, Activo)
        VALUES (%s, %s, %s)
    """
    
    try:
        execute_batch(cursor, query, categorias)
        conn.commit()
        print(f"✓ {len(CATEGORIAS)} categorías insertadas")
    except Exception as e:
        conn.rollback()
        print(f"❌ Error insertando categorías: {e}")
        raise


def poblar_productos(conn):
    """Poblar tabla Producto"""
    print(f"\n📦 Poblando {PRODUCTOS} productos...")
    cursor = conn.cursor()
    
    # Obtener IDs de categorías
    cursor.execute("SELECT Id_Categoria FROM Categoria")
    categoria_ids = [row[0] for row in cursor.fetchall()]
    
    productos = []
    for _ in tqdm(range(PRODUCTOS), desc="Productos"):
        id_categoria = random.choice(categoria_ids)
        nombre = fake.catch_phrase()[:200]
        descripcion = fake.text(max_nb_chars=500)
        precio = Decimal(random.uniform(10, 5000)).quantize(Decimal('0.01'))
        stock = random.randint(0, 1000)
        activo = random.choice([True, True, True, False])
        
        productos.append((id_categoria, nombre, descripcion, precio, stock, activo))
    
    query = """
        INSERT INTO Producto (Id_Categoria, Nombre, Descripcion, Precio, Stock, Activo)
        VALUES (%s, %s, %s, %s, %s, %s)
    """
    
    try:
        execute_batch(cursor, query, productos, page_size=50)
        conn.commit()
        print(f"✓ {PRODUCTOS} productos insertados")
    except Exception as e:
        conn.rollback()
        print(f"❌ Error insertando productos: {e}")
        raise


def poblar_pedidos_y_detalles(conn):
    """Poblar tablas Pedido y DetallePedido"""
    print(f"\n🛒 Poblando {PEDIDOS} pedidos con detalles...")
    cursor = conn.cursor()
    
    # Obtener IDs
    cursor.execute("SELECT Id_Cliente FROM Cliente WHERE Activo = TRUE")
    cliente_ids = [row[0] for row in cursor.fetchall()]
    
    cursor.execute("SELECT Id_Producto, Precio FROM Producto WHERE Activo = TRUE AND Stock > 0")
    productos_disponibles = cursor.fetchall()
    
    total_detalles = 0
    
    for _ in tqdm(range(PEDIDOS), desc="Pedidos"):
        try:
            # Crear pedido
            id_cliente = random.choice(cliente_ids)
            fecha_pedido = fake.date_time_between(start_date='-6m', end_date='now')
            estado = random.choice(ESTADOS_PEDIDO)
            
            cursor.execute("""
                INSERT INTO Pedido (Id_Cliente, Fecha_Pedido, Estado, Total)
                VALUES (%s, %s, %s, 0)
                RETURNING Id_Pedido
            """, (id_cliente, fecha_pedido, estado))
            
            id_pedido = cursor.fetchone()[0]
            
            # Crear detalles del pedido
            num_detalles = random.randint(MIN_DETALLES_POR_PEDIDO, MAX_DETALLES_POR_PEDIDO)
            productos_en_pedido = random.sample(productos_disponibles, min(num_detalles, len(productos_disponibles)))
            
            for id_producto, precio_actual in productos_en_pedido:
                cantidad = random.randint(1, 5)
                # Precio puede variar ±10% del actual
                variacion = random.uniform(0.9, 1.1)
                precio_unitario = Decimal(float(precio_actual) * variacion).quantize(Decimal('0.01'))
                
                # Desactivar temporalmente el trigger de stock para poblado inicial
                cursor.execute("""
                    INSERT INTO DetallePedido (Id_Pedido, Id_Producto, Cantidad, Precio_Unitario)
                    VALUES (%s, %s, %s, %s)
                """, (id_pedido, id_producto, cantidad, precio_unitario))
                
                total_detalles += 1
            
            # Crear pago si el pedido no está cancelado o pendiente
            if estado in ['Procesando', 'Enviado', 'Entregado']:
                cursor.execute("SELECT Total FROM Pedido WHERE Id_Pedido = %s", (id_pedido,))
                total_pedido = cursor.fetchone()[0]
                
                metodo = random.choice(METODOS_PAGO)
                fecha_pago = fecha_pedido + timedelta(hours=random.randint(1, 48))
                
                cursor.execute("""
                    INSERT INTO Pago (Id_Pedido, Fecha_Pago, Metodo, Monto)
                    VALUES (%s, %s, %s, %s)
                """, (id_pedido, fecha_pago, metodo, total_pedido))
            
            # Crear envío si el pedido fue enviado o entregado
            if estado in ['Enviado', 'Entregado']:
                direccion = fake.street_address()
                ciudad = fake.city()
                fecha_envio = fecha_pedido + timedelta(days=random.randint(1, 3))
                
                cursor.execute("""
                    INSERT INTO Envio (Id_Pedido, Direccion, Ciudad, Fecha_Envio)
                    VALUES (%s, %s, %s, %s)
                """, (id_pedido, direccion, ciudad, fecha_envio))
            
        except Exception as e:
            print(f"⚠️  Error en pedido: {e}")
            continue
    
    try:
        conn.commit()
        print(f"✓ {PEDIDOS} pedidos insertados con {total_detalles} detalles")
    except Exception as e:
        conn.rollback()
        print(f"❌ Error en transacción de pedidos: {e}")
        raise


def mostrar_estadisticas(conn):
    """Muestra estadísticas de la base de datos"""
    print("\n📊 Estadísticas de la base de datos:")
    cursor = conn.cursor()
    
    tablas = ['Cliente', 'Categoria', 'Producto', 'Pedido', 'DetallePedido', 'Pago', 'Envio']
    
    for tabla in tablas:
        cursor.execute(f"SELECT COUNT(*) FROM {tabla}")
        count = cursor.fetchone()[0]
        print(f"   {tabla:15} {count:>10,} registros")
    
    # Total
    cursor.execute("""
        SELECT 
            (SELECT COUNT(*) FROM Cliente) +
            (SELECT COUNT(*) FROM Categoria) +
            (SELECT COUNT(*) FROM Producto) +
            (SELECT COUNT(*) FROM Pedido) +
            (SELECT COUNT(*) FROM DetallePedido) +
            (SELECT COUNT(*) FROM Pago) +
            (SELECT COUNT(*) FROM Envio)
    """)
    total = cursor.fetchone()[0]
    print(f"   {'TOTAL':15} {total:>10,} registros")


def main():
    """Función principal"""
    print("\n" + "="*80)
    print("  POBLADO LEVE - NIVEL 1 (DESARROLLO)")
    print("="*80)
    
    # Métricas
    inicio = time.time()
    proceso = psutil.Process()
    memoria_inicio = proceso.memory_info().rss / 1024 / 1024
    
    # Conexión
    conn = conectar_db()
    print(f"✓ Conectado a {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}")
    
    try:
        # Poblado
        limpiar_datos(conn)
        poblar_clientes(conn)
        poblar_categorias(conn)
        poblar_productos(conn)
        poblar_pedidos_y_detalles(conn)
        
        # Estadísticas
        mostrar_estadisticas(conn)
        
        # Métricas finales
        fin = time.time()
        duracion = fin - inicio
        memoria_fin = proceso.memory_info().rss / 1024 / 1024
        memoria_usada = memoria_fin - memoria_inicio
        
        print(f"\n⏱️  Tiempo de ejecución: {duracion:.2f} segundos")
        print(f"💾 Memoria utilizada: {memoria_usada:.2f} MB")
        
        # Calcular registros/segundo
        cursor = conn.cursor()
        cursor.execute("""
            SELECT 
                (SELECT COUNT(*) FROM Cliente) +
                (SELECT COUNT(*) FROM Producto) +
                (SELECT COUNT(*) FROM Pedido) +
                (SELECT COUNT(*) FROM DetallePedido) +
                (SELECT COUNT(*) FROM Pago) +
                (SELECT COUNT(*) FROM Envio)
        """)
        total_registros = cursor.fetchone()[0]
        velocidad = total_registros / duracion
        print(f"🚀 Velocidad: {velocidad:.2f} registros/segundo")
        
        # Tamaño de BD
        cursor.execute("""
            SELECT pg_size_pretty(pg_database_size(%s))
        """, (DB_CONFIG['database'],))
        tamano_bd = cursor.fetchone()[0]
        print(f"💿 Tamaño de BD: {tamano_bd}")
        
        print("\n✅ Poblado completado exitosamente")
        
    except Exception as e:
        print(f"\n❌ Error durante el poblado: {e}")
        conn.rollback()
        sys.exit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
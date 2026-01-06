-- ============================================================================
-- PRÁCTICA 5 - OPERACIONES DML AVANZADAS
-- Sistema E-Commerce
-- Ejercicio 3: Manipulación de Datos
-- ============================================================================

\echo '============================================================================'
\echo '  EJERCICIO 3: OPERACIONES DML AVANZADAS'
\echo '============================================================================'

-- ============================================================================
-- 3.1 CONSULTAS SELECT AVANZADAS (Mínimo 10)
-- ============================================================================

\echo ''
\echo '--- 1. JOINS MÚLTIPLES (3+ tablas) ---'
\echo 'Top 10 clientes por monto gastado con información de envíos'

SELECT 
    c.Id_Cliente,
    c.Nombre AS Cliente,
    c.Email,
    COUNT(DISTINCT p.Id_Pedido) AS Total_Pedidos,
    SUM(p.Total) AS Total_Gastado,
    AVG(p.Total) AS Promedio_Por_Pedido,
    COUNT(DISTINCT e.Id_Envio) AS Total_Envios,
    STRING_AGG(DISTINCT e.Ciudad, ', ') AS Ciudades_Entrega
FROM Cliente c
JOIN Pedido p ON c.Id_Cliente = p.Id_Cliente
LEFT JOIN Envio e ON p.Id_Pedido = e.Id_Pedido
LEFT JOIN Pago pg ON p.Id_Pedido = pg.Id_Pedido
WHERE p.Estado != 'Cancelado'
GROUP BY c.Id_Cliente, c.Nombre, c.Email
HAVING SUM(p.Total) > 0
ORDER BY Total_Gastado DESC
LIMIT 10;

\echo ''
\echo '--- 2. SUBCONSULTA CORRELACIONADA ---'
\echo 'Productos con precio superior al promedio de su categoría'

SELECT 
    p.Id_Producto,
    p.Nombre,
    c.Nombre AS Categoria,
    p.Precio,
    (SELECT AVG(p2.Precio) 
     FROM Producto p2 
     WHERE p2.Id_Categoria = p.Id_Categoria) AS Precio_Promedio_Categoria,
    p.Precio - (SELECT AVG(p2.Precio) 
                FROM Producto p2 
                WHERE p2.Id_Categoria = p.Id_Categoria) AS Diferencia
FROM Producto p
JOIN Categoria c ON p.Id_Categoria = c.Id_Categoria
WHERE p.Precio > (
    SELECT AVG(p3.Precio)
    FROM Producto p3
    WHERE p3.Id_Categoria = p.Id_Categoria
)
ORDER BY Diferencia DESC
LIMIT 20;

\echo ''
\echo '--- 3. FUNCIONES DE AGREGACIÓN CON GROUP BY Y HAVING ---'
\echo 'Categorías con ventas superiores a $50,000'

SELECT 
    cat.Nombre AS Categoria,
    COUNT(DISTINCT prod.Id_Producto) AS Total_Productos,
    COUNT(DISTINCT dp.Id_Detalle) AS Total_Ventas,
    SUM(dp.Cantidad) AS Unidades_Vendidas,
    SUM(dp.Cantidad * dp.Precio_Unitario) AS Ingresos_Totales,
    AVG(dp.Precio_Unitario) AS Precio_Promedio,
    MIN(dp.Precio_Unitario) AS Precio_Minimo,
    MAX(dp.Precio_Unitario) AS Precio_Maximo
FROM Categoria cat
JOIN Producto prod ON cat.Id_Categoria = prod.Id_Categoria
JOIN DetallePedido dp ON prod.Id_Producto = dp.Id_Producto
JOIN Pedido p ON dp.Id_Pedido = p.Id_Pedido
WHERE p.Estado IN ('Procesando', 'Enviado', 'Entregado')
GROUP BY cat.Id_Categoria, cat.Nombre
HAVING SUM(dp.Cantidad * dp.Precio_Unitario) > 50000
ORDER BY Ingresos_Totales DESC;

\echo ''
\echo '--- 4. WINDOW FUNCTIONS (RANK, ROW_NUMBER, PARTITION BY) ---'
\echo 'Ranking de productos más vendidos por categoría'

SELECT 
    Categoria,
    Producto,
    Unidades_Vendidas,
    Ingresos,
    Ranking_En_Categoria,
    Ranking_General
FROM (
    SELECT 
        c.Nombre AS Categoria,
        p.Nombre AS Producto,
        SUM(dp.Cantidad) AS Unidades_Vendidas,
        SUM(dp.Cantidad * dp.Precio_Unitario) AS Ingresos,
        RANK() OVER (PARTITION BY c.Nombre ORDER BY SUM(dp.Cantidad) DESC) AS Ranking_En_Categoria,
        ROW_NUMBER() OVER (ORDER BY SUM(dp.Cantidad) DESC) AS Ranking_General,
        DENSE_RANK() OVER (PARTITION BY c.Nombre ORDER BY SUM(dp.Cantidad * dp.Precio_Unitario) DESC) AS Ranking_Ingresos
    FROM Categoria c
    JOIN Producto p ON c.Id_Categoria = p.Id_Categoria
    JOIN DetallePedido dp ON p.Id_Producto = dp.Id_Producto
    GROUP BY c.Nombre, p.Nombre
) ranked
WHERE Ranking_En_Categoria <= 3
ORDER BY Categoria, Ranking_En_Categoria;

\echo ''
\echo '--- 5. OPERACIONES DE CONJUNTOS (UNION) ---'
\echo 'Clientes activos e inactivos con estadísticas'

SELECT 'ACTIVOS' AS Estado, COUNT(*) AS Total, AVG(pedidos) AS Promedio_Pedidos
FROM (
    SELECT c.Id_Cliente, COUNT(p.Id_Pedido) AS pedidos
    FROM Cliente c
    LEFT JOIN Pedido p ON c.Id_Cliente = p.Id_Cliente
    WHERE c.Activo = TRUE
    GROUP BY c.Id_Cliente
) activos

UNION ALL

SELECT 'INACTIVOS', COUNT(*), AVG(pedidos)
FROM (
    SELECT c.Id_Cliente, COUNT(p.Id_Pedido) AS pedidos
    FROM Cliente c
    LEFT JOIN Pedido p ON c.Id_Cliente = p.Id_Cliente
    WHERE c.Activo = FALSE
    GROUP BY c.Id_Cliente
) inactivos

UNION ALL

SELECT 'TOTAL', COUNT(*), AVG(pedidos)
FROM (
    SELECT c.Id_Cliente, COUNT(p.Id_Pedido) AS pedidos
    FROM Cliente c
    LEFT JOIN Pedido p ON c.Id_Cliente = p.Id_Cliente
    GROUP BY c.Id_Cliente
) todos;

\echo ''
\echo '--- 6. COMMON TABLE EXPRESSIONS (CTEs) ---'
\echo 'Análisis de rentabilidad por producto con CTEs'

WITH VentasPorProducto AS (
    SELECT 
        p.Id_Producto,
        p.Nombre,
        p.Precio AS Precio_Actual,
        COUNT(dp.Id_Detalle) AS Numero_Ventas,
        SUM(dp.Cantidad) AS Unidades_Vendidas,
        AVG(dp.Precio_Unitario) AS Precio_Promedio_Venta,
        SUM(dp.Cantidad * dp.Precio_Unitario) AS Ingresos_Totales
    FROM Producto p
    LEFT JOIN DetallePedido dp ON p.Id_Producto = dp.Id_Producto
    GROUP BY p.Id_Producto, p.Nombre, p.Precio
),
PromedioGeneral AS (
    SELECT 
        AVG(Ingresos_Totales) AS Ingreso_Promedio,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Ingresos_Totales) AS Ingreso_Mediana
    FROM VentasPorProducto
    WHERE Numero_Ventas > 0
)
SELECT 
    v.Nombre AS Producto,
    v.Numero_Ventas,
    v.Unidades_Vendidas,
    v.Precio_Actual,
    v.Precio_Promedio_Venta,
    v.Ingresos_Totales,
    CASE 
        WHEN v.Ingresos_Totales > pg.Ingreso_Promedio * 1.5 THEN 'Excelente'
        WHEN v.Ingresos_Totales > pg.Ingreso_Promedio THEN 'Bueno'
        WHEN v.Ingresos_Totales > pg.Ingreso_Mediana THEN 'Regular'
        ELSE 'Bajo'
    END AS Clasificacion_Rentabilidad
FROM VentasPorProducto v
CROSS JOIN PromedioGeneral pg
WHERE v.Numero_Ventas > 0
ORDER BY v.Ingresos_Totales DESC
LIMIT 20;

\echo ''
\echo '--- 7. CONSULTAS CON CASE ---'
\echo 'Clasificación de clientes por nivel de compra'

SELECT 
    c.Nombre,
    c.Email,
    COUNT(p.Id_Pedido) AS Total_Pedidos,
    SUM(p.Total) AS Total_Gastado,
    CASE 
        WHEN SUM(p.Total) >= 100000 THEN 'VIP Platinum'
        WHEN SUM(p.Total) >= 50000 THEN 'VIP Gold'
        WHEN SUM(p.Total) >= 10000 THEN 'VIP Silver'
        WHEN SUM(p.Total) >= 1000 THEN 'Regular'
        ELSE 'Nuevo'
    END AS Nivel_Cliente,
    CASE 
        WHEN SUM(p.Total) >= 100000 THEN 0.20
        WHEN SUM(p.Total) >= 50000 THEN 0.15
        WHEN SUM(p.Total) >= 10000 THEN 0.10
        WHEN SUM(p.Total) >= 1000 THEN 0.05
        ELSE 0.00
    END AS Descuento_Aplicable
FROM Cliente c
LEFT JOIN Pedido p ON c.Id_Cliente = p.Id_Cliente AND p.Estado != 'Cancelado'
GROUP BY c.Id_Cliente, c.Nombre, c.Email
HAVING COUNT(p.Id_Pedido) > 0
ORDER BY Total_Gastado DESC
LIMIT 30;

\echo ''
\echo '--- 8. ANÁLISIS TEMPORAL CON FECHAS ---'
\echo 'Tendencia de ventas por mes en el último año'

SELECT 
    TO_CHAR(p.Fecha_Pedido, 'YYYY-MM') AS Mes,
    COUNT(DISTINCT p.Id_Pedido) AS Total_Pedidos,
    COUNT(DISTINCT p.Id_Cliente) AS Clientes_Unicos,
    SUM(p.Total) AS Ingresos_Totales,
    AVG(p.Total) AS Ticket_Promedio,
    SUM(dp.Cantidad) AS Unidades_Vendidas,
    COUNT(DISTINCT CASE WHEN p.Estado = 'Entregado' THEN p.Id_Pedido END) AS Pedidos_Entregados,
    ROUND(
        COUNT(DISTINCT CASE WHEN p.Estado = 'Entregado' THEN p.Id_Pedido END)::NUMERIC / 
        COUNT(DISTINCT p.Id_Pedido)::NUMERIC * 100, 
        2
    ) AS Tasa_Entrega_Pct
FROM Pedido p
JOIN DetallePedido dp ON p.Id_Pedido = dp.Id_Pedido
WHERE p.Fecha_Pedido >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY TO_CHAR(p.Fecha_Pedido, 'YYYY-MM')
ORDER BY Mes DESC;

\echo ''
\echo '--- 9. BÚSQUEDA DE TEXTO CON ILIKE ---'
\echo 'Búsqueda de productos con palabras clave'

SELECT 
    p.Id_Producto,
    p.Nombre,
    c.Nombre AS Categoria,
    p.Precio,
    p.Stock,
    CASE 
        WHEN p.Nombre ILIKE '%tech%' OR p.Nombre ILIKE '%digital%' THEN 'Tecnología'
        WHEN p.Nombre ILIKE '%smart%' OR p.Nombre ILIKE '%inteligente%' THEN 'Smart'
        ELSE 'Otros'
    END AS Clasificacion_Busqueda
FROM Producto p
JOIN Categoria c ON p.Id_Categoria = c.Id_Categoria
WHERE 
    p.Nombre ILIKE '%tech%' OR 
    p.Nombre ILIKE '%smart%' OR 
    p.Nombre ILIKE '%digital%' OR
    p.Descripcion ILIKE '%innovador%'
ORDER BY p.Precio DESC
LIMIT 20;

\echo ''
\echo '--- 10. ANÁLISIS COMPLEJO CON MÚLTIPLES JOINS Y AGREGACIONES ---'
\echo 'Dashboard ejecutivo: Métricas clave del negocio'

SELECT 
    'Resumen General' AS Metrica_Categoria,
    JSON_BUILD_OBJECT(
        'total_clientes', (SELECT COUNT(*) FROM Cliente WHERE Activo = TRUE),
        'total_productos', (SELECT COUNT(*) FROM Producto WHERE Activo = TRUE),
        'total_pedidos', (SELECT COUNT(*) FROM Pedido),
        'total_ingresos', (SELECT ROUND(SUM(Total)::NUMERIC, 2) FROM Pedido WHERE Estado != 'Cancelado'),
        'ticket_promedio', (SELECT ROUND(AVG(Total)::NUMERIC, 2) FROM Pedido WHERE Estado != 'Cancelado'),
        'productos_vendidos', (SELECT SUM(Cantidad) FROM DetallePedido),
        'tasa_conversion', (
            SELECT ROUND(
                COUNT(DISTINCT CASE WHEN Estado != 'Cancelado' THEN Id_Pedido END)::NUMERIC / 
                COUNT(DISTINCT Id_Cliente)::NUMERIC * 100, 
                2
            ) FROM Pedido
        ),
        'metodo_pago_popular', (
            SELECT Metodo FROM Pago GROUP BY Metodo ORDER BY COUNT(*) DESC LIMIT 1
        ),
        'estado_pedidos', (
            SELECT JSON_OBJECT_AGG(Estado, Total) FROM (
                SELECT Estado, COUNT(*) AS Total FROM Pedido GROUP BY Estado
            ) estados
        )
    ) AS Metricas
UNION ALL
SELECT 
    'Top 5 Productos',
    JSON_AGG(
        JSON_BUILD_OBJECT(
            'producto', Nombre,
            'ventas', Ventas,
            'ingresos', Ingresos
        )
    )
FROM (
    SELECT 
        p.Nombre,
        COUNT(dp.Id_Detalle) AS Ventas,
        ROUND(SUM(dp.Cantidad * dp.Precio_Unitario)::NUMERIC, 2) AS Ingresos
    FROM Producto p
    JOIN DetallePedido dp ON p.Id_Producto = dp.Id_Producto
    GROUP BY p.Nombre
    ORDER BY Ventas DESC
    LIMIT 5
) top_productos;

-- ============================================================================
-- 3.2 OPERACIONES INSERT
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '3.2 OPERACIONES INSERT'
\echo '============================================================================'

\echo ''
\echo '--- INSERT con subconsulta ---'
\echo 'Crear pedido automático con productos más vendidos'

BEGIN;

-- Insertar pedido
INSERT INTO Pedido (Id_Cliente, Fecha_Pedido, Estado, Total)
SELECT 
    (SELECT Id_Cliente FROM Cliente WHERE Activo = TRUE ORDER BY RANDOM() LIMIT 1),
    CURRENT_TIMESTAMP,
    'Pendiente',
    0
RETURNING Id_Pedido;

-- Guardar el ID en una variable temporal (solo para ejemplo)
\echo 'Pedido creado exitosamente'

ROLLBACK;  -- Deshacer para no modificar datos

\echo ''
\echo '--- INSERT múltiple ---'
\echo 'Insertar varios productos a la vez'

BEGIN;

INSERT INTO Producto (Id_Categoria, Nombre, Descripcion, Precio, Stock, Activo)
VALUES 
    ((SELECT Id_Categoria FROM Categoria WHERE Nombre = 'Electrónica' LIMIT 1),
     'Smartphone XYZ Pro', 'Teléfono de última generación', 15999.99, 50, TRUE),
    ((SELECT Id_Categoria FROM Categoria WHERE Nombre = 'Electrónica' LIMIT 1),
     'Laptop UltraBook 15"', 'Laptop profesional', 29999.99, 20, TRUE),
    ((SELECT Id_Categoria FROM Categoria WHERE Nombre = 'Hogar' LIMIT 1),
     'Cafetera Automática', 'Cafetera programable', 2499.99, 100, TRUE);

\echo 'Productos insertados exitosamente'

ROLLBACK;

\echo ''
\echo '--- INSERT con valores calculados ---'
\echo 'Insertar pedido con total pre-calculado'

BEGIN;

WITH nuevo_cliente AS (
    SELECT Id_Cliente FROM Cliente WHERE Activo = TRUE ORDER BY RANDOM() LIMIT 1
),
productos_seleccionados AS (
    SELECT Id_Producto, Precio 
    FROM Producto 
    WHERE Stock > 0 AND Activo = TRUE 
    ORDER BY RANDOM() 
    LIMIT 3
),
total_calculado AS (
    SELECT SUM(Precio * 2) AS total FROM productos_seleccionados
)
INSERT INTO Pedido (Id_Cliente, Fecha_Pedido, Estado, Total)
SELECT 
    nc.Id_Cliente,
    CURRENT_TIMESTAMP,
    'Pendiente',
    COALESCE(tc.total, 0)
FROM nuevo_cliente nc
CROSS JOIN total_calculado tc
RETURNING Id_Pedido, Total;

ROLLBACK;

\echo ''
\echo '--- UPSERT (INSERT ... ON CONFLICT) ---'
\echo 'Insertar o actualizar categoría'

BEGIN;

INSERT INTO Categoria (Nombre, Descripcion, Activo)
VALUES ('Tecnología Avanzada', 'Productos de alta tecnología', TRUE)
ON CONFLICT (Nombre) 
DO UPDATE SET 
    Descripcion = EXCLUDED.Descripcion,
    Activo = EXCLUDED.Activo;

\echo 'Categoría insertada o actualizada'

ROLLBACK;

-- ============================================================================
-- 3.3 OPERACIONES UPDATE
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '3.3 OPERACIONES UPDATE'
\echo '============================================================================'

\echo ''
\echo '--- UPDATE con JOIN ---'
\echo 'Aplicar descuento a productos de categorías específicas'

BEGIN;

UPDATE Producto p
SET Precio = p.Precio * 0.9
FROM Categoria c
WHERE p.Id_Categoria = c.Id_Categoria
  AND c.Nombre IN ('Electrónica', 'Gaming')
  AND p.Stock > 10;

\echo 'Descuento aplicado a productos'

ROLLBACK;

\echo ''
\echo '--- UPDATE condicional con CASE ---'
\echo 'Actualizar estado de pedidos según antigüedad'

BEGIN;

UPDATE Pedido
SET Estado = CASE 
    WHEN Estado = 'Pendiente' AND Fecha_Pedido < CURRENT_DATE - INTERVAL '7 days' THEN 'Cancelado'
    WHEN Estado = 'Procesando' AND Fecha_Pedido < CURRENT_DATE - INTERVAL '3 days' THEN 'Enviado'
    WHEN Estado = 'Enviado' AND Fecha_Pedido < CURRENT_DATE - INTERVAL '5 days' THEN 'Entregado'
    ELSE Estado
END
WHERE Estado IN ('Pendiente', 'Procesando', 'Enviado');

\echo 'Estados de pedidos actualizados'

ROLLBACK;

\echo ''
\echo '--- UPDATE masivo ---'
\echo 'Reactivar todos los clientes inactivos con más de 5 pedidos'

BEGIN;

UPDATE Cliente c
SET Activo = TRUE
WHERE Activo = FALSE
  AND (
    SELECT COUNT(*) 
    FROM Pedido p 
    WHERE p.Id_Cliente = c.Id_Cliente
  ) > 5;

\echo 'Clientes reactivados'

ROLLBACK;

\echo ''
\echo '--- UPDATE con subconsulta ---'
\echo 'Actualizar precio de productos según promedio de categoría'

BEGIN;

UPDATE Producto p
SET Precio = (
    SELECT AVG(p2.Precio) * 1.1
    FROM Producto p2
    WHERE p2.Id_Categoria = p.Id_Categoria
      AND p2.Id_Producto != p.Id_Producto
)
WHERE p.Stock = 0
  AND EXISTS (
    SELECT 1 
    FROM Producto p3 
    WHERE p3.Id_Categoria = p.Id_Categoria 
      AND p3.Stock > 0
  );

\echo 'Precios actualizados según promedio'

ROLLBACK;

-- ============================================================================
-- 3.4 OPERACIONES DELETE
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '3.4 OPERACIONES DELETE'
\echo '============================================================================'

\echo ''
\echo '--- DELETE con subconsulta ---'
\echo 'Eliminar pedidos cancelados antiguos sin detalles'

BEGIN;

DELETE FROM Pedido
WHERE Estado = 'Cancelado'
  AND Fecha_Pedido < CURRENT_DATE - INTERVAL '1 year'
  AND NOT EXISTS (
    SELECT 1 FROM DetallePedido dp WHERE dp.Id_Pedido = Pedido.Id_Pedido
  );

\echo 'Pedidos antiguos eliminados'

ROLLBACK;

\echo ''
\echo '--- DELETE con JOIN (usando subconsulta) ---'
\echo 'Eliminar productos sin ventas de categorías inactivas'

BEGIN;

DELETE FROM Producto
WHERE Id_Categoria IN (
    SELECT Id_Categoria FROM Categoria WHERE Activo = FALSE
)
AND NOT EXISTS (
    SELECT 1 FROM DetallePedido dp WHERE dp.Id_Producto = Producto.Id_Producto
);

\echo 'Productos sin ventas eliminados'

ROLLBACK;

\echo ''
\echo '--- Soft DELETE (marcado lógico) ---'
\echo 'Desactivar clientes en lugar de eliminarlos'

BEGIN;

UPDATE Cliente
SET Activo = FALSE
WHERE Id_Cliente IN (
    SELECT c.Id_Cliente
    FROM Cliente c
    LEFT JOIN Pedido p ON c.Id_Cliente = p.Id_Cliente
    WHERE c.Fecha_Registro < CURRENT_DATE - INTERVAL '2 years'
      AND p.Id_Pedido IS NULL
);

\echo 'Clientes desactivados (soft delete)'

ROLLBACK;

\echo ''
\echo '--- Archivado antes de eliminación ---'
\echo 'Crear tabla de archivo y mover datos antes de eliminar'

BEGIN;

-- Crear tabla de archivo si no existe
CREATE TABLE IF NOT EXISTS Pedido_Archivo (
    LIKE Pedido INCLUDING ALL
);

-- Archivar pedidos antiguos
INSERT INTO Pedido_Archivo
SELECT * FROM Pedido
WHERE Estado = 'Entregado'
  AND Fecha_Pedido < CURRENT_DATE - INTERVAL '2 years';

-- Ahora se podrían eliminar (pero no lo haremos)
\echo 'Datos archivados en Pedido_Archivo'

ROLLBACK;

-- ============================================================================
-- 3.5 TRANSACCIONES
-- ============================================================================

\echo ''
\echo '============================================================================'
\echo '3.5 TRANSACCIONES'
\echo '============================================================================'

\echo ''
\echo '--- Transacción con BEGIN/COMMIT/ROLLBACK ---'
\echo 'Crear pedido completo con validaciones'

BEGIN;

DO $$
DECLARE
    v_id_cliente INTEGER;
    v_id_pedido INTEGER;
    v_id_producto INTEGER;
    v_precio DECIMAL(10,2);
BEGIN
    -- Seleccionar cliente
    SELECT Id_Cliente INTO v_id_cliente 
    FROM Cliente 
    WHERE Activo = TRUE 
    ORDER BY RANDOM() 
    LIMIT 1;
    
    IF v_id_cliente IS NULL THEN
        RAISE EXCEPTION 'No hay clientes activos disponibles';
    END IF;
    
    -- Crear pedido
    INSERT INTO Pedido (Id_Cliente, Fecha_Pedido, Estado, Total)
    VALUES (v_id_cliente, CURRENT_TIMESTAMP, 'Pendiente', 0)
    RETURNING Id_Pedido INTO v_id_pedido;
    
    RAISE NOTICE 'Pedido % creado para cliente %', v_id_pedido, v_id_cliente;
    
    -- Agregar productos
    FOR v_id_producto, v_precio IN 
        SELECT Id_Producto, Precio 
        FROM Producto 
        WHERE Stock > 0 AND Activo = TRUE 
        ORDER BY RANDOM() 
        LIMIT 3
    LOOP
        INSERT INTO DetallePedido (Id_Pedido, Id_Producto, Cantidad, Precio_Unitario)
        VALUES (v_id_pedido, v_id_producto, 2, v_precio);
        
        RAISE NOTICE 'Producto % agregado al pedido', v_id_producto;
    END LOOP;
    
    RAISE NOTICE 'Transacción completada exitosamente';
END $$;

ROLLBACK;  -- Deshacer para demostración

\echo ''
\echo '--- Transacción con SAVEPOINTs ---'
\echo 'Uso de puntos de guardado parciales'

BEGIN;

-- Crear un pedido
INSERT INTO Pedido (Id_Cliente, Fecha_Pedido, Estado, Total)
SELECT Id_Cliente, CURRENT_TIMESTAMP, 'Pendiente', 0
FROM Cliente WHERE Activo = TRUE LIMIT 1;

SAVEPOINT pedido_creado;

-- Intentar agregar productos
INSERT INTO DetallePedido (Id_Pedido, Id_Producto, Cantidad, Precio_Unitario)
SELECT 
    (SELECT MAX(Id_Pedido) FROM Pedido),
    Id_Producto,
    1,
    Precio
FROM Producto
WHERE Stock > 0
LIMIT 2;

SAVEPOINT productos_agregados;

\echo 'Savepoints creados: pedido_creado, productos_agregados'

-- Si algo falla, podemos volver a un savepoint
-- ROLLBACK TO SAVEPOINT pedido_creado;

ROLLBACK;

\echo ''
\echo '--- Control de errores y rollback automático ---'
\echo 'Manejo de excepciones en transacciones'

DO $$
BEGIN
    BEGIN
        -- Intentar operación que puede fallar
        INSERT INTO Pedido (Id_Cliente, Fecha_Pedido, Estado, Total)
        VALUES (-999, CURRENT_TIMESTAMP, 'Pendiente', 0);  -- Cliente inexistente
        
        RAISE NOTICE 'Pedido creado exitosamente';
    EXCEPTION
        WHEN foreign_key_violation THEN
            RAISE NOTICE 'Error: Cliente no existe. Transacción revertida.';
        WHEN OTHERS THEN
            RAISE NOTICE 'Error inesperado: %. Transacción revertida.', SQLERRM;
    END;
END $$;

\echo ''
\echo '--- Bloqueo optimista con FOR UPDATE ---'
\echo 'Reservar stock de producto con bloqueo'

BEGIN;

DO $$
DECLARE
    v_id_producto INTEGER;
    v_stock_actual INTEGER;
    v_cantidad_reservar INTEGER := 5;
BEGIN
    -- Seleccionar producto con bloqueo
    SELECT Id_Producto, Stock INTO v_id_producto, v_stock_actual
    FROM Producto
    WHERE Stock > 10
    ORDER BY RANDOM()
    LIMIT 1
    FOR UPDATE;  -- Bloqueo para evitar condiciones de carrera
    
    IF v_stock_actual >= v_cantidad_reservar THEN
        UPDATE Producto
        SET Stock = Stock - v_cantidad_reservar
        WHERE Id_Producto = v_id_producto;
        
        RAISE NOTICE 'Stock actualizado: Producto %, Reservado: %, Stock restante: %', 
                     v_id_producto, v_cantidad_reservar, v_stock_actual - v_cantidad_reservar;
    ELSE
        RAISE EXCEPTION 'Stock insuficiente';
    END IF;
END $$;

ROLLBACK;

\echo ''
\echo '============================================================================'
\echo '  FIN DE OPERACIONES DML AVANZADAS'
\echo '============================================================================'

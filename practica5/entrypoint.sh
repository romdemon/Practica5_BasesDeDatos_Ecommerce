#!/bin/sh
# ============================================================================
# Entrypoint Script - Gestión de Poblado de Base de Datos
# Práctica 5 - Sistema E-Commerce
# ============================================================================

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Función para logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Banner
echo "============================================================================"
echo "  _____ _____  ___  __  __ __  __ _____ ____   ____ _____               "
echo " | ____| ____|/ _ \\|  \\/  |  \\/  | ____|  _ \\ / ___| ____|  "
echo " |  _| |  _| | | | | |\\/| | |\\/| |  _| | |_) | |   |  _|               "
echo " | |___| |___| |_| | |  | | |  | | |___|  _ <| |___| |___              "
echo " |_____|_____|\\___|_|  |_|_|  |_|_____|_| \\_\\\\____|_____|       "
echo "                                                                            "
echo "             Práctica 5 - Poblado Automatizado de Base de Datos            "
echo "============================================================================"
echo ""

# Variables de entorno
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-ecommerce_db}"
DB_USER="${DB_USER:-ecommerce_user}"
DB_PASSWORD="${DB_PASSWORD:-ecommerce_pass}"
NIVEL_POBLADO="${NIVEL_POBLADO:-leve}"

info "Configuración:"
info "  - Host: $DB_HOST:$DB_PORT"
info "  - Database: $DB_NAME"
info "  - Usuario: $DB_USER"
info "  - Nivel de poblado: $NIVEL_POBLADO"
echo ""

# Esperar a que PostgreSQL esté listo
log "Esperando a que PostgreSQL esté disponible..."
MAX_RETRIES=30
RETRY_COUNT=0

while ! PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>/dev/null; do
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        error "No se pudo conectar a PostgreSQL después de $MAX_RETRIES intentos"
        exit 1
    fi
    warning "PostgreSQL no disponible aún. Reintentando en 2 segundos... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

log "✓ PostgreSQL está disponible"
echo ""

# Verificar que el esquema esté creado
log "Verificando esquema de base de datos..."
TABLE_COUNT=$(PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE';" 2>/dev/null | tr -d ' ')

if [ "$TABLE_COUNT" -lt 5 ]; then
    warning "Esquema incompleto o no inicializado (encontradas $TABLE_COUNT tablas)"
    log "Aplicando esquema DDL..."
    
    if [ -f "/sql/ddl/schema.sql" ]; then
        PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f /sql/ddl/schema.sql > /dev/null 2>&1
        log "✓ Esquema DDL aplicado correctamente"
    else
        error "No se encontró el archivo schema.sql"
        exit 1
    fi
else
    log "✓ Esquema de base de datos verificado ($TABLE_COUNT tablas)"
fi
echo ""

# Ejecutar script de poblado según nivel
log "Iniciando poblado de base de datos (Nivel: $NIVEL_POBLADO)..."
echo ""

case "$NIVEL_POBLADO" in
    leve|light|dev|desarrollo)
        info "Ejecutando poblado LEVE (Desarrollo)"
        info "  - Clientes: ~100"
        info "  - Productos: ~50"
        info "  - Pedidos: ~200"
        info "  - Tiempo estimado: 5-10 segundos"
        echo ""
        python scripts/poblar_leve.py
        ;;
    
    moderado|medium|pre-produccion|preprod)
        info "Ejecutando poblado MODERADO (Pre-producción)"
        info "  - Clientes: ~10,000"
        info "  - Productos: ~5,000"
        info "  - Pedidos: ~15,000"
        info "  - Tiempo estimado: 2-5 minutos"
        echo ""
        python scripts/poblar_moderado.py
        ;;
    
    masivo|heavy|produccion|prod)
        info "Ejecutando poblado MASIVO (Producción)"
        info "  - Clientes: ~500,000"
        info "  - Productos: ~100,000"
        info "  - Pedidos: ~1,000,000"
        info "  - Tiempo estimado: 15-30 minutos"
        echo ""
        python scripts/poblar_masivo.py
        ;;
    
    *)
        error "Nivel de poblado no reconocido: $NIVEL_POBLADO"
        error "Niveles válidos: leve, moderado, masivo"
        exit 1
        ;;
esac

# Verificar resultado
if [ $? -eq 0 ]; then
    echo ""
    log "============================================================================"
    log "               ✓ POBLADO COMPLETADO EXITOSAMENTE"
    log "============================================================================"
    echo ""
    
    # Mostrar estadísticas
    log "Estadísticas de la base de datos:"
    PGPASSWORD=$DB_PASSWORD psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "
        SELECT 
            'Clientes' as tabla, COUNT(*) as registros FROM Cliente
        UNION ALL
        SELECT 'Categorías', COUNT(*) FROM Categoria
        UNION ALL
        SELECT 'Productos', COUNT(*) FROM Producto
        UNION ALL
        SELECT 'Pedidos', COUNT(*) FROM Pedido
        UNION ALL
        SELECT 'Detalles', COUNT(*) FROM DetallePedido
        UNION ALL
        SELECT 'Pagos', COUNT(*) FROM Pago
        UNION ALL
        SELECT 'Envíos', COUNT(*) FROM Envio;
    "
    
    echo ""
    info "Para acceder a pgAdmin4:"
    info "  URL: http://localhost:5050"
    info "  Email: admin@ecommerce.com"
    info "  Password: admin123"
    echo ""
    info "Conexión PostgreSQL en pgAdmin:"
    info "  Host: postgres"
    info "  Port: 5432"
    info "  Database: $DB_NAME"
    info "  Username: $DB_USER"
    info "  Password: $DB_PASSWORD"
    echo ""
    log "El contenedor permanecerá activo. Presiona Ctrl+C para detener."
    echo ""
    
    # Mantener el contenedor activo
    tail -f /dev/null
else
    error "Error durante el poblado de la base de datos"
    exit 1
fi
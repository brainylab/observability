#!/bin/bash

# ============================================================================
# Script de Renovação Manual de Certificados SSL
# Suporte para múltiplos domínios (UI + Ingest)
# ============================================================================

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir mensagens coloridas
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERRO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[PASSO]${NC} $1"
}

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then
    print_error "Este script precisa ser executado como root (use sudo)"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="$SCRIPT_DIR/nginx/ssl"

echo ""
echo "==========================================="
echo "  Renovação Manual de Certificados SSL"
echo "==========================================="
echo ""

# ============================================================================
# ETAPA 1: Verificar certificados existentes
# ============================================================================

print_step "ETAPA 1/5: Verificando certificados existentes..."

if [ ! -d "$SSL_DIR" ]; then
    print_error "Diretório de certificados não encontrado: $SSL_DIR"
    exit 1
fi

if [ -f "$SSL_DIR/server.crt" ]; then
    print_info "Certificado UI encontrado:"
    echo "  Arquivo: $SSL_DIR/server.crt"
    echo "  Validade:"
    openssl x509 -in "$SSL_DIR/server.crt" -noout -dates | sed 's/^/    /'
else
    print_warning "Certificado UI não encontrado em $SSL_DIR/server.crt"
fi

echo ""

if [ -f "$SSL_DIR/ingest.crt" ]; then
    print_info "Certificado Ingest encontrado:"
    echo "  Arquivo: $SSL_DIR/ingest.crt"
    echo "  Validade:"
    openssl x509 -in "$SSL_DIR/ingest.crt" -noout -dates | sed 's/^/    /'
else
    print_warning "Certificado Ingest não encontrado em $SSL_DIR/ingest.crt"
fi

echo ""
read -p "Deseja continuar com a renovação? [S/n]: " CONFIRM
if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    print_warning "Operação cancelada pelo usuário"
    exit 0
fi

# ============================================================================
# ETAPA 2: Parar Nginx
# ============================================================================

print_step "ETAPA 2/5: Parando Nginx..."

cd "$SCRIPT_DIR"

if docker-compose ps nginx 2>/dev/null | grep -q "Up"; then
    docker-compose stop nginx > /dev/null 2>&1
    print_info "Nginx parado com sucesso"
    sleep 2
else
    print_warning "Nginx não estava rodando"
fi

# ============================================================================
# ETAPA 3: Renovar certificados
# ============================================================================

print_step "ETAPA 3/5: Renovando certificados Let's Encrypt..."

certbot renew --quiet || {
    print_error "Falha ao renovar certificados!"
    print_info "Tentando renovação forçada..."
    certbot renew --force-renewal
}

print_info "Certificados renovados com sucesso!"

# ============================================================================
# ETAPA 4: Copiar certificados
# ============================================================================

print_step "ETAPA 4/5: Copiando certificados renovados..."

# Listar todos os certificados Let's Encrypt disponíveis
CERT_DIRS=$(ls -d /etc/letsencrypt/live/*/ 2>/dev/null)

if [ -z "$CERT_DIRS" ]; then
    print_error "Nenhum certificado encontrado em /etc/letsencrypt/live/"
    exit 1
fi

print_info "Certificados disponíveis:"
echo "$CERT_DIRS" | nl

# Procurar e copiar certificados
for cert_dir in $CERT_DIRS; do
    domain=$(basename "$cert_dir")

    # Pular README
    if [ "$domain" = "README" ]; then
        continue
    fi

    print_info "Processando certificado: $domain"

    # Verificar se é um domínio de ingest (contém "ingest" no nome)
    if [[ "$domain" == *"ingest"* ]]; then
        print_info "  → Identificado como domínio de INGEST"
        cp "${cert_dir}fullchain.pem" "$SSL_DIR/ingest.crt"
        cp "${cert_dir}privkey.pem" "$SSL_DIR/ingest.key"
        print_info "  ✓ Copiado para ingest.crt/key"
    else
        print_info "  → Identificado como domínio de UI"
        cp "${cert_dir}fullchain.pem" "$SSL_DIR/server.crt"
        cp "${cert_dir}privkey.pem" "$SSL_DIR/server.key"
        print_info "  ✓ Copiado para server.crt/key"
    fi
done

# Ajustar permissões
if [ -f "$SSL_DIR/server.crt" ]; then
    chmod 644 "$SSL_DIR/server.crt"
    chmod 600 "$SSL_DIR/server.key"
fi

if [ -f "$SSL_DIR/ingest.crt" ]; then
    chmod 644 "$SSL_DIR/ingest.crt"
    chmod 600 "$SSL_DIR/ingest.key"
fi

# Alterar dono se foi executado com sudo
if [ -n "$SUDO_USER" ]; then
    chown -R $SUDO_USER:$SUDO_USER "$SSL_DIR"
fi

print_info "Certificados copiados e permissões ajustadas"

# ============================================================================
# ETAPA 5: Reiniciar Nginx
# ============================================================================

print_step "ETAPA 5/5: Reiniciando Nginx e Uptrace..."

cd "$SCRIPT_DIR"
docker-compose up -d nginx uptrace > /dev/null 2>&1

sleep 3

# Verificar se nginx está rodando
if docker-compose ps nginx | grep -q "Up"; then
    print_info "Nginx reiniciado com sucesso!"
else
    print_error "Falha ao reiniciar Nginx!"
    docker-compose logs nginx
    exit 1
fi

# ============================================================================
# FINALIZAÇÃO
# ============================================================================

echo ""
echo "==========================================="
print_info "✅ Renovação concluída com sucesso!"
echo "==========================================="
echo ""

print_info "📋 Certificados renovados:"
echo ""

if [ -f "$SSL_DIR/server.crt" ]; then
    echo "  UI Certificate (server.crt):"
    openssl x509 -in "$SSL_DIR/server.crt" -noout -subject -dates | sed 's/^/    /'
    echo ""
fi

if [ -f "$SSL_DIR/ingest.crt" ]; then
    echo "  Ingest Certificate (ingest.crt):"
    openssl x509 -in "$SSL_DIR/ingest.crt" -noout -subject -dates | sed 's/^/    /'
    echo ""
fi

print_info "📝 Próxima renovação automática: $(date -d "+90 days" "+%Y-%m-%d" 2>/dev/null || date -v+90d "+%Y-%m-%d" 2>/dev/null || echo "em 90 dias")"
echo ""

print_info "✨ Renovação manual concluída!"
echo ""

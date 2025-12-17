#!/bin/bash

# ============================================================================
# Script de configuração automática de SSL com Let's Encrypt
# Suporte para múltiplos domínios (UI + Ingest)
# ============================================================================

set -e  # Para o script em caso de erro

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

echo ""
echo "============================================================================"
echo "  Configuração SSL com Let's Encrypt - Múltiplos Domínios"
echo "============================================================================"
echo ""

# ============================================================================
# CONFIGURAÇÃO - Solicitar informações do usuário
# ============================================================================

print_step "Configuração dos domínios"
echo ""
read -p "Digite o domínio da UI (ex: uptrace.exemplo.com): " DOMAIN_UI
read -p "Digite o domínio de ingestão (ex: ingest.exemplo.com): " DOMAIN_INGEST
read -p "Digite seu email: " EMAIL

# Validar entradas
if [ -z "$DOMAIN_UI" ] || [ -z "$DOMAIN_INGEST" ] || [ -z "$EMAIL" ]; then
    print_error "Todos os campos são obrigatórios!"
    exit 1
fi

echo ""
print_info "Configuração:"
echo "  UI Domain:     $DOMAIN_UI"
echo "  Ingest Domain: $DOMAIN_INGEST"
echo "  Email:         $EMAIL"
echo ""

# Perguntar se é teste ou produção
read -p "Usar certificado de TESTE? (recomendado na primeira vez) [s/N]: " USE_STAGING
if [[ "$USE_STAGING" =~ ^[Ss]$ ]]; then
    STAGING_ARG="--staging"
    print_warning "Modo TESTE ativado. Os certificados NÃO serão válidos."
else
    STAGING_ARG=""
    print_info "Modo PRODUÇÃO ativado. Certificados válidos serão gerados."
fi

# Diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="$SCRIPT_DIR/nginx/ssl"

print_info "Diretório do projeto: $SCRIPT_DIR"
echo ""

# Confirmar antes de continuar
read -p "Continuar com a configuração? [S/n]: " CONFIRM
if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
    print_warning "Operação cancelada pelo usuário"
    exit 0
fi

# ============================================================================
# ETAPA 1: Verificar pré-requisitos
# ============================================================================

print_step "ETAPA 1/8: Verificando pré-requisitos..."

# Verificar se certbot está instalado
if ! command -v certbot &> /dev/null; then
    print_warning "Certbot não encontrado. Instalando..."

    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        apt update -qq
        apt install -y certbot > /dev/null 2>&1
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL
        yum install -y certbot > /dev/null 2>&1
    else
        print_error "Sistema operacional não suportado"
        exit 1
    fi

    print_info "Certbot instalado com sucesso!"
else
    print_info "Certbot já está instalado: $(certbot --version | head -1)"
fi

# Verificar se docker-compose está instalado
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose não encontrado. Instale primeiro!"
    exit 1
fi

# ============================================================================
# ETAPA 2: Verificar DNS
# ============================================================================

print_step "ETAPA 2/8: Verificando DNS dos domínios..."

SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")
print_info "IP do servidor: $SERVER_IP"

# Verificar domínio da UI
if command -v dig &> /dev/null; then
    DOMAIN_UI_IP=$(dig +short $DOMAIN_UI | tail -n1)
    DOMAIN_INGEST_IP=$(dig +short $DOMAIN_INGEST | tail -n1)

    print_info "IP do domínio UI ($DOMAIN_UI): $DOMAIN_UI_IP"
    print_info "IP do domínio Ingest ($DOMAIN_INGEST): $DOMAIN_INGEST_IP"

    if [ "$SERVER_IP" != "$DOMAIN_UI_IP" ] || [ "$SERVER_IP" != "$DOMAIN_INGEST_IP" ]; then
        print_warning "Um ou mais domínios não apontam para este servidor!"
        print_warning "Isso pode causar falha na validação do Let's Encrypt"
        read -p "Deseja continuar mesmo assim? [s/N]: " CONTINUE
        if [[ ! "$CONTINUE" =~ ^[Ss]$ ]]; then
            exit 1
        fi
    fi
else
    print_warning "Comando 'dig' não encontrado. Pulando validação de DNS."
fi

# ============================================================================
# ETAPA 3: Parar Nginx temporariamente
# ============================================================================

print_step "ETAPA 3/8: Parando Nginx para liberar portas 80 e 443..."

cd "$SCRIPT_DIR"

# Verificar se nginx está rodando
if docker-compose ps nginx 2>/dev/null | grep -q "Up"; then
    docker-compose stop nginx > /dev/null 2>&1
    print_info "Nginx parado com sucesso"
    sleep 2
fi

# Verificar se a porta 80 está livre
if command -v netstat &> /dev/null; then
    if netstat -tlnp 2>/dev/null | grep -q ":80 "; then
        print_error "Porta 80 ainda está em uso!"
        netstat -tlnp | grep ":80 "
        exit 1
    fi
fi

# ============================================================================
# ETAPA 4: Gerar certificado para domínio da UI
# ============================================================================

print_step "ETAPA 4/8: Gerando certificado para UI ($DOMAIN_UI)..."

certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    --domains "$DOMAIN_UI" \
    --rsa-key-size 4096 \
    $STAGING_ARG \
    || {
        print_error "Falha ao gerar certificado para $DOMAIN_UI!"
        print_error "Verifique se:"
        print_error "1. O domínio está apontando para este servidor"
        print_error "2. A porta 80 está acessível externamente"
        print_error "3. Não há firewall bloqueando"
        exit 1
    }

print_info "Certificado para UI gerado com sucesso!"

# ============================================================================
# ETAPA 5: Gerar certificado para domínio de Ingestão
# ============================================================================

print_step "ETAPA 5/8: Gerando certificado para Ingest ($DOMAIN_INGEST)..."

certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    --domains "$DOMAIN_INGEST" \
    --rsa-key-size 4096 \
    $STAGING_ARG \
    || {
        print_error "Falha ao gerar certificado para $DOMAIN_INGEST!"
        exit 1
    }

print_info "Certificado para Ingest gerado com sucesso!"

# ============================================================================
# ETAPA 6: Copiar certificados
# ============================================================================

print_step "ETAPA 6/8: Copiando certificados para $SSL_DIR..."

# Criar diretório SSL se não existir
mkdir -p "$SSL_DIR"

# Copiar certificados da UI
cp "/etc/letsencrypt/live/$DOMAIN_UI/fullchain.pem" "$SSL_DIR/server.crt"
cp "/etc/letsencrypt/live/$DOMAIN_UI/privkey.pem" "$SSL_DIR/server.key"

# Copiar certificados de Ingestão
cp "/etc/letsencrypt/live/$DOMAIN_INGEST/fullchain.pem" "$SSL_DIR/ingest.crt"
cp "/etc/letsencrypt/live/$DOMAIN_INGEST/privkey.pem" "$SSL_DIR/ingest.key"

# Ajustar permissões
chmod 644 "$SSL_DIR/server.crt" "$SSL_DIR/ingest.crt"
chmod 600 "$SSL_DIR/server.key" "$SSL_DIR/ingest.key"

# Alterar dono para o usuário que executou o sudo
if [ -n "$SUDO_USER" ]; then
    chown -R $SUDO_USER:$SUDO_USER "$SSL_DIR"
fi

print_info "Certificados copiados com sucesso!"
echo ""
echo "📁 Certificados em $SSL_DIR:"
ls -lh "$SSL_DIR"
echo ""

# ============================================================================
# ETAPA 7: Reiniciar Nginx
# ============================================================================

print_step "ETAPA 7/8: Reiniciando Nginx..."

cd "$SCRIPT_DIR"
docker-compose up -d nginx > /dev/null 2>&1

sleep 5

# Verificar se nginx está rodando
if docker-compose ps nginx | grep -q "Up"; then
    print_info "Nginx iniciado com sucesso!"
else
    print_error "Falha ao iniciar Nginx!"
    echo ""
    print_info "Logs do Nginx:"
    docker-compose logs nginx
    exit 1
fi

# ============================================================================
# ETAPA 8: Criar script de renovação
# ============================================================================

print_step "ETAPA 8/8: Criando script de renovação automática..."

cat > "$SCRIPT_DIR/renew-ssl-multi.sh" << RENEW_SCRIPT
#!/bin/bash

# Script de renovação automática para múltiplos domínios
set -e

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="\$SCRIPT_DIR/nginx/ssl"

echo "[\$(date)] Iniciando renovação de certificados..."

# Parar nginx
cd "\$SCRIPT_DIR"
docker-compose stop nginx

# Renovar certificados
certbot renew --quiet

# Copiar certificados da UI
cp "/etc/letsencrypt/live/$DOMAIN_UI/fullchain.pem" "\$SSL_DIR/server.crt"
cp "/etc/letsencrypt/live/$DOMAIN_UI/privkey.pem" "\$SSL_DIR/server.key"

# Copiar certificados de Ingestão
cp "/etc/letsencrypt/live/$DOMAIN_INGEST/fullchain.pem" "\$SSL_DIR/ingest.crt"
cp "/etc/letsencrypt/live/$DOMAIN_INGEST/privkey.pem" "\$SSL_DIR/ingest.key"

# Ajustar permissões
chmod 644 "\$SSL_DIR/server.crt" "\$SSL_DIR/ingest.crt"
chmod 600 "\$SSL_DIR/server.key" "\$SSL_DIR/ingest.key"

# Reiniciar nginx
docker-compose up -d nginx

echo "[\$(date)] Renovação concluída com sucesso!"
RENEW_SCRIPT

chmod +x "$SCRIPT_DIR/renew-ssl-multi.sh"

print_info "Script de renovação criado: $SCRIPT_DIR/renew-ssl-multi.sh"

# Configurar renovação automática (cron)
print_info "Configurando renovação automática (cron)..."

CRON_JOB="0 3 * * * $SCRIPT_DIR/renew-ssl-multi.sh >> $SCRIPT_DIR/ssl-renew.log 2>&1"

# Verificar se o cron job já existe
if crontab -l 2>/dev/null | grep -q "renew-ssl-multi.sh"; then
    print_warning "Cron job já existe, pulando..."
else
    # Adicionar cron job
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    print_info "Cron job adicionado! Renovação automática às 3h da manhã."
fi

# ============================================================================
# FINALIZAÇÃO
# ============================================================================

echo ""
echo "============================================================================"
print_info "✅ Configuração SSL concluída com sucesso!"
echo "============================================================================"
echo ""

print_info "📋 Certificados gerados:"
echo ""
echo "  UI Domain ($DOMAIN_UI):"
echo "    - $SSL_DIR/server.crt"
echo "    - $SSL_DIR/server.key"
openssl x509 -in "$SSL_DIR/server.crt" -noout -dates | sed 's/^/    /'
echo ""
echo "  Ingest Domain ($DOMAIN_INGEST):"
echo "    - $SSL_DIR/ingest.crt"
echo "    - $SSL_DIR/ingest.key"
openssl x509 -in "$SSL_DIR/ingest.crt" -noout -dates | sed 's/^/    /'
echo ""

print_info "📝 Próximos passos:"
echo ""
echo "  1. Verifique se o nginx.conf está configurado com os domínios corretos"
echo "  2. Atualize o uptrace.yml:"
echo "     site:"
echo "       url: https://$DOMAIN_UI"
echo "       ingest_url: https://$DOMAIN_INGEST?grpc=4317"
echo ""
echo "  3. Reinicie os serviços:"
echo "     cd $SCRIPT_DIR"
echo "     docker-compose restart nginx uptrace"
echo ""
echo "  4. Teste os endpoints:"
echo "     - UI:     https://$DOMAIN_UI"
echo "     - Ingest: https://$DOMAIN_INGEST"
echo "     - gRPC:   $DOMAIN_INGEST:4317"
echo ""

if [[ "$STAGING_ARG" == "--staging" ]]; then
    print_warning "⚠️  ATENÇÃO: Certificados de TESTE gerados!"
    print_warning "Para produção, execute novamente SEM o modo teste."
    echo ""
fi

print_info "✨ Configuração concluída!"
echo ""

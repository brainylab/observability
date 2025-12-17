#!/bin/bash

# ============================================================================
# Script de configuração automática de SSL com Let's Encrypt
# ============================================================================

set -e  # Para o script em caso de erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Verificar se está rodando como root
if [ "$EUID" -ne 0 ]; then
    print_error "Este script precisa ser executado como root (use sudo)"
    exit 1
fi

# ============================================================================
# CONFIGURAÇÃO - EDITE AQUI
# ============================================================================

# Solicitar informações do usuário
read -p "Digite seu domínio (ex: uptrace.exemplo.com): " DOMAIN
read -p "Digite seu email: " EMAIL

# Validar domínio
if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
    print_error "Domínio e email são obrigatórios!"
    exit 1
fi

# Perguntar se é teste ou produção
read -p "Usar certificado de TESTE? (recomendado na primeira vez) [s/N]: " USE_STAGING
if [[ "$USE_STAGING" =~ ^[Ss]$ ]]; then
    STAGING_ARG="--staging"
    print_warning "Modo TESTE ativado. O certificado NÃO será válido."
else
    STAGING_ARG=""
    print_info "Modo PRODUÇÃO ativado. Certificado válido será gerado."
fi

# Diretórios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="$SCRIPT_DIR/certs"
LETSENCRYPT_DIR="/etc/letsencrypt/live/$DOMAIN"

print_info "Diretório do projeto: $SCRIPT_DIR"
print_info "Domínio: $DOMAIN"
print_info "Email: $EMAIL"

# ============================================================================
# ETAPA 1: Verificar pré-requisitos
# ============================================================================

print_info "Verificando pré-requisitos..."

# Verificar se certbot está instalado
if ! command -v certbot &> /dev/null; then
    print_warning "Certbot não encontrado. Instalando..."

    if [ -f /etc/debian_version ]; then
        # Debian/Ubuntu
        apt update
        apt install -y certbot
    elif [ -f /etc/redhat-release ]; then
        # CentOS/RHEL
        yum install -y certbot
    else
        print_error "Sistema operacional não suportado"
        exit 1
    fi

    print_info "Certbot instalado com sucesso!"
else
    print_info "Certbot já está instalado: $(certbot --version)"
fi

# Verificar se docker compose está instalado
if ! command -v docker compose &> /dev/null; then
    print_error "Docker Compose não encontrado. Instale primeiro!"
    exit 1
fi

# ============================================================================
# ETAPA 2: Verificar DNS
# ============================================================================

print_info "Verificando DNS do domínio..."

SERVER_IP=$(curl -s ifconfig.me)
DOMAIN_IP=$(dig +short $DOMAIN | tail -n1)

print_info "IP do servidor: $SERVER_IP"
print_info "IP do domínio: $DOMAIN_IP"

if [ "$SERVER_IP" != "$DOMAIN_IP" ]; then
    print_error "O domínio $DOMAIN não aponta para este servidor!"
    print_error "Servidor IP: $SERVER_IP"
    print_error "Domínio IP: $DOMAIN_IP"
    read -p "Deseja continuar mesmo assim? [s/N]: " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Ss]$ ]]; then
        exit 1
    fi
fi

# ============================================================================
# ETAPA 3: Parar Nginx temporariamente
# ============================================================================

print_info "Parando Nginx para liberar porta 80..."

cd "$SCRIPT_DIR"

# Verificar se nginx está rodando
if docker compose ps nginx 2>/dev/null | grep -q "Up"; then
    docker compose stop nginx
    print_info "Nginx parado com sucesso"
fi

# Verificar se a porta 80 está livre
if netstat -tlnp | grep -q ":80 "; then
    print_error "Porta 80 ainda está em uso!"
    netstat -tlnp | grep ":80 "
    exit 1
fi

# ============================================================================
# ETAPA 4: Gerar certificado
# ============================================================================

print_info "Gerando certificado Let's Encrypt..."

certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    --domains "$DOMAIN" \
    --rsa-key-size 4096 \
    $STAGING_ARG \
    || {
        print_error "Falha ao gerar certificado!"
        print_error "Verifique se:"
        print_error "1. O domínio está apontando para este servidor"
        print_error "2. A porta 80 está acessível externamente"
        print_error "3. Não há firewall bloqueando"
        exit 1
    }

print_info "Certificado gerado com sucesso!"

# ============================================================================
# ETAPA 5: Copiar certificados
# ============================================================================

print_info "Copiando certificados para $SSL_DIR..."

# Criar diretório SSL se não existir
mkdir -p "$SSL_DIR"

# Copiar certificados
cp "$LETSENCRYPT_DIR/fullchain.pem" "$SSL_DIR/server.crt"
cp "$LETSENCRYPT_DIR/privkey.pem" "$SSL_DIR/server.key"

# Ajustar permissões
chmod 644 "$SSL_DIR/server.crt"
chmod 600 "$SSL_DIR/server.key"

# Alterar dono para o usuário que executou o sudo
if [ -n "$SUDO_USER" ]; then
    chown $SUDO_USER:$SUDO_USER "$SSL_DIR/server.crt"
    chown $SUDO_USER:$SUDO_USER "$SSL_DIR/server.key"
fi

print_info "Certificados copiados com sucesso!"
ls -lh "$SSL_DIR"

# ============================================================================
# ETAPA 6: Reiniciar Nginx
# ============================================================================

print_info "Reiniciando Nginx..."

cd "$SCRIPT_DIR"
docker compose up -d nginx

sleep 5

# Verificar se nginx está rodando
if docker compose ps nginx | grep -q "Up"; then
    print_info "Nginx iniciado com sucesso!"
else
    print_error "Falha ao iniciar Nginx!"
    docker compose logs nginx
    exit 1
fi

# ============================================================================
# ETAPA 7: Criar script de renovação
# ============================================================================

print_info "Criando script de renovação automática..."

cat > "$SCRIPT_DIR/renew-ssl.sh" << 'RENEW_SCRIPT'
#!/bin/bash

# Script de renovação automática
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSL_DIR="$SCRIPT_DIR/nginx/ssl"

echo "[$(date)] Iniciando renovação de certificados..."

# Parar nginx
cd "$SCRIPT_DIR"
docker compose stop nginx

# Renovar certificados
certbot renew --quiet

# Encontrar o certificado mais recente
CERT_DIR=$(ls -td /etc/letsencrypt/live/*/ | head -1)

# Copiar certificados
cp "${CERT_DIR}fullchain.pem" "$SSL_DIR/server.crt"
cp "${CERT_DIR}privkey.pem" "$SSL_DIR/server.key"

# Reiniciar nginx
docker compose up -d nginx

echo "[$(date)] Renovação concluída com sucesso!"
RENEW_SCRIPT

chmod +x "$SCRIPT_DIR/renew-ssl.sh"

print_info "Script de renovação criado: $SCRIPT_DIR/renew-ssl.sh"

# ============================================================================
# ETAPA 8: Configurar renovação automática (cron)
# ============================================================================

print_info "Configurando renovação automática (cron)..."

CRON_JOB="0 3 * * * $SCRIPT_DIR/renew-ssl.sh >> $SCRIPT_DIR/ssl-renew.log 2>&1"

# Verificar se o cron job já existe
if crontab -l 2>/dev/null | grep -q "renew-ssl.sh"; then
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
print_info "============================================"
print_info "✅ Configuração SSL concluída com sucesso!"
print_info "============================================"
echo ""
print_info "Informações do certificado:"
openssl x509 -in "$SSL_DIR/server.crt" -noout -dates
echo ""
print_info "Arquivos criados:"
echo "  - $SSL_DIR/server.crt"
echo "  - $SSL_DIR/server.key"
echo "  - $SCRIPT_DIR/renew-ssl.sh"
echo ""
print_info "Próximos passos:"
echo "  1. Atualize o nginx.conf para usar HTTPS"
echo "  2. Atualize o uptrace.yml com https://$DOMAIN"
echo "  3. Execute: docker compose restart nginx"
echo ""

if [[ "$STAGING_ARG" == "--staging" ]]; then
    print_warning "ATENÇÃO: Certificado de TESTE gerado!"
    print_warning "Para produção, execute novamente SEM o modo teste."
fi

print_info "Testar certificado: https://$DOMAIN"

#!/bin/bash

# ============================================================================
# Script de Validação Pré-Setup SSL
# Verifica se tudo está pronto antes de executar setup-ssl.sh
# ============================================================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Contadores
ERRORS=0
WARNINGS=0
SUCCESS=0

print_header() {
    echo ""
    echo "============================================================================"
    echo "  $1"
    echo "============================================================================"
    echo ""
}

print_check() {
    echo -n "  ⏳ $1... "
}

print_ok() {
    echo -e "${GREEN}✓ OK${NC}"
    ((SUCCESS++))
}

print_error() {
    echo -e "${RED}✗ ERRO${NC}"
    echo -e "     ${RED}→${NC} $1"
    ((ERRORS++))
}

print_warning() {
    echo -e "${YELLOW}⚠ AVISO${NC}"
    echo -e "     ${YELLOW}→${NC} $1"
    ((WARNINGS++))
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# ============================================================================
# INÍCIO DA VALIDAÇÃO
# ============================================================================

clear
print_header "Validação de Pré-requisitos para Setup SSL"

# ============================================================================
# 1. VERIFICAR SISTEMA OPERACIONAL
# ============================================================================

echo "📋 Verificando Sistema Operacional"
echo ""

print_check "Sistema operacional suportado"
if [ -f /etc/debian_version ]; then
    OS="Debian/Ubuntu"
    print_ok
    print_info "Detectado: $OS"
elif [ -f /etc/redhat-release ]; then
    OS="CentOS/RHEL"
    print_ok
    print_info "Detectado: $OS"
else
    print_warning "Sistema operacional não identificado"
fi

print_check "Executando como root/sudo"
if [ "$EUID" -eq 0 ]; then
    print_error "Não execute este script como root!"
    print_info "Este script apenas valida. Use sudo apenas no setup-ssl.sh"
else
    print_ok
fi

echo ""

# ============================================================================
# 2. VERIFICAR FERRAMENTAS NECESSÁRIAS
# ============================================================================

echo "🔧 Verificando Ferramentas Instaladas"
echo ""

print_check "Docker instalado"
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
    print_ok
    print_info "Versão: $DOCKER_VERSION"
else
    print_error "Docker não encontrado. Instale: https://docs.docker.com/get-docker/"
fi

print_check "Docker Compose instalado"
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version | cut -d' ' -f3 | tr -d ',')
    print_ok
    print_info "Versão: $COMPOSE_VERSION"
else
    print_error "Docker Compose não encontrado. Instale: https://docs.docker.com/compose/install/"
fi

print_check "Certbot disponível ou instalável"
if command -v certbot &> /dev/null; then
    print_ok
    print_info "Certbot já instalado"
else
    print_warning "Certbot não instalado (será instalado pelo setup-ssl.sh)"
fi

print_check "curl instalado"
if command -v curl &> /dev/null; then
    print_ok
else
    print_error "curl não encontrado. Instale: apt install curl / yum install curl"
fi

print_check "dig (DNS tools) instalado"
if command -v dig &> /dev/null; then
    print_ok
else
    print_warning "dig não encontrado (recomendado para validação DNS)"
    print_info "Instale: apt install dnsutils / yum install bind-utils"
fi

print_check "openssl instalado"
if command -v openssl &> /dev/null; then
    print_ok
else
    print_error "openssl não encontrado. Instale: apt install openssl"
fi

echo ""

# ============================================================================
# 3. VERIFICAR ESTRUTURA DE ARQUIVOS
# ============================================================================

echo "📁 Verificando Estrutura de Arquivos"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_check "Diretório nginx/ existe"
if [ -d "$SCRIPT_DIR/nginx" ]; then
    print_ok
else
    print_error "Diretório nginx/ não encontrado"
fi

print_check "Arquivo nginx/nginx.conf existe"
if [ -f "$SCRIPT_DIR/nginx/nginx.conf" ]; then
    print_ok

    # Verificar se ainda tem domínios de exemplo
    if grep -q "seu-dominio.com" "$SCRIPT_DIR/nginx/nginx.conf"; then
        print_warning "nginx.conf ainda contém 'seu-dominio.com'"
        print_info "Edite nginx/nginx.conf e substitua pelos seus domínios reais"
    fi
else
    print_error "Arquivo nginx/nginx.conf não encontrado"
fi

print_check "Arquivo example-uptrace.yml existe"
if [ -f "$SCRIPT_DIR/example-uptrace.yml" ]; then
    print_ok
else
    print_error "Arquivo example-uptrace.yml não encontrado"
fi

print_check "Arquivo uptrace.yml foi criado"
if [ -f "$SCRIPT_DIR/uptrace.yml" ]; then
    print_ok

    # Verificar se ainda tem valores de exemplo
    if grep -q "localhost" "$SCRIPT_DIR/uptrace.yml"; then
        print_warning "uptrace.yml ainda contém 'localhost'"
        print_info "Atualize site.url e ingest_url com seus domínios reais"
    fi

    if grep -q "FIXME\|your_secret" "$SCRIPT_DIR/uptrace.yml"; then
        print_warning "uptrace.yml ainda contém secret padrão"
        print_info "Gere um secret: openssl rand -base64 32"
    fi
else
    print_error "Arquivo uptrace.yml não encontrado"
    print_info "Execute: mv example-uptrace.yml uptrace.yml"
fi

print_check "Arquivo docker-compose.yml existe"
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    print_ok
else
    print_error "Arquivo docker-compose.yml não encontrado"
fi

print_check "Script setup-ssl.sh existe e é executável"
if [ -f "$SCRIPT_DIR/setup-ssl.sh" ]; then
    if [ -x "$SCRIPT_DIR/setup-ssl.sh" ]; then
        print_ok
    else
        print_warning "setup-ssl.sh não é executável"
        print_info "Execute: chmod +x setup-ssl.sh"
    fi
else
    print_error "Script setup-ssl.sh não encontrado"
fi

echo ""

# ============================================================================
# 4. VERIFICAR REDE E PORTAS
# ============================================================================

echo "🌐 Verificando Conectividade e Portas"
echo ""

print_check "Conectividade com internet"
if ping -c 1 8.8.8.8 &> /dev/null; then
    print_ok
else
    print_error "Sem conectividade com internet"
fi

print_check "Porta 80 disponível"
if command -v netstat &> /dev/null; then
    if netstat -tlnp 2>/dev/null | grep -q ":80 "; then
        print_warning "Porta 80 está em uso"
        print_info "Porta 80 precisa estar livre para Let's Encrypt"
        netstat -tlnp 2>/dev/null | grep ":80 " | sed 's/^/     /'
    else
        print_ok
    fi
elif command -v ss &> /dev/null; then
    if ss -tlnp 2>/dev/null | grep -q ":80 "; then
        print_warning "Porta 80 está em uso"
        print_info "Porta 80 precisa estar livre para Let's Encrypt"
    else
        print_ok
    fi
else
    print_warning "Não foi possível verificar portas (netstat/ss não disponível)"
fi

print_check "Porta 443 disponível"
if command -v netstat &> /dev/null; then
    if netstat -tlnp 2>/dev/null | grep -q ":443 "; then
        print_warning "Porta 443 está em uso"
    else
        print_ok
    fi
elif command -v ss &> /dev/null; then
    if ss -tlnp 2>/dev/null | grep -q ":443 "; then
        print_warning "Porta 443 está em uso"
    else
        print_ok
    fi
fi

print_check "Porta 4317 disponível"
if command -v netstat &> /dev/null; then
    if netstat -tlnp 2>/dev/null | grep -q ":4317 "; then
        print_warning "Porta 4317 está em uso"
    else
        print_ok
    fi
elif command -v ss &> /dev/null; then
    if ss -tlnp 2>/dev/null | grep -q ":4317 "; then
        print_warning "Porta 4317 está em uso"
    else
        print_ok
    fi
fi

print_check "IP público do servidor"
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || curl -s icanhazip.com 2>/dev/null)
if [ -n "$SERVER_IP" ]; then
    print_ok
    print_info "IP: $SERVER_IP"
else
    print_warning "Não foi possível detectar IP público"
fi

echo ""

# ============================================================================
# 5. VERIFICAR DNS (se domínios estiverem configurados)
# ============================================================================

echo "🔍 Verificando Configuração DNS"
echo ""

if [ -f "$SCRIPT_DIR/nginx/nginx.conf" ]; then
    # Extrair domínios do nginx.conf
    DOMAINS=$(grep "server_name" "$SCRIPT_DIR/nginx/nginx.conf" | grep -v "#" | awk '{print $2}' | sed 's/;//g' | sort -u)

    for domain in $DOMAINS; do
        # Pular domínios de exemplo
        if [[ "$domain" == "_" ]] || [[ "$domain" == "localhost" ]] || [[ "$domain" == *"seu-dominio"* ]] || [[ "$domain" == *"exemplo"* ]]; then
            continue
        fi

        print_check "DNS para $domain"
        if command -v dig &> /dev/null; then
            DOMAIN_IP=$(dig +short "$domain" | tail -n1)
            if [ -n "$DOMAIN_IP" ]; then
                if [ "$DOMAIN_IP" == "$SERVER_IP" ]; then
                    print_ok
                    print_info "IP: $DOMAIN_IP ✓ (corresponde ao servidor)"
                else
                    print_warning "DNS aponta para $DOMAIN_IP, servidor é $SERVER_IP"
                    print_info "Aguarde propagação DNS ou verifique configuração"
                fi
            else
                print_error "DNS não resolve para $domain"
                print_info "Configure registro A no seu provedor DNS"
            fi
        else
            print_warning "Não foi possível verificar (dig não disponível)"
        fi
    done
fi

echo ""

# ============================================================================
# 6. VERIFICAR DOCKER CONTAINERS
# ============================================================================

echo "🐳 Verificando Docker Containers"
echo ""

print_check "Docker daemon rodando"
if docker info &> /dev/null; then
    print_ok
else
    print_error "Docker daemon não está rodando"
    print_info "Execute: sudo systemctl start docker"
fi

print_check "Containers do projeto"
cd "$SCRIPT_DIR"
if docker-compose ps &> /dev/null; then
    RUNNING=$(docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l)
    TOTAL=$(docker-compose ps --services 2>/dev/null | wc -l)

    if [ "$RUNNING" -gt 0 ]; then
        print_warning "$RUNNING/$TOTAL containers rodando"
        print_info "Nginx precisa estar parado para setup SSL"
        print_info "Execute: docker-compose stop nginx"
    else
        print_ok
        print_info "Nenhum container rodando (correto para setup)"
    fi
else
    print_ok
    print_info "Projeto ainda não foi iniciado (correto)"
fi

echo ""

# ============================================================================
# 7. VERIFICAR PERMISSÕES
# ============================================================================

echo "🔐 Verificando Permissões"
echo ""

print_check "Permissões de escrita no diretório"
if [ -w "$SCRIPT_DIR" ]; then
    print_ok
else
    print_error "Sem permissão de escrita em $SCRIPT_DIR"
fi

print_check "Permissão para criar diretório nginx/ssl"
mkdir -p "$SCRIPT_DIR/nginx/ssl" 2>/dev/null
if [ -d "$SCRIPT_DIR/nginx/ssl" ]; then
    print_ok
else
    print_error "Não foi possível criar diretório nginx/ssl"
fi

echo ""

# ============================================================================
# 8. VERIFICAR FIREWALL
# ============================================================================

echo "🔥 Verificando Firewall"
echo ""

print_check "Status do firewall"
if command -v ufw &> /dev/null; then
    if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
        print_warning "UFW ativo - verifique regras"
        print_info "Portas necessárias: 80, 443, 4317"

        if sudo ufw status 2>/dev/null | grep -q "80"; then
            print_info "  ✓ Porta 80 configurada"
        else
            print_info "  ✗ Porta 80 não encontrada: sudo ufw allow 80/tcp"
        fi

        if sudo ufw status 2>/dev/null | grep -q "443"; then
            print_info "  ✓ Porta 443 configurada"
        else
            print_info "  ✗ Porta 443 não encontrada: sudo ufw allow 443/tcp"
        fi

        if sudo ufw status 2>/dev/null | grep -q "4317"; then
            print_info "  ✓ Porta 4317 configurada"
        else
            print_info "  ✗ Porta 4317 não encontrada: sudo ufw allow 4317/tcp"
        fi
    else
        print_ok
        print_info "UFW não está ativo"
    fi
elif command -v firewall-cmd &> /dev/null; then
    if sudo firewall-cmd --state 2>/dev/null | grep -q "running"; then
        print_warning "firewalld ativo - verifique regras"
    else
        print_ok
    fi
else
    print_ok
    print_info "Firewall não detectado ou não configurado"
fi

echo ""

# ============================================================================
# RESUMO FINAL
# ============================================================================

print_header "Resumo da Validação"

echo -e "${GREEN}✓ Sucessos:${NC} $SUCCESS"
echo -e "${YELLOW}⚠ Avisos:${NC} $WARNINGS"
echo -e "${RED}✗ Erros:${NC} $ERRORS"
echo ""

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ PRONTO PARA SETUP SSL!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Próximos passos:"
    echo ""
    echo "  1. Verifique os avisos acima (se houver)"
    echo "  2. Execute o setup SSL:"
    echo -e "     ${BLUE}sudo ./setup-ssl.sh${NC}"
    echo ""

    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}⚠ Há $WARNINGS aviso(s). Recomenda-se corrigir antes de continuar.${NC}"
        echo ""
    fi
else
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}❌ ERROS ENCONTRADOS!${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${RED}Corrija os $ERRORS erro(s) acima antes de executar o setup SSL.${NC}"
    echo ""
    echo "Documentação:"
    echo "  - QUICK-START.md    - Guia rápido"
    echo "  - README.md         - Documentação completa"
    echo ""
    exit 1
fi

# ============================================================================
# CHECKLIST INTERATIVO
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 CHECKLIST FINAL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Antes de executar o setup SSL, confirme:"
echo ""
echo "  [ ] DNS configurado e propagado (aguarde 5-10 min após criar)"
echo "  [ ] nginx/nginx.conf editado com domínios corretos"
echo "  [ ] uptrace.yml criado e editado (url, ingest_url, secret)"
echo "  [ ] Portas 80, 443, 4317 abertas no firewall"
echo "  [ ] Nenhum outro serviço usando porta 80 ou 443"
echo "  [ ] Containers Docker parados (especialmente nginx)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0

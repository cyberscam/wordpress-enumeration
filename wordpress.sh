#!/bin/bash

# Banner ASCII
echo '
  _      __            _____                    ____                             __  _         
 | | /| / /__  _______/ / _ \_______ ___ ___   / __/__  __ ____ _  ___ _______ _/ /_(_)__  ___ 
 | |/ |/ / _ \/ __/ _  / ___/ __/ -_|_-<(_-<  / _// _ \/ // /  '\'' \/ -_) __/ _ `/ __/ / _ \/ _ \
 |__/|__/\___/_/  \_,_/_/  /_/  \__/___/___/ /___/_//_/\_,_/_/_/_/\__/_/  \_,_/\__/_/\___/_//_/  
'

# Verificação de dependências
verificar_dependencias() {
    if ! [ -x "$(command -v curl)" ] || ! [ -x "$(command -v host)" ]; then
        echo 'Erro: curl ou host não estão instalados.' >&2
        exit 1
    fi
}

declare -a resumo_expostos

# Função para analisar uma URL
analisar_url() {
    local url_original=$1
    local detalhes=""
    local detalhes_resumo=""
    local dados_expostos=false
    local protocolos=()
    local found_wp_version=false
    local found_users=false
    local link_versao=""
    local link_usuarios=""

    if [[ "$url_original" =~ ^https?:// ]]; then
        protocolos+=("${url_original%%://*}")
        url_original="${url_original#*://}"
    else
        protocolos=("http" "https")
    fi

    for protocolo in "${protocolos[@]}"; do
        local url_completa="$protocolo://$url_original"
        echo "Analisando $url_completa"

        resposta=$(curl -s -o /dev/null -w "%{http_code}" "$url_completa")
        if [ "$resposta" != "200" ]; then
            continue
        fi

        detalhes+="Analisando $url_completa\n"
        detalhes_resumo+="Analisado $url_completa\n"
        
        resposta=$(curl -s "$url_completa/wp-links-opml.php")
        versao=$(echo "$resposta" | grep -oP '(?<=generator="WordPress/)[^"]+')
        if [[ ! -z $versao ]]; then
            echo "Versão do WordPress: $versao"
            detalhes+="Versão do WordPress: $versao\n"
            detalhes_resumo+="Versão do WordPress: $versao\n"
            link_versao="Link para análise (Versão): ${url_completa}/wp-links-opml.php\n"
            dados_expostos=true
            found_wp_version=true
        fi
        
        resposta=$(curl -s "$url_completa/?rest_route=/wp/v2/users")
        usuarios=$(echo "$resposta" | grep -oP '(?<="slug":")[^"]+')
        if [[ ! -z $usuarios ]]; then
            echo "Usuários expostos: $usuarios"
            detalhes+="Usuários expostos: $usuarios\n"
            detalhes_resumo+="Usuários expostos: $usuarios\n"
            link_usuarios="Link para análise (Usuários): ${url_completa}/section/news?rest_route=/wp/v2/users\n"
            dados_expostos=true
            found_users=true
        fi

        if [[ $dados_expostos == true ]]; then
            dominio=$(echo "$url_completa" | awk -F/ '{print $3}')
            ip=$(host "$dominio" | grep -oP 'has address \K[^ ]+' | head -n 1)
            if [[ ! -z $ip ]]; then
                echo "IP da página: $ip"
                detalhes+="IP da página: $ip\n"
                detalhes_resumo+="IP da página: $ip\n"
            fi
            detalhes+="${link_versao}${link_usuarios}"
            detalhes_resumo+="${link_versao}${link_usuarios}"
            break
        fi
    done

    if [[ $found_wp_version == false && $found_users == false ]]; then
        echo "Versionamento do WordPress e usuários expostos não foram encontrados"
    fi

    if [[ $dados_expostos == true ]]; then
        resumo_expostos+=("$detalhes_resumo")
    fi

    echo "_______________________"
}

# Função para exibir o resumo
exibir_resumo() {
    if [ ${#resumo_expostos[@]} -ne 0 ]; then
        echo "Resumo Geral:"
        for detalhe in "${resumo_expostos[@]}"; do
            echo -e "$detalhe"
        done
    fi
}

# Exibe as opções de uso do script
exibir_ajuda() {
    echo "Uso: $0 [opção] [argumento]"
    echo "Opções:"
    echo "-h para exibir esta mensagem de ajuda."
    echo "-s <url> para analisar um único site."
    echo "-l <caminho_para_lista_de_urls> para analisar uma lista de sites."
}

while getopts ":hs:l:" opt; do
  case ${opt} in
    h )
      exibir_ajuda
      ;;
    s )
      analisar_url "$OPTARG"
      exibir_resumo
      ;;
    l )
      if [ ! -f "$OPTARG" ]; then
        echo "Erro: O arquivo '$OPTARG' não existe."
        exit 1
      fi
      while IFS= read -r url; do
        analisar_url "$url"
      done < "$OPTARG"
      exibir_resumo
      ;;
    \? )
      echo "Opção inválida: -$OPTARG" >&2
      exibir_ajuda
      ;;
    : )
      echo "Opção -$OPTARG requer um argumento." >&2
      exibir_ajuda
      ;;
  esac
done
shift $((OPTIND -1))

if [ "$#" -gt 0 ]; then
    echo "Argumento(s) inválido(s): $*"
    exibir_ajuda
fi

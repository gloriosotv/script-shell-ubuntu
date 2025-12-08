#!/bin/bash
#
# Script de limpeza de cache de memória + swap para Linux / Ubuntu
# Uso: sudo ./limpar_cache.sh
#
# AVISO: para uso em desktop/estação. Em servidores de produção, usar com cautela.

echo "### Iniciando limpeza de memória (cache + swap) ###"

# Sincronizar dados para o disco (evita perda de dados pendentes)
echo "Sincronizando sistema de arquivos..."
sudo sync
if [ $? -ne 0 ]; then
    echo "Falha ao sincronizar. Abortando."
    exit 1
fi

# Esvaziar caches: pagecache, dentries e inodes
echo "Limpando pagecache, dentries e inodes..."
# Comando correto para garantir permissão
echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null
if [ $? -eq 0 ]; then
    echo "Cache limpo com sucesso."
else
    echo "Falha ao limpar cache. Tente executar como root."
fi

# Desativar swap
echo "Desativando swap..."
sudo swapoff -a
if [ $? -eq 0 ]; then
    echo "Swap desativada com sucesso."
else
    echo "Falha ao desativar swap."
fi

# Reativar swap
echo "Reativando swap..."
sudo swapon -a
if [ $? -eq 0 ]; then
    echo "Swap reativada com sucesso."
else
    echo "Falha ao reativar swap."
fi

# Mostrar uso de memória e swap
echo "Uso atual de memória e swap:"
free -h

echo "### Processo concluído ###"

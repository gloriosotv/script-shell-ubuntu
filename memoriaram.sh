#!/bin/bash

# Sincronizar os dados da memória para o disco (evita perda de dados)
sync

# Limpar cache de páginas, inodes e dentries
echo "Limpando cache de páginas, inodes e dentries..."
sudo bash -c 'echo 3 > /proc/sys/vm/drop_caches'

# Verificar se o comando anterior foi bem-sucedido
if [ $? -eq 0 ]; then
    echo "Cache limpo com sucesso!"
else
    echo "Falha ao limpar cache."
fi

# Desativar e reativar a swap para limpar
echo "Desativando a swap..."
sudo swapoff -a

if [ $? -eq 0 ]; then
    echo "Swap desativada com sucesso!"
else
    echo "Falha ao desativar a swap."
fi

echo "Reativando a swap..."
sudo swapon -a

if [ $? -eq 0 ]; then
    echo "Swap reativada com sucesso!"
else
    echo "Falha ao reativar a swap."
fi

# Exibir o uso da memória
free -h

echo "Memória RAM e swap limpas com sucesso!"


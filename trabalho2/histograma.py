import matplotlib.pyplot as plt
import numpy as np
import os
from collections import Counter

FILE_NAME = "cluster_sizes.txt"

def ler_tamanhos_clusters(nome_arquivo):
    """Lê os tamanhos dos clusters do arquivo de texto gerado pelo C."""
    
    if not os.path.exists(nome_arquivo):
        print(f"ERRO: Arquivo '{nome_arquivo}' não encontrado.")
        print("Certifique-se de que o programa C foi compilado e executado primeiro.")
        return None
        
    try:
        tamanhos = []
        with open(nome_arquivo, 'r') as f:
            for line in f:
                # Converte cada linha para inteiro (que é o tamanho do cluster)
                tamanho = int(line.strip())
                if tamanho > 0: # Garante que apenas tamanhos válidos sejam considerados
                    tamanhos.append(tamanho)
        
        return tamanhos
        
    except Exception as e:
        print(f"ERRO ao ler o arquivo: {e}")
        return None

def gerar_histograma(tamanhos):
    """Gera e exibe o histograma dos tamanhos dos clusters."""
    
    num_clusters = len(tamanhos)
    
    if num_clusters == 0:
        print("Não há dados de clusters válidos para gerar o histograma.")
        return
        
    # Ordena para melhor visualização (opcional)
    tamanhos_ordenados = sorted(tamanhos, reverse=True)
    
    # Cria os rótulos para o eixo X
    labels = [f'C{i+1}\n({tamanho})' for i, tamanho in enumerate(tamanhos_ordenados)]
    
    # Cores para os clusters (pode repetir se houver mais de 3)
    cores = ['#4CAF50', '#FF9800', '#2196F3', '#9C27B0', '#00BCD4']
    cores_ciclo = [cores[i % len(cores)] for i in range(num_clusters)]

    # --- Plotagem ---
    
    plt.figure(figsize=(10, 6))
    
    barras = plt.bar(labels, tamanhos_ordenados, color=cores_ciclo, alpha=0.9, edgecolor='black', linewidth=1.2)
    
    # Adiciona o valor acima de cada barra
    for bar in barras:
        yval = bar.get_height()
        plt.text(bar.get_x() + bar.get_width()/2, yval + 1.5, int(yval), ha='center', va='bottom', fontsize=10, weight='bold')

    # Configurações do Gráfico
    plt.title(f'Histograma de Tamanhos dos {num_clusters} Clusters Encontrados', fontsize=16, pad=20)
    plt.xlabel('Cluster (Tamanho da Amostra)', fontsize=14)
    plt.ylabel('Número de Amostras (Tamanho)', fontsize=14)
    plt.xticks(rotation=0, ha='center', fontsize=12)
    plt.yticks(fontsize=10)
    plt.grid(axis='y', linestyle='--', alpha=0.6)
    
    # Linha de referência para o tamanho ideal (N=150 / 3 = 50)
    tamanho_ideal = 150 / 3
    plt.axhline(tamanho_ideal, color='red', linestyle=':', linewidth=2, label=f'Tamanho Ideal ({tamanho_ideal:.0f})')
    plt.legend()
    
    plt.tight_layout()
    plt.show()
    
    # Opcional: Salvar o histograma como imagem
    plt.savefig('histograma_clusters_tamanhos.png')
    print("\n✓ Histograma salvo como 'histograma_clusters_tamanhos.png'")
    
if __name__ == "__main__":
    tamanhos_dos_clusters = ler_tamanhos_clusters(FILE_NAME)
    
    if tamanhos_dos_clusters:
        print(f"\n--- Dados Lidos ---\nTotal de clusters: {len(tamanhos_dos_clusters)}")
        print(f"Tamanhos (do maior para o menor): {sorted(tamanhos_dos_clusters, reverse=True)}")
        print("Gerando histograma...")
        gerar_histograma(tamanhos_dos_clusters)

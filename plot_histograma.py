import pandas as pd
import networkx as nx
import matplotlib.pyplot as plt

# Lista de limiares usados no C
limiares = [0.0, 0.3, 0.5, 0.9]

# Dicionário para armazenar contagens por tamanho para cada L
resultados_por_L = {}

for L in limiares:
    nome_arquivo = f"grafo_L_{L:.1f}.csv"
    try:
        df = pd.read_csv(nome_arquivo)
    except FileNotFoundError:
        print(f"Arquivo {nome_arquivo} não encontrado. Ignorando.")
        continue

    # Cria grafo orientado com as arestas
    G = nx.DiGraph()
    for _, row in df.iterrows():
        G.add_edge(row['origem'], row['destino'])

    # Converte para grafo não-direcionado (componentes conexos exigem isso)
    G_undirected = G.to_undirected()

    # Calcula componentes conexos
    componentes = list(nx.connected_components(G_undirected))

    # Conta componentes por tamanho
    contagem_tamanhos = {}
    for componente in componentes:
        tamanho = len(componente)
        contagem_tamanhos[tamanho] = contagem_tamanhos.get(tamanho, 0) + 1

    # Armazena para uso posterior
    resultados_por_L[L] = contagem_tamanhos

# === PLOT ===
fig, axs = plt.subplots(2, 2, figsize=(14, 10))
axs = axs.flatten()

for idx, L in enumerate(limiares):
    ax = axs[idx]
    contagem = resultados_por_L.get(L, {})
    
    if not contagem:
        ax.set_title(f"L = {L} (sem dados)")
        continue

    tamanhos = sorted(contagem.keys())
    quantidades = [contagem[t] for t in tamanhos]

    ax.bar(tamanhos, quantidades, color='skyblue', edgecolor='black')
    ax.set_title(f"Limiar L = {L}")
    ax.set_xlabel("Tamanho do Componente")
    ax.set_ylabel("Número de Componentes")
    ax.grid(True)

plt.tight_layout()
plt.suptitle("Histograma: Nº de Componentes vs Tamanho (por Limiar)", fontsize=16, y=1.03)
plt.show()

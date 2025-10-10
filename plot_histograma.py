import matplotlib.pyplot as plt

# === DADOS PARA OS 4 CASOS ===
tamanhos_casos = [
    [1, 2, 3],           # L = 0.0
    [1],                 # L = 0.3
    [1],                 # L = 0.5
    [1]                  # L = 0.9
]

quantidades_casos = [
    [145, 1, 1],         # Frequências para L = 0.0
    [150],               # L = 0.3
    [150],               # L = 0.5
    [150]                # L = 0.9
]

titulos = ["Limiar L = 0.0", "Limiar L = 0.3", "Limiar L = 0.5", "Limiar L = 0.9"]
cores = ['blue', 'green', 'red', 'purple']

# === GERAR HISTOGRAMAS INDIVIDUAIS ===
for i in range(4):
    tamanhos = tamanhos_casos[i]
    quantidades = quantidades_casos[i]

    plt.figure(figsize=(8, 5))
    plt.bar(tamanhos, quantidades, color=cores[i], width=0.5, edgecolor='black', alpha=0.7)

    # Adicionar rótulos acima de cada barra
    for x, y in zip(tamanhos, quantidades):
        plt.text(x, y + max(quantidades)*0.02, f"{y}", ha='center', fontsize=10, fontweight='bold')

    # Configurações detalhadas do gráfico
    plt.title(f"Distribuição dos Componentes Conexos – {titulos[i]}", fontsize=14, fontweight='bold')
    plt.xlabel("Tamanho do Componente", fontsize=12)
    plt.ylabel("Número de Componentes", fontsize=12)
    plt.xticks(tamanhos)
    plt.grid(axis='y', linestyle='--', alpha=0.6)
    plt.legend([f"{titulos[i]}"], loc='upper right', fontsize=10)
    plt.tight_layout()

    # Mostrar gráfico individualmente
    plt.show()

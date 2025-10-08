import matplotlib.pyplot as plt

# === DADOS PARA OS 4 CASOS ===
tamanhos_casos = [
    [1, 2, 3],           # L = 0.0
    [1],                # L = 0.3
    [1],                # L = 0.5
    [1]                 # L = 0.9
]

quantidades_casos = [
    [145, 1, 1],         # Frequências para L = 0.0
    [150],              # L = 0.3
    [150],              # L = 0.5
    [150]               # L = 0.9
]

titulos = ["Limiar L = 0.0", "Limiar L = 0.3", "Limiar L = 0.5", "Limiar L = 0.9"]
cores = ['blue', 'green', 'red', 'purple']

# === PLOT ===
fig, axs = plt.subplots(1, 4, figsize=(20, 5), sharey=True)

for i in range(4):
    ax = axs[i]
    tamanhos = tamanhos_casos[i]
    quantidades = quantidades_casos[i]

    ax.scatter(tamanhos, quantidades, color=cores[i], s=100)

    for x, y in zip(tamanhos, quantidades):
        ax.text(x, y + 2, f"{y}", ha='center', fontsize=9)

    ax.set_title(titulos[i])
    ax.set_xlabel("Tamanho do Componente")
    if i == 0:
        ax.set_ylabel("Nº de Componentes")
    ax.grid(True)

plt.tight_layout()
plt.suptitle("Nuvem de Pontos: Componentes Conexos por Tamanho (4 Casos)", fontsize=16, y=1.05)
plt.subplots_adjust(top=0.85)
plt.show()

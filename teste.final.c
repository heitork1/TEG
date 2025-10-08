#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define N 150

// Função que transforma matriz de distâncias em grafo binário (0 ou 1)
void den(float matrizFinal[N][N], float DEmin, float DEmax, float L){
    int i, j;
    float den;
    for (i=0; i < N; i++){
        for(j=0; j < N; j++){
            if(i == j) continue;
            den = (matrizFinal[i][j] - DEmin)/(DEmax - DEmin); 
            matrizFinal[i][j] = (den <= L) ? 1 : 0;
        }
    }
    printf("DEmin: %f, DEmax: %f\n", DEmin, DEmax);
}

// Distância Euclidiana entre dois vetores 4D
float calcDist(float x1, float x2, float x3, float x4, float y1, float y2, float y3, float y4){
    return sqrt(pow(x1 - y1, 2) + pow(x2 - y2, 2) + pow(x3 - y3, 2) + pow(x4 - y4, 2));
}

// Calcula todas as distâncias e aplica o limiar
void calcAllDist(float matriz[N][4], float matrizFinal[N][N], float L){
    int i, j;
    float DEmin = 100, DEmax = 0, dist;

    for(i = 0; i < N; i++){
        for(j = 0; j < N; j++){
            if(i == j){
                matrizFinal[i][j] = 0;
                continue;
            }
            dist = calcDist(matriz[i][0], matriz[i][1], matriz[i][2], matriz[i][3],
                            matriz[j][0], matriz[j][1], matriz[j][2], matriz[j][3]);
            matrizFinal[i][j] = dist;
            if(dist < DEmin) DEmin = dist;
            if(dist > DEmax) DEmax = dist;
        }
    }

    den(matrizFinal, DEmin, DEmax, L);
}

// Salva o grafo como lista de arestas: origem,destino
void salvarMatrizCSV(float matriz[N][N], float L) {
    char nomeArquivo[50];
    snprintf(nomeArquivo, sizeof(nomeArquivo), "grafo_L_%.1f.csv", L);

    FILE *fp = fopen(nomeArquivo, "w");
    if (fp == NULL) {
        printf("Erro ao criar o arquivo CSV.\n");
        return;
    }

    fprintf(fp, "origem,destino\n");

    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            if (matriz[i][j] == 1) {
                fprintf(fp, "%d,%d\n", i, j);
            }
        }
    }

    fclose(fp);
    printf("Grafo salvo (compactado) em: %s\n", nomeArquivo);
}

// Lê o grafo salvo como lista de arestas
int carregarMatrizCSV(float matriz[N][N], float L) {
    char nomeArquivo[50];
    snprintf(nomeArquivo, sizeof(nomeArquivo), "grafo_L_%.1f.csv", L);

    FILE *fp = fopen(nomeArquivo, "r");
    if (fp == NULL) {
        return 0;
    }

    // Zera a matriz
    for (int i = 0; i < N; i++)
        for (int j = 0; j < N; j++)
            matriz[i][j] = 0;

    char linha[100];
    int i, j;

    // Ignora cabeçalho
    fgets(linha, sizeof(linha), fp);

    while (fgets(linha, sizeof(linha), fp)) {
        if (sscanf(linha, "%d,%d", &i, &j) == 2) {
            if (i >= 0 && i < N && j >= 0 && j < N) {
                matriz[i][j] = 1;
            }
        }
    }

    fclose(fp);
    printf("Grafo carregado (compactado) de: %s\n", nomeArquivo);
    return 1;
}

// DFS para busca em profundidade de componentes
void DFS(int v, int visitado[N], float matrizAdj[N][N], int *tamanhoComponente) {
    visitado[v] = 1;
    (*tamanhoComponente)++;

    for (int i = 0; i < N; i++) {
        if (matrizAdj[v][i] == 1 && !visitado[i]) {
            DFS(i, visitado, matrizAdj, tamanhoComponente);
        }
    }
}

// Encontra e mostra os componentes conexos e resumo compacto
void encontrarComponentesConexos(float matrizAdj[N][N]) {
    int visitado[N] = {0};
    int numComponentes = 0;
    int tamanhos[N] = {0};
    int ocorrenciasTamanhos[N + 1] = {0};

    printf("\n--- Componentes Conexos ---\n");

    for (int i = 0; i < N; i++) {
        if (!visitado[i]) {
            int tamanhoComponente = 0;
            DFS(i, visitado, matrizAdj, &tamanhoComponente);
            tamanhos[numComponentes] = tamanhoComponente;
            ocorrenciasTamanhos[tamanhoComponente]++;
            numComponentes++;
            printf("Componente %d: tamanho = %d\n", numComponentes, tamanhoComponente);
        }
    }

    printf("\nNúmero total de componentes conexos: %d\n", numComponentes);

    printf("\nResumo compacto:\n");
    for (int i = 1; i <= N; i++) {
        if (ocorrenciasTamanhos[i] > 0) {
            printf("%d componente(s) de tamanho %d\n", ocorrenciasTamanhos[i], i);
        }
    }
}

// MAIN
int main() {
    FILE *file;
    char linha[256];
    int escolha, i = 0, j;
    float L;
    float matriz[N][4];
    float matrizFinal[N][N];

    printf("Qual o L?\nDigite 1 para 0.0\nDigite 2 para 0.3\nDigite 3 para 0.5\nDigite 4 para 0.9\n");
    scanf("%d", &escolha);

    switch(escolha){
        case 1: L = 0.0; break;
        case 2: L = 0.3; break;
        case 3: L = 0.5; break;
        case 4: L = 0.9; break;
        default:
            printf("Escolha inválida.\n");
            return 1;
    }

    printf("Valor de L selecionado: %.1f\n", L);

    // Tenta carregar grafo compactado
    int grafoCarregado = carregarMatrizCSV(matrizFinal, L);

    // Se não encontrou o grafo, calcula e salva
    if (!grafoCarregado) {
        printf("Grafo não encontrado. Carregando dataset e gerando grafo...\n");

        file = fopen("my_dataset.csv", "r");
        if(file == NULL){
            printf("Erro ao abrir o arquivo do dataset.\n");
            return 1;
        }

        while (fgets(linha, sizeof(linha), file)){
            j = 0;
            matriz[i][j] = atof(strtok(linha, ","));
            for(j = 1; j < 4; j++){
                matriz[i][j] = atof(strtok(NULL, ","));
            }
            i++;
        }

        fclose(file);
        calcAllDist(matriz, matrizFinal, L);
        salvarMatrizCSV(matrizFinal, L);
    }

    encontrarComponentesConexos(matrizFinal);

    return 0;
}

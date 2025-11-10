#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>

#define N 150 // Número de nós (amostras)
#define MAX_LABEL_LEN 10 // Tamanho máximo do rótulo
#define NUM_CLASSES 3 // Temos 3 classes: Tipo1, Tipo2, Tipo3
#define TARGET_CLUSTERS 3 // Número desejado de clusters

// Estrutura para o Centro de Gravidade
typedef struct {
    float soma[4];
    int contagem;
} CentroDeGravidade;

// Estrutura para armazenar resultado de clustering
typedef struct {
    int numComponentes;
    int tamanhos[N];
    float L;
    float desvioPadrao;
    float score; // Métrica para avaliar qualidade do balanceamento
} ResultadoClustering;

// --- FUNÇÕES DE UTENSÍLIOS E CÁLCULO DE GRAFO ---

// Funcao que transforma matriz de distancias em grafo binario (0 ou 1)
void den(float matrizDist[N][N], float matrizAdj[N][N], float DEmin, float DEmax, float L) {
    int i, j;
    float den_val;
    
    float range = DEmax - DEmin;
    if (range == 0) range = 1.0;

    for (i = 0; i < N; i++) {
        for (j = 0; j < N; j++) {
            if (i == j) {
                matrizAdj[i][j] = 0;
                continue;
            }
            den_val = (matrizDist[i][j] - DEmin) / range;
            matrizAdj[i][j] = (den_val <= L) ? 1 : 0;
        }
    }
}

// Distancia Euclidiana entre dois vetores 4D
float calcDist(float x1, float x2, float x3, float x4, float y1, float y2, float y3, float y4) {
    return sqrt(pow(x1 - y1, 2) + pow(x2 - y2, 2) + pow(x3 - y3, 2) + pow(x4 - y4, 2));
}

// Calcula todas as distancias e retorna DEmin e DEmax
void calcAllDist(float matrizDados[N][4], float matrizDist[N][N], float *DEmin, float *DEmax) {
    int i, j;
    *DEmin = FLT_MAX;
    *DEmax = 0;
    float dist;

    for(i = 0; i < N; i++) {
        for(j = i + 1; j < N; j++) {
            dist = calcDist(matrizDados[i][0], matrizDados[i][1], matrizDados[i][2], matrizDados[i][3],
                            matrizDados[j][0], matrizDados[j][1], matrizDados[j][2], matrizDados[j][3]);
            
            matrizDist[i][j] = dist;
            matrizDist[j][i] = dist;

            if(dist < *DEmin) *DEmin = dist;
            if(dist > *DEmax) *DEmax = dist;
        }
    }
    for(i=0; i<N; i++) matrizDist[i][i] = 0;
}

// --- FUNÇÕES DE CLUSTERING (COMPONENTES CONEXOS) ---

// DFS adaptada para registrar membros do componente
void DFS_Cluster(int v, int visitado[N], float matrizAdj[N][N], int *tamanhoComponente, int membrosComponente[N], int *idxMembros) {
    visitado[v] = 1;
    (*tamanhoComponente)++;
    membrosComponente[(*idxMembros)++] = v; 

    for (int i = 0; i < N; i++) {
        if (matrizAdj[v][i] == 1 && !visitado[i]) {
            DFS_Cluster(i, visitado, matrizAdj, tamanhoComponente, membrosComponente, idxMembros);
        }
    }
}

// Encontra componentes conexos SEM rotular (fase de treinamento não supervisionado)
int encontrarComponentes(float matrizAdj[N][N], int tamanhos[N], int clusters[N][N], int tamanhosClusters[N]) {
    int visitado[N] = {0};
    int numComponentes = 0;

    for (int i = 0; i < N; i++) {
        if (!visitado[i]) {
            int tamanhoComponente = 0;
            int membrosComponente[N];
            int idxMembros = 0;

            DFS_Cluster(i, visitado, matrizAdj, &tamanhoComponente, membrosComponente, &idxMembros);
            
            tamanhos[numComponentes] = tamanhoComponente;
            
            // Armazena os membros do cluster
            for (int k = 0; k < idxMembros; k++) {
                clusters[numComponentes][k] = membrosComponente[k];
            }
            tamanhosClusters[numComponentes] = idxMembros;
            
            numComponentes++;
        }
    }

    return numComponentes;
}

// Calcula desvio padrão dos tamanhos dos clusters
float calcularDesvioPadrao(int tamanhos[N], int numComponentes) {
    if (numComponentes == 0) return FLT_MAX;
    
    float media = 0;
    for (int i = 0; i < numComponentes; i++) {
        media += tamanhos[i];
    }
    media /= numComponentes;
    
    float variancia = 0;
    for (int i = 0; i < numComponentes; i++) {
        variancia += pow(tamanhos[i] - media, 2);
    }
    variancia /= numComponentes;
    
    return sqrt(variancia);
}

// Função de score para avaliar qualidade do clustering
// Queremos: exatamente 3 clusters com tamanhos similares
float calcularScore(int numComponentes, int tamanhos[N]) {
    if (numComponentes != TARGET_CLUSTERS) {
        // Penalização severa se não tiver exatamente 3 clusters
        return FLT_MAX;
    }
    
    // Queremos minimizar o desvio padrão dos tamanhos
    float desvioPadrao = calcularDesvioPadrao(tamanhos, numComponentes);
    
    // Tamanho ideal por cluster
    float tamanhoIdeal = (float)N / TARGET_CLUSTERS;
    
    // Penaliza clusters muito diferentes do ideal
    float penalizacao = 0;
    for (int i = 0; i < numComponentes; i++) {
        penalizacao += fabs(tamanhos[i] - tamanhoIdeal);
    }
    
    return desvioPadrao + penalizacao * 0.1;
}

// --- TREINAMENTO: BUSCA DO MELHOR LIMIAR L ---

float treinarClustering(float matrizDist[N][N], float DEmin, float DEmax, 
                        float matrizAdjFinal[N][N], int melhorTamanhos[N],
                        int melhorClusters[N][N], int melhorTamanhosClusters[N]) {
    
    printf("\n========================================\n");
    printf("  FASE 1: TREINAMENTO (NÃO SUPERVISIONADO)\n");
    printf("========================================\n\n");
    
    printf("Buscando o melhor limiar L para obter %d clusters balanceados...\n\n", TARGET_CLUSTERS);
    printf("Range de distâncias: [%.4f, %.4f]\n\n", DEmin, DEmax);
    
    float melhorL = 0;
    float melhorScore = FLT_MAX;
    int melhorNumComponentes = 0;
    
    // Busca em grade de valores de L
    int numTestes = 50; // Número de valores de L para testar
    
    printf("Testando %d valores de L...\n", numTestes);
    printf("%-8s | %-12s | %-12s | %-8s\n", "L", "Clusters", "Desvio", "Score");
    printf("---------|--------------|--------------|----------\n");
    
    for (int i = 0; i <= numTestes; i++) {
        float L = (float)i / numTestes; // L varia de 0.0 a 1.0
        
        float matrizAdj[N][N];
        den(matrizDist, matrizAdj, DEmin, DEmax, L);
        
        int tamanhos[N] = {0};
        int clusters[N][N];
        int tamanhosClusters[N];
        int numComponentes = encontrarComponentes(matrizAdj, tamanhos, clusters, tamanhosClusters);
        
        float score = calcularScore(numComponentes, tamanhos);
        
        // Exibe apenas resultados com 3 clusters ou próximos
        if (numComponentes >= TARGET_CLUSTERS - 1 && numComponentes <= TARGET_CLUSTERS + 1) {
            float desvio = calcularDesvioPadrao(tamanhos, numComponentes);
            printf("%-8.2f | %-12d | %-12.2f | %-8.2f", L, numComponentes, desvio, score);
            
            if (numComponentes == TARGET_CLUSTERS) {
                printf(" [OK]");
            }
            printf("\n");
        }
        
        // Atualiza melhor resultado
        if (score < melhorScore) {
            melhorScore = score;
            melhorL = L;
            melhorNumComponentes = numComponentes;
            
            // Salva os tamanhos e clusters
            for (int j = 0; j < numComponentes; j++) {
                melhorTamanhos[j] = tamanhos[j];
                melhorTamanhosClusters[j] = tamanhosClusters[j];
                for (int k = 0; k < tamanhosClusters[j]; k++) {
                    melhorClusters[j][k] = clusters[j][k];
                }
            }
            
            // Copia a matriz de adjacência
            for (int x = 0; x < N; x++) {
                for (int y = 0; y < N; y++) {
                    matrizAdjFinal[x][y] = matrizAdj[x][y];
                }
            }
        }
    }
    
    printf("\n>>> MELHOR RESULTADO:\n");
    printf("    L = %.3f\n", melhorL);
    printf("    Número de clusters: %d\n", melhorNumComponentes);
    printf("    Score: %.2f\n", melhorScore);
    printf("    Tamanhos dos clusters: ");
    for (int i = 0; i < melhorNumComponentes; i++) {
        printf("%d ", melhorTamanhos[i]);
    }
    printf("\n");
    
    return melhorL;
}

// --- VOTAÇÃO E ROTULAGEM (APÓS TREINAMENTO) ---

void votarERotularCluster(int membrosComponente[N], int numMembros, 
                          char rotulosOriginais[N][MAX_LABEL_LEN], 
                          char rotulosPreditos[N][MAX_LABEL_LEN],
                          int clusterID) {
    
    int contagemTipo1 = 0, contagemTipo2 = 0, contagemTipo3 = 0;

    for (int k = 0; k < numMembros; k++) {
        int no = membrosComponente[k];
        
        if (strcmp(rotulosOriginais[no], "Tipo1") == 0) { 
            contagemTipo1++;
        } else if (strcmp(rotulosOriginais[no], "Tipo2") == 0) {
            contagemTipo2++;
        } else if (strcmp(rotulosOriginais[no], "Tipo3") == 0) {
            contagemTipo3++;
        }
    }

    char *rotuloVencedor;
    
    if (contagemTipo1 >= contagemTipo2 && contagemTipo1 >= contagemTipo3) {
        rotuloVencedor = "Tipo1";
    } else if (contagemTipo2 >= contagemTipo1 && contagemTipo2 >= contagemTipo3) {
        rotuloVencedor = "Tipo2";
    } else {
        rotuloVencedor = "Tipo3";
    }
    
    for (int k = 0; k < numMembros; k++) {
        int no = membrosComponente[k];
        strcpy(rotulosPreditos[no], rotuloVencedor);
    }

    printf("  Cluster %d: %s (Votos: T1=%d, T2=%d, T3=%d | Total=%d)\n", 
           clusterID, rotuloVencedor, contagemTipo1, contagemTipo2, contagemTipo3, numMembros);
}

void aplicarRotulagem(int clusters[N][N], int tamanhosClusters[N], int numClusters,
                      char rotulosOriginais[N][MAX_LABEL_LEN], 
                      char rotulosPreditos[N][MAX_LABEL_LEN]) {
    
    printf("\n========================================\n");
    printf("  FASE 2: ROTULAGEM POR VOTAÇÃO\n");
    printf("========================================\n\n");
    
    for (int i = 0; i < N; i++) strcpy(rotulosPreditos[i], "");
    
    for (int i = 0; i < numClusters; i++) {
        votarERotularCluster(clusters[i], tamanhosClusters[i], 
                            rotulosOriginais, rotulosPreditos, i + 1);
    }
}

// --- CENTRO DE GRAVIDADE ---

void calcularCentrosDeGravidade(float matrizDados[N][4], char rotulosPreditos[N][MAX_LABEL_LEN]) {
    
    CentroDeGravidade cg[NUM_CLASSES] = {{{0, 0, 0, 0}, 0}, {{0, 0, 0, 0}, 0}, {{0, 0, 0, 0}, 0}};
    
    for (int i = 0; i < N; i++) {
        int index = -1;
        
        if (strcmp(rotulosPreditos[i], "Tipo1") == 0) index = 0;
        else if (strcmp(rotulosPreditos[i], "Tipo2") == 0) index = 1;
        else if (strcmp(rotulosPreditos[i], "Tipo3") == 0) index = 2;

        if (index != -1) {
            for (int j = 0; j < 4; j++) {
                cg[index].soma[j] += matrizDados[i][j];
            }
            cg[index].contagem++;
        }
    }

    printf("\n========================================\n");
    printf("  FASE 3: CENTROS DE GRAVIDADE\n");
    printf("========================================\n");
    
    char *rotulos[NUM_CLASSES] = {"Tipo1", "Tipo2", "Tipo3"};
    
    for (int i = 0; i < NUM_CLASSES; i++) {
        if (cg[i].contagem > 0) {
            printf("\n%s (%d amostras):\n", rotulos[i], cg[i].contagem);
            printf("  Centro: (");
            for (int j = 0; j < 4; j++) {
                printf("%.4f%s", cg[i].soma[j] / cg[i].contagem, (j < 3) ? ", " : "");
            }
            printf(")\n");
        } else {
            printf("\n%s: SEM AMOSTRAS\n", rotulos[i]);
        }
    }
}

// --- AVALIAÇÃO (MATRIZ DE CONFUSÃO E MÉTRICAS) ---

void calcularMetricas(char rotulosOriginais[N][MAX_LABEL_LEN], char rotulosPreditos[N][MAX_LABEL_LEN]) {
    
    int confusionMatrix[NUM_CLASSES][NUM_CLASSES] = {0};
    char *rotulos[NUM_CLASSES] = {"Tipo1", "Tipo2", "Tipo3"};
    int totalCorreto = 0;

    for (int i = 0; i < N; i++) {
        int actual = -1, predicted = -1;

        for (int c = 0; c < NUM_CLASSES; c++) {
            if (strcmp(rotulosOriginais[i], rotulos[c]) == 0) actual = c;
            if (strcmp(rotulosPreditos[i], rotulos[c]) == 0) predicted = c;
        }

        if (actual != -1 && predicted != -1) {
            confusionMatrix[actual][predicted]++;
            if (actual == predicted) totalCorreto++;
        }
    }

    printf("\n========================================\n");
    printf("  FASE 4: AVALIAÇÃO DO MODELO\n");
    printf("========================================\n");
    
    printf("\n--- Matriz de Confusão ---\n");
    printf("REAL\\PRED  |");
    for (int j = 0; j < NUM_CLASSES; j++) {
        printf(" %7s |", rotulos[j]);
    }
    printf(" TOTAL\n");
    printf("-----------|");
    for (int j = 0; j < NUM_CLASSES; j++) {
        printf("---------|");
    }
    printf("-------\n");

    for (int i = 0; i < NUM_CLASSES; i++) {
        printf("%9s |", rotulos[i]);
        int somaLinha = 0;
        for (int j = 0; j < NUM_CLASSES; j++) {
            printf(" %7d |", confusionMatrix[i][j]);
            somaLinha += confusionMatrix[i][j];
        }
        printf(" %5d\n", somaLinha);
    }

    float acc_global = (float)totalCorreto / N;
    
    printf("\n--- Acurácia Global ---\n");
    printf("Acurácia = (TP + TN) / (TP + FP + TN + FN)\n");
    printf("Acurácia = %d / %d = %.4f (%.2f%%)\n\n", totalCorreto, N, acc_global, acc_global * 100);

    printf("--- Métricas por Classe ---\n");

    float macro_precision = 0, macro_recall = 0, macro_f1 = 0;
    
    for (int c = 0; c < NUM_CLASSES; c++) {
        int TP = confusionMatrix[c][c];
        
        int FP = 0;
        for (int i = 0; i < NUM_CLASSES; i++) {
            if (i != c) FP += confusionMatrix[i][c];
        }

        int FN = 0;
        for (int j = 0; j < NUM_CLASSES; j++) {
            if (j != c) FN += confusionMatrix[c][j];
        }

        int TN = N - TP - FP - FN;
        
        float precision = (TP + FP) > 0 ? (float)TP / (TP + FP) : 0.0;
        float recall = (TP + FN) > 0 ? (float)TP / (TP + FN) : 0.0;
        float f1_score = (precision + recall) > 0.0001 ? 2.0 * (precision * recall) / (precision + recall) : 0.0;

        macro_precision += precision;
        macro_recall += recall;
        macro_f1 += f1_score;

        printf("\n%s:\n", rotulos[c]);
        printf("  TP=%d | FP=%d | FN=%d | TN=%d\n", TP, FP, FN, TN);
        printf("  Precision: %.4f (%.1f%%)\n", precision, precision * 100);
        printf("  Recall:    %.4f (%.1f%%)\n", recall, recall * 100);
        printf("  F1-Score:  %.4f\n", f1_score);
        printf("  Acurácia desta classe: %.4f (%.1f%%)\n", 
               (float)(TP + TN) / N, ((float)(TP + TN) / N) * 100);
    }
    
    printf("\n--- Médias Macro ---\n");
    printf("Macro-Precision: %.4f\n", macro_precision / NUM_CLASSES);
    printf("Macro-Recall:    %.4f\n", macro_recall / NUM_CLASSES);
    printf("Macro-F1:        %.4f\n", macro_f1 / NUM_CLASSES);
}

// --- CARREGAMENTO DE DADOS ---

int carregarDados(char *nomeArquivo, float matrizDados[N][4], char rotulosOriginais[N][MAX_LABEL_LEN]) {
    FILE *file = fopen(nomeArquivo, "r");
    if(file == NULL) return 0;

    char linha[256];
    int i = 0;
    
    while (i < N && fgets(linha, sizeof(linha), file)) {
        linha[strcspn(linha, "\r\n")] = 0;
        
        if (sscanf(linha, "%f,%f,%f,%f,%s", 
            &matrizDados[i][0], &matrizDados[i][1], 
            &matrizDados[i][2], &matrizDados[i][3], 
            rotulosOriginais[i]) == 5) {
            i++;
        }
    }
    
    fclose(file);
    return i;
}

// --- FUNÇÃO PRINCIPAL ---

int main() {
    float matrizDados[N][4];
    char rotulosOriginais[N][MAX_LABEL_LEN];
    char rotulosPreditos[N][MAX_LABEL_LEN];
    float matrizDist[N][N];
    float matrizAdjFinal[N][N];
    float DEmin, DEmax;
    
    int melhorTamanhos[N];
    int melhorClusters[N][N];
    int melhorTamanhosClusters[N];

    printf("========================================\n");
    printf(" CLUSTERING NÃO SUPERVISIONADO\n");
    printf(" Baseado em Componentes Conexos\n");
    printf("========================================\n\n");

    // Carrega dados
    printf("Carregando dataset...\n");
    int numAmostras = carregarDados("rotulada.txt", matrizDados, rotulosOriginais);
    if (numAmostras == 0) {
        numAmostras = carregarDados("rotulada.csv", matrizDados, rotulosOriginais);
    }
    
    if (numAmostras == 0) {
        printf("\nERRO: Não foi possível carregar os dados.\n");
        printf("Arquivo esperado: rotulada.txt ou rotulada.csv\n");
        printf("Formato: valor1,valor2,valor3,valor4,TipoX\n");
        return 1;
    }
    
    printf("✓ %d amostras carregadas com sucesso!\n", numAmostras);

    // Calcula todas as distâncias
    printf("Calculando matriz de distâncias...\n");
    calcAllDist(matrizDados, matrizDist, &DEmin, &DEmax);
    printf("✓ Matriz de distâncias calculada!\n");

    // FASE 1: TREINAMENTO (não supervisionado) - busca melhor L
    float melhorL = treinarClustering(matrizDist, DEmin, DEmax, matrizAdjFinal, 
                                       melhorTamanhos, melhorClusters, melhorTamanhosClusters);

    // FASE 2: ROTULAGEM (votação usando ground truth)
    aplicarRotulagem(melhorClusters, melhorTamanhosClusters, TARGET_CLUSTERS,
                     rotulosOriginais, rotulosPreditos);

    // FASE 3: CENTROS DE GRAVIDADE
    calcularCentrosDeGravidade(matrizDados, rotulosPreditos);

    // FASE 4: AVALIAÇÃO
    calcularMetricas(rotulosOriginais, rotulosPreditos);

    printf("\n========================================\n");
    printf("  ANÁLISE CONCLUÍDA\n");
    printf("========================================\n");

    return 0;
}

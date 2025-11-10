#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>

#define N 150 // Número de nós (amostras). Adequado para o dataset Iris.
#define MAX_LABEL_LEN 10 // Tamanho máximo do rótulo
#define NUM_CLASSES 3 // Temos 3 classes: Tipo 1, Tipo 2, Tipo 3
#define TARGET_CLUSTERS 3 // Número desejado de clusters

// Estrutura para o Centro de Gravidade
typedef struct {
    float soma[4];
    int contagem;
} CentroDeGravidade;

// Estrutura para armazenar resultado de clustering (não usado diretamente, mas a lógica usa variáveis equivalentes)
typedef struct {
    int numComponentes;
    int tamanhos[N];
    float L;
    float desvioPadrao;
    float score; // Métrica para avaliar qualidade do balanceamento
} ResultadoClustering;

// --- FUNÇÕES DE UTENSÍLIOS E CÁLCULO DE GRAFO ---

/**
 * @brief Transforma matriz de distancias em grafo binario (0 ou 1) baseado no limiar L.
 *
 * @param matrizDist Matriz de distâncias euclidianas.
 * @param matrizAdj Matriz de adjacência de saída (0 ou 1).
 * @param DEmin Distância mínima.
 * @param DEmax Distância máxima.
 * @param L Limiar normalizado (entre 0 e 1).
 */
void den(float matrizDist[N][N], float matrizAdj[N][N], float DEmin, float DEmax, float L) {
    int i, j;
    float den_val;
    
    // Range para normalização da distância
    float range = DEmax - DEmin;
    if (range == 0) range = 1.0; // Evita divisão por zero

    for (i = 0; i < N; i++) {
        for (j = 0; j < N; j++) {
            if (i == j) {
                matrizAdj[i][j] = 0;
                continue;
            }
            
            // Normaliza a distância para o range [0, 1]
            den_val = (matrizDist[i][j] - DEmin) / range;
            
            // Cria a aresta se a distância normalizada for menor ou igual ao limiar L
            matrizAdj[i][j] = (den_val <= L) ? 1 : 0;
        }
    }
}

/**
 * @brief Distancia Euclidiana entre dois vetores 4D.
 */
float calcDist(float x1, float x2, float x3, float x4, float y1, float y2, float y3, float y4) {
    return sqrt(pow(x1 - y1, 2) + pow(x2 - y2, 2) + pow(x3 - y3, 2) + pow(x4 - y4, 2));
}

/**
 * @brief Calcula todas as distancias e retorna DEmin e DEmax.
 */
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
    // Distância de um nó para ele mesmo é 0
    for(i=0; i<N; i++) matrizDist[i][i] = 0;
}

// --- FUNÇÕES DE CLUSTERING (COMPONENTES CONEXOS) ---

/**
 * @brief DFS adaptada para encontrar todos os membros de um componente conexo.
 *
 * @param v Nó atual.
 * @param visitado Array de nós visitados.
 * @param matrizAdj Matriz de adjacência do grafo binário.
 * @param tamanhoComponente Ponteiro para o tamanho do componente (acumulador).
 * @param membrosComponente Array para armazenar os índices dos nós do componente.
 * @param idxMembros Ponteiro para o índice atual no array membrosComponente.
 */
void DFS_Cluster(int v, int visitado[N], float matrizAdj[N][N], int *tamanhoComponente, int membrosComponente[N], int *idxMembros) {
    visitado[v] = 1;
    (*tamanhoComponente)++;
    membrosComponente[(*idxMembros)++] = v; 

    for (int i = 0; i < N; i++) {
        // Verifica se há aresta e se o nó vizinho não foi visitado
        if (matrizAdj[v][i] == 1 && !visitado[i]) {
            DFS_Cluster(i, visitado, matrizAdj, tamanhoComponente, membrosComponente, idxMembros);
        }
    }
}

/**
 * @brief Encontra todos os componentes conexos (clusters) no grafo.
 *
 * @param matrizAdj Matriz de adjacência do grafo.
 * @param tamanhos Array de saída com o tamanho de cada componente.
 * @param clusters Matriz de saída com os índices dos nós em cada cluster.
 * @param tamanhosClusters Array de saída com o número de membros de cada cluster.
 * @return int O número total de componentes conexos encontrados.
 */
int encontrarComponentes(float matrizAdj[N][N], int tamanhos[N], int clusters[N][N], int tamanhosClusters[N]) {
    int visitado[N] = {0};
    int numComponentes = 0;

    for (int i = 0; i < N; i++) {
        if (!visitado[i]) {
            int tamanhoComponente = 0;
            int membrosComponente[N];
            int idxMembros = 0; // Índice para controle de preenchimento do array de membros

            // Inicia a busca em profundidade para encontrar um novo componente
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

/**
 * @brief Calcula desvio padrão dos tamanhos dos clusters.
 */
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

/**
 * @brief Função de score para avaliar qualidade do clustering.
 * Prioriza obter exatamente TARGET_CLUSTERS (3) com tamanhos similares.
 */
float calcularScore(int numComponentes, int tamanhos[N]) {
    if (numComponentes != TARGET_CLUSTERS) {
        // Penalização severa se não tiver exatamente 3 clusters (prioridade máxima)
        // A penalização é baseada no quão longe de 3 está.
        return FLT_MAX - (100.0 * (float)abs(numComponentes - TARGET_CLUSTERS));
    }
    
    // Queremos minimizar o desvio padrão dos tamanhos
    float desvioPadrao = calcularDesvioPadrao(tamanhos, numComponentes);
    
    // Tamanho ideal por cluster (N/3)
    float tamanhoIdeal = (float)N / TARGET_CLUSTERS;
    
    // Penaliza clusters muito diferentes do tamanho ideal (penalização de balanceamento)
    float penalizacao = 0;
    for (int i = 0; i < numComponentes; i++) {
        penalizacao += fabs(tamanhos[i] - tamanhoIdeal);
    }
    
    // O score é o desvio padrão (que deve ser minimizado) + uma penalização por desbalanceamento
    // Queremos minimizar este valor.
    return desvioPadrao + penalizacao * 0.1;
}

// --- TREINAMENTO: BUSCA DO MELHOR LIMIAR L ---

/**
 * @brief Realiza a busca em grade para encontrar o melhor limiar L
 * que produz os clusters mais balanceados e com o número desejado.
 *
 * @return float O melhor valor de L encontrado.
 */
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
    int numTestes = 500; // Número de valores de L para testar
    
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
        
        // Exibe apenas resultados com 3 clusters ou próximos para não poluir a saída
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
            
            // Copia a matriz de adjacência (o grafo final)
            for (int x = 0; x < N; x++) {
                for (int y = 0; y < N; y++) {
                    matrizAdjFinal[x][y] = matrizAdj[x][y];
                }
            }
        }
    }
    
    printf("\n>>> MELHOR RESULTADO:\n");
    printf("     L = %.3f\n", melhorL);
    printf("     Número de clusters: %d\n", melhorNumComponentes);
    printf("     Score: %.2f\n", melhorScore);
    printf("     Tamanhos dos clusters: ");
    for (int i = 0; i < melhorNumComponentes; i++) {
        printf("%d ", melhorTamanhos[i]);
    }
    printf("\n");
    
    return melhorL;
}

// --- VOTAÇÃO E ROTULAGEM (APÓS TREINAMENTO) ---

/**
 * @brief Vota e atribui o rótulo majoritário do ground truth a todos os membros do cluster.
 */
void votarERotularCluster(int membrosComponente[N], int numMembros, 
                          char rotulosOriginais[N][MAX_LABEL_LEN], 
                          char rotulosPreditos[N][MAX_LABEL_LEN],
                          int clusterID) {
    
    int contagemTipo1 = 0, contagemTipo2 = 0, contagemTipo3 = 0;

    for (int k = 0; k < numMembros; k++) {
        int no = membrosComponente[k];
        
        if (strcmp(rotulosOriginais[no], "Tipo 1") == 0) { 
            contagemTipo1++;
        } else if (strcmp(rotulosOriginais[no], "Tipo 2") == 0) {
            contagemTipo2++;
        } else if (strcmp(rotulosOriginais[no], "Tipo 3") == 0) {
            contagemTipo3++;
        }
    }

    char *rotuloVencedor;
    
    // Encontra o rótulo majoritário (regra de desempate: Tipo 1 > Tipo 2 > Tipo 3)
    if (contagemTipo1 >= contagemTipo2 && contagemTipo1 >= contagemTipo3) {
        rotuloVencedor = "Tipo 1";
    } else if (contagemTipo2 >= contagemTipo1 && contagemTipo2 >= contagemTipo3) {
        rotuloVencedor = "Tipo 2";
    } else {
        rotuloVencedor = "Tipo 3";
    }
    
    // Atribui o rótulo vencedor a todos os membros do cluster
    for (int k = 0; k < numMembros; k++) {
        int no = membrosComponente[k];
        strcpy(rotulosPreditos[no], rotuloVencedor);
    }

    printf("  Cluster %d: %s (Votos: T1=%d, T2=%d, T3=%d | Total=%d)\n", 
           clusterID, rotuloVencedor, contagemTipo1, contagemTipo2, contagemTipo3, numMembros);
}

/**
 * @brief Aplica a votação e rotulagem aos clusters encontrados.
 */
void aplicarRotulagem(int clusters[N][N], int tamanhosClusters[N], int numClusters,
                      char rotulosOriginais[N][MAX_LABEL_LEN], 
                      char rotulosPreditos[N][MAX_LABEL_LEN]) {
    
    printf("\n========================================\n");
    printf("  FASE 2: ROTULAGEM POR VOTAÇÃO\n");
    printf("========================================\n\n");
    
    // Limpa rótulos preditos antes de iniciar
    for (int i = 0; i < N; i++) strcpy(rotulosPreditos[i], "");
    
    // Rótula apenas os primeiros TARGET_CLUSTERS clusters
    int clustersToLabel = (numClusters < TARGET_CLUSTERS) ? numClusters : TARGET_CLUSTERS;

    for (int i = 0; i < clustersToLabel; i++) {
        votarERotularCluster(clusters[i], tamanhosClusters[i], 
                             rotulosOriginais, rotulosPreditos, i + 1);
    }
    
    // Se o número de clusters encontrados for diferente de TARGET_CLUSTERS,
    // o resultado do clustering não atendeu ao critério ideal de balanceamento
    if (numClusters != TARGET_CLUSTERS) {
        printf("\nAtenção: O número de clusters encontrados (%d) não foi o alvo (%d).\n", numClusters, TARGET_CLUSTERS);
        printf("A rotulagem foi aplicada aos %d maiores clusters.\n", clustersToLabel);
    }
}

// --- CENTRO DE GRAVIDADE ---

/**
 * @brief Calcula os Centros de Gravidade (médias) para cada classe predita.
 */
void calcularCentrosDeGravidade(float matrizDados[N][4], char rotulosPreditos[N][MAX_LABEL_LEN]) {
    
    // Inicializa os Centros de Gravidade
    CentroDeGravidade cg[NUM_CLASSES] = {{{0, 0, 0, 0}, 0}, {{0, 0, 0, 0}, 0}, {{0, 0, 0, 0}, 0}};
    
    for (int i = 0; i < N; i++) {
        int index = -1;
        
        // Mapeia o rótulo predito para o índice (0, 1, 2)
        if (strcmp(rotulosPreditos[i], "Tipo 1") == 0) index = 0;
        else if (strcmp(rotulosPreditos[i], "Tipo 2") == 0) index = 1;
        else if (strcmp(rotulosPreditos[i], "Tipo 3") == 0) index = 2;

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
    
    char *rotulos[NUM_CLASSES] = {"Tipo 1", "Tipo 2", "Tipo 3"};
    
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

/**
 * @brief Calcula e exibe a Matriz de Confusão e as métricas de desempenho.
 */
void calcularMetricas(char rotulosOriginais[N][MAX_LABEL_LEN], char rotulosPreditos[N][MAX_LABEL_LEN]) {
    
    int confusionMatrix[NUM_CLASSES][NUM_CLASSES] = {0};
    char *rotulos[NUM_CLASSES] = {"Tipo 1", "Tipo 2", "Tipo 3"};
    int totalCorreto = 0;

    for (int i = 0; i < N; i++) {
        int actual = -1, predicted = -1;

        // Mapeia rótulos para índices (0, 1, 2)
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
        int TP = confusionMatrix[c][c]; // Verdadeiros Positivos
        
        int FP = 0; // Falsos Positivos (Predito como 'c', mas era outra classe)
        for (int i = 0; i < NUM_CLASSES; i++) {
            if (i != c) FP += confusionMatrix[i][c];
        }

        int FN = 0; // Falsos Negativos (Realmente 'c', mas predito como outra classe)
        for (int j = 0; j < NUM_CLASSES; j++) {
            if (j != c) FN += confusionMatrix[c][j];
        }

        // O TN é tudo o que não é TP, FP ou FN
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

/**
 * @brief Carrega dados do arquivo CSV/TXT.
 *
 * @param nomeArquivo Nome do arquivo a ser lido.
 * @param matrizDados Matriz de saída com as features.
 * @param rotulosOriginais Matriz de saída com os rótulos.
 * @return int O número de amostras lidas.
 */
int carregarDados(char *nomeArquivo, float matrizDados[N][4], char rotulosOriginais[N][MAX_LABEL_LEN]) {
    FILE *file = fopen(nomeArquivo, "r");
    if(file == NULL) return 0;

    char linha[256];
    int i = 0;
    
    while (i < N && fgets(linha, sizeof(linha), file)) {
        // Remove quebras de linha e retornos de carro
        linha[strcspn(linha, "\r\n")] = 0;
        
        // CORREÇÃO: Usar %9[^\r\n] ao invés de %s para ler a string do rótulo,
        // pois %s para no espaço. Isso garante que rótulos como "Tipo 1" sejam lidos
        // corretamente, resolvendo o problema de 150 casos incorretos.
        if (sscanf(linha, "%f,%f,%f,%f,%9[^\r\n]", 
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
    // Tenta carregar rotulada.txt e depois rotulada.csv (para compatibilidade)
    int numAmostras = carregarDados("rotulada.txt", matrizDados, rotulosOriginais);
    if (numAmostras == 0) {
        numAmostras = carregarDados("rotulada.csv", matrizDados, rotulosOriginais);
    }
    
    if (numAmostras == 0 || numAmostras != N) {
        printf("\nERRO: Não foi possível carregar os dados ou o número de amostras é diferente de N (%d).\n", N);
        printf("Arquivo esperado: rotulada.txt ou rotulada.csv\n");
        printf("Formato: valor1,valor2,valor3,valor4,Tipo X\n");
        return 1;
    }
    
    printf("✓ %d amostras carregadas com sucesso!\n", numAmostras);

    // Calcula todas as distâncias
    printf("Calculando matriz de distâncias...\n");
    calcAllDist(matrizDados, matrizDist, &DEmin, &DEmax);
    printf("✓ Matriz de distâncias calculada! (DEmin=%.4f, DEmax=%.4f)\n", DEmin, DEmax);

    // FASE 1: TREINAMENTO (não supervisionado) - busca melhor L
    float melhorL = treinarClustering(matrizDist, DEmin, DEmax, matrizAdjFinal, 
                                     melhorTamanhos, melhorClusters, melhorTamanhosClusters);

    // Recalcula o número de clusters encontrados com o melhor L
    int numClustersFinais = 0;
    for (int i = 0; i < N; i++) {
        if (melhorTamanhos[i] > 0) numClustersFinais++;
    }

    // FASE 2: ROTULAGEM (votação usando ground truth)
    // Passamos o TARGET_CLUSTERS para aplicarRotulagem, mas ela usa numClustersFinais 
    // ou o número de clusters ideal, dependendo do score.
    aplicarRotulagem(melhorClusters, melhorTamanhosClusters, numClustersFinais,
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

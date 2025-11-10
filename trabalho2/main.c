#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <float.h>

#define N 150 // Número de nós (amostras)
#define MAX_LABEL_LEN 10 // Tamanho máximo do rótulo
#define NUM_CLASSES 3 // Temos 3 classes: Tipo1, Tipo2, Tipo3

// Estrutura para o Centro de Gravidade
typedef struct {
    float soma[4];
    int contagem;
} CentroDeGravidade;

// Estrutura para armazenar as métricas de avaliação por classe
typedef struct {
    float accuracy;
    float precision;
    float recall;
    float f1_score;
} Metricas;

// --- FUNÇÕES DE UTENSÍLIOS E CÁLCULO DE GRAFO ---

// Funcao que transforma matriz de distancias em grafo binario (0 ou 1)
void den(float matrizDist[N][N], float matrizAdj[N][N], float DEmin, float DEmax, float L) {
    int i, j;
    float den_val;
    
    // Evita divisão por zero
    float range = DEmax - DEmin;
    if (range == 0) range = 1.0;

    for (i = 0; i < N; i++) {
        for (j = 0; j < N; j++) {
            if (i == j) {
                matrizAdj[i][j] = 0; // Sem laços (arestas para si mesmo)
                continue;
            }
            den_val = (matrizDist[i][j] - DEmin) / range;
            matrizAdj[i][j] = (den_val <= L) ? 1 : 0;
        }
    }
    printf("DEmin: %.4f, DEmax: %.4f\n", DEmin, DEmax);
}

// Distancia Euclidiana entre dois vetores 4D
float calcDist(float x1, float x2, float x3, float x4, float y1, float y2, float y3, float y4) {
    return sqrt(pow(x1 - y1, 2) + pow(x2 - y2, 2) + pow(x3 - y3, 2) + pow(x4 - y4, 2));
}

// Calcula todas as distancias e aplica o limiar
void calcAllDistAndAdj(float matrizDados[N][4], float matrizAdjFinal[N][N], float L) {
    int i, j;
    float matrizDistancias[N][N]; // Matriz temporária para as distâncias

    // FLT_MAX é o maior numero possivel para float
    float DEmin = FLT_MAX, DEmax = 0, dist;

    for(i = 0; i < N; i++) {
        for(j = i + 1; j < N; j++) { // Otimização para calcular cada par uma vez
            dist = calcDist(matrizDados[i][0], matrizDados[i][1], matrizDados[i][2], matrizDados[i][3],
                            matrizDados[j][0], matrizDados[j][1], matrizDados[j][2], matrizDados[j][3]);
            
            matrizDistancias[i][j] = dist;
            matrizDistancias[j][i] = dist; // Matriz simétrica

            if(dist < DEmin) DEmin = dist;
            if(dist > DEmax) DEmax = dist;
        }
    }
    for(i=0; i<N; i++) matrizDistancias[i][i] = 0; // Preenche a diagonal, elemento para si

    // Agora chama 'den' para popular a matriz de adjacência final
    den(matrizDistancias, matrizAdjFinal, DEmin, DEmax, L);
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

// Lê o grafo salvo
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

    // Ignora cabecalho (origem,destino)
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


// --- FUNÇÕES DE CLUSTERING (COMPONENTES CONEXOS E VOTAÇÃO) ---

// DFS adaptada para registrar membros do componente
void DFS_Cluster(int v, int visitado[N], float matrizAdj[N][N], int *tamanhoComponente, int membrosComponente[N], int *idxMembros) {
    visitado[v] = 1;
    (*tamanhoComponente)++;
    
    // Adiciona o nó atual à lista de membros do componente
    membrosComponente[(*idxMembros)++] = v; 

    for (int i = 0; i < N; i++) {
        // Verifica a aresta e se o nó ainda não foi visitado
        if (matrizAdj[v][i] == 1 && !visitado[i]) {
            DFS_Cluster(i, visitado, matrizAdj, tamanhoComponente, membrosComponente, idxMembros);
        }
    }
}

// Função auxiliar para calcular a moda (votação) e rotular os nós do cluster
void votarERotular(int membrosComponente[N], int numMembros, char rotulosOriginais[N][MAX_LABEL_LEN], char rotulosPreditos[N][MAX_LABEL_LEN]) {
    
    int contagemTipo1 = 0;
    int contagemTipo2 = 0;
    int contagemTipo3 = 0;

    for (int k = 0; k < numMembros; k++) {
        int no = membrosComponente[k];
        
        // Contagem dos votos baseada no rótulo original (Ground Truth)
        if (strcmp(rotulosOriginais[no], "Tipo1") == 0) { 
            contagemTipo1++;
        } else if (strcmp(rotulosOriginais[no], "Tipo2") == 0) {
            contagemTipo2++;
        } else if (strcmp(rotulosOriginais[no], "Tipo3") == 0) {
            contagemTipo3++;
        }
    }

    char *rotuloVencedor;
    
    // Lógica da Votação:
    if (contagemTipo1 >= contagemTipo2 && contagemTipo1 >= contagemTipo3) {
        rotuloVencedor = "Tipo1";
    } else if (contagemTipo2 >= contagemTipo1 && contagemTipo2 >= contagemTipo3) {
        rotuloVencedor = "Tipo2";
    } else {
        rotuloVencedor = "Tipo3";
    }
    
    // Atribui o rótulo vencedor a TODOS os membros do componente (PREDICTED VALUE)
    for (int k = 0; k < numMembros; k++) {
        int no = membrosComponente[k];
        strcpy(rotulosPreditos[no], rotuloVencedor);
    }

    printf(" -> Rótulo Vencedor: %s (Votos: T1=%d, T2=%d, T3=%d)\n", rotuloVencedor, contagemTipo1, contagemTipo2, contagemTipo3);
}


// Encontra e mostra os componentes conexos, realiza a votação e rotula os nós
void encontrarComponentesConexos(float matrizAdj[N][N], char rotulosOriginais[N][MAX_LABEL_LEN], char rotulosPreditos[N][MAX_LABEL_LEN]) {
    int visitado[N] = {0};
    int numComponentes = 0;
    int tamanhos[N] = {0};
    int ocorrenciasTamanhos[N + 1] = {0};

    // Zera os rótulos preditos inicialmente
    for(int i=0; i<N; i++) strcpy(rotulosPreditos[i], "");


    printf("\n--- Determinação de Componentes Conexos ---\n");
    for (int i = 0; i < N; i++) {
        if (!visitado[i]) {
            int tamanhoComponente = 0;
            int membrosComponente[N]; // Armazena os IDs dos nós neste componente
            int idxMembros = 0;

            printf("Componente %d (iniciando no nó %d).", numComponentes + 1, i);
            
            // Chama a DFS adaptada
            DFS_Cluster(i, visitado, matrizAdj, &tamanhoComponente, membrosComponente, &idxMembros);
            
            // Realiza a votação para determinar o rótulo do cluster
            votarERotular(membrosComponente, idxMembros, rotulosOriginais, rotulosPreditos);

            // Atualiza estatísticas (histograma)
            tamanhos[numComponentes] = tamanhoComponente;
            ocorrenciasTamanhos[tamanhoComponente]++;
            numComponentes++;
        }
    }

    printf("\nNumero total de componentes conexos: %d\n", numComponentes);

    printf("\nResumo (Histograma de Componentes):\n");
    for (int i = 1; i <= N; i++) {
        if (ocorrenciasTamanhos[i] > 0) {
            printf("%d componente(s) de tamanho %d\n", ocorrenciasTamanhos[i], i);
        }
    }
}


// --- FUNÇÃO DE CENTRO DE GRAVIDADE ---

// Calcula e exibe o centro de gravidade (média) dos 3 agrupamentos finais
void calcularCentrosDeGravidade(float matrizDados[N][4], char rotulosPreditos[N][MAX_LABEL_LEN]) {
    
    // Arrays para representar os 3 centros de gravidade
    CentroDeGravidade cg[NUM_CLASSES] = {{{0, 0, 0, 0}, 0}, {{0, 0, 0, 0}, 0}, {{0, 0, 0, 0}, 0}};
    
    // Agregação dos dados
    for (int i = 0; i < N; i++) {
        int index = -1;
        
        if (strcmp(rotulosPreditos[i], "Tipo1") == 0) {
            index = 0;
        } else if (strcmp(rotulosPreditos[i], "Tipo2") == 0) {
            index = 1;
        } else if (strcmp(rotulosPreditos[i], "Tipo3") == 0) {
            index = 2;
        }

        if (index != -1) {
            for (int j = 0; j < 4; j++) {
                cg[index].soma[j] += matrizDados[i][j];
            }
            cg[index].contagem++;
        }
    }

    printf("\n--- Cálculo do Centro de Gravidade ---\n");
    
    // Cálculo da média e exibição
    for (int i = 0; i < NUM_CLASSES; i++) {
        char rotulo[MAX_LABEL_LEN];
        if (i == 0) strcpy(rotulo, "Tipo1");
        if (i == 1) strcpy(rotulo, "Tipo2");
        if (i == 2) strcpy(rotulo, "Tipo3");

        if (cg[i].contagem > 0) {
            printf("Centro de Gravidade do Grupo %s (%d membros):\n", rotulo, cg[i].contagem);
            printf("  Coordenadas: (");
            for (int j = 0; j < 4; j++) {
                printf("%.4f%s", cg[i].soma[j] / cg[i].contagem, (j < 3) ? ", " : "");
            }
            printf(")\n");
        } else {
            printf("Grupo %s não possui membros.\n", rotulo);
        }
    }
}


// --- FUNÇÕES DE AVALIAÇÃO (MATRIZ DE CONFUSÃO E MÉTRICAS) ---

// Calcula e exibe a Matriz de Confusão e as Métricas de Qualidade
void calcularMetricas(char rotulosOriginais[N][MAX_LABEL_LEN], char rotulosPreditos[N][MAX_LABEL_LEN]) {
    // Matriz de Confusão (3x3): Linha=Actual (Original), Coluna=Predicted (Predito)
    // Indices: 0=Tipo1, 1=Tipo2, 2=Tipo3
    int confusionMatrix[NUM_CLASSES][NUM_CLASSES] = {0};
    char *rotulos[NUM_CLASSES] = {"Tipo1", "Tipo2", "Tipo3"};
    int totalCorreto = 0;

    // 1. Popula a Matriz de Confusão
    for (int i = 0; i < N; i++) {
        int actual = -1, predicted = -1;

        // Mapeia rótulos originais para índices
        for (int c = 0; c < NUM_CLASSES; c++) {
            if (strcmp(rotulosOriginais[i], rotulos[c]) == 0) {
                actual = c;
            }
            if (strcmp(rotulosPreditos[i], rotulos[c]) == 0) {
                predicted = c;
            }
        }

        if (actual != -1 && predicted != -1) {
            confusionMatrix[actual][predicted]++;
            if (actual == predicted) {
                totalCorreto++;
            }
        }
    }

    printf("\n--- Avaliação de Agrupamento (Matriz de Confusão) ---\n");
    
    // 2. Exibe a Matriz de Confusão
    printf("Matriz de Confusão:\n");
    printf("ACTUAL\\PRED |");
    for (int j = 0; j < NUM_CLASSES; j++) {
        printf(" %7s |", rotulos[j]);
    }
    printf("\n");
    printf("-------------|");
    for (int j = 0; j < NUM_CLASSES; j++) {
        printf("---------|");
    }
    printf("\n");

    for (int i = 0; i < NUM_CLASSES; i++) {
        printf("%9s  |", rotulos[i]);
        for (int j = 0; j < NUM_CLASSES; j++) {
            printf(" %7d |", confusionMatrix[i][j]);
        }
        printf("\n");
    }

    // 3. Cálculo das Métricas (Acurácia Global, Precision, Recall, F1 por classe)
    float acc_global = (float)totalCorreto / N;
    printf("\n--- Métricas de Qualidade ---\n");
    printf("Acurácia Global (Total de Acertos / Total de Amostras): %.4f\n", acc_global);

    printf("\nMétricas por Classe:\n");

    for (int c = 0; c < NUM_CLASSES; c++) {
        // TP (True Positive): acertos na classe 'c'
        int TP = confusionMatrix[c][c];
        
        // FP (False Positive): previu 'c', mas era outra classe (soma da coluna 'c' exceto TP)
        int FP = 0;
        for (int i = 0; i < NUM_CLASSES; i++) {
            if (i != c) {
                FP += confusionMatrix[i][c];
            }
        }

        // FN (False Negative): era 'c', mas previu outra classe (soma da linha 'c' exceto TP)
        int FN = 0;
        for (int j = 0; j < NUM_CLASSES; j++) {
            if (j != c) {
                FN += confusionMatrix[c][j];
            }
        }

        // TN (True Negative): não era 'c' e não previu 'c' (soma de todos os outros)
        int TN = N - TP - FP - FN;
        
        // Métrica Precision: TP / (TP + FP)
        float precision = (TP + FP) > 0 ? (float)TP / (TP + FP) : 0.0;
        
        // Métrica Recall: TP / (TP + FN)
        float recall = (TP + FN) > 0 ? (float)TP / (TP + FN) : 0.0;
        
        // Métrica F1-Score: 2 * (Precision * Recall) / (Precision + Recall)
        float f1_score = (precision + recall) > 0.0001 ? 2.0 * (precision * recall) / (precision + recall) : 0.0;

        printf("  %s:\n", rotulos[c]);
        printf("    TP: %-3d | FP: %-3d | FN: %-3d | TN: %-3d\n", TP, FP, FN, TN);
        printf("    Precision: %.4f | Recall: %.4f | F1-Score: %.4f\n", precision, recall, f1_score);
    }
}


// --- FUNÇÃO PRINCIPAL ---

int main() {
    FILE *file;
    char linha[256];
    int escolha, i = 0, j;
    float L;
    float matrizFinal[N][N];
    float matrizDados[N][4];
    char rotulosOriginais[N][MAX_LABEL_LEN];
    char rotulosPreditos[N][MAX_LABEL_LEN];

    printf("Qual o L?\nDigite 1 para 0.0\nDigite 2 para 0.3\nDigite 3 para 0.5\nDigite 4 para 0.9\n");
    scanf("%d", &escolha);

    switch(escolha) {
    case 1:
        L = 0.0;
        break;
    case 2:
        L = 0.3;
        break;
    case 3:
        L = 0.5;
        break;
    case 4:
        L = 0.9;
        break;
    default:
        printf("Escolha invalida.\n");
        return 1;
    }

    printf("Valor de L selecionado: %.1f\n\n", L);

    // Tenta carregar grafo compactado
    int grafoCarregado = carregarMatrizCSV(matrizFinal, L);

    // Se nao encontrou o grafo, calcula e salva novo arquivo
    if (!grafoCarregado) {
        printf("Grafo nao encontrado. Carregando dataset e gerando grafo...\n\n");

        file = fopen("rotulada.csv", "r");
        if(file == NULL) {
            printf("Erro ao abrir o arquivo do dataset 'rotulada.csv'.\n");
            return 1;
        }
        i=0;
        // Leitura do dataset (coordenadas + rótulo original)
        while (i < N && fgets(linha, sizeof(linha), file)) {
            
            // Certifique-se de que a linha possui 4 floats e 1 string
            if (sscanf(linha, "%f,%f,%f,%f,%s", 
                &matrizDados[i][0], &matrizDados[i][1], 
                &matrizDados[i][2], &matrizDados[i][3], 
                rotulosOriginais[i]) == 5) {
                
                i++;
            }
        }
        printf("Leitura concluida. Total de casos lidos: %d\n", i);
        fclose(file);

        if (i < N) {
             printf("AVISO: Esperado %d amostras, lido apenas %d. Ajustando N.\n", N, i);
             // Para N fixo, o programa continuará com N=150, mas processará apenas os 'i' dados lidos.
        }

        // 1. Calcula todas as distâncias e gera a matriz de adjacência (Grafo)
        calcAllDistAndAdj(matrizDados, matrizFinal, L);
        
        // 2. Salva o grafo para reuso
        salvarMatrizCSV(matrizFinal, L);
    }
    
    // --- EXECUÇÃO DO CLUSTERING E AVALIAÇÃO ---

    // 1. Estudo sobre a distribuição, rotulagem por votação e preenchimento de rotulosPreditos
    encontrarComponentesConexos(matrizFinal, rotulosOriginais, rotulosPreditos);

    // 2. Cálculo do centro de gravidade (média das coordenadas)
    calcularCentrosDeGravidade(matrizDados, rotulosPreditos);

    // 3. Avaliação da qualidade do agrupamento
    calcularMetricas(rotulosOriginais, rotulosPreditos);

    return 0;
}
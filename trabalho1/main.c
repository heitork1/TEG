#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define N 150

void den(float matrizFinal[N][N], float DEmin, float DEmax, float L){
    int i;
    int j;
    float den;
    for (i=0; i < N; i++){
        for(j=0; j < N; j++){
            if(i == j){
                continue;
            }
            den = (matrizFinal[i][j] - DEmin)/(DEmax - DEmin); 
            if(den <= L ){
                matrizFinal[i][j] = 1;
            } else {
                matrizFinal[i][j] = 0;
            }
        }
    }
    printf("DEmin: %f, DEmax: %f", DEmin, DEmax);
}

float calcDist(float  x1 ,float x2, float  x3 ,float x4, float  y1 ,float y2, float  y3 ,float y4 ){
    float dist = sqrt(pow(x1-y1, 2) + pow(x2-y2, 2) + pow(x3-y3, 2) + pow(x4-y4, 2));
    return (dist);
}

void calcAllDist(float matriz[N][4], float matrizFinal[N][N], float L){
    int i;
    int j;
    float DEmin = 100; //valor arbitrário grande
    float DEmax = 0;
    float dist;
    for(i = 0; i < N; i++){
        for(j=0; j<N; j++){
            if(i == j){
                matrizFinal[i][j] = 0;
                continue;
            }
            dist = calcDist(matriz[i][0], matriz[i][1], matriz[i][2], matriz[i][3], matriz[j][0], matriz[j][1], matriz[j][2], matriz[j][3]);
            matrizFinal[i][j] = dist;
            if(dist < DEmin){
                DEmin = dist;
            }
            if(dist > DEmax){
                DEmax = dist;
            }
        }
    }
    
    den(matrizFinal, DEmin, DEmax, L);
}

int main(){
    FILE * file; 
    char linha[256];
    int escolha, i=0, j;
    float L;
    float matriz[N][4];
    float matrizFinal[N][N];
    
    file = fopen("my_dataset.txt", "r");
    if(file == NULL){
        printf("Erro ao abrir o arquivo. \n");
        return 1;
    }
    printf("Qual o L?\nDigite 1 para 0.0\nDigite 2 para 0.3\nDigite 3 para 0.5\nDigite 4 para 0.9\n");
    scanf("%d", &escolha);
    
    switch(escolha){
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
            L= 0.9;
            break;
        default:
            printf("Escolha não definida");
    }
    
    printf("%d\n", escolha);
    printf("%.1f\n", L);
    
    while (fgets(linha, sizeof(linha), file)){
        j=0;
        matriz[i][j] = atof(strtok(linha, ","));//pega primeira coluna e converte para numero
        // printf("%f\n", matriz[i][j]);
        // printf("%s\n", strtok(linha, ","));
        for(j = 1; j < 4; j++){
            matriz[i][j] = atof(strtok(NULL, ","));
        }
        i++;
    }
    for(i = 0; i < N; i++){
        printf("-------------------\n");
        for(j=0; j<4; j++){
            printf("%.2f\n", matriz[i][j]);
        }
    }
    
    calcAllDist(matriz, matrizFinal, L);
    
    printf("\nMatriz de adjacencias:\n");
    for(i = 0; i < N; i++){
        printf("| ");
        for(j=0; j<N; j++){
            printf("%.f ", matrizFinal[i][j]);
        }
        printf("|\n");
        printf("Fim da linha\n");
    }
    
    fclose(file);

    return 0;
}

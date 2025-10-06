#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

void den(float matrizFinal[150][150], float DEmin, float DEmax, float L){
    int i;
    int j;
    float den;
    for (i=0; i < 150; i++){
        for(j=0; j < 150; j++){
            den = (matrizFinal[i][j] - DEmin)/(DEmax - DEmin); 
            if(den <= L ){
                matrizFinal[i][j] = 1;
            } else {
                matrizFinal[i][j] = 0;
            }
        }
    }
}

float calcDist(float  x1 ,float x2, float  x3 ,float x4, float  y1 ,float y2, float  y3 ,float y4 ){
    float dist = sqrt(pow(x1-y1, 2) + pow(x2-y2, 2) + pow(x3-y3, 2) + pow(x3-y3, 2));
    return (dist);
}

void calcAllDist(float matriz[150][4], float matrizFinal[150][150]){
    int i;
    int j;
    float DEmin = 100; //valor arbitrário grande
    float DEmax = 0;
    float dist;
    for(i = 0; i < 150; i++){
        for(j=0; j<150; j++){
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
}

//para cada linha k, vou passar para calDist os 4 atributos de K + 


int main(){
    FILE * file; 
    char linha[256];
    int escolha;
    float L;
    float matriz[150][4];
    float matrizFinal[150][150];
    
    file = fopen("my_dataset.txt", "r");
    if(file == NULL){
        printf("Erro ao abrir o arquivo. \n");
        return 1;
    }
    printf("Qual o L?\nDigite 1 para 0.0\nDigite 2 para 0.3\nDigite 3 para 0.5\n");
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
    printf("%.1f", L);
    
    while (fgets(linha, sizeof(linha), file)){
        
        printf("%s\n", strtok(linha, ","));
        int i;
        for(i = 0; i < 3; i++){
            printf("%s\n", strtok(NULL, ","));
        }
        
    }
    
    fclose(file);
    float teste = calcDist(5.1,3.5,1.4,.2,4.9,3,1.4,.2);
    printf("%f\n", teste);

    return 0;
}

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

float calcDist(float  x1 ,float x2, float  x3 ,float x4, float  y1 ,float y2, float  y3 ,float y4 ){
    float dist = sqrt(pow(x1-y1, 2) + pow(x2-y2, 2) + pow(x3-y3, 2) + pow(x3-y3, 2));
    return (dist);
}

//função que calcula o DEN e chama a função que cacula a distancia

int main(){
    FILE * file; 
    char linha[256];

    file = fopen("C:/Users/glize/Documents/TEG/IrisDataset.csv", "r");
    if(file == NULL){
        printf("Erro ao abrir o arquivo. \n");
        return 1;
    }
    while (fgets(linha, sizeof(linha), file)){
        // printf("%s", linha);
    }

    fclose(file);
    float teste = calcDist(5.1,3.5,1.4,.2,4.9,3,1.4,.2);
    printf("%f\n", teste);

    return 0;
}


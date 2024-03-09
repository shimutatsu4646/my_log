#include <stdio.h>

void encrypt(char* flag){
    for(int i = 0; flag[i] != '\0'; i++){
        flag[i] = flag[i] ^ 0x10;
    }
}

int main(){
    char flag[100];
    printf("Input Flag: ");
    scanf("%s", flag);
    encrypt(flag);
    printf("Encrypted Flag: %s\n", flag);
    return 0;
}


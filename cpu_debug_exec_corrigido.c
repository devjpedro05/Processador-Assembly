#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MEM_TAM 1024

void carregar_programa(unsigned char* memoria, const char* nome_arquivo) {
    FILE* f = fopen(nome_arquivo, "r");
    if (!f) {
        perror("Erro ao abrir o programa");
        exit(1);
    }

    char linha[256];
    int pos = 0;

    while (fgets(linha, sizeof(linha), f)) {
        char* tok = strtok(linha, " \t\n\r");
        while (tok && pos < MEM_TAM) {
            int byte;
            if (sscanf(tok, "%x", &byte) == 1) {
                memoria[pos++] = (unsigned char)byte;
            }
            tok = strtok(NULL, " \t\n\r");
        }
    }

    fclose(f);
    printf("Programa carregado. Bytes carregados: %d\n", pos);
}

extern void _start_cycle_cpu(void* cpu, unsigned char* mem);

typedef struct {
    unsigned char r8[4];
    unsigned short r16[4];
    unsigned int r32[5]; // 4 regs + DESV
    __uint128_t r128[2];
    unsigned char flags;
    unsigned int pc;
    int executando;
} CPU;

int main() {
    unsigned char memoria[MEM_TAM] = {0};
    CPU cpu = {0};
    cpu.executando = 1;

    carregar_programa(memoria, "programa.txt");

    printf("\nIniciando simulacao...\n");
    _start_cycle_cpu(&cpu, memoria);
    printf("Simulacao finalizada.\n");

    printf("Estado final:\n");
    for (int i = 0; i < 4; i++)
        printf("R8[%d]: %02X\n", i, cpu.r8[i]);
    for (int i = 0; i < 4; i++)
        printf("R16[%d]: %04X\n", i, cpu.r16[i]);
    for (int i = 0; i < 5; i++)
        printf("R32[%d]: %08X\n", i, cpu.r32[i]);
    for (int i = 0; i < 2; i++)
        printf("R128[%d]: %016llX%016llX\n", i, (unsigned long long)(cpu.r128[i] >> 64), (unsigned long long)cpu.r128[i]);
    printf("Flags: %02X\n", cpu.flags);
    printf("PC: %08X\n", cpu.pc);

    return 0;
}

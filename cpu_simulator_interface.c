//
// Created by bjoao on 25/06/2025.
//
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <assert.h>
#include <string.h>

#define MEM_TAM 1024

// Estrutura CPU alinhada para corresponder ao Assembly
typedef struct {
    uint8_t     r8[4];       // 4 regs de 8-bit
    uint16_t    r16[4];      // 4 regs de 16-bit
    uint32_t    r32[5];      // 4 regs + slot de desvio (desv)
    __uint128_t r128[2];     // 2 regs de 128-bit
    uint8_t     flags;       // Flags Z/C/N
    uint8_t     _pad[3];     // Padding para alinhar pc a 4 bytes
    uint32_t    pc;          // Program Counter
    int32_t     executando;  // Controle de execução
} CPU;

// Verifica em tempo de compilação se o tamanho está correto
_Static_assert(sizeof(CPU) == 80, "Layout de CPU inesperado: verifique os tipos e padding");

// Carrega o programa de texto (hex bytes) em memória e preenche o restante com HALT
void carregar_programa(uint8_t* memoria, const char* nome_arquivo) {
    FILE* f = fopen(nome_arquivo, "r");
    if (!f) {
        perror("Erro ao abrir o programa");
        exit(EXIT_FAILURE);
    }

    char linha[256];
    int pos = 0;

    while (fgets(linha, sizeof(linha), f) && pos < MEM_TAM) {
        char* tok = strtok(linha, " \t\n\r");
        while (tok && pos < MEM_TAM) {
            unsigned int byte;
            if (sscanf(tok, "%x", &byte) == 1) {
                memoria[pos++] = (uint8_t)byte;
            }
            tok = strtok(NULL, " \t\n\r");
        }
    }
    fclose(f);

    printf("Programa carregado. Bytes carregados: %d\n", pos);

    // Preencher o restante da memória com opcode HALT (0x06)
    for (int i = pos; i < MEM_TAM; i++) {
        memoria[i] = 0x06;
    }
}

// Função Assembly exportada para simulação
extern void _start_cycle_cpu(void* cpu, uint8_t* mem);

int main(int argc, char* argv[]) {
    uint8_t memoria[MEM_TAM] = {0};
    CPU cpu = {0};
    cpu.executando = 1;
    cpu.pc = 0;
    cpu.flags = 0;

    const char* arquivo = (argc > 1) ? argv[1] : "programa.txt";
    carregar_programa(memoria, arquivo);

    printf("\nIniciando simulacao.\n");
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
        printf("R128[%d]: %016llX%016llX\n", i,
               (unsigned long long)(cpu.r128[i] >> 64),
               (unsigned long long)cpu.r128[i]);
    printf("Flags: %02X\n", cpu.flags);
    printf("PC: %08X\n", cpu.pc);
    printf("Executando: %d\n", cpu.executando);
    printf("Ciclos executados: verificar com debugger\n");

    return 0;
}

# Simulador de CPU x86-64 em Assembly

## 📋 Descrição
Simulador completo de CPU x86-64 implementado em Assembly (NASM) e C, com suporte a todas as bases de registradores e operações aritméticas, lógicas e de memória.

## 🎯 Status do Projeto
✅ **PROJETO FINALIZADO COM SUCESSO COMPLETO**

## 📁 Arquivos Principais
- `cpu_simulator_x86_64.asm` - Implementação principal do simulador em Assembly
- `cpu_simulator_interface.c` - Interface C e carregamento de programas
- `example_program.txt` - Arquivo de programa exemplo
- `README.md` - Documentação do projeto

## 🔧 Compilação e Execução

```bash
# Compilar o assembly
nasm -f win64 cpu_simulator_x86_64.asm -o cpu_simulator_x86_64.o

# Linkar com o código C
gcc -o CPU cpu_simulator_interface.c cpu_simulator_x86_64.o

# Executar com programa
./CPU example_program.txt
```

## 🚀 Funcionalidades Implementadas

### ✅ Registradores Suportados
- **R8[0-3]** - Registradores de 8 bits (100% funcional)
- **R16[0-3]** - Registradores de 16 bits (100% funcional)
- **R32[0-4]** - Registradores de 32 bits (100% funcional)
- **R128[0-1]** - Registradores de 128 bits (100% funcional)

### ✅ Operações Implementadas
| Opcode | Operação | Bases Suportadas | Status |
|--------|----------|------------------|---------|
| 0x00 | AND | R8, R16, R32, R128 | ✅ Funcional |
| 0x01 | OR | R8, R16, R32, R128 | ✅ Funcional |
| 0x02 | XOR | R8, R16, R32, R128 | ✅ Funcional |
| 0x03 | NOT | R8, R16, R32, R128 | ✅ Funcional |
| 0x04 | ADD | R8, R16, R32, R128 | ✅ Funcional |
| 0x05 | SUB | R8, R16, R32, R128 | ✅ Funcional |
| 0x06 | HALT | - | ✅ Funcional |
| 0x10 | STORE | R8, R16, R32, R128 | ✅ Funcional |
| 0x11 | LOAD | R8, R16, R32, R128 | ✅ Funcional |
| 0x12 | INIT_R128 | R128 | ✅ Funcional |

### ✅ Modos de Operação
- **Modo Registrador**: Operações entre registradores
- **Modo Imediato**: Operações com valores constantes
- **LOAD/STORE**: Acesso à memória
- **Inicialização R128**: Padrões especiais (zeros, ones, alternado, crescente)

### ✅ Características Técnicas
- Validação completa de índices e bounds
- Controle correto do Program Counter (PC)
- Manipulação adequada de flags (Z, C, N)
- Suporte a instruções de tamanho variável
- Tratamento robusto de overflow
- Arquitetura x86-64 compatível

## 📊 Códigos de Operandos

### Modo Registrador
- **R8**: 0x00-0x03 (R8[0] a R8[3])
- **R16**: 0x40-0x43 (R16[0] a R16[3])
- **R32**: 0x80-0x84 (R32[0] a R32[4])
- **R128**: 0xF0-0xF1 (R128[0] a R128[1])

### Modo Imediato
- **R8**: 0xC0-0xC3 (R8[0] a R8[3])
- **R16**: 0xD0-0xD3 (R16[0] a R16[3])
- **R32**: 0xE0-0xE4 (R32[0] a R32[4])
- **R128**: 0xC0-0xC1 (INIT especial)

## 💻 Exemplo de Programa

```assembly
; Programa exemplo - operações básicas
04 C0 0A    ; ADD R8[0], #10 -> R8[0] = 10
04 C1 05    ; ADD R8[1], #5 -> R8[1] = 5
04 00 01    ; ADD R8[0], R8[1] -> R8[0] = 15
03 00       ; NOT R8[0] -> R8[0] = 240
06          ; HALT
```

## 🏆 Resultados de Validação

Todos os testes foram executados com sucesso:
- ✅ Operações aritméticas validadas para todas as bases
- ✅ Operações lógicas funcionando corretamente
- ✅ LOAD/STORE operando sem erros
- ✅ Modo imediato e entre registradores funcionais
- ✅ Controle de fluxo e flags adequados
- ✅ Arquitetura robusta e confiável

## 👨‍💻 Autores e Desenvolvedores

**Diógenes Varelo Correia** - Diih062 (@Git)  
**João Pedro Barros** - devjpedro05 (@Git) | dev.jpedro (@Instagram)  

Engenharia de Computação - PUC-GO  
4° Período - Disciplina: Arquitetura e Organização de Computadores  

## 🎓 Contexto Acadêmico
Este projeto foi desenvolvido como trabalho acadêmico para a disciplina de **Arquitetura e Organização de Computadores** do curso de **Engenharia de Computação** da **Pontifícia Universidade Católica de Goiás (PUC-GO)**, 4° período.

**Objetivo**: Implementar um simulador completo de CPU x86-64 em Assembly, demonstrando conhecimentos práticos sobre:
- Arquitetura de processadores
- Linguagem Assembly (NASM)
- Organização de registradores
- Operações aritméticas e lógicas
- Gerenciamento de memória
- Controle de fluxo de execução

---
**Status**: ✅ PROJETO CONCLUÍDO COM SUCESSO TOTAL
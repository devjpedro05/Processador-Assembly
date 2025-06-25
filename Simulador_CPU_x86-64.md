# Pontifícia Universidade Católica de Goiás

**Alunos:** Diógenes Varelo Correia e João Pedro Barros  
**Docente:** Claúdio Martins Garcia  
**Disciplina:** Arquitetura de Computadores I  
**Trabalho:** Simulador de CPU x86-64 em Assembly

---

## 1. Visão Geral do Projeto

Este documento detalha o "Simulador de CPU x86-64 em Assembly", um projeto que visa emular o comportamento de uma Unidade Central de Processamento (CPU) compatível com a arquitetura x86-64. Desenvolvido primariamente em Assembly (NASM) para o núcleo de simulação e em C para a interface de carregamento e execução de programas, o simulador abrange um conjunto de instruções essenciais, gerenciamento de registradores de diferentes tamanhos (8, 16, 32 e 128 bits), e controle de fluxo, memória e flags. O objetivo principal é demonstrar o funcionamento interno de uma CPU, desde a busca de instruções até a execução e atualização de estados.

## 2. Estrutura e Definição dos Arquivos

O projeto é organizado em três arquivos principais, cada um com uma responsabilidade bem definida:

### 2.1. `cpu_simulator_x86_64.asm`

* **Propósito**: Este é o módulo central do simulador, contendo a implementação da lógica da CPU em linguagem Assembly (NASM). Ele define a estrutura de dados da CPU, o ciclo de execução de instruções (fetch-decode-execute) e as rotinas para cada uma das operações suportadas.

* **Conteúdo Detalhado**:
    * **Constantes e Offsets**: Define constantes para o tamanho máximo do programa (`PROG_MAX`) e offsets dentro da estrutura da CPU para acessar os diferentes conjuntos de registradores (R8, R16, R32, R128), as flags, o Program Counter (PC) e o estado de execução (`EXEC`).
        ```assembly
        %define PROG_MAX 1024    ; tamanho máximo do programa em bytes
        
        ; constantes de "código de base"
        %define BASE_R8   0
        %define BASE_R16  1
        %define BASE_R32  2
        %define BASE_R128 3
        
        ; offsets reais dentro da struct CPU
        %define OFF_R8    0
        %define OFF_R16   4
        %define OFF_R32   12
        %define OFF_R128  32
        %define FLAGS     64
        %define PC        68
        %define EXEC      72
        ```
    * **Ponto de Entrada**: A função `_start_cycle_cpu` é o ponto de entrada da simulação, chamada a partir do código C. Ela configura o ambiente inicial (salva registradores, carrega ponteiros para CPU e memória) e inicia o loop principal de simulação.
    * **Ciclo Fetch-Decode-Execute**: A maior parte do arquivo é dedicada à implementação deste ciclo, com rótulos para cada fase e saltos condicionais para as rotinas de instrução.
    * **Rotinas de Instrução**: Contém as implementações para cada `opcode` (AND, OR, XOR, NOT, ADD, SUB, HALT, JMP, JNZ, JZ, JL, JLE, JG, JGE, JC, JNC, LOAD, STORE, INIT_R128). Cada rotina gerencia a operação específica, a atualização dos registradores de destino e das flags, e o retorno ao loop principal.
    * **Gerenciamento de Flags**: Inclui a sub-rotina `.atualizar_flags_128` que é especificamente responsável por calcular e atualizar as flags Zero (Z) e Negativo (N) para operações de 128 bits, devido à complexidade de manipulação de valores tão grandes.
    * **Tratamento de Erros**: Seções como `.err_oob` (out of bounds) e `.err_invalid` (instrução/operando inválido) garantem que o simulador pare a execução em caso de erros graves, setando a flag `EXEC` para `0`.

### 2.2. `cpu_simulator_interface.c`

* **Propósito**: Este arquivo em C atua como uma interface de alto nível para o simulador em Assembly. Ele é responsável por gerenciar a memória simulada, carregar programas a partir de arquivos e exibir o estado final da CPU após a simulação.

* **Conteúdo Detalhado**:
    * **Estrutura `CPU`**: Define a mesma estrutura da CPU utilizada no Assembly, garantindo a correspondência de offsets e tamanhos de dados. A assertiva `_Static_assert(sizeof(CPU) == 80, "Layout de CPU inesperado: verifique os tipos e padding");` verifica essa correspondência em tempo de compilação.
        ```c
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
        ```
    * **`carregar_programa`**: Lê bytes hexadecimais de um arquivo de texto e os carrega em um array `memoria`, preenchendo o restante com a instrução HALT (`0x06`). Isso simula o carregamento de um programa na memória principal da CPU.
    * **`main`**: A função principal do programa C. Ela inicializa a memória e a estrutura `CPU`, carrega o programa exemplo (ou um programa fornecido via argumento de linha de comando) e então chama a função `_start_cycle_cpu` do Assembly. Após o término da simulação, ela imprime o estado final de todos os registradores, flags e o Program Counter, facilitando a depuração e verificação dos resultados.

### 2.3. `example_program.txt`

* **Propósito**: Este arquivo de texto simples contém uma sequência de bytes em formato hexadecimal. Estes bytes representam as instruções (`opcodes` e operandos) que serão carregadas na memória do simulador e executadas.

* **Conteúdo**: Cada linha pode conter um ou mais bytes hexadecimais, que são interpretados sequencialmente como o código de máquina do programa.
    ```
    0x04 0x01 0x55
    0x03 0x03 0x01
    0x06 0x00 0x00
    ```
    O programa acima ilustra:
    * `0x04 0x01 0x55`: Uma instrução ADD.
    * `0x03 0x03 0x01`: Uma instrução NOT.
    * `0x06 0x00 0x00`: Uma instrução HALT, que sinaliza o fim da execução.

## 3. Arquitetura da CPU Simulada e Registradores

A CPU simulada é baseada em uma arquitetura x86-64 simplificada, focando nos conceitos de registradores de propósito geral e um conjunto de flags.

### 3.1. Estrutura da CPU

A estrutura `CPU` é uma representação em memória do estado interno do processador. Ela contém:
* **Registradores de 8 bits (R8[0-3])**: 4 registradores de 1 byte cada.
* **Registradores de 16 bits (R16[0-3])**: 4 registradores de 2 bytes cada.
* **Registradores de 32 bits (R32[0-4])**: 5 registradores de 4 bytes cada (um extra para desvios em certas implementações).
* **Registradores de 128 bits (R128[0-1])**: 2 registradores de 16 bytes cada, para operações vetoriais (SIMD).
* **Flags**: Um byte contendo as flags de estado (Zero, Carry, Negative).
* **Program Counter (PC)**: Um registrador de 32 bits que armazena o endereço da próxima instrução a ser executada.
* **Executando**: Uma flag de controle que indica se a CPU deve continuar o ciclo de execução.

### 3.2. Mapeamento de Offsets

Os offsets definidos no Assembly são cruciais para o acesso direto aos campos da estrutura `CPU`.
* `OFF_R8`: `0` (início dos registradores de 8 bits).
* `OFF_R16`: `4` (início dos registradores de 16 bits, após 4 bytes de R8).
* `OFF_R32`: `12` (início dos registradores de 32 bits, após 8 bytes de R16).
* `OFF_R128`: `32` (início dos registradores de 128 bits, após 20 bytes de R32).
* `FLAGS`: `64` (localização do byte de flags).
* `PC`: `68` (localização do Program Counter).
* `EXEC`: `72` (localização da flag de execução).

### 3.3. Flags

As flags são utilizadas para indicar o resultado de operações aritméticas e lógicas, afetando o comportamento das instruções de salto condicional.
* **Z (Zero Flag - Bit `0x01`)**: Setada se o resultado da operação for zero.
* **C (Carry Flag - Bit `0x02`)**: Setada se houver um `carry` (transbordo para operações sem sinal) ou `borrow` (em subtrações) para fora do bit mais significativo.
* **N (Negative Flag - Bit `0x04`)**: Setada se o resultado da operação for negativo (ou seja, o bit mais significativo do resultado é 1).

## 4. Ciclo de Fetch-Decode-Execute

O simulador opera seguindo o ciclo fundamental de uma CPU. A função `_start_cycle_cpu` gerencia este loop.

### 4.1. Configuração Inicial

A rotina `_start_cycle_cpu` é o ponto de entrada da simulação em Assembly e executa as seguintes etapas iniciais, preparando o ambiente para o ciclo de execução da CPU:

* **1. Preservação de Registradores**: Ao ser chamada, a função `_start_cycle_cpu` primeiramente salva os registradores de propósito geral (`rbx`, `rsi`, `rdi`, `r12`, `r13`, `r14`, `r15`, `r10`) na pilha. Esta é uma prática padrão em Assembly (conhecida como *callee-saved registers*) para garantir que a função não sobrescreva inadvertidamente valores importantes que podem estar sendo usados pelo código C que a chamou, preservando a integridade do estado do programa.
    ```assembly
    _start_cycle_cpu:
        push rbx
        push rsi
        push rdi
        push r12
        push r13
        push r14
        push r15
        push r10
    ```

* **2. Carregamento de Ponteiros Essenciais**: Em seguida, os ponteiros para a estrutura `CPU` e para a memória simulada são carregados em registradores específicos para acesso rápido durante a simulação. Na convenção de chamada x86-64 (System V AMD64 ABI, comum em Linux), o primeiro argumento é passado em `rcx` e o segundo em `rdx`. Assim, `rcx` (ponteiro para a estrutura CPU) é movido para `r13` e `rdx` (ponteiro para a memória) é movido para `r12`. Estes registradores (`r13`, `r12`) atuarão como ponteiros base para todas as operações que interagem com o estado da CPU ou com a memória do programa.
    ```assembly
        mov r13, rcx        ; r13 = CPU*
        mov r12, rdx        ; r12 = memória
    ```

* **3. Inicialização do Contador de Ciclos**: Um registrador (`r9d`) é zerado. Ele será utilizado como um contador de ciclos de execução, que é incrementado a cada instrução processada. Este contador serve a um propósito de segurança: ele permite impor um limite máximo de ciclos de simulação (definido como 100.000), o que é crucial para evitar que o simulador entre em loops infinitos caso o programa simulado contenha um erro ou nunca atinja uma instrução `HALT`.
    ```assembly
        xor r9d, r9d        ; contador de ciclos
    ```

### 4.2. FETCH (Busca de Instrução)

O `PC` é lido para obter o endereço da instrução atual. O `opcode` é então buscado na memória nesse endereço. Uma checagem de limites (`PROG_MAX`) é realizada para garantir que o acesso à memória está dentro dos limites do programa.

```assembly
    ; FETCH + BOUND CHECK
    mov eax, [r13 + PC]
    cmp eax, PROG_MAX
    jae .err_oob          ; Erro se fora dos limites
    movzx r8d, byte [r12 + rax]   ; Carrega opcode
```

### 4.3. DECODE (Decodificação de Operandos)

Após o opcode, os operandos (se houver) são lidos. Instruções unárias (como NOT) leem apenas um operando (op1), enquanto binárias leem dois (op1, op2). O PC é incrementado conforme os bytes lidos.

A decodificação dos operandos envolve determinar o tipo da base (R8, R16, R32, R128) e o modo de endereçamento (registrador ou imediato) através de bits específicos nos bytes dos operandos.

* **Modo Registrador**: Bits 7-6 = 00, 01, 10 para R8, R16, R32 respectivamente. Bits 7-4 para R128. Bits 3-0 para o índice do registrador.
* **Modo Imediato**: Bits 7-6 = 11 (3). Os bits 5-4 indicam a base real (0=R8, 1=R16, 2=R32, 3=R128), e os bits 3-0 contêm o valor imediato diretamente para 8 bits, ou indicam o tamanho para leituras maiores da memória do programa.

```assembly
.decode_operands:
    xor r11d, r11d               ; r11 = 0 (modo registrador por padrão)

    ; DECODE BASE + INDEX (op1 - dest)
    mov r14d, edx
    shr r14d, 6              ; bits 7-6: tipo base
    mov r15d, edx
    and r15d, 0x0F           ; bits 3-0: índice

.check_imm_normal:
    cmp r14d, 3              ; Se bits 7-6 = 11 (3), é modo imediato
    jne .check_op2
    mov r11d, 1              ; Marca como imediato
    mov r14d, edx
    shr r14d, 4
    and r14d, 3              ; bits 5-4: tipo real (0=R8, 1=R16, 2=R32, 3=R128)
    
; ... validações de índice ...
```

**Validação de Índices**: Para cada base, o índice do registrador (bits 3-0 do operando) é validado para garantir que não se tente acessar um registrador inexistente (ex: R8[4] não existe, pois vai de 0 a 3).

```assembly
.validate_dest:
   cmp r14d, BASE_R8
   je .chk_dest_r8
   ; ... para outras bases ...

.chk_dest_r8:
    cmp r15d, 3
    ja  .err_invalid ; R8 só tem índices 0 a 3
    jmp .chk_src
```

### 4.4. DISPATCH (Despacho de Instrução)

Uma vez que o opcode e os operandos são decodificados e validados, o PC é atualizado para a próxima instrução, e o controle é transferido para a rotina Assembly específica da operação através de uma série de comparações e saltos.

```assembly
.dispatch:
    mov [r13 + PC], eax ; Atualiza PC
    cmp r8b, 0x00
    je .and
    cmp r8b, 0x01
    je .or
    ; ... outras comparações de opcode ...
    cmp r8b, 0x12
    je .init_r128
.err_invalid:
    ; ...
```

## 5. Análise Completa das Subrotinas do Simulador de CPU

Este código implementa um simulador de CPU com diversas subrotinas organizadas por funcionalidade. Aqui está a explicação de cada uma:

### 5.1. Subrotina Principal: `_start_cycle_cpu`

**Função**: Loop principal de execução do simulador.

**Funcionalidade**: Esta é a orquestradora do simulador, controlando o ciclo de fetch-decode-execute e o fluxo geral do programa simulado.

* **Controle de Ciclo e Limite de Segurança**: Esta fase inicial de cada iteração do loop incrementa um contador de ciclos (r9d) e verifica se um limite predefinido (100.000 ciclos) foi atingido. Se o limite for excedido, a simulação é encerrada (je .fim) para evitar loops infinitos.

```assembly
.loop_safety:
    inc r9d
    cmp r9d, 100000     ; safety limit aumentado
    je .fim
```

* **Verificação de Estado de Execução**: Em seguida, o simulador verifica o estado de execução da CPU. Isso é feito comparando o valor da flag EXEC (no offset EXEC da estrutura CPU) com zero. Se EXEC for 0, indica que o programa simulado foi encerrado (e.g., por uma instrução HALT), e a simulação termina seu loop principal (je .fim).

```assembly
    cmp dword [r13 + EXEC], 0
    je .fim
```

* **Fase de FETCH (Busca de Instrução)**: Se a CPU ainda estiver em execução, o Program Counter (PC) (em [r13 + PC]) é lido para obter o endereço da próxima instrução. O opcode é então buscado nesse endereço na memória simulada ([r12 + rax]). Uma validação de limites (cmp eax, PROG_MAX) é feita para garantir que o acesso à memória é válido e não excede o tamanho do programa.

```assembly
; FETCH + BOUND CHECK
mov eax, [r13 + PC]
cmp eax, PROG_MAX
jae .err_oob
movzx r8d, byte [r12 + rax]   ; Carrega opcode
```

* **Fase de DECODE (Decodificação de Operandos)**: Após a busca do opcode, os operandos da instrução (se houver) são lidos do fluxo de instruções. A subrotina analisa os bits dos operandos (usando shr, and) para determinar o tipo de registrador (8, 16, 32, 128 bits) e o modo de endereçamento (registrador para registrador ou imediato). Validações de índice (.validate_dest, .chk_src) são realizadas para garantir que os registradores acessados são válidos.

```assembly
; DECODE
mov r14d, edx       ; op1 (destino)
shr r14d, 6
mov r15d, edx
and r15d, 0x0F
; ... (lógica para op2, e modos imediato/registrador) ...
call .validate_dest ; Chama subrotinas de validação
```

* **Fase de DISPATCH (Despacho de Execução)**: Com o opcode e os operandos decodificados e validados, o PC é atualizado para apontar para o início da próxima instrução. Em seguida, o controle é transferido para a subrotina Assembly específica que implementa a operação identificada (e.g., ADD, SUB, AND, LOAD), através de uma série de comparações (cmp r8b, 0xXX) e saltos condicionais (je .nome_da_rotina).

```assembly
.dispatch:
    mov [r13 + PC], eax ; Atualiza PC
    cmp r8b, 0x00
    je .and
    cmp r8b, 0x01
    je .or
    ; ... (e assim por diante para todas as instruções) ...
```

### 5.2. Subrotinas de Validação

#### `.validate_dest` e `.chk_src`

**Função**: Validar índices de registradores.

**Funcionalidade**: Estas subrotinas são cruciais para a segurança do simulador, impedindo acessos a regiões de memória inválidas ou registradores inexistentes. Elas verificam se os índices dos registradores de destino (r15d para destino) e fonte (ebx para fonte) estão dentro dos limites permitidos para suas respectivas bases (R8, R16, R32, R128). Se um índice inválido for detectado, a execução é desviada para a rotina de erro .err_invalid, que encerra a simulação.

**Limites**:
- **R8/R16**: Índices de 0 a 3 (total de 4 registradores). A comparação é feita com `cmp r15d, 3` ou `cmp ebx, 3` e `ja .err_invalid` (Jump Above, se maior que 3).
- **R32**: Índices de 0 a 4 (total de 5 registradores). A comparação é feita com `cmp r15d, 4` ou `cmp ebx, 4` e `ja .err_invalid`.
- **R128**: Índices de 0 a 1 (total de 2 registradores). A comparação é feita com `cmp r15d, 1` ou `cmp ebx, 1` e `ja .err_invalid`.

```assembly
.validate_dest:
   cmp r14d, BASE_R8 ; Verifica o tipo da base do destino
   je .chk_dest_r8
   ; ...
.chk_dest_r8:
    cmp r15d, 3 ; Verifica se o índice do R8 é > 3
    ja  .err_invalid
    jmp .chk_src ; Se válido, vai para checagem da fonte
```

### 5.3. Subrotinas de Carregamento de Memória (LOAD)

#### `.load`, `.load_r8`, `.load_r16`, `.load_r32`, `.load_r128`

**Função**: Carregar dados de um endereço específico na memória principal para um registrador da CPU.

**Funcionalidade**: A subrotina `.load` atua como um dispatcher, direcionando a execução para a sub-rotina específica da base de registrador (R8, R16, R32, R128). Cada uma dessas sub-rotinas realiza:

1. **Leitura do Endereço de Memória**: O endereço de onde os dados serão carregados é um valor de 16 bits que é lido do fluxo de instruções (`word [r12 + rsi]`). O Program Counter (PC) é temporariamente ajustado para essa leitura.

2. **Validação de Limites (Bounds)**: É feita uma comparação entre o endereço lido e `PROG_MAX` (ou `PROG_MAX` menos o tamanho do dado) para garantir que o acesso à memória não exceda os limites do programa simulado. Se exceder, desvia para `.err_oob`.

3. **Carregamento dos Dados**: Os dados são lidos da memória principal (apontada por r12) para um registrador temporário do processador físico (ex: bl para R8, bx para R16, ecx para R32, xmm0 para R128).

4. **Armazenamento no Registrador da CPU Simulada**: O valor do registrador temporário é então movido para o registrador de destino correspondente na estrutura CPU (apontada por r13), usando o offset e o índice calculados.

5. **Atualização do Program Counter (PC)**: O PC é avançado em 2 bytes (o tamanho do endereço de 16 bits lido) após a operação ser concluída.

6. **Atualização de Flags (Zero, Negative)**: As flags Z e N são atualizadas com base no valor que acabou de ser carregado no registrador de destino. Para R128, a subrotina `.atualizar_flags_128` é chamada.

```assembly
.load_r8:
    mov   esi, [r13 + PC]         ; 1. Salva PC
    movzx eax, word [r12 + rsi]   ; 2. Lê endereço de 16 bits
    cmp   eax, PROG_MAX           ; 3. Valida bounds
    jae   .err_oob
    mov   bl, byte [r12 + rax]    ; 4. Carrega da memória
    mov   [r13 + OFF_R8 + r15], bl ; 5. Armazena no registrador
    add   esi, 2                  ; 6. Avança PC
    mov   [r13 + PC], esi
    ; 7. Atualiza flags (Z e N)
    jmp .loop_safety
```

### 5.4. Subrotinas de Armazenamento em Memória (STORE)

#### `.store`, `.store_r8`, `.store_r16`, `.store_r32`, `.store_r128`

**Função**: Salvar dados de um registrador da CPU para um endereço específico na memória principal.

**Funcionalidade**: A subrotina `.store` é o dispatcher para as sub-rotinas específicas de cada base. Cada uma delas executa:

1. **Leitura do Endereço de Memória**: Assim como no LOAD, o endereço de destino na memória é lido como um valor de 16 bits do fluxo de instruções.

2. **Validação de Limites (Bounds)**: Uma verificação de `PROG_MAX` (ou `PROG_MAX` menos o tamanho do dado) é realizada para garantir que o endereço de escrita esteja dentro dos limites válidos da memória simulada.

3. **Carregamento dos Dados do Registrador da CPU Simulada**: O valor do registrador de origem (na estrutura CPU) é carregado em um registrador temporário do processador físico.

4. **Escrita na Memória Principal**: O valor do registrador temporário é então escrito no endereço calculado na memória principal (apontada por r12).

5. **Atualização do Program Counter (PC)**: O PC é avançado em 2 bytes (o tamanho do endereço de 16 bits lido).

6. **Flags**: As operações STORE geralmente não afetam as flags de estado da CPU.

```assembly
.store_r8:
    mov   esi, [r13 + PC]         ; 1. Salva PC
    movzx eax, word [r12 + rsi]   ; 2. Lê endereço de 16 bits
    cmp   eax, PROG_MAX           ; 3. Valida bounds
    jae   .err_oob
    mov   bl, [r13 + OFF_R8 + r15] ; 4. Carrega do registrador (R8[r15])
    mov   [r12 + rax], bl         ; 5. Escreve na memória
    add   esi, 2                  ; 6. Avança PC
    mov   [r13 + PC], esi
    jmp .loop_safety
```

### 5.5. Subrotinas de Operações Lógicas

Essas subrotinas realizam operações lógicas bit a bit no registrador de destino, com base em um registrador fonte ou um valor imediato. As flags Z (Zero) e N (Negative) são atualizadas após cada operação.

#### **AND (`.and`, `.and_rX`, `.andc_rX`)**

**Função**: Operação lógica E bit-a-bit.

**Versões**:
- **Registrador para Registrador** (`.and_r8`, `.and_r16`, `.and_r32`, `.and_r128`): Realiza destino = destino AND fonte, onde ambos são registradores.
- **Imediato** (`.andc_r8`, `.andc_r16`, `.andc_r32`, `.andc_r128`): Realiza destino = destino AND constante, onde a constante é um valor imediato.

**Funcionalidade**:
- A subrotina `.and` primeiro verifica se a operação é no modo imediato (`cmp r11, 1`) ou registrador (`cmp r11, 0`) e então direciona para a sub-rotina de base apropriada (`.and_rX` ou `.andc_rX`).
- Para registradores: Os valores dos registradores de destino e fonte são carregados em registradores temporários, a operação AND é aplicada, e o resultado é armazenado de volta no registrador de destino da CPU simulada.
- Para imediatos: O valor imediato é lido do fluxo de instruções e a operação AND é aplicada com o registrador de destino.
- **Atualização de Flags**: Após a operação, `test` é usado para verificar se o resultado é zero (para Z) ou negativo (para N), atualizando o byte de flags. Para R128, a rotina `.atualizar_flags_128` é chamada.

```assembly
.and_r8:
    lea    rdx, [r13 + OFF_R8 + r15]  ; Endereço do R8 de destino
    mov    al, [rdx]                  ; Carrega valor do destino
    and    ebx, 0x0F                  ; Garante que ebx contenha o índice da fonte
    lea    rsi, [r13 + OFF_R8 + rbx]  ; Endereço do R8 de fonte
    mov    cl, [rsi]                  ; Carrega valor da fonte
    and    al, cl                     ; al = al AND cl
    mov    [rdx], al                  ; Salva resultado
    ; Atualiza flags Z e N
    jmp    .loop_safety
```

```assembly
.andc_r8:
    lea    rdx, [r13 + OFF_R8 + r15] ; Endereço do R8 de destino
    mov    al, bl                    ; bl já contém o valor imediato para R8
    and    al, byte [rdx]            ; al = imediato AND (valor do destino)
    mov    byte [rdx], al            ; Salva resultado
    ; Atualiza flags Z e N
    jmp    .loop_safety
```

#### **OR (`.or`, `.or_rX`, `.orc_rX`)**

**Função**: Operação lógica OU bit-a-bit.

**Versões**: Registrador para registrador e imediato.

**Funcionalidade**: Idêntica à lógica do AND, mas utilizando a instrução OR (ou `por` para R128). Atualiza flags Z e N.

```assembly
.or_r8:
    ; (similar ao AND_r8, mas com 'or al, cl')
    or     al, cl
    mov    [rdx], al
    ; Atualiza flags Z e N
    jmp    .loop_safety
```

#### **XOR (`.xor`, `.xor_rX`, `.xorc_rX`)**

**Função**: Operação lógica OU-exclusivo bit-a-bit.

**Versões**: Registrador para registrador e imediato.

**Funcionalidade**: Idêntica à lógica do AND/OR, mas utilizando a instrução XOR (ou `pxor` para R128). Atualiza flags Z e N.

```assembly
.xor_r8:
    ; (similar ao AND_r8, mas com 'xor al, cl')
    xor    al, cl
    mov    [rdx], al
    ; Atualiza flags Z e N
    jmp    .loop_safety
```

#### **NOT (`.not`, `.not_r8`, `.not_r16`, `.not_r32`, `.not_r128`)**

**Função**: Operação lógica complemento bit-a-bit (inversão de todos os bits).

**Funcionalidade**: Sendo uma instrução unária, ela opera apenas em um registrador de destino. O valor do registrador é carregado, a instrução NOT é aplicada, e o resultado é salvo de volta. As flags Z e N são atualizadas.

```assembly
.not_r8:
    mov    al, [r13 + r15 + OFF_R8]
    not    al
    mov    [r13 + r15 + OFF_R8], al
    ; Atualiza flags Z e N
    jmp    .loop_safety
```

### 5.6. Subrotinas de Operações Aritméticas

Essas subrotinas realizam adição e subtração. As flags Z (Zero), C (Carry/Borrow) e N (Negative) são atualizadas após cada operação, refletindo o resultado aritmético.

#### **ADD (`.add`, `.add_rX`, `.addc_rX`)**

**Função**: Adição aritmética.

**Versões**:
- **Registrador para Registrador** (`.add_r8`, `.add_r16`, `.add_r32`, `.add_r128`): Realiza destino = destino + fonte, onde ambos são registradores.
- **Imediato** (`.addc_r8`, `.addc_r16`, `.addc_r32`, `.addc_r128`): Realiza destino = destino + constante, onde a constante é um valor imediato lido do fluxo de instruções.

**Funcionalidade**:
- A subrotina `.add` direciona para a base e modo corretos.
- Os valores são carregados, a instrução ADD é executada (que automaticamente afeta as flags Z, C, N do processador físico), e o resultado é salvo no registrador de destino da CPU simulada.
- **Atualização de Flags**: A Carry Flag (C) é explicitamente capturada usando `setc dh`. Z e N são determinadas a partir do resultado final usando `test` e `js`. Para R128, `paddq` é usado, e `.atualizar_flags_128` é chamada.

```assembly
.add_r8:
    lea    rdx, [r13 + OFF_R8 + r15]   ; Endereço R8 de destino
    mov    al, byte [rdx]              ; Carrega valor destino
    mov    cl, byte [r13 + OFF_R8 + rbx] ; Carrega valor fonte
    add    al, cl                      ; al = al + cl (afeta flags do CPU físico)
    mov    [rdx], al                   ; Salva resultado
    ; Atualiza flags Z, C, N com base em al e nas flags do CPU físico
    jmp    .loop_safety
```

#### **SUB (`.sub`, `.sub_rX`, `.subc_rX`)**

**Função**: Subtração aritmética.

**Versões**: Registrador para registrador e imediato.

**Funcionalidade**: Similar à adição, mas realiza a subtração. A instrução SUB do x86-64 também afeta as flags Z, C (que age como borrow aqui) e N. `psubq` é usado para R128.

```assembly
.sub_r8:
    mov    al, [r13 + OFF_R8 + r15]   ; Valor destino
    mov    dl, [r13 + OFF_R8 + rbx]   ; Valor fonte
    sub    al, dl                     ; al = al - dl
    mov    [r13 + OFF_R8 + r15], al   ; Salva resultado
    ; Atualiza flags Z, C, N
    jmp    .loop_safety
```

### 5.7. Subrotinas de Controle de Fluxo

Essas subrotinas alteram o valor do Program Counter (PC), direcionando a execução para diferentes partes do código do programa simulado.

#### **JMP (`.jmp`, `.jmp_r8`, `.jmp_r16`, `.jmp_r32`, `.jmp_r128`)**

**Função**: Salto incondicional.

**Funcionalidade**: Altera o PC para um novo endereço, que é obtido do registrador de destino especificado.
- A subrotina `.jmp` atua como um dispatcher para as versões específicas da base.
- O valor do registrador fonte (R8, R16, R32, ou R128) é carregado e copiado diretamente para o PC. Para R128, apenas os 4 bytes mais baixos (que representam um endereço de 32 bits) são considerados.

```assembly
.jmp_r32:
    mov eax, [r13 + r15*4 + OFF_R32] ; Carrega o valor do R32[r15]
    mov [r13 + PC], eax              ; Move para o PC
    jmp .loop_safety
```

#### **Saltos Condicionais**:

**Funcionalidade**: Cada subrotina de salto condicional testa uma ou mais das flags de estado (Z, C, N) na estrutura CPU. Se a condição for verdadeira, a execução salta para a rotina `.jmp`, que então carrega o novo endereço do PC. Caso contrário, a execução continua sequencialmente, e o PC já terá sido avançado para a próxima instrução no ciclo de fetch.

- **`.jz`**: Salta se a Zero Flag (0x01 no byte de flags) for 1. (`test byte [r13 + FLAGS], 0x01; jz .jmp`)
- **`.jnz`**: Salta se a Zero Flag (0x01) for 0. (`test byte [r13 + FLAGS], 0x01; jnz .jmp`)
- **`.jl`**: Salta se menor. A condição é Negative Flag = 1 (0x04 no byte de flags). (`test byte [r13 + FLAGS], 0x04; jnz .jmp`)
- **`.jle`**: Salta se menor ou igual. A condição é Zero Flag = 1 OU Negative Flag = 1.
- **`.jg`**: Salta se maior. A condição é Zero Flag = 0 E Negative Flag = 0.
- **`.jge`**: Salta se maior ou igual. A condição é Negative Flag = 0.
- **`.jc`**: Salta se carry. A condição é Carry Flag = 1 (0x02 no byte de flags). (`test byte [r13 + FLAGS], 0x02; jz .loop_safety; jmp .jmp`)
- **`.jnc`**: Salta se não carry. A condição é Carry Flag = 0. (`test byte [r13 + FLAGS], 0x02; jnz .loop_safety; jmp .jmp`)

### 5.8. Subrotinas Auxiliares

#### **`.atualizar_flags_128`**

**Função**: Atualizar as flags Zero (Z) e Negative (N) especificamente para operações que envolvem registradores de 128 bits.

**Funcionalidade**: Diferente das operações de 8, 16 ou 32 bits onde as flags do processador x86-64 são usadas diretamente, a verificação para 128 bits exige uma lógica manual.

- **Verifica Zero Flag (Z)**: Para determinar se o resultado de 128 bits é zero, a rotina armazena temporariamente o valor de 128 bits (xmm0) na pilha. Em seguida, ela realiza uma operação OR lógica nos dois qword (64 bits) que compõem o valor de 128 bits. Se o resultado desse OR for zero, significa que todos os 128 bits são zero, e a flag Z (bit 0x01) é setada no registrador FLAGS da CPU simulada.

- **Verifica Negative Flag (N)**: Para determinar a flag N (bit 0x04), o bit mais significativo (MSB, ou bit 7) do último byte (o 15º byte, ou `[rsp + 15]`) do valor de 128 bits é testado. Se o MSB for 1, a flag N é setada, indicando um valor negativo.

```assembly
.atualizar_flags_128:
    sub rsp, 16                     ; Aloca espaço na pilha
    movdqu [rsp], xmm0              ; Salva XMM0 na pilha

    ; Verifica Z (se todos os 128 bits são zero)
    mov rax, qword [rsp]
    or  rax, qword [rsp + 8]        ; OR lógico dos dois qwords
    test rax, rax
    jnz .not_zero_128
    or byte [r13 + FLAGS], 0x01     ; Seta Z
.not_zero_128:
    ; ... (limpa Z se não for zero) ...

    ; Verifica N (MSB do último byte)
    mov al, byte [rsp + 15]
    test al, 0x80                   ; Testa o bit mais significativo
    jz .not_neg_128
    or byte [r13 + FLAGS], 0x04     ; Seta N
.not_neg_128:
    ; ... (limpa N se não for negativo) ...

    add rsp, 16                     ; Libera espaço da pilha
    ret
```

#### **`.halt`**

**Função**: Parar a execução da CPU.

**Funcionalidade**: Esta subrotina é extremamente simples, mas crucial. Ela define o valor do campo EXEC na estrutura CPU para 0. Como o loop principal (`.loop_safety`) verifica constantemente este campo, definir EXEC como 0 sinaliza que a simulação deve ser encerrada na próxima iteração do loop.

```assembly
.halt:
    mov dword [r13 + EXEC], 0
    jmp .fim ; Salta para a finalização do simulador
```

#### **`.init_r128`**

**Função**: Inicialização direta de registradores R128 para testes.

**Funcionalidade**: Esta subrotina permite carregar padrões predefinidos (zeros, uns, alternado, crescente) em um dos registradores R128. Isso é útil para configurar cenários de teste rapidamente sem a necessidade de operações complexas de LOAD.
- O operando ebx contém o código do padrão desejado.
- As instruções SSE/AVX (`pxor`, `pcmpeqb`, `movq`, `movlhps`) são usadas para gerar e carregar os padrões de 128 bits.
- A rotina `.atualizar_flags_128` é chamada após a inicialização para refletir o estado do registrador.

```assembly
.init_zeros:
    pxor xmm0, xmm0                 ; Seta todos os bits de xmm0 para zero
    movdqu [r13 + rcx + OFF_R128], xmm0 ; Move xmm0 (zeros) para o R128
    jmp .init_r128_end
```

### 5.9. Subrotinas de Tratamento de Erro

Estas subrotinas são acionadas quando uma condição de erro grave é detectada, levando ao término da simulação para evitar comportamento indefinido ou falhas (segmentation faults).

#### **`.err_invalid` e `.err_oob`**

**Função**: Tratamento de erros.

**Funcionalidade**:
- **`.err_invalid`**: É chamada quando um operando inválido (ex: índice de registrador fora do limite para a base) ou um opcode não reconhecido é encontrado durante a fase de decodificação.
- **`.err_oob`**: É acionada quando uma tentativa de acesso à memória (seja para buscar uma instrução ou para operações de LOAD/STORE) excede os limites definidos para o programa (PROG_MAX). Isso impede que o simulador tente ler ou escrever em regiões de memória não alocadas para o programa simulado.

Em ambos os casos, a funcionalidade é a mesma: o campo EXEC na estrutura CPU é definido como 0, forçando o término do loop principal de simulação e, consequentemente, do simulador.

```assembly
.err_oob:
    ; acesso fora do programa
    mov dword [r13 + EXEC], 0
    jmp .fim ; Salta para a finalização
```

#### **Arquitetura dos Registradores**:

Os registradores da CPU simulada são organizados em arrays dentro da estrutura CPU, acessíveis através de offsets específicos.

- **R8**: 4 registradores de 8 bits (índices 0-3), acessados via OFF_R8.
- **R16**: 4 registradores de 16 bits (índices 0-3), acessados via OFF_R16.
- **R32**: 5 registradores de 32 bits (índices 0-4), acessados via OFF_R32.
- **R128**: 2 registradores de 128 bits (índices 0-1), acessados via OFF_R128.

#### **Sistema de Flags**:

Um único byte (FLAGS) dentro da estrutura CPU é usado para armazenar o estado das flags.

- **Bit 0 (0x01) (Z)**: Zero flag.
- **Bit 1 (0x02) (C)**: Carry flag.
- **Bit 2 (0x04) (N)**: Negative flag.

## 6. Compilação e Execução

Para compilar e executar o simulador, os seguintes comandos podem ser utilizados em um ambiente Linux (ou compatível com GCC e NASM):

```bash
# Compilar o código Assembly
nasm -f win64 cpu_simulator_x86_64.asm -o cpu_simulator_x86_64.o

# Linkar o código Assembly compilado com o código C
gcc -o CPU cpu_simulator_interface.c cpu_simulator_x86_64.o

# Executar o simulador com um programa exemplo
./CPU example_program.txt
```

## 7. Conclusão

O "Simulador de CPU x86-64 em Assembly" representa uma implementação robusta e didática dos princípios fundamentais da arquitetura de computadores. Através de sua lógica modular e o suporte a diversas bases de registradores, operações aritméticas, lógicas e de controle de fluxo, o projeto demonstra um profundo entendimento sobre como uma CPU processa instruções em baixo nível. A validação de limites e o tratamento de erros contribuem para a estabilidade do simulador, tornando-o uma ferramenta eficaz para aprendizado e experimentação em arquitetura de computadores e programação Assembly.

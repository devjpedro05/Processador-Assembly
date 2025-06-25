; cpu_Atual_fixed.asm
; Versão corrigida com validações de limites e índices, remoção de debug inseguro

%define PROG_MAX 1024    ; tamanho máximo do programa em bytes
; Removed problematic constants that exceed 1024-byte buffer:
; %define MEM128    0x5000
; %define CONST128  0x6000
; %define TMP128    0x7000

; ──────────── constantes de “código de base” ────────────
%define BASE_R8   0
%define BASE_R16  1
%define BASE_R32  2
%define BASE_R128 3

; ──────────── offsets reais dentro da struct ────────────
%define OFF_R8    0
%define OFF_R16   4
%define OFF_R32   12
%define OFF_R128  32
%define FLAGS     64
%define PC        68
%define EXEC      72

section .text
    global _start_cycle_cpu

_start_cycle_cpu:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    push r10

    mov r13, rcx        ; r13 = CPU*
    mov r12, rdx        ; r12 = memória
    xor r9d, r9d        ; contador de ciclos

.loop_safety:
    inc r9d
    cmp r9d, 100000     ; safety limit aumentado
    je .fim

    cmp dword [r13 + EXEC], 0
    je .fim

    ; FETCH + BOUND CHECK
    mov eax, [r13 + PC]
    cmp eax, PROG_MAX
    jae .err_oob
    movzx r8d, byte [r12 + rax]   ; opcode
    
    ; Para HALT, não precisa de operandos
    cmp r8b, 0x06
    je .halt_direct
    
    ; Para NOT (instrução unária), só carrega op1
    cmp r8b, 0x03
    je .load_unary
    
    ; Para outras instruções, carrega operandos
    inc rax
    movzx edx, byte [r12 + rax]   ; op1
    inc rax
    movzx ecx, byte [r12 + rax]   ; op2
    inc rax
    jmp .decode_operands

.load_unary:
    inc rax
    movzx edx, byte [r12 + rax]   ; op1 apenas
    inc rax
    xor ecx, ecx                  ; op2 = 0 (não usado)
    jmp .decode_operands

.decode_operands:
    
    ; INICIALIZAÇÃO: assume modo registrador por padrão
    xor r11d, r11d               ; r11 = 0 (modo registrador)

    ; DECODE BASE + INDEX
    ; op1 (dest)
    mov r14d, edx
    shr r14d, 6              ; bits 7-6: tipo base 
    mov r15d, edx
    and r15d, 0x0F           ; bits 3-0: índice
    
    
.check_imm_normal:
    ; Para todas as bases, verificar modo imediato tradicional
    ; se bits 7-6 = 11 (3), isso indica modo imediato
    cmp r14d, 3
    jne .check_op2
    mov r11d, 1              ; marca como imediato
    mov r14d, edx
    shr r14d, 4
    and r14d, 3              ; bits 5-4: tipo real (0=R8, 1=R16, 2=R32, 3=R128)
    
.check_op2:
    ; op2 (src) - para imediato, é o valor literal
    mov r10d, ecx
    shr r10d, 6
    mov ebx, ecx
    and ebx, 0x0F            ; CORREÇÃO: garantir que rbx contenha apenas o índice (bits 3-0)
    
.validate_dest:
    ; VALIDAÇÃO DE ÍNDICE DEST
.validate_dest:
   cmp r14d, BASE_R8
   je .chk_dest_r8
   cmp r14d, BASE_R16
   je .chk_dest_r16
   cmp r14d, BASE_R32
   je .chk_dest_r32
   cmp r14d, BASE_R128
   je .chk_dest_r128
   jmp .err_invalid

.chk_dest_r8:
    cmp r15d, 3
    ja  .err_invalid
    jmp .chk_src

.chk_dest_r16:
    cmp r15d, 3
    ja  .err_invalid
    jmp .chk_src

.chk_dest_r32:
    cmp r15d, 4
    ja  .err_invalid
    jmp .chk_src

.chk_dest_r128:
    cmp r15d, 1
    ja  .err_invalid    ; R128 só tem índices 0 e 1
    jmp .chk_src

.chk_src:
    ; Pula validação de source se for modo imediato
    cmp r11d, 1
    je .dispatch
    
    ; Pula validação de source para instruções unárias (NOT)
    cmp r8b, 0x03
    je .dispatch
    
    ; VALIDAÇÃO SRC para evitar segfaults (padrão: índices<4, <5 ou <2)
    cmp r10d, BASE_R8
    je .chk_src_r8
    cmp r10d, BASE_R16
    je .chk_src_r16
    cmp r10d, BASE_R32
    je .chk_src_r32
    cmp r10d, BASE_R128
    je .chk_src_r128
    jmp .err_invalid

.chk_src_r8:
    cmp ebx, 3
    ja .err_invalid
    jmp .dispatch

.chk_src_r16:
    cmp ebx, 3
    ja .err_invalid
    jmp .dispatch

.chk_src_r32:
    cmp ebx, 4
    ja .err_invalid
    jmp .dispatch

.chk_src_r128:
    ; Para R128: se modo registrador, apenas índices 0-1 válidos
    ; Se modo imediato, também apenas índices 0-1 válidos (após conversão)
    cmp ebx, 1
    ja  .err_invalid    ; R128 só tem índices 0 e 1
    jmp .dispatch

; DISPATCH INSTRUÇÕES (sem debug syscalls)
.dispatch:
    mov [r13 + PC], eax
    cmp r8b, 0x00
    je .and
    cmp r8b, 0x01
    je .or
    cmp r8b, 0x02
    je .xor
    cmp r8b, 0x03
    je .not
    cmp r8b, 0x04
    je .add
    cmp r8b, 0x05
    je .sub
    cmp r8b, 0x06
    je .halt
    cmp r8b, 0x07
    je .jmp
    cmp r8b, 0x08
    je .jnz
    cmp r8b, 0x09
    je .jz
    cmp r8b, 0x0A
    je .jl
    cmp r8b, 0x0B
    je .jle
    cmp r8b, 0x0C
    je .jg
    cmp r8b, 0x0D
    je .jge
    cmp r8b, 0x0E
    je .jc
    cmp r8b, 0x0F
    je .jnc
    cmp r8b, 0x10
    je .load
    cmp r8b, 0x11
    je .store
    cmp r8b, 0x12
    je .init_r128
.err_invalid:
    mov dword [r13 + EXEC], 0
    jmp .fim
    mov dword [r13 + EXEC], 0
    jmp .fim

.err_oob:
    ; acesso fora do programa
    mov dword [r13 + EXEC], 0
    jmp .fim
; (Restante das rotinas .load, .store, .add, .sub, .halt, .jmp, .jz, etc.)
; Mantém o mesmo corpo original, sem debug syscalls

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; LOAD (carrega da memória para registrador) + Atualização de FLAGS
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.load:
    cmp r14, 0
    je .load_r8
    cmp r14, 1
    je .load_r16
    cmp r14, 2
    je .load_r32
    cmp r14, 3
    je .load_r128
    jmp .loop_safety

.load_r8:
    ; CORREÇÃO: Separar decodificação de instrução e dados
    ; 1. Salvar PC atual
    mov   esi, [r13 + PC]         ; PC atual (aponta para endereço)
    
    ; 2. Ler endereço de dados SEM atualizar PC ainda
    movzx eax, word [r12 + rsi]   ; lê endereço de 16 bits da memória principal
    
    ; 3. Validar bounds do endereço
    cmp   eax, PROG_MAX
    jae   .err_oob
    
    ; 4. Ler dados da memória
    mov   bl, byte [r12 + rax]    ; carrega da memória principal (r12) no endereço
    
    ; 5. Armazenar no registrador
    mov   [r13 + OFF_R8 + r15], bl ; armazena no registrador CPU (r13)
    
    ; 6. APENAS AGORA atualizar PC (5 bytes: opcode + op1 + op2 + endereço 16-bit)
    add   esi, 2                  ; avança PC para pular o endereço (2 bytes)
    mov   [r13 + PC], esi         ; atualiza PC
    
    ; 7. Atualizar flags
    xor edx, edx
    test bl, bl
    sete dl
    test bl, bl
    js .load_r8_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.load_r8_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

.load_r16:
    ; CORREÇÃO: Separar decodificação de instrução e dados
    ; 1. Salvar PC atual
    mov   esi, [r13 + PC]         ; PC atual (aponta para endereço)
    
    ; 2. Ler endereço de dados SEM atualizar PC ainda
    movzx eax, word [r12 + rsi]   ; lê endereço de 16 bits da memória principal
    
    ; 3. Validar bounds do endereço
    cmp   eax, PROG_MAX - 1       ; precisa de 2 bytes consecutivos
    ja    .err_oob
    
    ; 4. Ler dados da memória
    mov   bx, word [r12 + rax]    ; carrega da memória principal (r12) no endereço
    
    ; 5. Armazenar no registrador
    mov   [r13 + r15*2 + OFF_R16], bx ; armazena no registrador CPU (r13)
    
    ; 6. APENAS AGORA atualizar PC
    add   esi, 2                  ; avança PC para pular o endereço (2 bytes)
    mov   [r13 + PC], esi         ; atualiza PC
    
    ; 7. Atualizar flags
    xor edx, edx
    test bx, bx
    sete dl
    test bx, bx
    js .load_r16_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.load_r16_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety
    mov [r13 + FLAGS], dl
    jmp .loop_safety

.load_r32:
    ; CORREÇÃO: Separar decodificação de instrução e dados
    ; 1. Salvar PC atual
    mov   esi, [r13 + PC]         ; PC atual (aponta para endereço)
    
    ; 2. Ler endereço de dados SEM atualizar PC ainda
    movzx eax, word [r12 + rsi]   ; lê endereço de 16 bits da memória principal
    
    ; 3. Validar bounds do endereço
    cmp   eax, PROG_MAX - 3       ; precisa de 4 bytes consecutivos
    ja    .err_oob
    
    ; 4. Ler dados da memória
    mov   ecx, dword [r12 + rax]  ; carrega da memória principal (r12) no endereço
    
    ; 5. Armazenar no registrador
    mov   [r13 + r15*4 + OFF_R32], ecx ; armazena no registrador CPU (r13)
    
    ; 6. APENAS AGORA atualizar PC
    add   esi, 2                  ; avança PC para pular o endereço (2 bytes)
    mov   [r13 + PC], esi         ; atualiza PC
    
    ; 7. Atualizar flags
    xor edx, edx
    test ecx, ecx
    sete dl
    test ecx, ecx
    js .load_r32_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.load_r32_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

.load_r128:
    ; CORREÇÃO: Separar decodificação de instrução e dados
    ; 1. Salvar PC atual
    mov   esi, [r13 + PC]         ; PC atual
    
    ; 2. Ler endereço de dados SEM atualizar PC ainda (pula opcode + op1 + op2)
    add   esi, 3                  ; aponta para o endereço após op1/op2
    movzx eax, word [r12 + rsi]   ; lê endereço de 16 bits da memória principal
    
    ; 3. Validar bounds do endereço
    cmp   eax, PROG_MAX - 15      ; precisa de 16 bytes consecutivos
    ja    .err_oob                ; endereço inválido
    
    ; 4. Ler dados da memória
    movdqu xmm0, [r12 + rax]      ; lê 16 bytes da memória principal
    
    ; 5. Armazenar no registrador
    mov   rcx, r15                ; índice do registrador
    shl   rcx, 4                  ; rcx = índice * 16
    movdqu [r13 + rcx + OFF_R128], xmm0  ; armazena no registrador
    
    ; 6. APENAS AGORA atualizar PC (5 bytes: opcode + op1 + op2 + endereço 16-bit)
    add   esi, 2                  ; avança PC para pular o endereço (2 bytes)
    mov   [r13 + PC], esi         ; atualiza PC para 5 bytes total
    
    ; 7. Atualizar flags
    call .atualizar_flags_128
    jmp .loop_safety


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; STORE (salva valor do registrador na memória)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.store:
    cmp r14, 0
    je .store_r8
    cmp r14, 1
    je .store_r16
    cmp r14, 2
    je .store_r32
    cmp r14, 3
    je .store_r128
    jmp .loop_safety

.store_r8:
    ; CORREÇÃO: Separar decodificação de instrução e dados
    ; 1. Salvar PC atual
    mov   esi, [r13 + PC]         ; PC atual (aponta para endereço)
    
    ; 2. Ler endereço de dados SEM atualizar PC ainda
    movzx eax, word [r12 + rsi]   ; lê endereço de 16 bits da memória principal
    
    ; 3. Validar bounds do endereço
    cmp   eax, PROG_MAX
    jae   .err_oob
    
    ; 4. Ler dados do registrador
    mov   bl, [r13 + OFF_R8 + r15] ; carrega do registrador CPU (r13)
    
    ; 5. Escrever na memória
    mov   [r12 + rax], bl         ; escreve na memória principal (r12) no endereço
    
    ; 6. APENAS AGORA atualizar PC
    add   esi, 2                  ; avança PC para pular o endereço (2 bytes)
    mov   [r13 + PC], esi         ; atualiza PC
    jmp .loop_safety

.store_r16:
    ; CORREÇÃO: Separar decodificação de instrução e dados
    ; 1. Salvar PC atual
    mov   esi, [r13 + PC]         ; PC atual (aponta para endereço)
    
    ; 2. Ler endereço de dados SEM atualizar PC ainda
    movzx eax, word [r12 + rsi]   ; lê endereço de 16 bits da memória principal
    
    ; 3. Validar bounds do endereço
    cmp   eax, PROG_MAX - 1       ; precisa de 2 bytes consecutivos
    ja    .err_oob
    
    ; 4. Ler dados do registrador
    mov   bx, [r13 + r15*2 + OFF_R16] ; carrega do registrador CPU (r13)
    
    ; 5. Escrever na memória
    mov   [r12 + rax], bx         ; escreve na memória principal (r12) no endereço
    
    ; 6. APENAS AGORA atualizar PC
    add   esi, 2                  ; avança PC para pular o endereço (2 bytes)
    mov   [r13 + PC], esi         ; atualiza PC
    jmp .loop_safety

.store_r32:
    ; CORREÇÃO: Separar decodificação de instrução e dados
    ; 1. Salvar PC atual
    mov   esi, [r13 + PC]         ; PC atual (aponta para endereço)
    
    ; 2. Ler endereço de dados SEM atualizar PC ainda
    movzx eax, word [r12 + rsi]   ; lê endereço de 16 bits da memória principal
    
    ; 3. Validar bounds do endereço
    cmp   eax, PROG_MAX - 3       ; precisa de 4 bytes consecutivos
    ja    .err_oob
    
    ; 4. Ler dados do registrador
    mov   ecx, [r13 + r15*4 + OFF_R32] ; carrega do registrador CPU (r13)
    
    ; 5. Escrever na memória
    mov   [r12 + rax], ecx        ; escreve na memória principal (r12) no endereço
    
    ; 6. APENAS AGORA atualizar PC
    add   esi, 2                  ; avança PC para pular o endereço (2 bytes)
    mov   [r13 + PC], esi         ; atualiza PC
    jmp .loop_safety
    jmp .loop_safety

.store_r128:
    ; CORREÇÃO: Separar decodificação de instrução e dados
    ; 1. Salvar PC atual
    mov   esi, [r13 + PC]         ; PC atual
    
    ; 2. Ler endereço de dados SEM atualizar PC ainda (pula opcode + op1 + op2)
    add   esi, 3                  ; aponta para o endereço após op1/op2
    movzx eax, word [r12 + rsi]   ; lê endereço de 16 bits da memória principal
    
    ; 3. Validar bounds do endereço
    cmp   eax, PROG_MAX - 15      ; precisa de 16 bytes consecutivos
    ja    .err_oob                ; endereço inválido
    
    ; 4. Ler dados do registrador
    mov   rcx, r15                ; índice do registrador
    shl   rcx, 4                  ; rcx = índice * 16
    movdqu xmm0, [r13 + rcx + OFF_R128] ; carrega registrador 128
    
    ; 5. Escrever na memória
    movdqu [r12 + rax], xmm0      ; escreve na memória principal
    
    ; 6. APENAS AGORA atualizar PC (5 bytes: opcode + op1 + op2 + endereço 16-bit)
    add   esi, 2                  ; avança PC para pular o endereço (2 bytes)
    mov   [r13 + PC], esi         ; atualiza PC para 5 bytes total
    jmp .loop_safety

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Operações Lógicas: AND, OR, XOR, NOT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.and:
    cmp r11, 1
    je .and_const
    cmp r14, 0
    je .and_r8
    cmp r14, 1
    je .and_r16
    cmp r14, 2
    je .and_r32
    cmp r14, 3
    je .and_r128
    jmp .loop_safety

.and_const:
    cmp r14, 0
    je .andc_r8
    cmp r14, 1
    je .andc_r16
    cmp r14, 2
    je .andc_r32
    cmp r14, 3
    je .andc_r128
    jmp .loop_safety

; ===== AND R8 Registrador =====
; ===== AND R8 Registrador =====
.and_r8:
    lea    rdx, [r13 + OFF_R8]
    mov    rcx, r15
    add    rdx, rcx              ; endereço do registrador destino
    mov    al, [rdx]             ; valor destino
    and    ebx, 0x0F             ; CORREÇÃO: garante índice correto
    lea    rsi, [r13 + OFF_R8 + rbx]  ; endereço do registrador fonte  
    mov    cl, [rsi]             ; valor fonte
    and    al, cl                ; al = al & cl
    mov    [rdx], al             ; armazena resultado
    xor    edx, edx
    test   al, al
    sete   dl
    test   al, al
    js     .and_r8_setn
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety
.and_r8_setn:
    or     dl, 0x04
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety

.and_r16:
    mov ax, [r13 + r15*2 + OFF_R16]
    and ebx, 0x0F                     ; CORREÇÃO: garante índice correto
    and ax, [r13 + OFF_R16 + rbx*2]
    mov [r13 + r15*2 + OFF_R16], ax
    xor edx, edx
    test ax, ax
    sete dl
    test ax, ax
    js .and_r16_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.and_r16_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

.and_r32:
    mov eax, [r13 + r15*4 + OFF_R32]
    and ebx, 0x0F                     ; CORREÇÃO: garante índice correto
    and eax, [r13 + OFF_R32 + rbx*4]
    mov [r13 + r15*4 + OFF_R32], eax
    xor edx, edx
    test eax, eax
    sete dl
    test eax, eax
    js .and_r32_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.and_r32_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

.and_r128:
    ; CORREÇÃO: Limpar registradores SSE antes de usar
    pxor xmm0, xmm0
    pxor xmm1, xmm1
    
    ; Calcular endereço do registrador destino
    mov rax, r15
    shl rax, 4
    lea rax, [r13 + rax + OFF_R128]
    movdqu xmm0, [rax]                        ; carrega destino

    ; Calcular endereço do registrador fonte
    mov rsi, rbx
    shl rsi, 4
    lea rsi, [r13 + rsi + OFF_R128]
    movdqu xmm1, [rsi]                        ; carrega fonte

    pand xmm0, xmm1                           ; AND
    movdqu [rax], xmm0                        ; salva resultado
    call .atualizar_flags_128
    jmp .loop_safety

; ===== AND R8 Imediato =====
.andc_r8:
    lea    rdx, [r13 + OFF_R8]
    mov    rcx, r15
    add    rdx, rcx
    mov    al, bl
    and    al, byte [rdx]
    mov    byte [rdx], al
    xor    edx, edx
    test   al, al
    sete   dl
    test   al, al
    js     .andc_r8_setn
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety
.andc_r8_setn:
    or     dl, 0x04
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety


.andc_r16:
    mov ax, [r12 + rax]                     ; Lê constante de 16 bits
    add rax, 2
    and [r13 + r15*2 + OFF_R16], ax             ; Aplica AND com registrador destino
    mov [r13 + PC], rax
    mov ax, [r13 + r15*2 + OFF_R16]
             ; Recarrega resultado
    xor edx, edx
    test ax, ax
    sete dl                                 ; Flag Z
    test ax, ax
    js .andc_r16_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety

.andc_r16_setn:
    or dl, 0x04                             ; Flag N
    mov [r13 + FLAGS], dl
    jmp .loop_safety

.andc_r32:
    mov eax, [r12 + rax]                    ; Lê constante de 32 bits
    add rax, 4
    and [r13 + r15*4 + OFF_R32], eax
    mov [r13 + PC], rax
    mov eax, [r13 + r15*4 + OFF_R32]
            ; Recarrega resultado
    xor edx, edx
    test eax, eax
    sete dl
    test eax, eax
    js .andc_r32_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.andc_r32_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

.andc_r128:
    mov   esi, [r13 + PC]         ; PC original
    mov   rcx, r15
    shl   rcx, 4
    movdqu xmm0, [r13 + rcx + OFF_R128]  ; registrador destino
    lea   rdx, [r12 + rsi]        ; endereço na memória principal
    movdqu xmm1, [rdx]            ; carrega constante da memória
    pand  xmm0, xmm1
    movdqu [r13 + rcx + OFF_R128], xmm0
    call .atualizar_flags_128
    jmp .loop_safety

.or:
    cmp r11, 1
    je .or_const
    cmp r14, 0
    je .or_r8
    cmp r14, 1
    je .or_r16
    cmp r14, 2
    je .or_r32
    cmp r14, 3
    je .or_r128
    jmp .loop_safety

.or_const:
    cmp r14, 0
    je .orc_r8
    cmp r14, 1
    je .orc_r16
    cmp r14, 2
    je .orc_r32
    cmp r14, 3
    je .orc_r128
    jmp .loop_safety

; ===== OR R8 Registrador =====
; ===== OR R8 Registrador =====
.or_r8:
    lea    rdx, [r13 + OFF_R8]
    mov    rcx, r15
    add    rdx, rcx              ; endereço do registrador destino
    mov    al, [rdx]             ; valor destino
    and    ebx, 0x0F             ; CORREÇÃO: garante índice correto
    lea    rsi, [r13 + OFF_R8 + rbx]  ; endereço do registrador fonte
    mov    cl, [rsi]             ; valor fonte (usa CL em vez de BL)
    or     al, cl                ; al = al | cl
    mov    [rdx], al             ; armazena resultado
    xor    edx, edx
    test   al, al
    sete   dl
    test   al, al
    js     .or_r8_setn
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety
.or_r8_setn:
    or     dl, 0x04
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety

; OR com registrador - OFF_R16
.or_r16:
    mov ax, [r13 + r15*2 + OFF_R16]
    and ebx, 0x0F                     ; CORREÇÃO: garante índice correto
    or ax, [r13 + OFF_R16 + rbx*2]
    mov [r13 + r15*2 + OFF_R16], ax
    xor edx, edx
    test ax, ax
    sete dl
    test ax, ax
    js .or_r16_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.or_r16_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

; OR com registrador - OFF_R32
.or_r32:
    mov eax, [r13 + r15*4 + OFF_R32]
    and ebx, 0x0F                     ; CORREÇÃO: garante índice correto
    or eax, [r13 + OFF_R32 + rbx*4]
    mov [r13 + r15*4 + OFF_R32], eax
    xor edx, edx
    test eax, eax
    sete dl
    test eax, eax
    js .or_r32_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.or_r32_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

; OR com registrador - OFF_R128
.or_r128:
    ; CORREÇÃO: Limpar registradores SSE antes de usar
    pxor xmm0, xmm0
    pxor xmm1, xmm1
    
    ; Calcular endereço do registrador destino
    mov rax, r15
    shl rax, 4
    lea rax, [r13 + rax + OFF_R128]
    movdqu xmm0, [rax]                        ; carrega destino

    ; Calcular endereço do registrador fonte
    mov rsi, rbx
    shl rsi, 4
    lea rsi, [r13 + rsi + OFF_R128]
    movdqu xmm1, [rsi]                        ; carrega fonte

    por xmm0, xmm1                            ; OR
    movdqu [rax], xmm0                        ; salva resultado
    call .atualizar_flags_128
    jmp .loop_safety

; ===== OR R8 Imediato =====
.orc_r8:
    lea    rdx, [r13 + OFF_R8]
    mov    rcx, r15
    add    rdx, rcx
    mov    al, bl
    or     al, byte [rdx]
    mov    byte [rdx], al
    xor    edx, edx
    test   al, al
    sete   dl
    test   al, al
    js     .orc_r8_setn
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety
.orc_r8_setn:
    or     dl, 0x04
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety

; OR com constante - OFF_R16
.orc_r16:
    mov ax, [r12 + rax]
    add rax, 2
    or [r13 + r15*2 + OFF_R16], ax
    mov [r13 + PC], rax
    mov ax, [r13 + r15*2 + OFF_R16]

    xor edx, edx
    test ax, ax
    sete dl
    test ax, ax
    js .orc_r16_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.orc_r16_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

; OR com constante - OFF_R32
.orc_r32:
    mov eax, [r12 + rax]
    add rax, 4
    or [r13 + r15*4 + OFF_R32], eax
    mov [r13 + PC], rax
    mov eax, [r13 + r15*4 + OFF_R32]

    xor edx, edx
    test eax, eax
    sete dl
    test eax, eax
    js .orc_r32_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.orc_r32_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

; OR com constante - OFF_R128
.orc_r128:
    mov   esi, [r13 + PC]         ; PC original
    mov   rcx, r15
    shl   rcx, 4
    movdqu xmm0, [r13 + rcx + OFF_R128]  ; registrador destino
    lea   rdx, [r12 + rsi]        ; endereço na memória principal
    movdqu xmm1, [rdx]            ; carrega constante da memória
    por   xmm0, xmm1
    movdqu [r13 + rcx + OFF_R128], xmm0
    call .atualizar_flags_128
    jmp .loop_safety

.xor:
    cmp r11, 1
    je .xor_const
    cmp r14, 0
    je .xor_r8
    cmp r14, 1
    je .xor_r16
    cmp r14, 2
    je .xor_r32
    cmp r14, 3
    je .xor_r128
    jmp .loop_safety

.xor_const:
    cmp r14, 0
    je .xorc_r8
    cmp r14, 1
    je .xorc_r16
    cmp r14, 2
    je .xorc_r32
    cmp r14, 3
    je .xorc_r128
    jmp .loop_safety

; ===== XOR R8 Registrador =====
; ===== XOR R8 Registrador =====
.xor_r8:
    lea    rdx, [r13 + OFF_R8]
    mov    rcx, r15
    add    rdx, rcx              ; endereço do registrador destino
    mov    al, [rdx]             ; valor destino
    and    ebx, 0x0F             ; CORREÇÃO: garante índice correto
    lea    rsi, [r13 + OFF_R8 + rbx]  ; endereço do registrador fonte
    mov    cl, [rsi]             ; valor fonte (usa CL em vez de BL)
    xor    al, cl                ; al = al ^ cl
    mov    [rdx], al             ; armazena resultado
    xor    edx, edx
    test   al, al
    sete   dl
    test   al, al
    js     .xor_r8_setn
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety
.xor_r8_setn:
    or     dl, 0x04
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety

; XOR com registrador - OFF_R16
.xor_r16:
    mov ax, [r13 + r15*2 + OFF_R16]
    and ebx, 0x0F                     ; CORREÇÃO: garante índice correto
    xor ax, [r13 + OFF_R16 + rbx*2]
    mov [r13 + r15*2 + OFF_R16], ax
    xor edx, edx
    test ax, ax
    sete dl
    test ax, ax
    js .xor_r16_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.xor_r16_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

; XOR com registrador - OFF_R32
.xor_r32:
    mov eax, [r13 + r15*4 + OFF_R32]
    and ebx, 0x0F                     ; CORREÇÃO: garante índice correto
    xor eax, [r13 + OFF_R32 + rbx*4]
    mov [r13 + r15*4 + OFF_R32], eax
    xor edx, edx
    test eax, eax
    sete dl
    test eax, eax
    js .xor_r32_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.xor_r32_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

; XOR com registrador - OFF_R128
.xor_r128:
    ; CORREÇÃO: Limpar registradores SSE antes de usar
    pxor xmm0, xmm0
    pxor xmm1, xmm1
    
    ; Calcular endereço do registrador destino
    mov rax, r15
    shl rax, 4
    lea rax, [r13 + rax + OFF_R128]
    movdqu xmm0, [rax]                        ; carrega destino

    ; Calcular endereço do registrador fonte
    mov rsi, rbx
    shl rsi, 4
    lea rsi, [r13 + rsi + OFF_R128]
    movdqu xmm1, [rsi]                        ; carrega fonte

    pxor xmm0, xmm1                           ; XOR
    movdqu [rax], xmm0                        ; salva resultado
    call .atualizar_flags_128
    jmp .loop_safety


; ===== XOR R8 Imediato =====
.xorc_r8:
    lea    rdx, [r13 + OFF_R8]
    mov    rcx, r15
    add    rdx, rcx
    mov    al, bl
    xor    al, byte [rdx]
    mov    byte [rdx], al
    xor    edx, edx
    test   al, al
    sete   dl
    test   al, al
    js     .xorc_r8_setn
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety
.xorc_r8_setn:
    or     dl, 0x04
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety



; XOR com constante - OFF_R16
.xorc_r16:
    mov ax, [r12 + rax]
    add rax, 2
    xor [r13 + r15*2 + OFF_R16], ax
    mov [r13 + PC], rax
    mov ax, [r13 + r15*2 + OFF_R16]

    xor edx, edx
    test ax, ax
    sete dl
    test ax, ax
    js .xorc_r16_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.xorc_r16_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

; XOR com constante - OFF_R32
.xorc_r32:
    mov eax, [r12 + rax]
    add rax, 4
    xor [r13 + r15*4 + OFF_R32], eax
    mov [r13 + PC], rax
    mov eax, [r13 + r15*4 + OFF_R32]

    xor edx, edx
    test eax, eax
    sete dl
    test eax, eax
    js .xorc_r32_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.xorc_r32_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

; XOR com constante - OFF_R128
.xorc_r128:
    mov   esi, [r13 + PC]         ; PC original
    mov   rcx, r15
    shl   rcx, 4
    movdqu xmm0, [r13 + rcx + OFF_R128]  ; registrador destino
    lea   rdx, [r12 + rsi]        ; endereço na memória principal
    movdqu xmm1, [rdx]            ; carrega constante da memória
    pxor  xmm0, xmm1
    movdqu [r13 + rcx + OFF_R128], xmm0
    call .atualizar_flags_128
    jmp .loop_safety

.not:
    cmp r14, 0
    je .not_r8
    cmp r14, 1
    je .not_r16
    cmp r14, 2
    je .not_r32
    cmp r14, 3
    je .not_r128
    jmp .loop_safety

; ===== NOT R8 Registrador =====
.not_r8:
    mov    al, [r13 + r15 + OFF_R8]
    not    al
    mov    [r13 + r15 + OFF_R8], al
    xor    edx, edx
    test   al, al
    sete   dl
    test   al, al
    js     .not_r8_setn
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety
.not_r8_setn:
    or     dl, 0x04
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety

; NOT com registrador - OFF_R16
.not_r16:
    mov ax, [r13 + r15*2 + OFF_R16]

    not ax
    mov [r13 + r15*2 + OFF_R16], ax
    xor edx, edx
    test ax, ax
    sete dl
    test ax, ax
    js .not_r16_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.not_r16_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

; NOT com registrador - OFF_R32
.not_r32:
    mov eax, [r13 + r15*4 + OFF_R32]

    not eax
    mov [r13 + r15*4 + OFF_R32], eax
    xor edx, edx
    test eax, eax
    sete dl
    test eax, eax
    js .not_r32_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.not_r32_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

; NOT com registrador - OFF_R128
.not_r128:
    mov rcx, r15
    shl rcx, 4
    movdqu xmm0, [r13 + rcx + OFF_R128]
    pcmpeqb xmm1, xmm1
    pxor xmm0, xmm1
    movdqu [r13 + rcx + OFF_R128], xmm0
    call .atualizar_flags_128
    jmp .loop_safety

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Operações Aritméticas: ADD, SUB Para todas as bases
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ADD
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.add:
    cmp r11, 1
    je .add_const
    cmp r14, 0
    je .add_r8
    cmp r14, 1
    je .add_r16
    cmp r14, 2
    je .add_r32
    cmp r14, 3
    je .add_r128
    jmp .loop_safety

.add_const:
    cmp r14, 0
    je .addc_r8
    cmp r14, 1
    je .addc_r16
    cmp r14, 2
    je .addc_r32
    cmp r14, 3
    je .addc_r128
    jmp .loop_safety

; ===== ADD R8 Registrador =====
; ===== ADD R8 Registrador =====
.add_r8:
    ; Calcula endereço do registrador destino
    lea    rdx, [r13 + OFF_R8 + r15]
    ; Carrega valores
    mov    al, byte [rdx]             ; valor destino
    and    ebx, 0x0F                  ; CORREÇÃO: garante índice correto
    lea    rcx, [r13 + OFF_R8 + rbx]  ; endereço fonte com índice correto
    mov    cl, byte [rcx]             ; valor fonte
    ; Executa soma
    add    al, cl                     ; al = al + cl
    ; Armazena resultado
    mov    [rdx], al
    ; Atualiza FLAGS Z, C, N
    xor    edx, edx
    test   al, al
    sete   dl
    setc   dh
    test   al, al
    js     .add_r8_setn
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety
.add_r8_setn:
    or     dl, 0x04
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety

; Implementação para .add_r16 (registrador de 16 bits)
.add_r16:
    mov ax, [r13 + r15*2 + OFF_R16]
           ; carrega valor do registrador de destino (OFF_R16[idx_dest])
    and ebx, 0x0F                         ; CORREÇÃO: garante índice correto
    add ax, [r13 + OFF_R16 + rbx*2]           ; soma com o valor do registrador fonte (OFF_R16[idx_src])
    mov [r13 + r15*2 + OFF_R16], ax           ; armazena o resultado de volta no registrador destino

    ; Atualiza as FLAGS com base no resultado
    xor edx, edx                          ; zera edx
    test ax, ax                           ; testa se o resultado é zero
    sete dl                               ; Z
    setc dh                               ; C
    test ax, ax                           ; testa novamente para sinal
    js .add_r16_setn                      ; se negativo, pula para setar N
    mov [r13 + FLAGS], dl                 ; armazena Z e C
    jmp .loop_safety

.add_r16_setn:
    or dl, 0x04                           ; seta N
    mov [r13 + FLAGS], dl                 ; armazena Z, C, N
    jmp .loop_safety

.add_r32:
    mov eax, [r13 + r15*4 + OFF_R32]
    and ebx, 0x0F                     ; CORREÇÃO: garante índice correto
    add eax, [r13 + OFF_R32 + rbx*4]
    mov [r13 + r15*4 + OFF_R32], eax

 ; Atualiza as FLAGS com base no resultado
    xor edx, edx                          ; zera o registrador edx
    test eax, eax                         ; testa se o resultado é zero
    sete dl                               ; seta bit 0 (Z) se resultado == 0
    setc dh                               ; seta bit 8 (C) se houve carry (overflow)
    test eax, eax                         ; testa novamente para sinal
    js .add_r32_setn                      ; se negativo, pula para setar N
    mov [r13 + FLAGS], dl                 ; armazena apenas Z e C (sem N)
    jmp .loop_safety

.add_r32_setn:
    or dl, 0x04                           ; seta bit 2 (N)
    mov [r13 + FLAGS], dl                 ; armazena Z, C e N conforme necessário
    jmp .loop_safety

.add_r128:
    ; Soma entre registradores de 128 bits
    ; idx_dest = r15, idx_src = rbx

    ; CORREÇÃO: Limpar registradores SSE antes de usar para evitar lixo
    pxor xmm0, xmm0
    pxor xmm1, xmm1

    ; Calcular endereço do registrador destino
    mov rax, r15
    shl rax, 4
    lea rax, [r13 + rax + OFF_R128]
    movdqu xmm0, [rax]                        ; carrega destino

    ; Calcular endereço do registrador fonte
    mov rsi, rbx
    shl rsi, 4
    lea rsi, [r13 + rsi + OFF_R128]
    movdqu xmm1, [rsi]                        ; carrega fonte

    paddq xmm0, xmm1                          ; soma
    movdqu [rax], xmm0                        ; salva resultado

    call .atualizar_flags_128
    jmp .loop_safety
; ===== ADD R8 Imediato =====
.addc_r8:
    lea    rdx, [r13 + OFF_R8 + r15]
    ; O valor imediato está no último byte lido (op2)
    mov    esi, [r13 + PC]       ; PC atual
    dec    esi                   ; retrocede para o valor imediato
    movzx  ecx, byte [r12 + rsi] ; lê valor imediato de 8 bits
    ; Avança PC para próxima instrução (formato R8 imediato é de 3 bytes)
    mov    esi, [r13 + PC]       ; recarrega PC
    ; PC já foi incrementado 3 vezes no fetch, então já aponta corretamente
    mov    al, byte [rdx]        ; carrega registrador destino
    add    al, cl                ; soma valor imediato
    mov    [rdx], al             ; armazena resultado
    xor    edx, edx
    test   al, al
    sete   dl
    setc   dh
    test   al, al
    js     .addc_r8_setn
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety
.addc_r8_setn:
    or     dl, 0x04
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety
    jmp    .loop_safety

; Implementação para .addc_r16 (registro de 16 bits com constante)
.addc_r16:
    lea    rdx, [r13 + r15*2 + OFF_R16]
    ; O valor imediato está nos últimos 2 bytes que acabamos de "ler" como op2 + próximo byte
    mov    esi, [r13 + PC]       ; PC atual (aponta 1 byte após o valor imediato)
    sub    esi, 1                ; retrocede para o início do valor imediato
    movzx  ecx, word [r12 + rsi] ; lê valor imediato de 16 bits
    mov    esi, [r13 + PC]       ; restaura PC atual
    add    esi, 1                ; avança PC para próxima instrução (mais 1 byte para completar o imediato)
    mov    [r13 + PC], esi       ; atualiza PC
    mov    ax, word [rdx]        ; carrega registrador destino
    add    ax, cx                ; soma valor imediato
    mov    [rdx], ax             ; armazena resultado
    xor    edx, edx
    test   ax, ax
    sete   dl                        ; Z
    setc   dh                        ; C
    test   ax, ax
    js     .addc_r16_setn            ; N
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety
.addc_r16_setn:
    or     dl, 0x04
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety

; Implementação para .addc_r32 (registro de 32 bits com constante)
.addc_r32:
    lea    rdx, [r13 + r15*4 + OFF_R32]
    ; O valor imediato de 32 bits está nos últimos bytes lidos + próximos bytes
    mov    esi, [r13 + PC]       ; PC atual
    sub    esi, 1                ; retrocede para o início do valor imediato
    mov    ecx, dword [r12 + rsi]; lê valor imediato de 32 bits
    add    esi, 4                ; avança para pular todo o valor imediato (4 bytes)
    mov    [r13 + PC], esi       ; atualiza PC
    mov    eax, dword [rdx]      ; carrega registrador destino
    add    eax, ecx              ; soma valor imediato
    mov    [rdx], eax            ; armazena resultado
    xor    edx, edx
    test   eax, eax
    sete   dl                        ; Z
    setc   dh                        ; C
    test   eax, eax
    js     .addc_r32_setn            ; N
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety
.addc_r32_setn:
    or     dl, 0x04
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety

; Implementação para .addc_r128 (registro de 128 bits com constante)
.addc_r128:
    ; Soma com constante para 128 bits
    mov   esi, [r13 + PC]         ; PC original
    mov   rcx, r15
    shl   rcx, 4
    movdqu xmm0, [r13 + rcx + OFF_R128]  ; registrador destino
    lea   rdx, [r12 + rsi]        ; endereço na memória principal
    movdqu xmm1, [rdx]            ; carrega constante da memória
    paddq xmm0, xmm1
    movdqu [r13 + rcx + OFF_R128], xmm0

    call .atualizar_flags_128
    jmp .loop_safety

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; SUB
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.sub:
    cmp r11, 1
    je .sub_const
    cmp r14, 0
    je .sub_r8
    cmp r14, 1
    je .sub_r16
    cmp r14, 2
    je .sub_r32
    cmp r14, 3
    je .sub_r128
    jmp .loop_safety

.sub_const:
    cmp r14, 0
    je .subc_r8
    cmp r14, 1
    je .subc_r16
    cmp r14, 2
    je .subc_r32
    cmp r14, 3
    je .subc_r128
    jmp .loop_safety

; ===== SUB R8 Registrador =====
.sub_r8:
    ; Implementação corrigida
    and    ebx, 0x0F                  
    mov    al, [r13 + OFF_R8 + r15]   
    mov    dl, [r13 + OFF_R8 + rbx]   
    sub    al, dl                     
    mov    [r13 + OFF_R8 + r15], al   
    
    xor    esi, esi                   
    test   al, al
    sete   sil
    test   al, al
    js     .sub_r8_setn
    mov    [r13 + FLAGS], sil
    jmp    .loop_safety
.sub_r8_setn:
    or     sil, 0x04
    mov    [r13 + FLAGS], sil
    jmp    .loop_safety

; Implementação para .sub_r16
.sub_r16:
    mov ax, [r13 + r15*2 + OFF_R16]
    and ebx, 0x0F                     ; CORREÇÃO: garante índice correto
    sub ax, [r13 + OFF_R16 + rbx*2]
    mov [r13 + r15*2 + OFF_R16], ax
    xor edx, edx
    test ax, ax
    sete dl
    setc dh
    test ax, ax
    js .sub_r16_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.sub_r16_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

; Implementação para .sub_r32
.sub_r32:
    mov eax, [r13 + r15*4 + OFF_R32]
    and ebx, 0x0F                     ; CORREÇÃO: garante índice correto
    sub eax, [r13 + OFF_R32 + rbx*4]
    mov [r13 + r15*4 + OFF_R32], eax
    xor edx, edx
    test eax, eax
    sete dl
    setc dh
    test eax, eax
    js .sub_r32_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.sub_r32_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

.sub_r128:
    ; Subtração entre registradores 128 bits
    ; CORREÇÃO: Limpar registradores SSE antes de usar
    pxor xmm0, xmm0
    pxor xmm1, xmm1
    
    ; Calcular endereço do registrador destino
    mov rax, r15
    shl rax, 4
    lea rax, [r13 + rax + OFF_R128]
    movdqu xmm0, [rax]                        ; carrega destino

    ; Calcular endereço do registrador fonte
    mov rsi, rbx
    shl rsi, 4
    lea rsi, [r13 + rsi + OFF_R128]
    movdqu xmm1, [rsi]                        ; carrega fonte

    psubq xmm0, xmm1                          ; subtração
    movdqu [rax], xmm0                        ; salva resultado

    call .atualizar_flags_128
    jmp .loop_safety

; ===== SUB R8 Imediato =====
.subc_r8:
    lea    rdx, [r13 + OFF_R8 + r15]
    mov    al, bl
    sub    al, byte [rdx]
    mov    [rdx], al
    xor    edx, edx
    test   al, al
    sete   dl
    setc   dh
    test   al, al
    js     .subc_r8_setn
    mov    [r13 + FLAGS], dl
    jmp    .loop_safety
.subc_r8_setn:
    or     dl, 0x04
    mov    [r13 + FLAGS], dl
    jmp .loop_safety

; Implementação para .subc_r16 (subtração com constante, 16 bits)
.subc_r16:
    mov ax, [r12 + rax]                     ; Carrega a constante de 16 bits da memória
    add rax, 2                              ; Avança o PC
    sub [r13 + r15*2 + OFF_R16], ax             ; Subtrai a constante do registrador destino
    mov [r13 + PC], rax                     ; Atualiza o PC
    mov ax, [r13 + r15*2 + OFF_R16]
             ; Recarrega para testar flags
    xor edx, edx
    test ax, ax
    sete dl
    setc dh
    test ax, ax
    js .subc_r16_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.subc_r16_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

; Implementação para .subc_r32 (subtração com constante, 32 bits)
.subc_r32:
    mov eax, [r12 + rax]                    ; Carrega a constante de 32 bits
    add rax, 4                              ; Avança o PC
    sub [r13 + r15*4 + OFF_R32], eax            ; Subtrai a constante do registrador destino
    mov [r13 + PC], rax                     ; Atualiza o PC
    mov eax, [r13 + r15*4 + OFF_R32]
            ; Recarrega resultado para checar flags
    xor edx, edx
    test eax, eax
    sete dl
    setc dh
    test eax, eax
    js .subc_r32_setn
    mov [r13 + FLAGS], dl
    jmp .loop_safety
.subc_r32_setn:
    or dl, 0x04
    mov [r13 + FLAGS], dl
    jmp .loop_safety

.subc_r128:
    mov   esi, [r13 + PC]         ; PC original
    mov   rcx, r15
    shl   rcx, 4
    movdqu xmm0, [r13 + rcx + OFF_R128]  ; registrador destino
    lea   rdx, [r12 + rsi]        ; endereço na memória principal
    movdqu xmm1, [rdx]            ; carrega constante da memória
    psubq xmm0, xmm1
    movdqu [r13 + rcx + OFF_R128], xmm0

    call .atualizar_flags_128
    jmp .loop_safety

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; JMP (incondicional) baseado na base r14
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.jmp:
    cmp r14, 0
    je .jmp_r8
    cmp r14, 1
    je .jmp_r16
    cmp r14, 2
    je .jmp_r32
    cmp r14, 3
    je .jmp_r128
    jmp .loop_safety

.jmp_r8:
    movzx eax, byte [r13 + OFF_R8 + r15]
    mov [r13 + PC], eax
    jmp .loop_safety

.jmp_r16:
    movzx eax, word [r13 + r15*2 + OFF_R16]

    mov [r13 + PC], eax
    jmp .loop_safety

.jmp_r32:
    mov eax, [r13 + r15*4 + OFF_R32]

    mov [r13 + PC], eax
    jmp .loop_safety

.jmp_r128:
    mov rcx, r15
    shl rcx, 4
    mov eax, dword [r13 + rcx + OFF_R128]  ; usa só os 4 bytes mais baixos
    mov [r13 + PC], eax
    jmp .loop_safety

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Condicionais - verificam FLAGS e saltam via .jmp
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.jz:
    test byte [r13 + FLAGS], 0x01   ; Z
    jz .loop_safety
    jmp .jmp

.jnz:
    test byte [r13 + FLAGS], 0x01
    jnz .loop_safety
    jmp .jmp

.jl:
    test byte [r13 + FLAGS], 0x04   ; N
    jz .loop_safety
    jmp .jmp

.jle:
    test byte [r13 + FLAGS], 0x01   ; Z
    jnz .jmp
    test byte [r13 + FLAGS], 0x04   ; N
    jnz .jmp
    jmp .loop_safety

.jg:
    test byte [r13 + FLAGS], 0x01
    jnz .loop_safety
    test byte [r13 + FLAGS], 0x04
    jnz .loop_safety
    jmp .jmp

.jge:
    test byte [r13 + FLAGS], 0x04   ; N
    jz .jmp
    jmp .loop_safety

.jc:
    test byte [r13 + FLAGS], 0x02   ; C
    jz .loop_safety
    jmp .jmp

.jnc:
    test byte [r13 + FLAGS], 0x02
    jnz .loop_safety
    jmp .jmp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Rotina para atualizar as flags (Z e N) com base em xmm0 (OFF_R128)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.atualizar_flags_128:
    ; Usa a pilha para armazenar temporariamente o valor de 128 bits
    sub rsp, 16                     ; aloca 16 bytes na pilha
    movdqu [rsp], xmm0              ; armazena xmm0 na pilha

    ; Verifica Z (zero flag): se todos os 128 bits forem zero
    mov rax, qword [rsp]
    or  rax, qword [rsp + 8]
    test rax, rax
    jnz .not_zero_128
    or byte [r13 + FLAGS], 0x01     ; seta Z
    jmp .check_neg_128

.not_zero_128:
    and byte [r13 + FLAGS], 0xFE    ; limpa Z

.check_neg_128:
    ; Verifica N (negativo) - MSB do último byte
    mov al, byte [rsp + 15]
    test al, 0x80
    jz .not_neg_128
    or byte [r13 + FLAGS], 0x04     ; seta N
    jmp .end_flags_128

.not_neg_128:
    and byte [r13 + FLAGS], 0xFB    ; limpa N

.end_flags_128:
    add rsp, 16                     ; libera espaço da pilha
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; HALT
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.halt:
    mov dword [r13 + EXEC], 0
    jmp .fim

.halt_direct:
    ; HALT tem apenas 1 byte, incrementa PC em 1
    mov eax, [r13 + PC]
    inc eax
    mov [r13 + PC], eax
    mov dword [r13 + EXEC], 0
    jmp .fim

.fim:
    pop r10
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbx
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; INIT_R128 - Inicialização direta de registradores R128 para testes
; Formato: 0x12 [reg] [padrão]
; Padrões: 0x00=zeros, 0x01=ones, 0x02=alternado, 0x03=crescente
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.init_r128:
    ; Validar apenas o índice do registrador (deve ser 0 ou 1)
    cmp r15d, 1
    ja .err_invalid
    
    mov rcx, r15        ; índice do registrador (0 ou 1)
    shl rcx, 4          ; rcx = índice * 16 (offset em bytes)
    
    ; Verifica o padrão solicitado (em ebx)
    cmp ebx, 0
    je .init_zeros
    cmp ebx, 1
    je .init_ones
    cmp ebx, 2
    je .init_alternado
    cmp ebx, 3
    je .init_crescente
    jmp .err_invalid

.init_zeros:
    pxor xmm0, xmm0
    movdqu [r13 + rcx + OFF_R128], xmm0
    jmp .init_r128_end

.init_ones:
    pcmpeqb xmm0, xmm0  ; seta todos os bits para 1
    movdqu [r13 + rcx + OFF_R128], xmm0
    jmp .init_r128_end

.init_alternado:
    ; Padrão 0xAA55AA55...
    mov rax, 0xAA55AA55AA55AA55
    movq xmm0, rax
    movlhps xmm0, xmm0  ; duplica para 128 bits
    movdqu [r13 + rcx + OFF_R128], xmm0
    jmp .init_r128_end

.init_crescente:
    ; Padrão 0x01020304...0F10
    mov rax, 0x0807060504030201
    mov rdx, 0x100F0E0D0C0B0A09
    movq xmm0, rax
    movq xmm1, rdx
    movlhps xmm0, xmm1
    movdqu [r13 + rcx + OFF_R128], xmm0
    jmp .init_r128_end

.init_r128_end:
    call .atualizar_flags_128
    jmp .loop_safety

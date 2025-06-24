global _start_cycle_cpu

section .text

%define R8      0
%define R16     4
%define R32     12
%define R128    32
%define FLAGS   64
%define PC      68
%define EXEC    72

_start_cycle_cpu:
    push rbx
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    push r10

    mov r13, rcx        ; ponteiro para CPU
    mov r12, rdx        ; ponteiro para memória

.loop:
    cmp dword [r13 + EXEC], 0
    je .fim

    mov eax, [r13 + PC] ; carrega PC

    movzx r10, byte [r12 + rax] ; opcode
    inc rax
    movzx edx, byte [r12 + rax] ; op1
    inc rax
    movzx ecx, byte [r12 + rax] ; op2 (valor imediato ou reg)
    inc rax

    mov [r13 + PC], eax ; atualiza PC somente após leitura completa

    ; decodificar operandos
    movzx r15, dl
    shr r15, 4                 ; registrador destino
    movzx r14, dl
    and r14, 0x0F              ; segundo operando (reg fonte)

    cmp r10b, 0x01    ; MOV R1, CONST
    je .mov_const
    cmp r10b, 0x02
    je .sub
    cmp r10b, 0x06
    je .add
    cmp r10b, 0x0C
    je .jmp
    cmp r10b, 0x0D
    je .jz
    cmp r10b, 0x0A
    je .halt

    jmp .opcode_invalido

.mov_const:
    mov rax, r15
    mov [r13 + R32 + rax * 4], ecx
    jmp .loop

.sub:
    mov rdi, r15                         ; salva o índice de destino
    mov eax, [r13 + R32 + r15 * 4]       ; lê valor de Rdest
    sub eax, [r13 + R32 + r14 * 4]       ; subtrai Rsrc
    mov [r13 + R32 + rdi * 4], eax       ; salva o resultado em Rdest

    test eax, eax
    sete dl                             ; Z
    mov byte [r13 + FLAGS], dl
    test eax, eax
    js .negativo
    jmp .loop

.negativo:
    or byte [r13 + FLAGS], 0x04         ; seta bit de negativo (bit 2)
    jmp .loop

.add:
    mov rdi, r15
    mov eax, [r13 + R32 + r15 * 4]
    add eax, [r13 + R32 + r14 * 4]
    mov [r13 + R32 + rdi * 4], eax
    jmp .loop

.jmp:
    mov eax, [r13 + R32 + 4*4]           ; DESV = R32[4]
    mov [r13 + PC], eax
    jmp .loop

.jz:
    test byte [r13 + FLAGS], 0x01       ; testa Z
    jnz .faz_desvio                     ; se Z = 1, desvia
    jmp .loop

.faz_desvio:
    mov eax, [r13 + R32 + 4*4]          ; pega destino em DESV
    mov [r13 + PC], eax
    jmp .loop

.opcode_invalido:
    mov dword [r13 + EXEC], 0
    jmp .fim

.halt:
    mov dword [r13 + EXEC], 0

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

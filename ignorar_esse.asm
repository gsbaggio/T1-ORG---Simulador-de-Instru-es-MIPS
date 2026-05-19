#==============================================================================
# TRABALHO 1: Simulador de Instruções MIPS
# Disciplina: ELC1011 - Organização de Computadores
#==============================================================================

    # Diretrizes .eqv para constantes
    .eqv MEM_TEXT_BASE  0x00400000
    .eqv MEM_TEXT_LIMIT 0x00401000  # 4096 bytes
    .eqv MEM_DATA_BASE  0x10010000
    .eqv MEM_DATA_LIMIT 0x10011000  # 4096 bytes
    .eqv MEM_STACK_LIMIT 0x7FFFE000 # Topo teórico mapeado para o array
    .eqv MEM_STACK_BASE 0x7FFFEFFC  # 4096 bytes (cresce para baixo)
    .eqv MEM_SIZE       4096

    .eqv SYS_PRINT_STR  4
    .eqv SYS_PRINT_CHR  11
    .eqv SYS_EXIT       10
    .eqv SYS_EXIT2      17
    .eqv SYS_OPEN       13
    .eqv SYS_READ       14
    .eqv SYS_CLOSE      16

.data
    # 1. Variáveis para a simulação do processador MIPS
    
    # (a) Memória simulada (3 segmentos de 4096 bytes)
    mem_text:   .space MEM_SIZE
    mem_data:   .space MEM_SIZE
    mem_stack:  .space MEM_SIZE

    # (b) Banco de Registradores de uso geral (32 registradores de 32 bits)
    reg:        .space 128

    # (c) Registradores de uso interno PC e IR
    PC:         .word MEM_TEXT_BASE
    IR:         .word 0

    # (d) Campos das instruções
    opcode:     .word 0
    rs:         .word 0
    rt:         .word 0
    rd:         .word 0
    shamt:      .word 0
    funct:      .word 0 
    immediate:  .word 0
    address:    .word 0

    # Arquivos para carga
    file_bin:   .asciiz "C:/Users/SAMSUNG/Documents/T1-ORG---Simulador-de-Instru-es-MIPS/ex-000-073.bin"
    file_dat:   .asciiz "C:/Users/SAMSUNG/Documents/T1-ORG---Simulador-de-Instru-es-MIPS/ex-000-073.dat"
    msg_err1:   .asciiz "Erro: Nao foi possivel abrir o arquivo .bin!\n"
    msg_err2:   .asciiz "Erro: Nao foi possivel abrir o arquivo .dat!\n"
    msg_err_mem:.asciiz "\nErro: Falha de segmentação (Endereço inválido)!\n"

.text
.globl main

main:
    # 1. Inicialização
    # Limpar registradores e inicializar $sp (reg[29])
    li $a0, 29
    li $a1, MEM_STACK_BASE
    jal write_reg

    # 2. Carregamento dos Arquivos
    # Carregar arquivo TEXT (.bin)
    li $v0, SYS_OPEN
    la $a0, file_bin
    li $a1, 0           # flag de leitura
    li $a2, 0
    syscall
    bltz $v0, erro_arq1
    move $s0, $v0       # salvar descritor
    
    li $v0, SYS_READ
    move $a0, $s0
    la $a1, mem_text
    li $a2, MEM_SIZE
    syscall
    
    li $v0, SYS_CLOSE
    move $a0, $s0
    syscall

    # Carregar arquivo DATA (.dat)
    li $v0, SYS_OPEN
    la $a0, file_dat
    li $a1, 0
    li $a2, 0
    syscall
    bltz $v0, erro_arq2
    move $s0, $v0       # salvar descritor
    
    li $v0, SYS_READ
    move $a0, $s0
    la $a1, mem_data
    li $a2, MEM_SIZE
    syscall
    
    li $v0, SYS_CLOSE
    move $a0, $s0
    syscall

#==============================================================================
# 3. Loop de Execução Principal
#==============================================================================
fetch_loop:
    # (a) Buscar Instrução
    lw $a0, PC
    jal read_mem
    sw $v0, IR
    
    # Condição de parada de segurança (instrução 0 = nop)
    # beqz $v0, fim_simulacao

    # Incrementar PC em 4
    lw $t0, PC
    addiu $t0, $t0, 4
    sw $t0, PC

    # (b) Decodificar a instrução
    lw $t0, IR
    
    srl $t1, $t0, 26
    andi $t1, $t1, 0x3F
    sw $t1, opcode

    srl $t1, $t0, 21
    andi $t1, $t1, 0x1F
    sw $t1, rs

    srl $t1, $t0, 16
    andi $t1, $t1, 0x1F
    sw $t1, rt

    srl $t1, $t0, 11
    andi $t1, $t1, 0x1F
    sw $t1, rd

    srl $t1, $t0, 6
    andi $t1, $t1, 0x1F
    sw $t1, shamt

    andi $t1, $t0, 0x3F
    sw $t1, funct

    andi $t1, $t0, 0xFFFF
    sw $t1, immediate

    li $t2, 0x3FFFFFF
    and $t1, $t0, $t2
    sw $t1, address

    # (c) Executar a instrução
    lw $t0, opcode
    beqz $t0, exec_rtype
    beq $t0, 2, exec_j
    beq $t0, 3, exec_jal
    beq $t0, 4, exec_beq
    beq $t0, 5, exec_bne
    beq $t0, 8, exec_addi
    beq $t0, 9, exec_addi    # addiu (ignora overflow na simulação)
    beq $t0, 12, exec_andi
    beq $t0, 13, exec_ori
    beq $t0, 15, exec_lui
    beq $t0, 35, exec_lw
    beq $t0, 36, exec_lbu
    beq $t0, 40, exec_sb
    beq $t0, 43, exec_sw
    
    # Instrução não suportada: pular
    j fetch_loop

exec_rtype:
    lw $t0, funct
    beq $t0, 0, exec_sll
    beq $t0, 2, exec_srl
    beq $t0, 8, exec_jr
    beq $t0, 12, exec_syscall
    beq $t0, 32, exec_add
    beq $t0, 33, exec_add    # addu
    beq $t0, 34, exec_sub
    beq $t0, 35, exec_sub    # subu
    beq $t0, 36, exec_and
    beq $t0, 37, exec_or
    j fetch_loop

#==============================================================================
# Implementação das Instruções
#==============================================================================

exec_add:
    lw $a0, rs
    jal read_reg
    move $s0, $v0
    lw $a0, rt
    jal read_reg
    addu $s0, $s0, $v0
    lw $a0, rd
    move $a1, $s0
    jal write_reg
    j fetch_loop

exec_sub:
    lw $a0, rs
    jal read_reg
    move $s0, $v0
    lw $a0, rt
    jal read_reg
    subu $s0, $s0, $v0
    lw $a0, rd
    move $a1, $s0
    jal write_reg
    j fetch_loop

exec_and:
    lw $a0, rs
    jal read_reg
    move $s0, $v0
    lw $a0, rt
    jal read_reg
    and $s0, $s0, $v0
    lw $a0, rd
    move $a1, $s0
    jal write_reg
    j fetch_loop

exec_or:
    lw $a0, rs
    jal read_reg
    move $s0, $v0
    lw $a0, rt
    jal read_reg
    or $s0, $s0, $v0
    lw $a0, rd
    move $a1, $s0
    jal write_reg
    j fetch_loop

exec_sll:
    lw $a0, rt
    jal read_reg
    lw $t0, shamt
    sllv $s0, $v0, $t0
    lw $a0, rd
    move $a1, $s0
    jal write_reg
    j fetch_loop

exec_srl:
    lw $a0, rt
    jal read_reg
    lw $t0, shamt
    srlv $s0, $v0, $t0
    lw $a0, rd
    move $a1, $s0
    jal write_reg
    j fetch_loop

exec_addi:
    lw $a0, rs
    jal read_reg
    move $s0, $v0
    lw $t0, immediate
    sll $t0, $t0, 16
    sra $t0, $t0, 16      # Sign extend
    addu $s0, $s0, $t0
    lw $a0, rt
    move $a1, $s0
    jal write_reg
    j fetch_loop

exec_andi:
    lw $a0, rs
    jal read_reg
    lw $t0, immediate     # Zero extend na origem
    and $s0, $v0, $t0
    lw $a0, rt
    move $a1, $s0
    jal write_reg
    j fetch_loop

exec_ori:
    lw $a0, rs
    jal read_reg
    lw $t0, immediate
    or $s0, $v0, $t0
    lw $a0, rt
    move $a1, $s0
    jal write_reg
    j fetch_loop

exec_lui:
    lw $t0, immediate
    sll $s0, $t0, 16
    lw $a0, rt
    move $a1, $s0
    jal write_reg
    j fetch_loop

exec_lw:
    lw $a0, rs
    jal read_reg
    move $s0, $v0
    lw $t0, immediate
    sll $t0, $t0, 16
    sra $t0, $t0, 16
    addu $a0, $s0, $t0
    jal read_mem
    move $a1, $v0
    lw $a0, rt
    jal write_reg
    j fetch_loop

exec_sw:
    lw $a0, rs
    jal read_reg
    move $s0, $v0
    lw $t0, immediate
    sll $t0, $t0, 16
    sra $t0, $t0, 16
    addu $s0, $s0, $t0
    lw $a0, rt
    jal read_reg
    move $a1, $v0
    move $a0, $s0
    jal write_mem
    j fetch_loop

exec_lbu:
    lw $a0, rs
    jal read_reg
    move $s0, $v0
    lw $t0, immediate
    sll $t0, $t0, 16
    sra $t0, $t0, 16
    addu $s0, $s0, $t0
    # Obter a word que contém o byte
    move $a0, $s0
    li $t3, 0xFFFFFFFC
    and $a0, $a0, $t3
    jal read_mem
    # Extrair o byte (little-endian)
    andi $t1, $s0, 3
    sll $t1, $t1, 3       # * 8 para deslocamento de bits
    srlv $s0, $v0, $t1
    andi $s0, $s0, 0xFF
    lw $a0, rt
    move $a1, $s0
    jal write_reg
    j fetch_loop

exec_sb:
    lw $a0, rs
    jal read_reg
    move $s0, $v0
    lw $t0, immediate
    sll $t0, $t0, 16
    sra $t0, $t0, 16
    addu $s0, $s0, $t0
    
    lw $a0, rt
    jal read_reg
    andi $t2, $v0, 0xFF   # byte a ser escrito
    
    # Ler word da memória
    move $a0, $s0
    li $t3, 0xFFFFFFFC
    and $a0, $a0, $t3
    jal read_mem
    move $t4, $v0         # t4 = word atual
    
    # Mascarar e inserir byte
    andi $t1, $s0, 3
    sll $t1, $t1, 3       # shift amt
    li $t5, 0xFF
    sllv $t5, $t5, $t1
    not $t5, $t5
    and $t4, $t4, $t5     # limpar área do byte
    sllv $t2, $t2, $t1
    or $t4, $t4, $t2      # inserir byte
    
    move $a0, $s0
    and $a0, $a0, $t3
    move $a1, $t4
    jal write_mem
    j fetch_loop

exec_beq:
    lw $a0, rs
    jal read_reg
    move $s0, $v0
    lw $a0, rt
    jal read_reg
    bne $s0, $v0, fetch_loop
    lw $t0, immediate
    sll $t0, $t0, 16
    sra $t0, $t0, 16
    sll $t0, $t0, 2
    lw $t1, PC
    addu $t1, $t1, $t0
    sw $t1, PC
    j fetch_loop

exec_bne:
    lw $a0, rs
    jal read_reg
    move $s0, $v0
    lw $a0, rt
    jal read_reg
    beq $s0, $v0, fetch_loop
    lw $t0, immediate
    sll $t0, $t0, 16
    sra $t0, $t0, 16
    sll $t0, $t0, 2
    lw $t1, PC
    addu $t1, $t1, $t0
    sw $t1, PC
    j fetch_loop

exec_j:
    lw $t0, address
    sll $t0, $t0, 2
    lw $t1, PC
    li $t2, 0xF0000000
    and $t1, $t1, $t2
    or $t1, $t1, $t0
    sw $t1, PC
    j fetch_loop

exec_jal:
    li $a0, 31
    lw $a1, PC
    jal write_reg
    lw $t0, address
    sll $t0, $t0, 2
    lw $t1, PC
    li $t2, 0xF0000000
    and $t1, $t1, $t2
    or $t1, $t1, $t0
    sw $t1, PC
    j fetch_loop

exec_jr:
    lw $a0, rs
    jal read_reg
    sw $v0, PC
    j fetch_loop

exec_syscall:
    li $a0, 2             # Reg $v0
    jal read_reg
    move $s0, $v0
    
    beq $s0, SYS_EXIT, fim_simulacao
    beq $s0, SYS_EXIT2, fim_simulacao
    
    # Interceptar SYSCALL 4 (String) e 11 (Char) para o console MARS
    beq $s0, SYS_PRINT_STR, sim_print_str
    beq $s0, SYS_PRINT_CHR, sim_print_chr
    j fetch_loop

sim_print_chr:
    li $a0, 4             # Reg $a0 contém o char
    jal read_reg
    move $a0, $v0
    li $v0, SYS_PRINT_CHR
    syscall
    j fetch_loop

sim_print_str:
    li $a0, 4             # Reg $a0 contém o endereço virtual da string
    jal read_reg
    li $t0, MEM_DATA_BASE
    sub $t1, $v0, $t0     # Offset
    la $a0, mem_data
    addu $a0, $a0, $t1    # Mapear para buffer real do MARS
    li $v0, SYS_PRINT_STR
    syscall
    j fetch_loop

#==============================================================================
# Procedimentos Auxiliares
#==============================================================================

# Ler registrador (a0 = index, retorna v0 = valor)
read_reg:
    beqz $a0, read_reg_zero
    sll $t0, $a0, 2
    la $t1, reg
    addu $t0, $t1, $t0
    lw $v0, 0($t0)
    jr $ra
read_reg_zero:
    li $v0, 0
    jr $ra

# Escrever registrador (a0 = index, a1 = valor)
write_reg:
    beqz $a0, write_reg_end
    sll $t0, $a0, 2
    la $t1, reg
    addu $t0, $t1, $t0
    sw $a1, 0($t0)
write_reg_end:
    jr $ra

# Ler da Memória (a0 = endereço, retorna v0 = valor)
read_mem:
    li $t0, MEM_TEXT_BASE
    li $t1, MEM_TEXT_LIMIT
    bltu $a0, $t0, rm_check_data
    bgeu $a0, $t1, rm_check_data
    sub $t2, $a0, $t0
    la $t3, mem_text
    addu $t3, $t3, $t2
    lw $v0, 0($t3)
    jr $ra
rm_check_data:
    li $t0, MEM_DATA_BASE
    li $t1, MEM_DATA_LIMIT
    bltu $a0, $t0, rm_check_stack
    bgeu $a0, $t1, rm_check_stack
    sub $t2, $a0, $t0
    la $t3, mem_data
    addu $t3, $t3, $t2
    lw $v0, 0($t3)
    jr $ra
rm_check_stack:
    li $t0, MEM_STACK_LIMIT
    li $t1, MEM_STACK_BASE
    bltu $a0, $t0, erro_memoria
    bgtu $a0, $t1, erro_memoria
    sub $t2, $a0, $t0
    la $t3, mem_stack
    addu $t3, $t3, $t2
    lw $v0, 0($t3)
    jr $ra

# Escrever na Memória (a0 = endereço, a1 = valor)
write_mem:
    li $t0, MEM_TEXT_BASE
    li $t1, MEM_TEXT_LIMIT
    bltu $a0, $t0, wm_check_data
    bgeu $a0, $t1, wm_check_data
    sub $t2, $a0, $t0
    la $t3, mem_text
    addu $t3, $t3, $t2
    sw $a1, 0($t3)
    jr $ra
wm_check_data:
    li $t0, MEM_DATA_BASE
    li $t1, MEM_DATA_LIMIT
    bltu $a0, $t0, wm_check_stack
    bgeu $a0, $t1, wm_check_stack
    sub $t2, $a0, $t0
    la $t3, mem_data
    addu $t3, $t3, $t2
    sw $a1, 0($t3)
    jr $ra
wm_check_stack:
    li $t0, MEM_STACK_LIMIT
    li $t1, MEM_STACK_BASE
    bltu $a0, $t0, erro_memoria
    bgtu $a0, $t1, erro_memoria
    sub $t2, $a0, $t0
    la $t3, mem_stack
    addu $t3, $t3, $t2
    sw $a1, 0($t3)
    jr $ra

#==============================================================================
# Tratamento de Erros e Saída
#==============================================================================
erro_arq1:
    li $v0, SYS_PRINT_STR
    la $a0, msg_err1
    syscall
    j fim_simulacao

erro_arq2:
    li $v0, SYS_PRINT_STR
    la $a0, msg_err2
    syscall
    j fim_simulacao

erro_memoria:
    li $v0, SYS_PRINT_STR
    la $a0, msg_err_mem
    syscall

fim_simulacao:
    li $v0, SYS_EXIT
    syscall

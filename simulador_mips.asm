#*******************************************************************************
# Simulador de Instruções MIPS
# Disciplina: ELC1011 - Organização de Computadores
# Grupo: Gabriel Souza Baggio e Gabriel Stiegemeier
#
# Descrição:
#   Este programa simula a execução de um subconjunto de instruções MIPS.
#   Ele carrega arquivos binários (.bin e .dat) nos segmentos de memória
#   simulados e executa o ciclo Fetch-Decode-Execute em loop até encontrar
#   uma syscall de encerramento.
#
# Instruções implementadas:
#   R-type: addu, subu, jr, syscall
#   I-type: addiu, ori, lui, lw, sw, lbu, sb, beq, bne
#   J-type: j, jal
#   ->     (15) Instruções no Total
#
# Estrutura da memória simulada (4096 bytes cada segmento):
#   mem_text  : segmento de texto TEXT_BASE  (0x00400000)
#   mem_data  : segmento de dados DATA_BASE  (0x10010000)
#   mem_stack : segmento de pilha STACK_TOP  (0x7FFFEFFC)
#
# Registradores simulados:
#   reg[0-31]  : 32 registradores de 32 bits
#   PC         : Program Counter (32 bits)
#   IR         : Instruction Register (32 bits)
#
# Campos das instruções decodificadas (variáveis de 32 bits):
#   f_opcode, f_rs, f_rt, f_rd, f_shamt, f_funct, f_imm, f_addr
#
# Convenção de registradores do simulador (host):
#   $s6 : endereço host de reg[0] (base do banco de registradores simulados)
#   $s7 : endereço host de PC
#   $t0-$t9, $a0-$a3, $v0-$v1 : usados livremente dentro de cada bloco
#   $ra : salvo/restaurado nos procedimentos que chamam outros via jal
#   $t8 : argumento de entrada para sim_to_host (endereço simulado)
#   $t9 : usado para salvar endereço host antes de novo jal em exec_sw/exec_sb
#*******************************************************************************

# Endereços base dos segmentos de memória SIMULADOS
.eqv  TEXT_BASE,   0x00400000   # Base do segmento de texto simulado
.eqv  DATA_BASE,   0x10010000   # Base do segmento de dados simulado (SPIM/MARS)
.eqv  STACK_TOP,   0x7FFFEFFC   # Topo inicial da pilha simulada

# Tamanho de cada segmento de memória simulado (em bytes)
.eqv  MEM_SIZE,    4096

# Número de registradores simulados
.eqv  NUM_REGS,    32

# Índices de registradores MIPS especiais (usados por get_reg / set_reg)
.eqv  IDX_ZERO,    0            # $zero
.eqv  IDX_V0,      2            # $v0 (código de syscall / retorno)
.eqv  IDX_A0,      4            # $a0 (1o argumento)
.eqv  IDX_A1,      5            # $a1 (2o argumento)
.eqv  IDX_SP,      29           # $sp (stack pointer)
.eqv  IDX_RA,      31           # $ra (return address)

# Códigos de syscall do programa MIPS simulado
.eqv  SVC_PRINT_INT,    1
.eqv  SVC_PRINT_STR,    4
.eqv  SVC_READ_INT,     5
.eqv  SVC_READ_STR,     8
.eqv  SVC_EXIT,         10
.eqv  SVC_PRINT_CHAR,   11
.eqv  SVC_EXIT2,        17

# Opcodes MIPS
.eqv  OP_RTYPE,  0
.eqv  OP_J,      2
.eqv  OP_JAL,    3
.eqv  OP_BEQ,    4
.eqv  OP_BNE,    5
.eqv  OP_ADDIU,  9
.eqv  OP_ORI,    13
.eqv  OP_LUI,    15
.eqv  OP_LW,     35
.eqv  OP_LBU,    36
.eqv  OP_SB,     40
.eqv  OP_SW,     43

# Functs R-type
.eqv  FUNCT_JR,      8
.eqv  FUNCT_SYSCALL, 12
.eqv  FUNCT_ADDU,    33
.eqv  FUNCT_SUBU,    35

# ===========================================================================
.text
.globl main

################################################################################
# main - Procedimento principal do simulador
################################################################################
main:
    # Salvar registradores do host que usaremos como dedicados
    addiu   $sp, $sp, -12
    sw      $ra, 8($sp)
    sw      $s6, 4($sp)
    sw      $s7, 0($sp)

    # -------------------------------------------------------------------------
    # Fixar ponteiros dedicados para as estruturas principais
    #   $s6 = endereço host de reg[0]
    #   $s7 = endereço host de PC
    # Esses dois registradores nunca são sobrescritos pelo restante do código.
    # -------------------------------------------------------------------------
    la      $s6, reg
    la      $s7, PC

    # =========================================================================
    # 1. Inicialização das estruturas simuladas
    # =========================================================================

    # Zerar todos os registradores simulados reg[0..31]
    move    $t0, $s6            # $t0 = ponteiro corrente (começa em reg[0])
    li      $t1, NUM_REGS       # contador de 32 iterações
init_clr_loop:
    sw      $zero, 0($t0)
    addiu   $t0, $t0, 4
    addiu   $t1, $t1, -1
    bgtz    $t1, init_clr_loop

    # Inicializar reg[29] ($sp simulado) = STACK_TOP = 0x7FFFEFFC
    # Construímos 0x7FFFEFFC explicitamente (li sozinho pode não funcionar com
    # valores > 0x7FFFFFFF em algumas versões do montador)
    li      $t0, 0x7FFF
    sll     $t0, $t0, 16
    ori     $t0, $t0, 0xEFFC       # $t0 = 0x7FFFEFFC
    sw      $t0, 116($s6)   # reg[29] = 0x7FFFEFFC

    # Inicializar PC simulado = TEXT_BASE = 0x00400000
    li      $t0, TEXT_BASE
    sw      $t0, 0($s7)

    # Inicializar IR = 0
    la      $t0, IR
    sw      $zero, 0($t0)

    # =========================================================================
    # 2. Carregamento dos arquivos binários nos segmentos simulados
    # =========================================================================

    # Ler arquivo .bin -> mem_text
    la      $a0, fname_bin
    la      $a1, mem_text
    li      $a2, MEM_SIZE
    jal     carregar_arquivo

    # Ler arquivo .dat -> mem_data
    la      $a0, fname_dat
    la      $a1, mem_data
    li      $a2, MEM_SIZE
    jal     carregar_arquivo

    # =========================================================================
    # 3. Loop de Execução: Fetch - Decode - Execute
    # =========================================================================
exec_loop:

    # -------------------------------------------------------------------------
    # (a) Busca (FETCH): IR <- Mem[PC]
    # -------------------------------------------------------------------------
    lw      $t0, 0($s7)             # $t0 = PC simulado
    li      $t1, TEXT_BASE
    subu    $t1, $t0, $t1           # $t1 = offset dentro de mem_text
    la      $t2, mem_text
    addu    $t2, $t2, $t1           # $t2 = endereço host da instrução
    lw      $t3, 0($t2)             # $t3 = instrução (conteúdo de IR)
    la      $t4, IR
    sw      $t3, 0($t4)             # IR = instrução buscada

    # -------------------------------------------------------------------------
    # (b) Decodificação (DECODE): extrair campos e incrementar PC
    # -------------------------------------------------------------------------

    # PC <- PC + 4
    addiu   $t0, $t0, 4
    sw      $t0, 0($s7)

    # Extrair todos os campos a partir de $t3 (IR)

    # opcode = IR[31:26]
    srl     $t4, $t3, 26
    andi    $t4, $t4, 0x3F
    la      $t0, f_opcode
    sw      $t4, 0($t0)

    # rs = IR[25:21]
    srl     $t4, $t3, 21
    andi    $t4, $t4, 0x1F
    la      $t0, f_rs
    sw      $t4, 0($t0)

    # rt = IR[20:16]
    srl     $t4, $t3, 16
    andi    $t4, $t4, 0x1F
    la      $t0, f_rt
    sw      $t4, 0($t0)

    # rd = IR[15:11]
    srl     $t4, $t3, 11
    andi    $t4, $t4, 0x1F
    la      $t0, f_rd
    sw      $t4, 0($t0)

    # shamt = IR[10:6]
    srl     $t4, $t3, 6
    andi    $t4, $t4, 0x1F
    la      $t0, f_shamt
    sw      $t4, 0($t0)

    # funct = IR[5:0]
    andi    $t4, $t3, 0x3F
    la      $t0, f_funct
    sw      $t4, 0($t0)

    # immediate = IR[15:0] com extensão de sinal
    # Técnica: mover para bits [31:16] e depois deslocar com sinal
    sll     $t4, $t3, 16
    sra     $t4, $t4, 16
    la      $t0, f_imm
    sw      $t4, 0($t0)

    # address = IR[25:0]  (J-type, 26 bits sem sinal)
    li      $t0, 0x03FFFFFF
    and     $t4, $t3, $t0
    la      $t0, f_addr
    sw      $t4, 0($t0)

    # -------------------------------------------------------------------------
    # (c) Execução (EXECUTE): despachar pelo opcode
    # -------------------------------------------------------------------------
    la      $t0, f_opcode
    lw      $t0, 0($t0)             # $t0 = opcode

    beq     $t0, OP_RTYPE,  exec_rtype
    beq     $t0, OP_J,      exec_j
    beq     $t0, OP_JAL,    exec_jal
    beq     $t0, OP_BEQ,    exec_beq
    beq     $t0, OP_BNE,    exec_bne
    beq     $t0, OP_ADDIU,  exec_addiu
    beq     $t0, OP_ORI,    exec_ori
    beq     $t0, OP_LUI,    exec_lui
    beq     $t0, OP_LW,     exec_lw
    beq     $t0, OP_LBU,    exec_lbu
    beq     $t0, OP_SB,     exec_sb
    beq     $t0, OP_SW,     exec_sw

    # Opcode não reconhecido: imprimir aviso e continuar
    la      $a0, msg_unk_op
    li      $v0, 4
    syscall
    j       exec_loop

    # =========================================================================
    # R-type: despachar pelo campo funct
    # =========================================================================
exec_rtype:
    la      $t0, f_funct
    lw      $t0, 0($t0)             # $t0 = funct

    beq     $t0, FUNCT_JR,      exec_jr
    beq     $t0, FUNCT_SYSCALL, exec_syscall
    beq     $t0, FUNCT_ADDU,    exec_addu
    beq     $t0, FUNCT_SUBU,    exec_subu

    # Funct não reconhecido
    la      $a0, msg_unk_funct
    li      $v0, 4
    syscall
    j       exec_loop

    # =========================================================================
    # Implementação individual de cada instrução
    # =========================================================================

    # -------------------------------------------------------------------------
    # jr rs               : PC = reg[rs]
    # -------------------------------------------------------------------------
exec_jr:
    la      $t0, f_rs
    lw      $a0, 0($t0)
    jal     get_reg             # $v0 = reg[rs]
    sw      $v0, 0($s7)         # PC = reg[rs]
    j       exec_loop

    # -------------------------------------------------------------------------
    # syscall             : verificar reg[2] e executar o serviço
    # -------------------------------------------------------------------------
exec_syscall:
    li      $a0, IDX_V0
    jal     get_reg             # $v0 = reg[2] (código de serviço)
    move    $t0, $v0

    beq     $t0, SVC_PRINT_INT,  svc_print_int
    beq     $t0, SVC_PRINT_STR,  svc_print_str
    beq     $t0, SVC_READ_INT,   svc_read_int
    beq     $t0, SVC_READ_STR,   svc_read_str
    beq     $t0, SVC_EXIT,       svc_exit
    beq     $t0, SVC_PRINT_CHAR, svc_print_char
    beq     $t0, SVC_EXIT2,      svc_exit2

    j       exec_loop           # serviço desconhecido: ignorar

    # ---- Serviço 1: print_int -----------------------------------------------
svc_print_int:
    li      $a0, IDX_A0
    jal     get_reg
    move    $a0, $v0
    li      $v0, 1
    syscall
    j       exec_loop

    # ---- Serviço 4: print_string --------------------------------------------
svc_print_str:
    li      $a0, IDX_A0
    jal     get_reg             # $v0 = endereço simulado da string
    move    $t8, $v0
    jal     sim_to_host         # $v0 = endereço host
    move    $a0, $v0
    li      $v0, 4
    syscall
    j       exec_loop

    # ---- Serviço 5: read_int ------------------------------------------------
svc_read_int:
    li      $v0, 5
    syscall
    li      $a0, IDX_V0
    move    $a1, $v0
    jal     set_reg             # reg[2] = inteiro lido
    j       exec_loop

    # ---- Serviço 8: read_string ---------------------------------------------
svc_read_str:
    li      $a0, IDX_A0
    jal     get_reg
    move    $t8, $v0
    jal     sim_to_host
    move    $t9, $v0            # $t9 = endereço host do buffer
    li      $a0, IDX_A1
    jal     get_reg             # $v0 = tamanho (reg[5])
    move    $a1, $v0
    move    $a0, $t9
    li      $v0, 8
    syscall
    j       exec_loop

    # ---- Serviço 10: exit ---------------------------------------------------
svc_exit:
    li      $v0, 10
    syscall

    # ---- Serviço 11: print_char ---------------------------------------------
svc_print_char:
    li      $a0, IDX_A0
    jal     get_reg
    move    $a0, $v0
    li      $v0, 11
    syscall
    j       exec_loop

    # ---- Serviço 17: exit2 --------------------------------------------------
svc_exit2:
    li      $a0, IDX_A0
    jal     get_reg
    move    $a0, $v0
    li      $v0, 17
    syscall

    # -------------------------------------------------------------------------
    # addu rd, rs, rt : reg[rd] = reg[rs] + reg[rt]
    # -------------------------------------------------------------------------
exec_addu:
    la      $t0, f_rs
    lw      $a0, 0($t0)
    jal     get_reg
    move    $t1, $v0            # $t1 = reg[rs]
    la      $t0, f_rt
    lw      $a0, 0($t0)
    jal     get_reg             # $v0 = reg[rt]
    addu    $t1, $t1, $v0
    la      $t0, f_rd
    lw      $a0, 0($t0)
    move    $a1, $t1
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # subu rd, rs, rt : reg[rd] = reg[rs] - reg[rt]
    # -------------------------------------------------------------------------
exec_subu:
    la      $t0, f_rs
    lw      $a0, 0($t0)
    jal     get_reg
    move    $t1, $v0
    la      $t0, f_rt
    lw      $a0, 0($t0)
    jal     get_reg
    subu    $t1, $t1, $v0
    la      $t0, f_rd
    lw      $a0, 0($t0)
    move    $a1, $t1
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # j target            : PC = (PC_atual[31:28] | (target << 2))
    # Nota: PC já foi incrementado no Decode; usamos esse valor para extrair
    # os 4 bits superiores (conforme especificação MIPS).
    # -------------------------------------------------------------------------
exec_j:
    la      $t0, f_addr
    lw      $t0, 0($t0)         # $t0 = campo target (26 bits)
    sll     $t0, $t0, 2         # $t0 = target * 4
    lw      $t1, 0($s7)         # $t1 = PC (após incremento)
    li      $t2, 0xF0000000
    and     $t1, $t1, $t2       # $t1 = PC[31:28]
    or      $t0, $t1, $t0       # endereço de destino
    sw      $t0, 0($s7)         # PC = endereço de destino
    j       exec_loop

    # -------------------------------------------------------------------------
    # jal target          : reg[31] = PC;  PC = (PC[31:28] | (target << 2))
    # -------------------------------------------------------------------------
exec_jal:
    # 1. Salvar endereço de retorno em reg[31]
    lw      $t9, 0($s7)         # $t9 = PC (após incremento) = endereço de retorno
    li      $a0, IDX_RA
    move    $a1, $t9
    jal     set_reg             # reg[31] = endereço de retorno

    # 2. Calcular endereço de desvio (mesmo cálculo que j)
    la      $t0, f_addr
    lw      $t0, 0($t0)         # $t0 = target (26 bits)
    sll     $t0, $t0, 2
    lw      $t1, 0($s7)         # PC atual (depois de set_reg, s7 não mudou)
    li      $t2, 0xF0000000
    and     $t1, $t1, $t2
    or      $t0, $t1, $t0
    sw      $t0, 0($s7)
    j       exec_loop

    # -------------------------------------------------------------------------
    # beq rs, rt, offset  : if (reg[rs] == reg[rt]) PC = PC + (offset << 2)
    # -------------------------------------------------------------------------
exec_beq:
    la      $t0, f_rs
    lw      $a0, 0($t0)
    jal     get_reg
    move    $t1, $v0            # $t1 = reg[rs]
    la      $t0, f_rt
    lw      $a0, 0($t0)
    jal     get_reg             # $v0 = reg[rt]
    bne     $t1, $v0, exec_loop # condição falsa: sem branch
    # Branch tomado
    la      $t0, f_imm
    lw      $t0, 0($t0)         # $t0 = offset com sinal
    sll     $t0, $t0, 2
    lw      $t1, 0($s7)
    addu    $t1, $t1, $t0
    sw      $t1, 0($s7)
    j       exec_loop

    # -------------------------------------------------------------------------
    # bne rs, rt, offset  : if (reg[rs] != reg[rt]) PC = PC + (offset << 2)
    # -------------------------------------------------------------------------
exec_bne:
    la      $t0, f_rs
    lw      $a0, 0($t0)
    jal     get_reg
    move    $t1, $v0
    la      $t0, f_rt
    lw      $a0, 0($t0)
    jal     get_reg
    beq     $t1, $v0, exec_loop # condição falsa: sem branch
    la      $t0, f_imm
    lw      $t0, 0($t0)
    sll     $t0, $t0, 2
    lw      $t1, 0($s7)
    addu    $t1, $t1, $t0
    sw      $t1, 0($s7)
    j       exec_loop

    # -------------------------------------------------------------------------
    # addiu rt, rs, imm : reg[rt] = reg[rs] + sign_ext(imm)
    # -------------------------------------------------------------------------
exec_addiu:
    la      $t0, f_rs
    lw      $a0, 0($t0)
    jal     get_reg             # $v0 = reg[rs]
    la      $t0, f_imm
    lw      $t1, 0($t0)         # $t1 = imm (extensão de sinal já feita no decode)
    addu    $t1, $v0, $t1
    la      $t0, f_rt
    lw      $a0, 0($t0)
    move    $a1, $t1
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # ori rt, rs, imm     : reg[rt] = reg[rs] | zero_ext(imm)
    # -------------------------------------------------------------------------
exec_ori:
    la      $t0, f_rs
    lw      $a0, 0($t0)
    jal     get_reg
    la      $t0, f_imm
    lw      $t1, 0($t0)
    andi    $t1, $t1, 0xFFFF    # zero-extension
    or      $t1, $v0, $t1
    la      $t0, f_rt
    lw      $a0, 0($t0)
    move    $a1, $t1
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # lui rt, imm         : reg[rt] = imm << 16
    # -------------------------------------------------------------------------
exec_lui:
    la      $t0, f_imm
    lw      $t1, 0($t0)
    andi    $t1, $t1, 0xFFFF
    sll     $t1, $t1, 16
    la      $t0, f_rt
    lw      $a0, 0($t0)
    move    $a1, $t1
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # lw rt, imm(rs)      : reg[rt] = Mem32[reg[rs] + imm]
    # -------------------------------------------------------------------------
exec_lw:
    la      $t0, f_rs
    lw      $a0, 0($t0)
    jal     get_reg
    la      $t0, f_imm
    lw      $t1, 0($t0)
    addu    $t8, $v0, $t1       # $t8 = endereço simulado
    jal     sim_to_host         # $v0 = endereço host
    lw      $t1, 0($v0)
    la      $t0, f_rt
    lw      $a0, 0($t0)
    move    $a1, $t1
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # lbu rt, imm(rs)     : reg[rt] = zero_ext(Mem8[reg[rs] + imm])
    # -------------------------------------------------------------------------
exec_lbu:
    la      $t0, f_rs
    lw      $a0, 0($t0)
    jal     get_reg
    la      $t0, f_imm
    lw      $t1, 0($t0)
    addu    $t8, $v0, $t1
    jal     sim_to_host
    lbu     $t1, 0($v0)
    la      $t0, f_rt
    lw      $a0, 0($t0)
    move    $a1, $t1
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # sw rt, imm(rs)      : Mem32[reg[rs] + imm] = reg[rt]
    # -------------------------------------------------------------------------
exec_sw:
    la      $t0, f_rs
    lw      $a0, 0($t0)
    jal     get_reg
    la      $t0, f_imm
    lw      $t1, 0($t0)
    addu    $t8, $v0, $t1       # $t8 = endereço simulado
    jal     sim_to_host         # $v0 = endereço host
    move    $t9, $v0            # salvar endereço host antes do próximo jal
    la      $t0, f_rt
    lw      $a0, 0($t0)
    jal     get_reg             # $v0 = reg[rt]
    sw      $v0, 0($t9)
    j       exec_loop

    # -------------------------------------------------------------------------
    # sb rt, imm(rs)      : Mem8[reg[rs] + imm] = reg[rt] & 0xFF
    # -------------------------------------------------------------------------
exec_sb:
    la      $t0, f_rs
    lw      $a0, 0($t0)
    jal     get_reg
    la      $t0, f_imm
    lw      $t1, 0($t0)
    addu    $t8, $v0, $t1
    jal     sim_to_host
    move    $t9, $v0
    la      $t0, f_rt
    lw      $a0, 0($t0)
    jal     get_reg
    sb      $v0, 0($t9)
    j       exec_loop


################################################################################
# get_reg - Lê o valor de um registrador simulado
#
# Argumentos:
#   $a0 : índice do registrador (0..31)
# Retorno:
#   $v0 : valor de reg[$a0]   (reg[0] sempre retorna 0)
# Registradores preservados: $s6, $s7, $t5-$t9, $a0-$a3
################################################################################
get_reg:
    beqz    $a0, get_reg_zero
    sll     $t0, $a0, 2         # offset = índice * 4
    addu    $t0, $s6, $t0       # endereço host = base_reg + offset
    lw      $v0, 0($t0)
    jr      $ra
get_reg_zero:
    li      $v0, 0
    jr      $ra

################################################################################
# set_reg - Escreve em um registrador simulado
#
# Argumentos:
#   $a0 : índice do registrador (0..31)
#   $a1 : valor a gravar
# Nota: reg[0] é imutável (escrita ignorada)
# Registradores preservados: $s6, $s7, $t5-$t9, $a0-$a3
################################################################################
set_reg:
    beqz    $a0, set_reg_done
    sll     $t0, $a0, 2
    addu    $t0, $s6, $t0
    sw      $a1, 0($t0)
set_reg_done:
    jr      $ra

################################################################################
# sim_to_host - Converte endereço MIPS simulado em endereço host
#
# Argumento de entrada  : $t8 = endereço simulado
# Retorno               : $v0 = endereço host correspondente
#
# Mapeamento de segmentos:
#   Texto : [TEXT_BASE,  TEXT_BASE  + MEM_SIZE)  ->  mem_text[0..]
#   Dados : [DATA_BASE,  DATA_BASE  + MEM_SIZE)  ->  mem_data[0..]
#   Pilha : [STACK_TOP - MEM_SIZE + 4, STACK_TOP] -> mem_stack[0..]
#
# Registradores preservados: $s6, $s7, $a0, $a1, $t8, $t9, $ra
################################################################################
sim_to_host:

    # ---- Segmento de texto --------------------------------------------------
    li      $t0, TEXT_BASE
    subu    $t1, $t8, $t0       # offset = addr - TEXT_BASE
    bltz    $t1, sth_data       # offset < 0 -> não é texto
    li      $t2, MEM_SIZE
    subu    $t3, $t1, $t2       # offset - MEM_SIZE
    bgez    $t3, sth_data       # offset >= MEM_SIZE -> não é texto
    la      $v0, mem_text
    addu    $v0, $v0, $t1
    jr      $ra

    # ---- Segmento de dados --------------------------------------------------
sth_data:
    li      $t0, DATA_BASE
    subu    $t1, $t8, $t0
    bltz    $t1, sth_stack
    li      $t2, MEM_SIZE
    subu    $t3, $t1, $t2
    bgez    $t3, sth_stack
    la      $v0, mem_data
    addu    $v0, $v0, $t1
    jr      $ra

    # ---- Segmento de pilha --------------------------------------------------
    # A pilha cresce para baixo a partir de STACK_TOP.
    # Base inferior do bloco mapeado = STACK_TOP - MEM_SIZE + 4
sth_stack:
    li      $t0, 0x7FFF
    sll     $t0, $t0, 16
    ori     $t0, $t0, 0xEFFC    # $t0 = STACK_TOP = 0x7FFFEFFC
    li      $t2, MEM_SIZE
    subu    $t3, $t0, $t2
    addiu   $t3, $t3, 4         # $t3 = base inferior
    subu    $t1, $t8, $t3       # offset = addr - base_inferior
    bltz    $t1, sth_erro
    subu    $t4, $t1, $t2
    bgez    $t4, sth_erro
    la      $v0, mem_stack
    addu    $v0, $v0, $t1
    jr      $ra

sth_erro:
    la      $a0, msg_addr_err
    li      $v0, 4
    syscall
    la      $v0, mem_text       # retornar ponteiro seguro para não travar
    jr      $ra

################################################################################
# carregar_arquivo - Abre um arquivo e lê seus bytes para um buffer
#
# Argumentos:
#   $a0 : ponteiro para nome do arquivo
#   $a1 : ponteiro para buffer de destino (host)
#   $a2 : número máximo de bytes
# Retorno:
#   $v0 : bytes lidos (ou -1 se erro ao abrir)
#
# Syscalls:
#   13 - open   ($a0=nome, $a1=flags=0, $a2=modo=0) -> $v0=fd
#   14 - read   ($a0=fd, $a1=buffer, $a2=nbytes)    -> $v0=bytes_lidos
#   16 - close  ($a0=fd)
################################################################################
carregar_arquivo:
    addiu   $sp, $sp, -24
    sw      $ra, 20($sp)
    sw      $s0, 16($sp)
    sw      $s1, 12($sp)
    sw      $s2,  8($sp)
    sw      $s3,  4($sp)
    sw      $s4,  0($sp)

    move    $s0, $a0            # nome
    move    $s1, $a1            # buffer
    move    $s2, $a2            # max bytes

    # Abrir arquivo (modo leitura = 0)
    li      $v0, 13
    move    $a0, $s0
    li      $a1, 0
    li      $a2, 0
    syscall
    move    $s3, $v0            # $s3 = file descriptor

    bltz    $s3, ca_erro

    # Ler bytes
    li      $v0, 14
    move    $a0, $s3
    move    $a1, $s1
    move    $a2, $s2
    syscall
    move    $s4, $v0            # $s4 = bytes lidos

    # Fechar arquivo
    li      $v0, 16
    move    $a0, $s3
    syscall

    move    $v0, $s4
    j       ca_fim

ca_erro:
    la      $a0, msg_file_err
    li      $v0, 4
    syscall
    li      $v0, -1

ca_fim:
    lw      $s0, 16($sp)
    lw      $s1, 12($sp)
    lw      $s2,  8($sp)
    lw      $s3,  4($sp)
    lw      $s4,  0($sp)
    lw      $ra, 20($sp)
    addiu   $sp, $sp, 24
    jr      $ra

# ===========================================================================
# Seção de dados do simulador
# ===========================================================================
.data

# ---- Nomes dos arquivos de entrada ----------------------------------------
fname_bin:  .asciiz "ex-000-073.bin"
fname_dat:  .asciiz "ex-000-073.dat"

# ---- Segmentos de memória simulados (4 KB cada, alinhados em palavra) -----
        .align 2
mem_text:   .space  4096        # texto  - instruções do programa simulado
        .align 2
mem_data:   .space  4096        # dados  - variáveis estáticas
        .align 2
mem_stack:  .space  4096        # pilha  - cresce para endereços menores

# ---- Banco de registradores simulados: 32 x 4 bytes -----------------------
        .align 2
reg:        .space  128         # reg[0] .. reg[31]

# ---- Registradores internos -----------------------------------------------
        .align 2
PC:         .word   0           # Program Counter simulado
IR:         .word   0           # Instruction Register simulado

# ---- Campos decodificados da instrução corrente ---------------------------
        .align 2
f_opcode:   .word   0           # bits [31:26]
f_rs:       .word   0           # bits [25:21]
f_rt:       .word   0           # bits [20:16]
f_rd:       .word   0           # bits [15:11]
f_shamt:    .word   0           # bits [10:6]
f_funct:    .word   0           # bits [5:0]
f_imm:      .word   0           # bits [15:0]  com extensão de sinal
f_addr:     .word   0           # bits [25:0]  campo J-type (sem sinal)

# ---- Mensagens de diagnóstico ---------------------------------------------
msg_unk_op:     .asciiz "\n[SIM] Opcode desconhecido\n"
msg_unk_funct:  .asciiz "\n[SIM] Funct R-type desconhecido\n"
msg_addr_err:   .asciiz "\n[SIM] Endereco fora dos segmentos simulados\n"
msg_file_err:   .asciiz "\n[SIM] Erro ao abrir arquivo de entrada\n"
#*******************************************************************************
# Simulador de Instruções MIPS
# Disciplina: ELC1011 – Organização de Computadores
# Universidade Federal de Santa Maria – UFSM/CT/DELC
# Prof. Giovani Baratto – 2026/1
#
# Descrição:
#   Este programa simula a execução de um subconjunto de instruções MIPS.
#   Ele carrega arquivos binários (.bin e .dat) nos segmentos de memória
#   simulados e executa o ciclo Fetch–Decode–Execute em loop até encontrar
#   uma syscall de encerramento (exit=1 ou exit2=10/17).
#
# Instruções implementadas:
#   R-type: add, addu, sub, subu, and, or, slt, sll, srl, jr, syscall
#   I-type: addi, addiu, andi, ori, lui, lw, sw, lbu, lb, sb, beq, bne, slti
#   J-type: j, jal
#
# Estrutura da memória simulada:
#   mem_text  : 4096 bytes a partir de TEXT_BASE  = 0x00400000
#   mem_data  : 4096 bytes a partir de DATA_BASE  = 0x10010000
#   mem_stack : 4096 bytes a partir de STACK_BASE = 0x7FFFEFFC (cresce para baixo)
#
# Registradores simulados:
#   reg[0..31] : banco de 32 registradores de 32 bits
#   PC         : contador de programa (32 bits)
#   IR         : registrador de instrução (32 bits)
#
# Campos das instruções (variáveis de 32 bits):
#   f_opcode, f_rs, f_rt, f_rd, f_shamt, f_funct, f_imm, f_addr
#*******************************************************************************
#        1         2         3         4         5         6         7         8
#2345678901234567890123456789012345678901234567890123456789012345678901234567890

.text
.globl main

################################################################################
# Constantes de endereços-base dos segmentos de memória simulados
################################################################################
#   TEXT_BASE  = 0x00400000
#   DATA_BASE  = 0x10010000   (nota: o .dat usa base 0x10010000 conforme o SPIM)
#   STACK_BASE = 0x7FFFEFFC
#   MEM_SIZE   = 4096 bytes = 1024 palavras de 32 bits

################################################################################
# main – Procedimento principal
#
# Fluxo:
#   1. Inicialização das estruturas de dados
#   2. Carregamento dos arquivos .bin e .dat
#   3. Loop Fetch–Decode–Execute
################################################################################
main:
    # -------------------------------------------------------------------------
    # 1. Inicialização
    # -------------------------------------------------------------------------
    # Zerar todos os registradores simulados (reg[0..31])
    la      $t0, reg            # $t0 <- endereço de reg[0]
    li      $t1, 32             # contador: 32 registradores
    li      $t2, 0
clr_reg_loop:
    beqz    $t1, clr_reg_done
    sw      $t2, 0($t0)
    addiu   $t0, $t0, 4
    addiu   $t1, $t1, -1
    j       clr_reg_loop
clr_reg_done:

    # Inicializar $sp simulado (reg[29]) = STACK_BASE = 0x7FFFEFFC
    la      $t0, reg
    li      $t1, 0x7FFF
    sll     $t1, $t1, 16
    ori     $t1, $t1, 0xEFFC
    sw      $t1, 116($t0)       # reg[29] = 29*4 = 116

    # Inicializar PC = TEXT_BASE = 0x00400000
    li      $t1, 0x0040
    sll     $t1, $t1, 16
    sw      $t1, PC

    # Zerar IR
    sw      $zero, IR

    # -------------------------------------------------------------------------
    # 2. Carregamento dos arquivos
    # -------------------------------------------------------------------------
    # Carregar arquivo .bin -> mem_text
    la      $a0, fname_bin      # nome do arquivo
    la      $a1, mem_text       # buffer de destino
    li      $a2, 4096           # tamanho máximo
    jal     carregar_arquivo

    # Carregar arquivo .dat -> mem_data
    la      $a0, fname_dat
    la      $a1, mem_data
    li      $a2, 4096
    jal     carregar_arquivo

    # -------------------------------------------------------------------------
    # 3. Loop de Execução: Fetch – Decode – Execute
    # -------------------------------------------------------------------------
exec_loop:
    # -- Fetch ----------------------------------------------------------------
    # IR <- mem_text[PC - TEXT_BASE]
    lw      $t0, PC             # $t0 <- PC atual
    li      $t1, 0x0040
    sll     $t1, $t1, 16        # $t1 <- TEXT_BASE
    subu    $t2, $t0, $t1       # $t2 <- offset em bytes dentro de mem_text
    la      $t3, mem_text
    addu    $t3, $t3, $t2       # $t3 <- endereço real em mem_text
    lw      $t4, 0($t3)         # $t4 <- instrução (IR)
    sw      $t4, IR

    # -- Decode ---------------------------------------------------------------
    # Incrementar PC
    lw      $t0, PC
    addiu   $t0, $t0, 4
    sw      $t0, PC

    # Extrair campos da instrução em IR
    lw      $t4, IR

    # opcode = IR[31:26]
    srl     $t5, $t4, 26
    andi    $t5, $t5, 0x3F
    sw      $t5, f_opcode

    # rs = IR[25:21]
    srl     $t5, $t4, 21
    andi    $t5, $t5, 0x1F
    sw      $t5, f_rs

    # rt = IR[20:16]
    srl     $t5, $t4, 16
    andi    $t5, $t5, 0x1F
    sw      $t5, f_rt

    # rd = IR[15:11]
    srl     $t5, $t4, 11
    andi    $t5, $t5, 0x1F
    sw      $t5, f_rd

    # shamt = IR[10:6]
    srl     $t5, $t4, 6
    andi    $t5, $t5, 0x1F
    sw      $t5, f_shamt

    # funct = IR[5:0]
    andi    $t5, $t4, 0x3F
    sw      $t5, f_funct

    # immediate (16 bits, com sinal) = IR[15:0] com extensão de sinal
    andi    $t5, $t4, 0xFFFF
    # extensão de sinal manual
    sll     $t5, $t5, 16
    sra     $t5, $t5, 16
    sw      $t5, f_imm

    # address (26 bits) = IR[25:0]
    li      $t6, 0x03FFFFFF
    and     $t5, $t4, $t6
    sw      $t5, f_addr

    # -- Execute --------------------------------------------------------------
    # Despachar pela tabela de opcodes
    lw      $t0, f_opcode

    # opcode == 0: instrução R-type
    beqz    $t0, exec_rtype

    # opcode == 2: j
    li      $t1, 2
    beq     $t0, $t1, exec_j

    # opcode == 3: jal
    li      $t1, 3
    beq     $t0, $t1, exec_jal

    # opcode == 4: beq
    li      $t1, 4
    beq     $t0, $t1, exec_beq

    # opcode == 5: bne
    li      $t1, 5
    beq     $t0, $t1, exec_bne

    # opcode == 8: addi
    li      $t1, 8
    beq     $t0, $t1, exec_addi

    # opcode == 9: addiu
    li      $t1, 9
    beq     $t0, $t1, exec_addiu

    # opcode == 10: slti
    li      $t1, 10
    beq     $t0, $t1, exec_slti

    # opcode == 12: andi
    li      $t1, 12
    beq     $t0, $t1, exec_andi

    # opcode == 13: ori
    li      $t1, 13
    beq     $t0, $t1, exec_ori

    # opcode == 15: lui
    li      $t1, 15
    beq     $t0, $t1, exec_lui

    # opcode == 32: lb
    li      $t1, 32
    beq     $t0, $t1, exec_lb

    # opcode == 35: lw
    li      $t1, 35
    beq     $t0, $t1, exec_lw

    # opcode == 36: lbu
    li      $t1, 36
    beq     $t0, $t1, exec_lbu

    # opcode == 40: sb
    li      $t1, 40
    beq     $t0, $t1, exec_sb

    # opcode == 43: sw
    li      $t1, 43
    beq     $t0, $t1, exec_sw

    # Instrução não reconhecida
    la      $a0, msg_unk_op
    li      $v0, 4
    syscall
    j       exec_loop

    # =========================================================================
    # R-type: despachar pelo campo funct
    # =========================================================================
exec_rtype:
    lw      $t0, f_funct

    li      $t1, 0              # sll
    beq     $t0, $t1, exec_sll

    li      $t1, 2              # srl
    beq     $t0, $t1, exec_srl

    li      $t1, 8              # jr
    beq     $t0, $t1, exec_jr

    li      $t1, 9              # jalr
    beq     $t0, $t1, exec_jalr

    li      $t1, 12             # syscall
    beq     $t0, $t1, exec_syscall

    li      $t1, 32             # add
    beq     $t0, $t1, exec_add

    li      $t1, 33             # addu
    beq     $t0, $t1, exec_addu

    li      $t1, 34             # sub
    beq     $t0, $t1, exec_sub

    li      $t1, 35             # subu
    beq     $t0, $t1, exec_subu

    li      $t1, 36             # and
    beq     $t0, $t1, exec_and

    li      $t1, 37             # or
    beq     $t0, $t1, exec_or

    li      $t1, 42             # slt
    beq     $t0, $t1, exec_slt

    # Instrução R não reconhecida
    la      $a0, msg_unk_funct
    li      $v0, 4
    syscall
    j       exec_loop

    # =========================================================================
    # Implementação das instruções
    # =========================================================================

    # -------------------------------------------------------------------------
    # sll rd, rt, shamt    IR[31:26]=0, funct=0
    # reg[rd] = reg[rt] << shamt
    # -------------------------------------------------------------------------
exec_sll:
    lw      $a0, f_rt
    jal     get_reg             # $v0 <- reg[rt]
    lw      $t1, f_shamt
    sllv    $t0, $v0, $t1       # shift left logical variable
    lw      $a0, f_rd
    move    $a1, $t0
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # srl rd, rt, shamt
    # reg[rd] = reg[rt] >> shamt (logical)
    # -------------------------------------------------------------------------
exec_srl:
    lw      $a0, f_rt
    jal     get_reg
    lw      $t1, f_shamt
    srlv    $t0, $v0, $t1
    lw      $a0, f_rd
    move    $a1, $t0
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # jr rs
    # PC = reg[rs]
    # -------------------------------------------------------------------------
exec_jr:
    lw      $a0, f_rs
    jal     get_reg
    sw      $v0, PC
    j       exec_loop

    # -------------------------------------------------------------------------
    # jalr rd, rs   (rd padrão = $ra = reg[31])
    # reg[rd] = PC; PC = reg[rs]
    # -------------------------------------------------------------------------
exec_jalr:
    lw      $t0, PC
    lw      $a0, f_rd
    move    $a1, $t0
    jal     set_reg
    lw      $a0, f_rs
    jal     get_reg
    sw      $v0, PC
    j       exec_loop

    # -------------------------------------------------------------------------
    # syscall
    # Verificar reg[2] ($v0) para o código de serviço
    # -------------------------------------------------------------------------
exec_syscall:
    li      $a0, 2              # índice de $v0
    jal     get_reg             # $v0 <- reg[2] (código de serviço)
    move    $t0, $v0

    # serviço 1: print_int
    li      $t1, 1
    beq     $t0, $t1, svc_print_int

    # serviço 4: print_string
    li      $t1, 4
    beq     $t0, $t1, svc_print_string

    # serviço 5: read_int
    li      $t1, 5
    beq     $t0, $t1, svc_read_int

    # serviço 8: read_string
    li      $t1, 8
    beq     $t0, $t1, svc_read_string

    # serviço 10: exit
    li      $t1, 10
    beq     $t0, $t1, svc_exit

    # serviço 11: print_char
    li      $t1, 11
    beq     $t0, $t1, svc_print_char

    # serviço 17: exit2
    li      $t1, 17
    beq     $t0, $t1, svc_exit2

    # Serviço não reconhecido – ignorar
    j       exec_loop

    # -------  Serviços  -------------------------------------------------------

    # svc 1: print_int – imprime reg[4] ($a0) como inteiro
svc_print_int:
    li      $a0, 4
    jal     get_reg
    move    $a0, $v0
    li      $v0, 1
    syscall
    j       exec_loop

    # svc 4: print_string – imprime string cujo endereço está em reg[4] ($a0)
svc_print_string:
    li      $a0, 4
    jal     get_reg             # $v0 <- endereço simulado da string
    move    $t8, $v0            # $t8 <- endereço simulado
    jal     sim_addr_to_real    # $v0 <- endereço real (host) da string
    move    $a0, $v0
    li      $v0, 4
    syscall
    j       exec_loop

    # svc 5: read_int – lê inteiro e armazena em reg[2] ($v0)
svc_read_int:
    li      $v0, 5
    syscall                     # MIPS real: retorna inteiro em $v0
    move    $a1, $v0
    li      $a0, 2
    jal     set_reg
    j       exec_loop

    # svc 8: read_string – lê string para o buffer em reg[4]($a0), tamanho reg[5]($a1)
svc_read_string:
    li      $a0, 4
    jal     get_reg
    move    $t8, $v0
    jal     sim_addr_to_real
    move    $t9, $v0            # buffer real
    li      $a0, 5
    jal     get_reg
    move    $a1, $v0            # tamanho
    move    $a0, $t9
    li      $v0, 8
    syscall
    j       exec_loop

    # svc 10: exit – encerra o simulador com código 0
svc_exit:
    li      $v0, 10
    syscall

    # svc 11: print_char – imprime o caractere em reg[4]($a0)
svc_print_char:
    li      $a0, 4
    jal     get_reg
    move    $a0, $v0
    li      $v0, 11
    syscall
    j       exec_loop

    # svc 17: exit2 – encerra o simulador com código em reg[4]($a0)
svc_exit2:
    li      $a0, 4
    jal     get_reg
    move    $a0, $v0
    li      $v0, 17
    syscall

    # -------------------------------------------------------------------------
    # add rd, rs, rt      reg[rd] = reg[rs] + reg[rt]
    # -------------------------------------------------------------------------
exec_add:
exec_addu:
    lw      $a0, f_rs
    jal     get_reg
    move    $t0, $v0
    lw      $a0, f_rt
    jal     get_reg
    addu    $t0, $t0, $v0
    lw      $a0, f_rd
    move    $a1, $t0
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # sub rd, rs, rt      reg[rd] = reg[rs] - reg[rt]
    # -------------------------------------------------------------------------
exec_sub:
exec_subu:
    lw      $a0, f_rs
    jal     get_reg
    move    $t0, $v0
    lw      $a0, f_rt
    jal     get_reg
    subu    $t0, $t0, $v0
    lw      $a0, f_rd
    move    $a1, $t0
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # and rd, rs, rt      reg[rd] = reg[rs] & reg[rt]
    # -------------------------------------------------------------------------
exec_and:
    lw      $a0, f_rs
    jal     get_reg
    move    $t0, $v0
    lw      $a0, f_rt
    jal     get_reg
    and     $t0, $t0, $v0
    lw      $a0, f_rd
    move    $a1, $t0
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # or rd, rs, rt       reg[rd] = reg[rs] | reg[rt]
    # -------------------------------------------------------------------------
exec_or:
    lw      $a0, f_rs
    jal     get_reg
    move    $t0, $v0
    lw      $a0, f_rt
    jal     get_reg
    or      $t0, $t0, $v0
    lw      $a0, f_rd
    move    $a1, $t0
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # slt rd, rs, rt      reg[rd] = (reg[rs] < reg[rt]) ? 1 : 0
    # -------------------------------------------------------------------------
exec_slt:
    lw      $a0, f_rs
    jal     get_reg
    move    $t0, $v0
    lw      $a0, f_rt
    jal     get_reg
    slt     $t0, $t0, $v0
    lw      $a0, f_rd
    move    $a1, $t0
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # j target            PC = (PC[31:28] | (target << 2))
    # -------------------------------------------------------------------------
exec_j:
    lw      $t0, f_addr         # target (26 bits)
    sll     $t0, $t0, 2         # target << 2
    lw      $t1, PC             # PC já foi incrementado
    li      $t2, 0xF0000000
    and     $t1, $t1, $t2       # bits [31:28] do PC
    or      $t0, $t1, $t0       # endereço final
    sw      $t0, PC
    j       exec_loop

    # -------------------------------------------------------------------------
    # jal target          reg[31] = PC; PC = (PC[31:28] | (target << 2))
    # -------------------------------------------------------------------------
exec_jal:
    lw      $t0, PC             # salvar PC em reg[31]
    li      $a0, 31
    move    $a1, $t0
    jal     set_reg
    j       exec_j              # reaproveitamos a lógica de j

    # -------------------------------------------------------------------------
    # beq rs, rt, offset  if (reg[rs]==reg[rt]) PC = PC + (offset << 2)
    # -------------------------------------------------------------------------
exec_beq:
    lw      $a0, f_rs
    jal     get_reg
    move    $t0, $v0
    lw      $a0, f_rt
    jal     get_reg
    bne     $t0, $v0, exec_beq_no
    # branch tomado
    lw      $t1, f_imm
    sll     $t1, $t1, 2
    lw      $t2, PC
    addu    $t2, $t2, $t1
    sw      $t2, PC
exec_beq_no:
    j       exec_loop

    # -------------------------------------------------------------------------
    # bne rs, rt, offset  if (reg[rs]!=reg[rt]) PC = PC + (offset << 2)
    # -------------------------------------------------------------------------
exec_bne:
    lw      $a0, f_rs
    jal     get_reg
    move    $t0, $v0
    lw      $a0, f_rt
    jal     get_reg
    beq     $t0, $v0, exec_bne_no
    # branch tomado
    lw      $t1, f_imm
    sll     $t1, $t1, 2
    lw      $t2, PC
    addu    $t2, $t2, $t1
    sw      $t2, PC
exec_bne_no:
    j       exec_loop

    # -------------------------------------------------------------------------
    # addi rt, rs, imm    reg[rt] = reg[rs] + sign_ext(imm)
    # -------------------------------------------------------------------------
exec_addi:
exec_addiu:
    lw      $a0, f_rs
    jal     get_reg
    lw      $t1, f_imm          # já com extensão de sinal (feita no decode)
    addu    $t0, $v0, $t1
    lw      $a0, f_rt
    move    $a1, $t0
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # slti rt, rs, imm    reg[rt] = (reg[rs] < sign_ext(imm)) ? 1 : 0
    # -------------------------------------------------------------------------
exec_slti:
    lw      $a0, f_rs
    jal     get_reg
    lw      $t1, f_imm
    slt     $t0, $v0, $t1
    lw      $a0, f_rt
    move    $a1, $t0
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # andi rt, rs, imm    reg[rt] = reg[rs] & zero_ext(imm)
    # -------------------------------------------------------------------------
exec_andi:
    lw      $a0, f_rs
    jal     get_reg
    lw      $t1, f_imm
    andi    $t1, $t1, 0xFFFF    # forçar zero-extension (ignorar sinal)
    and     $t0, $v0, $t1
    lw      $a0, f_rt
    move    $a1, $t0
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # ori rt, rs, imm     reg[rt] = reg[rs] | zero_ext(imm)
    # -------------------------------------------------------------------------
exec_ori:
    lw      $a0, f_rs
    jal     get_reg
    lw      $t1, f_imm
    andi    $t1, $t1, 0xFFFF
    or      $t0, $v0, $t1
    lw      $a0, f_rt
    move    $a1, $t0
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # lui rt, imm         reg[rt] = imm << 16
    # -------------------------------------------------------------------------
exec_lui:
    lw      $t1, f_imm
    andi    $t1, $t1, 0xFFFF
    sll     $t1, $t1, 16
    lw      $a0, f_rt
    move    $a1, $t1
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # lw rt, imm(rs)      reg[rt] = Mem32[reg[rs] + imm]
    # -------------------------------------------------------------------------
exec_lw:
    lw      $a0, f_rs
    jal     get_reg
    lw      $t1, f_imm
    addu    $t8, $v0, $t1       # $t8 <- endereço simulado
    jal     sim_addr_to_real    # $v0 <- endereço real
    lw      $t0, 0($v0)
    lw      $a0, f_rt
    move    $a1, $t0
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # lb rt, imm(rs)      reg[rt] = sign_ext(Mem8[reg[rs] + imm])
    # -------------------------------------------------------------------------
exec_lb:
    lw      $a0, f_rs
    jal     get_reg
    lw      $t1, f_imm
    addu    $t8, $v0, $t1
    jal     sim_addr_to_real
    lb      $t0, 0($v0)         # lb faz extensão de sinal automaticamente
    lw      $a0, f_rt
    move    $a1, $t0
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # lbu rt, imm(rs)     reg[rt] = zero_ext(Mem8[reg[rs] + imm])
    # -------------------------------------------------------------------------
exec_lbu:
    lw      $a0, f_rs
    jal     get_reg
    lw      $t1, f_imm
    addu    $t8, $v0, $t1
    jal     sim_addr_to_real
    lbu     $t0, 0($v0)
    lw      $a0, f_rt
    move    $a1, $t0
    jal     set_reg
    j       exec_loop

    # -------------------------------------------------------------------------
    # sw rt, imm(rs)      Mem32[reg[rs] + imm] = reg[rt]
    # -------------------------------------------------------------------------
exec_sw:
    lw      $a0, f_rs
    jal     get_reg
    lw      $t1, f_imm
    addu    $t8, $v0, $t1       # $t8 <- endereço simulado
    jal     sim_addr_to_real    # $v0 <- endereço real
    move    $t9, $v0
    lw      $a0, f_rt
    jal     get_reg
    sw      $v0, 0($t9)
    j       exec_loop

    # -------------------------------------------------------------------------
    # sb rt, imm(rs)      Mem8[reg[rs] + imm] = reg[rt] & 0xFF
    # -------------------------------------------------------------------------
exec_sb:
    lw      $a0, f_rs
    jal     get_reg
    lw      $t1, f_imm
    addu    $t8, $v0, $t1
    jal     sim_addr_to_real
    move    $t9, $v0
    lw      $a0, f_rt
    jal     get_reg
    sb      $v0, 0($t9)
    j       exec_loop

################################################################################
# get_reg – Lê o valor de um registrador simulado
#
# Argumentos:
#   $a0 : índice do registrador (0..31)
#
# Retorno:
#   $v0 : valor do registrador (reg[a0])
#
# Nota: reg[0] sempre retorna 0 (zero-register)
################################################################################
get_reg:
    beqz    $a0, get_reg_zero
    la      $v0, reg
    sll     $t0, $a0, 2         # offset = índice * 4
    addu    $v0, $v0, $t0
    lw      $v0, 0($v0)
    jr      $ra
get_reg_zero:
    li      $v0, 0
    jr      $ra

################################################################################
# set_reg – Escreve um valor em um registrador simulado
#
# Argumentos:
#   $a0 : índice do registrador (0..31)
#   $a1 : valor a ser gravado
#
# Nota: escrita em reg[0] é ignorada (zero-register é sempre 0)
################################################################################
set_reg:
    beqz    $a0, set_reg_done   # reg[0] é imutável
    la      $t0, reg
    sll     $t1, $a0, 2
    addu    $t0, $t0, $t1
    sw      $a1, 0($t0)
set_reg_done:
    jr      $ra

################################################################################
# sim_addr_to_real – Converte endereço simulado MIPS para endereço real (host)
#
# Argumentos:
#   $t8 : endereço simulado (endereço MIPS)
#
# Retorno:
#   $v0 : ponteiro real para a posição correspondente na memória simulada
#
# Segmentos suportados:
#   TEXT : [0x00400000, 0x00401000)
#   DATA : [0x10010000, 0x10011000)  (SPIM usa 0x10010000 como base do .data)
#   STACK: [0x7FFFEFFC, 0x7FFFF000)  (simplificado)
################################################################################
sim_addr_to_real:
    # Verificar segmento de texto
    li      $t0, 0x0040
    sll     $t0, $t0, 16        # $t0 = 0x00400000
    subu    $t1, $t8, $t0       # offset
    bltz    $t1, try_data
    li      $t2, 4096
    bge     $t1, $t2, try_data
    la      $v0, mem_text
    addu    $v0, $v0, $t1
    jr      $ra

try_data:
    # Verificar segmento de dados (base 0x10010000 – padrão SPIM)
    li      $t0, 0x1001
    sll     $t0, $t0, 16        # $t0 = 0x10010000
    subu    $t1, $t8, $t0
    bltz    $t1, try_stack
    li      $t2, 4096
    bge     $t1, $t2, try_stack
    la      $v0, mem_data
    addu    $v0, $v0, $t1
    jr      $ra

try_stack:
    # Verificar segmento da pilha
    # Pilha cresce para baixo a partir de 0x7FFFEFFC
    # Mapeamos [0x7FFFEFFC - 4096 + 4 .. 0x7FFFEFFC] -> mem_stack[0..4095]
    li      $t0, 0x7FFF
    sll     $t0, $t0, 16
    ori     $t0, $t0, 0xEFFC    # $t0 = 0x7FFFEFFC (topo da pilha)
    li      $t2, 4096
    subu    $t3, $t0, $t2       # $t3 = base inferior da pilha simulada
    addu    $t3, $t3, 4
    subu    $t1, $t8, $t3       # offset a partir da base inferior
    bltz    $t1, addr_erro
    bge     $t1, $t2, addr_erro
    la      $v0, mem_stack
    addu    $v0, $v0, $t1
    jr      $ra

addr_erro:
    la      $a0, msg_addr_err
    li      $v0, 4
    syscall
    # retorna ponteiro para região segura (mem_text[0]) para não travar
    la      $v0, mem_text
    jr      $ra

################################################################################
# carregar_arquivo – Lê bytes de um arquivo e armazena no buffer
#
# Argumentos:
#   $a0 : ponteiro para o nome do arquivo (string terminada em nulo)
#   $a1 : ponteiro para o buffer de destino
#   $a2 : número máximo de bytes a ler
#
# Retorno:
#   $v0 : número de bytes lidos (ou -1 em caso de erro)
#
# Usa syscalls do MARS/SPIM:
#   13 – open (read-only)
#   14 – read
#   16 – close
################################################################################
carregar_arquivo:
    # Prólogo
    addiu   $sp, $sp, -20
    sw      $ra, 16($sp)
    sw      $s0,  0($sp)
    sw      $s1,  4($sp)
    sw      $s2,  8($sp)
    sw      $s3, 12($sp)

    move    $s0, $a0            # $s0 <- nome do arquivo
    move    $s1, $a1            # $s1 <- buffer de destino
    move    $s2, $a2            # $s2 <- tamanho máximo

    # Abrir o arquivo (modo leitura = 0)
    li      $v0, 13             # syscall 13: open
    move    $a0, $s0            # nome do arquivo
    li      $a1, 0              # flags: somente leitura
    li      $a2, 0              # modo (ignorado)
    syscall
    move    $s3, $v0            # $s3 <- file descriptor

    bltz    $s3, carregar_erro  # se fd < 0, erro ao abrir

    # Ler os bytes do arquivo para o buffer
    li      $v0, 14             # syscall 14: read
    move    $a0, $s3            # file descriptor
    move    $a1, $s1            # buffer de destino
    move    $a2, $s2            # número máximo de bytes
    syscall
    move    $s2, $v0            # $s2 <- bytes efetivamente lidos

    # Fechar o arquivo
    li      $v0, 16             # syscall 16: close
    move    $a0, $s3
    syscall

    move    $v0, $s2            # retornar número de bytes lidos
    j       carregar_fim

carregar_erro:
    la      $a0, msg_file_err
    li      $v0, 4
    syscall
    li      $v0, -1

carregar_fim:
    lw      $s0,  0($sp)
    lw      $s1,  4($sp)
    lw      $s2,  8($sp)
    lw      $s3, 12($sp)
    lw      $ra, 16($sp)
    addiu   $sp, $sp, 20
    jr      $ra

################################################################################
# Seção de dados do simulador
################################################################################
.data

# ---- Nomes dos arquivos de entrada ----------------------------------------
fname_bin:  .asciiz "ex-000-073.bin"
fname_dat:  .asciiz "ex-000-073.dat"

# ---- Memórias simuladas (4096 bytes cada) ----------------------------------
        .align 2
mem_text:   .space 4096         # segmento de texto (instruções)
        .align 2
mem_data:   .space 4096         # segmento de dados estáticos
        .align 2
mem_stack:  .space 4096         # segmento da pilha

# ---- Banco de registradores simulados (32 x 4 bytes = 128 bytes) ----------
        .align 2
reg:        .space 128          # reg[0..31]

# ---- Registradores internos ------------------------------------------------
        .align 2
PC:         .word 0             # Program Counter
IR:         .word 0             # Instruction Register

# ---- Campos decodificados da instrução atual --------------------------------
        .align 2
f_opcode:   .word 0
f_rs:       .word 0
f_rt:       .word 0
f_rd:       .word 0
f_shamt:    .word 0
f_funct:    .word 0
f_imm:      .word 0
f_addr:     .word 0

# ---- Mensagens de diagnóstico -----------------------------------------------
msg_unk_op:     .asciiz "\n[SIMULADOR] Opcode desconhecido\n"
msg_unk_funct:  .asciiz "\n[SIMULADOR] Funct desconhecido\n"
msg_addr_err:   .asciiz "\n[SIMULADOR] Erro: endereco fora dos segmentos simulados\n"
msg_file_err:   .asciiz "\n[SIMULADOR] Erro ao abrir arquivo\n"
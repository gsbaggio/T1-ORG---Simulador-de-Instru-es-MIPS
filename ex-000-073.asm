#*******************************************************************************
# Descrição: Este programa lê e imprime as palavras de uma string.
#*******************************************************************************
#        1         2         3         4         5         6         7         8
#2345678901234567890123456789012345678901234567890123456789012345678901234567890
#           M     O             #
.text
.globl      main

################################################################################           
# Este procedimento lê as palavras de uma string e imprime
#
# Argumentos do procedimento:
# Não há argumentos
#
# Mapa da pilha
# $sp + 0 : ptr
#
# Mapa dos registradores
# veja comentários do texto
#
# Retorno do procedimento
# Este procedimento retorna o valor 0, indicando que o programa foi executado corretamente
################################################################################
# int main(void)
main:
# {
# prólogo do procedimento
#     char *ptr;
            addiu   $sp, $sp, -4
# corpo do procedimento
#     ptr = str;
            la      $t0, str        # $t0 <- endereço de str
            sw      $t0, 0($sp)     # ptr = str
#     
#     printf("String: [%s]\n", str);
            li      $v0, 4          # serviço 4, imprime uma string
            la      $a0, str_01     # endereço da string
            syscall                 # imprimimos a string
            la      $a0, str        # endereço da string
            syscall                 # imprimimos a string
            la      $a0, str_02     # endereço da string
            syscall                 # imprimimos a sring
#     printf("Lendo as palavras da string\n");
            la      $a0, str_03     # carregamos em $a0 o endereço da string
            syscall                 # imprimimos a string
#     while(1){
main_while:
#         ptr = leia_palavra(ptr, buffer, delim);
            lw      $a0, 0($sp)     # $a0 <- ptr
            la      $a1, buffer     # $a1 <- buffer
            la      $a2, delim      # $a2 <- delim
            jal     leia_palavra    # chamamos o procedimento leia_palavra
            sw      $v0, 0($sp)     # ptr = leia_palavra(ptr, buffer, delim)
#         if(*buffer) printf("[%s]", buffer); else break;
            # se *buffer == 0 saímos deste laço while
            la      $t1, buffer     # $t1 <- endereço de buffer
            lbu     $t2, 0($t1)     # $t2 <- *buffer
            beqz    $t2, main_fim_while # se condição é falsa, saímos deste laço while
            # imprimimos a string em buffer
            li      $v0, 11         # serviço 11: imprime um caractere
            li      $a0, '['        # $a0 <- caractere a ser impresso
            syscall                 # imprimimos o caractere em $a0
            li      $v0, 4          # serviço 4: imprime string apontada por $a0
            move    $a0, $t1        # $a1 <- endereço da string
            syscall                 # imprimimos a string
            li      $v0, 11         # serviço 11: imprime um caractere
            li      $a0, ']'        # $a0 <- caractere a ser impresso
            syscall                 # imprimimos o caractere
            j   main_while          # se condição é verdadeira, continuamos no laço while
#     }
main_fim_while:
#     printf("\n");                 
            li      $v0, 11         # serviço 11: imprimimos um caractere
            li      $a0, '\n'       # $a0 <- nova linha
            syscall                 # imprimimos uma nova linha
# epílogo do procedimento
            addiu   $sp, $sp, 4     # restauramos a pilha
#     return 0;
            li      $v0, 17         # serviço 17: exit2, terminamos o programa
            li      $a0, 0          # valor de retorno
            syscall                 # encerramos o programa
            
# }

################################################################################           
# Este procedimento verifica se um caractere é um delimitador.
#
# Argumentos do procedimento:
# $a0: o caractere (ch) que será verificado
# $a1: um ponteiro para a string (delim), com os caracteres delimitadores
#
# Mapa da pilha
# não usamos a pilha neste procedimento
#
# Mapa dos registradores
# $t0: *delim
# $t1: valor diferente de 0 se *delim != ch
#
# Retorno do procedimento
# $v0: valor diferente de 0 se o caractere é um delimitador ou 0 se o caractere
#      não é um caractere delimitador
################################################################################
# char caractere_eh_delimitador(char ch, char* delim)
caractere_eh_delimitador:
# prólogo do procedimento
# corpo do procedimento
# {
#     while(*delim && (*delim != ch)) delim++;
caractere_eh_delimitador_while:
            lbu     $t0, 0($a1)     # $t0 <-*delim, 0 se chegamos no final da string com os caracteres delimitadores
            subu    $t1, $t0, $a0   # $t1 <- valor diferente de 0 se *delim != ch
            # se uma das condições for falsa, a operação and é falsa: saímos do laço while
            beqz    $t0, caractere_eh_delimitador_while_falsa
            beqz    $t1, caractere_eh_delimitador_while_falsa
            addiu   $a1, $a1, 1     # delim++
            j       caractere_eh_delimitador_while 
caractere_eh_delimitador_while_falsa:            
# epílogo do procedimento
#     return *delim;
            move    $v0, $t0        # $v0 <- *delim
# }
            jr      $ra             # retornamos ao procedimento chamador
#-------------------------------------------------------------------------------
         

################################################################################           
# Este procedimento coloca em um buffer uma palavra de uma string. Se buffer ="" = '\0'
# não existem mais palavras na string. 
#
# Argumentos do procedimento:
# $a0: str, ponteiro para a string onde serão procurada as palavras
# $a1: buffer, ponteiro para um buffer, onde guardamos uma palavra da string
# $a2: delim, ponteiro para uma string com os caracteres delimitadores
#
# Mapa da pilha
# $sp + 12: $ra
# $sp + 8 : $s0
# $sp + 4 : $s1
# $sp + 0 : $s2
#
# Mapa dos registradores
# $s0: str, ponteiro para str, 
# $s1: buffer, ponteiro para buffer
# $s2: delim, ponteiro para delim
#
# Retorno do procedimento
# $v0: um ponteiro para o primeiro caractere após a palavra encontrada ou o final
#      da string. 
################################################################################
# /* retorna uma palavra em buffer, lida de str e um ponteiro para o primeiro
#    caractere após a palavra lida*/
# char* leia_palavra(char *str, char *buffer, char *delim)
leia_palavra:
# {
# prólogo do procedimento
            addiu   $sp, $sp, -16
            sw      $ra, 12($sp)
            sw      $s0, 8($sp)
            sw      $s1, 4($sp)
            sw      $s2, 0($sp)

            move    $s0, $a0
            move    $s1, $a1
            move    $s2, $a2
# corpo do procedimento
#     //verificamos se existe um delimitador antes da palavra.
#     while(*str && (caractere_eh_delimitador(*str, delim))) str++;
leia_palavra_while_1:
            # executamos o procedimento caractere_eh_delimitador
            lbu     $a0, 0($s0)
            move    $a1, $s2
            jal     caractere_eh_delimitador # chamamos o procedimento caractere_eh_delimitador
            # se uma das condiçoes da operação and em while for zero, saímos deste laço while
            # retorno de (caractere_eh_delimitador(*str, delim) está em $v0
            lbu     $t0, 0($s0)     # $t0 <- *str
            beqz    $v0, leia_palavra_while_1_falsa
            beqz    $t0, leia_palavra_while_1_falsa
            addiu   $s0, $s0, 1 
            j       leia_palavra_while_1
leia_palavra_while_1_falsa:
#     // lemos a palavra até um delimitador ou o fim da string
#     while(*str && (!caractere_eh_delimitador(*str, delim))) *buffer++ = *str++;
leia_palavra_while_2:
            # executamos o procedimento caractere_eh_delimitador
            lbu     $a0, 0($s0)
            move    $a1, $s2
            jal     caractere_eh_delimitador # chamamos o procedimento caractere_eh_delimitador
            # se uma das condiçoes da operação and em while for zero, saímos deste laço while
            # retorno de (caractere_eh_delimitador(*str, delim) está em $v0
            lbu     $t0, 0($s0)     # $t0 <- *str
            bnez    $v0, leia_palavra_while_2_falsa
            beqz    $t0, leia_palavra_while_2_falsa
            sb      $t0, 0($s1)     # *buffer = *str 
            addiu   $s0, $s0, 1     # str++
            addiu   $s1, $s1, 1     # buffer++
            j       leia_palavra_while_2
leia_palavra_while_2_falsa:
#     *buffer = 0; 
            sb      $zero, 0($s1)  
# epílogo do procedimento
#     return str;
            move    $v0, $s0        # $v0 <- str
            # restauramos os valores originais dos registradores
            lw      $s2, 0($sp)
            lw      $s1, 4($sp)
            lw      $s0, 8($sp)
            lw      $ra, 12($sp)
            addiu   $sp, $sp, 16    # restauramos a pilha            
# }
            jr      $ra             # retornamos ao procedimento chamador
#-------------------------------------------------------------------------------            

.data 

#     char str[] = "   \tteste1\tteste2 123.233\t\t\ta  122  r1\n01  fim x,y, z, \t w ";
#     char delim[] = " \t\n,";
#     char buffer[256];

str:        .asciiz "   \tteste1\tteste2 123.233\t\t\ta  122  r1\n01  fim x,y, z, \t w "
delim:      .asciiz " \t\n,"
buffer:     .space 256
str_01:     .asciiz "String: ["
str_02:     .asciiz "]\n"
str_03:     .asciiz "Lendo as palavras da string\n"

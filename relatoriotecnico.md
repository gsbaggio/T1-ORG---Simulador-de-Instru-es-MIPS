Optimizing tool selection...# Relatório Técnico: Simulador de Instruções MIPS

**Autoria/Disciplina:** ELC1011 - Organização de Computadores  
**Desenvolvedores (Conforme código):** Gabriel Souza Baggio e Gabriel Stiegemeier  
**Linguagem de Implementação:** Assembly MIPS  

---

## 1. Visão Geral do Sistema

O sistema provido consiste em um simulador da arquitetura MIPS implementado na própria linguagem Assembly MIPS (modelo Host-Target semelhante). Seu objetivo central é emular o comportamento de um subconjunto de 15 instruções MIPS, reproduzindo integralmente o ciclo lógico de processamento de um processador real: **Busca (*Fetch*)**, **Decodificação (*Decode*)** e **Execução (*Execute*)**.

O simulador é capaz de carregar e emular a execução de programas binários (gerados previamente), isolando o ambiente simulado em suas próprias abstrações de memória, registradores e contador de programa (PC), interpretando as instruções passo a passo.

---

## 2. Arquitetura e Mapeamento de Memória

Para garantir o isolamento da emulação, a memória foi particionada em segmentos de 4096 bytes (4 KB) cada no *Host*, mapeados para endereços virtuais fixos dentro da máquina simulada:

1. **Segmento de Texto (`mem_text`):**
   * **Endereço Simulado Base:** `0x00400000` (`TEXT_BASE`)
   * **Propósito:** Armazena o código binário (instruções do programa simulado). É carregado a partir do arquivo `.bin`.

2. **Segmento de Dados (`mem_data`):**
   * **Endereço Simulado Base:** `0x10010000` (`DATA_BASE`)
   * **Propósito:** Armazena variáveis globais e estáticas. O simulador carrega seu estado inicial do arquivo `.dat`.

3. **Segmento de Pilha (`mem_stack`):**
   * **Endereço Simulado Base (Topo):** `0x7FFFEFFC` (`STACK_TOP`)
   * **Propósito:** Memória de pilha (*stack*) temporária. Diferente do texto e dados que crescem positivamente, a pilha MIPS encolhe para endereços menores a partir do `STACK_TOP`. Cobre o intervalo de `0x7FFFEFFC` até `0x7FFFEFFC - 4096 + 4`.

### Tradução de Endereços (*Memory Management Unit* Simulado)
Como a máquina simulada usa endereços "irreais" (ex: `0x10010000`), a rotina `transfere_sim_para_host` faz o papel de uma MMU de software. Ao receber um endereço simulado, ela:
1. Verifica através de limite superior e inferior a qual segmento (Texto, Dados ou Pilha) o endereço pertence.
2. Calcula o *offset* subtraindo o endereço original pela base correspondente.
3. Soma o *offset* ao ponteiro de endereço do *Host* (`mem_text`, `mem_data`, ou `mem_stack`).
4. Lança o erro `"Endereço fora dos segmentos simulados"` caso o acesso seja inválido.

---

## 3. Arquitetura de Registradores

O banco de registradores `reg[]` é emulado estaticamente na seção `.data` alocando 128 bytes (32 registradores de 32 bits, ou 4 bytes).
1. **Reg[0-31] (`reg`):**
   * O registrador `$zero` (`reg[0]`) é mantido rígido nas rotinas `get_reg` e `set_reg`. Tentativas de atualizar `reg[0]` falham silenciosamente, e leituras sempre retornam inteiro zero.
   * `reg[29]` (o Stack Pointer `$sp` simulado) é inicializado rigorosamente com a constante `STACK_TOP` (`0x7FFFEFFC`).
2. **PC (Program Counter):** Inicia preenchido com `TEXT_BASE` (`0x00400000`).
3. **IR (Instruction Register):** Utilizado para guardar transitoriamente o bloco de 32-bits lido na fase de *Fetch*.

Para gerir isso eficientemente em tempo de execução, o código usa de forma hardcoded registradores do *Host* como âncoras (salvaguardados do sistema operacional via pilha):
* `$s6`: Guarda o endereço raiz host para o array `reg`.
* `$s7`: Guarda o endereço host de `PC`.

---

## 4. O Ciclo Lógico Central de Processamento (Fetch-Decode-Execute)

### 4.1 Busca (*Fetch*)
A sub-rotina `exec_fetch` extrai o valor de `PC` do ambiente emulador. Ela descobre o limite de deslocamento em memória calculando: `Offset = PC - TEXT_BASE`.
Com este deslocamento acrescido ao endereço nativo `mem_text`, ela lê exatamente os 4 bytes da instrução do vetor (array) na RAM e a escreve em `IR`.

### 4.2 Decodificação (*Decode*)
Ao ingressar em `exec_decode`, o processador simulado imediatamente atualiza `PC = PC + 4`. Logo em sequência, disseca de forma primorosa todos os potenciais rótulos presentes no `IR` de 32-bits via máscaras AND (`andi`) e Shifts lógicos LSL/LSR (`sll`, `srl`, `sra`), gravando em variáveis locais isoladas:
* `opcode` (bits 31-26, shift de 26 + AND 0x3F)
* `rs` (bits 25-21, shift 21 + AND 0x1F)
* `rt` (bits 20-16, shift 16 + AND 0x1F)
* `rd` (bits 15-11, shift 11 + AND 0x1F)
* `shamt` (bits 10-6, shift 6 + AND 0x1F)
* `funct` (bits 5-0, puro AND 0x3F)
* `imm` (bits 15-0): Recebe **extensão de sinal real** movendo os bits lógicos para o espectro superior (shift-left pra casa 16) e aplicando shift contendo sinal para voltar à estaca inferior (`sll` seguido por `sra`, preservando o MSB como bits de sinal 31-16).
* `addr` (bits 25-0): Para Jump-types, feito via isolamento Lógico AND usando `0x03FFFFFF`.

### 4.3 Execução e Despacho (*Execute*)
A rotina compara imperativamente (através de `beq`) o `opcode` recolhido com as diretivas predefinidas (`OP_RTYPE`, `OP_ADDIU`, etc). O dispatcher distribui para roteamentos específicos e encerra retornando em laço ininterrupto a `exec_loop`.

---

## 5. Subconjunto de Instruções Implementadas

O núcleo aborda formidavelmente exatas 15 instruções, destrinchadas conforme seu formato arquitetural original.

### 5.1 Tipo-J (Jump)
* **`j`**: Determina que seu próximo desvio é pautado pelo bit `target`. Pega os 26 bits já recortados, propaga shift left de 2 zeros (`sll $t0, $t0, 2`, tornando em 28bits), mescla com os 4 bits nativos mais altos do `PC` recentemente incrementado via porta lógia `or` finalizando na substituição do `PC`.
* **`jal`**: Replica todo o funcionamento matemático do pulo `j`, intercalando na rotina inicial um acionamento à função `set_reg` em que aciona `$a0` índice `31` e submete o valor `PC` em incremento, guardando o retorno para sub-rotinas vinculadas.

### 5.2 Tipo-R (Aritmético/Lógicas/Controle)
Trata o Opcode `0` enviando-o para ramificações ditadas pelo campo decorativo `funct`.
* **`addu` & `subu`**: Carrega o conteúdo simulado através da auxiliar `get_reg` informando `rs` e `rt`. Usa operações genuínas `addu` e `subu` do *Host* para extrair o resultado em `$t1`, preenchendo devolutivamente em `rd` providenciando o método `set_reg`.
* **`jr`**: Busca em `rs` o alvo virtual, redirecionando o conteúdo imediato de `$v0` para a RAM simulada local alusiva ao registrador `PC`.
* **`syscall`**: Exige dedicação à parte, exposta na aba Syscalls (vide abaixo).

### 5.3 Tipo-I (Imediatos, Memória e Desvios Condicionais)
* **`addiu`**: Soma Aritmética Mips. Aciona `get_reg` de `rs` e adiciona ao Campo `imm` extenso logicamente recuperado em etapa Deco, despejando sobre rotina `set_reg` ref a `rt`.
* **`ori` & `lui`**: Funções perfeitamente em torno do campo literal, contudo sem admitir extensão de sinal (executa um `andi 0xFFFF` para limpamento das instâncias superiores de lixo).
* **`beq` & `bne`**: Utiliza as pontes de pulo do *Host* em cima the equivalência das amostras extraídas em `rs` e `rt`. Caso a verificação seja sucedida, converte o `imm` a byte offset (multiplicando por 4 via `sll de 2`). Soma isso ao contador programável nativo referindo aos ciclos simulados.
* **Loads / Stores (`lw`, `sw`, `lbu`, `sb`)**: Executa cálculo real do endereço através da equação Aritmética `(Conteúdo Reg(rs) + Imediato estendido)`. Aciona a importante MMU virtual do emulador `transfere_sim_para_host`. Usa funções diretas de salvamento na memória (`lw/sw/lbu/sb`) da base remetida pelo Mapeamento devolvido pela MMU e atua sobre `rt`.

---

## 6. Mecanismo de Syscall e Integração I/O

No emulador, acionar uma interrupção `syscall` instrui a rotina `exec_syscall` a observar o flag do registrador virtual simulado `reg[2]` (ou `$v0`). O MIPS simulado é dotado de transdutores nativos ao syscall do host SPIM/MARS correspondente. 

* **Operação Direta (Valores Inteiros - Svc `1`, `5`, `11`, `17`)**: Leem parâmetros do virtual `a0`, efetuam no Host, injetam regressores se preciso ou abortam o simulador (`exit`).
* **Operação Indireta/Ponteiros (Strings - Svc `4`, `8`)**: Como os endereços da simulação (`0x10010000`, etc) fariam segment fault no *Host*, usa-se `transfere_sim_para_host` garantindo que os bytes string a serem imprimidos ou gravados caiam efetivamente na fatia real do alocador `mem_data`, renegociando o ponteiro virtual até a chamada crua do syscall `4` ou `8`.

---

## 7. Interfaces Utilitárias Aditivas

* **`get_reg` / `set_reg`**: Garantes da mecânica RICS - Mips da máquina. Ambos conferem instantaneamente a indicação solicitada em `a0` (o idx do reg). Se equacionar à índice 0 ($zero), ele descarta as escritas (`set`) ou obriga devoluta em zero para leituras (`get`), evitando distúrbios na regra arquitetônica em que `$zero` jamais oscila de valor.  O cálculo das instâncias faz offset de byte em memória emulando ponteiros arrays comuns em compiladores C.
* **`carregar_arquivo`**: Adicionado no topo da pirâmide via diretrizes macro no `main`. Implementação rústica via posix-like da API de OS do MARS/SPIM (Svc 13 -> open, Svc 14 -> read, Svc 16 -> close) instanciando bytes diretos da raiz no HD local (como trabalho_01-2026_1.bin) sobrepondo toda a esteira virtual de abstração do programa.

---

## 8. Considerações Finais e Robustez

A modelagem efetuada neste código consagra-se como um emulador MIPS funcional exímio com robustez impressionante, apresentando:
1. **Padrão de Salvamento Preservado de Registradores Host:** Preserva devidamente blocos S em subrotinas e gerencia as matrizes `$s6` e `$s7` de maneira exemplar global. Padrão impecável de empilhamento de `$ra` em toda call em aninhamento. 
2. **Tratamento de Sign Extension seguro e inteligente:** Efetuado de ponta-a-ponta direto no Fetch, livrando a poluição na área de despache Execute.
3. **Mecanismos Contra Colapso Memory-bounds:** Tratativas eficientes do memory translation que atuariam abortando falhas graves do emulador perante à códigos defeituosos ou ponteiros envenenados provindos do binário.  

Trata-se de um sistema apto para simular sub-rotinas densas incluindo recursividade, ponteiros complexos (inclusive implementações C traduzidas para assembly mips como o caso de processador de literais no `.dat`), com rastreabilidade absoluta de recursos.
# 1. Introdução

O estudo da Organização e Arquitetura de Computadores exige a compreensão profunda de como o hardware interpreta e executa as instruções contidas no software. Nesse contexto, os simuladores de Conjunto de Instruções (ISA - *Instruction Set Architecture*) e as Máquinas Virtuais desempenham um papel fundamental. Eles permitem a observação detalhada e controlada do fluxo de dados, da manipulação de registradores e do gerenciamento de memória, isolando o ambiente de execução para fins educacionais e de validação de algoritmos.

O presente trabalho aborda o desafio técnico de projetar e implementar um simulador educacional da arquitetura MIPS32 utilizando a própria linguagem Assembly MIPS como ambiente hospedeiro. Essa abordagem de simulação (onde o hospedeiro e o alvo compartilham a mesma ISA) exige um controle rigoroso sobre o estado da máquina e as convenções de chamada. O simulador precisa preservar seu próprio contexto de execução — como sua pilha, seus ponteiros e seus registradores de retorno — enquanto gerencia simultaneamente as estruturas virtuais do programa alvo, garantindo que não ocorram sobreposições indevidas ou falhas de segmentação de memória.

Para solucionar esse problema, foi desenvolvido um simulador modular capaz de carregar arquivos binários brutos (`.bin` e `.dat`) e mapeá-los de forma segura em segmentos de memória simulados (Texto, Dados e Pilha). O sistema reproduz fielmente o caminho de dados (*datapath*) de um processador monociclo por meio da implementação rigorosa do ciclo de Busca, Decodificação e Execução (*Fetch-Decode-Execute*). A solução final suporta um subconjunto representativo de 15 instruções (abrangendo os formatos R, I e J) e gerencia as chamadas de sistema (*syscalls*), estabelecendo uma infraestrutura robusta para a execução de códigos MIPS complexos diretamente no console.

# 2. Objetivos

**Objetivo Geral**

O objetivo principal deste trabalho é projetar e desenvolver um simulador funcional de um subconjunto da arquitetura de conjunto de instruções (ISA) MIPS32, utilizando, para isso, a própria linguagem de montagem MIPS. O simulador deve ser capaz de inicializar o seu próprio ambiente, carregar programas alvo pré-compilados e reproduzir com exatidão o seu comportamento na memória, atuando como uma máquina virtual básica e isolada.

**Objetivos Específicos**

Para alcançar o objetivo central e garantir o funcionamento seguro e preciso do simulador, foram definidos os seguintes objetivos específicos:

* **Mapeamento de Memória:** Implementar estruturas no hospedeiro para emular a organização de memória do MIPS, isolando e gerenciando os segmentos de Texto (instruções), Dados (variáveis estáticas) e Pilha (memória dinâmica de execução), cada um com tamanho fixo de 4096 bytes.
* **Ciclo de Instrução:** Desenvolver o laço principal de controle implementando as etapas clássicas de Busca, Decodificação e Execução (*Fetch-Decode-Execute*), utilizando operações lógicas bit a bit (máscaras e deslocamentos) para extrair os campos do Registrador de Instrução (IR).
* **Encapsulamento de Registradores:** Construir e gerenciar um banco de 32 registradores de 32 bits de propósito geral, assegurando as restrições arquiteturais da máquina, como a imutabilidade obrigatória do registrador `$zero` e a correta inicialização do ponteiro de pilha (`$sp`).
* **Tradução de Endereços:** Desenvolver uma rotina de validação e conversão de endereços (semelhante a uma *Memory Management Unit* - MMU) que traduza os endereços virtuais do programa simulado para os endereços físicos do hospedeiro, prevenindo falhas de segmentação.
* **Gerenciamento de E/S e Arquivos:** Criar rotinas baseadas em chamadas de sistema (*syscalls*) para abrir e ler os arquivos binários brutos de entrada (`.bin` e `.dat`), transferindo seu conteúdo para a memória simulada.
* **Execução e Controle de Fluxo:** Suportar o roteamento e a execução correta de um subconjunto de 15 instruções (abrangendo os formatos R, I e J) e simular serviços do sistema, como impressão de dados e encerramento de rotinas.

# 3. Revisão Bibliográfica

A fundamentação teórica deste trabalho engloba os conceitos estruturais da arquitetura MIPS, a organização de seu espaço de endereçamento de memória, o funcionamento do ciclo de instrução e o emprego de operações lógicas e aritméticas bit a bit para a decodificação de opcodes e operandos.

## 3.1. A Arquitetura MIPS e a Filosofia RISC

A arquitetura MIPS (*Microprocessor without Interlocked Pipelined Stages*) é um modelo clássico de computador com conjunto reduzido de instruções (RISC - *Reduced Instruction Set Computer*). Diferente das arquiteturas CISC (*Complex Instruction Set Computer*), que possuem instruções complexas de tamanho variável e múltiplos modos de endereçamento, a filosofia RISC baseia-se em princípios de simplicidade e regularidade para otimizar o desempenho do hardware:

* **Instruções de tamanho fixo:** Todas as instruções MIPS possuem exatamente 32 bits (4 bytes), o que simplifica drasticamente o estágio de busca e o alinhamento na memória.
* **Arquitetura Load/Store:** As operações aritméticas e lógicas são executadas exclusivamente entre registradores internos do processador. O acesso à memória de dados é restrito a instruções específicas de carregamento (`lw`, `lbu`) e armazenamento (`sw`, `sb`).
* **Banco de registradores ortogonal:** O MIPS32 dispoe de um banco de 32 registradores de propósito geral, cada um com 32 bits de largura (denotados de `$0` a `$31`). Por convenção de hardware, o registrador `$0` (`$zero`) é permanentemente conectado ao valor nulo (0) e qualquer tentativa de escrita nele é descartada.

## 3.2. Formatos de Instrução MIPS

Para manter a regularidade do decodificador físico, o MIPS mapeia todas as suas instruções em apenas três formatos estruturais básicos, variando a interpretação dos blocos de bits conforme o tipo de operação:

### Formato Tipo-R (Registrador)

Utilizado para instruções aritméticas, lógicas e de desvio indireto (como `addu`, `subu` e `jr`). Seus 32 bits são subdivididos em seis campos:

* **Opcode (6 bits):** Código de operação principal. No formato R, é sempre zero (`000000`).
* **rs (5 bits):** Primeiro registrador fonte.
* **rt (5 bits):** Segundo registrador fonte.
* **rd (5 bits):** Registrador de destino (onde o resultado será gravado).
* **shamt (5 bits):** Quantidade de deslocamento (*shift amount*), usado em operações de deslocamento de bits.
* **funct (5 bits):** Campo de função. Como o opcode é zero, este campo especifica a operação exata a ser realizada (ex: `33` para `addu`).

### Formato Tipo-I (Imediato)

Utilizado para instruções que envolvem constantes numéricas, acessos à memória ou desvios condicionais (como `addiu`, `ori`, `lw`, `sw`, `beq` e `bne`). Seus campos são:

* **Opcode (6 bits):** Identifica univocamente a instrução (ex: `9` para `addiu`).
* **rs (5 bits):** Registrador fonte ou base para o cálculo de endereço.
* **rt (5 bits):** Registrador destino (em operações aritméticas/load) ou registrador fonte adicional (em operações de store/branch).
* **Immediate (16 bits):** Um valor constante ou deslocamento relativo. Dependendo da instrução, este campo deve sofrer extensão de sinal (preservando o bit de sinal para operações aritméticas) ou extensão de zeros (para operações lógicas).

### Formato Tipo-J (Salto)

Utilizado para instruções de desvio incondicional direto na memória (`j` e `jal`). Possui uma estrutura simplificada para maximizar o tamanho do operando de destino:

* **Opcode (6 bits):** Identifica a instrução de salto (`2` para `j` e `3` para `jal`).
* **Address (26 bits):** Endereço absoluto do alvo do desvio. Como as instruções estão sempre alinhadas em palavras (múltiplos de 4 bytes), os dois bits menos significativos do endereço real são implicitamente zero. Na execução, este campo sofre um deslocamento lógico de dois bits para a esquerda (multiplicação por 4) e é concatenado com os quatro bits mais significativos do Program Counter (PC) corrente para formar o endereço de destino de 32 bits.

## 3.3. Organização da Memória Virtual no MIPS

O espaço de endereçamento linear do MIPS32 mapeia até $2^{32}$ bytes (4 GB). Para organizar a execução dos programas e proteger o sistema operacional, essa memória virtual é tradicionalmente segmentada em regiões distintas com fronteiras bem definidas:

1. **Segmento de Texto (*Text Segment*):** Região destinada ao armazenamento do código de máquina (instruções brutas). Convencionalmente, inicia-se no endereço base `0x00400000`. É uma área de memória protegida contra escrita em tempo de execução para evitar a corrupção do código.
2. **Segmento de Dados (*Data Segment*):** Região que armazena variáveis globais, dados estáticos alocados em tempo de compilação e o monte (*heap*) para alocação dinâmica. Inicia-se no endereço base `0x10010000`.
3. **Segmento de Pilha (*Stack Segment*):** Região utilizada para gerenciar o fluxo de execução de subrotinas, armazenando registros de ativação, variáveis locais e endereços de retorno (`$ra`). A pilha inicia-se no topo da memória de usuário, no endereço `0x7FFFEFFC`, e cresce dinamicamente em direção a endereços menores à medida que novos dados são empilhados.

## 3.4. O Ciclo Clássico de Instrução

O processamento de um programa em uma arquitetura de computadores baseia-se na repetição contínua de um laço de controle síncrono, dividido essencialmente em três etapas consecutivas:

* **Busca (*Fetch*):** O processador utiliza o endereço armazenado no registrador *Program Counter* (PC) para ler uma palavra de 32 bits da memória de texto. Essa palavra é copiada para o *Instruction Register* (IR), que reterá a instrução durante o restante do ciclo.
* **Decodificação (*Decode*):** O circuito de controle quebra os 32 bits do IR nos campos correspondentes (opcode, registradores, imediatos) de acordo com o formato da instrução. Paralelamente, o PC é atualizado para apontar para a próxima instrução sequencial ($PC = PC + 4$). Os valores dos registradores fontes mapeados pelos campos `rs` e `rt` são lidos do banco de registradores.
* **Execução (*Execute*):** A Unidade Lógica e Aritmética (ULA) realiza a operação comandada pela unidade de controle (ou o cálculo de endereço de memória, ou a comparação de desvio). O resultado é escrito no registrador de destino (`rd` ou `rt`), ou utilizado para atualizar o PC em caso de instruções de salto/ramificação (`j`, `jal`, `jr`, `beq`, `bne`).

## 3.5. Operações Bit a Bit na Emulação de Software

Em um simulador baseado em software, o hardware físico do decodificador é substituído por expressões lógicas programadas. Para isolar os bits específicos de cada campo contido no Instructon Register (IR), utilizam-se duas operações primitivas da álgebra booleana:

* **Máscaras de Bits (Operação AND):** A operação lógica `AND` com uma constante (máscara) é empregada para zerar todos os bits irrelevantes de uma palavra, preservando intactos apenas os bits da posição desejada. Por exemplo, para isolar um campo de 5 bits, utiliza-se a máscara hexadecimal `0x1F` (binário `11111`).
* **Deslocamentos Lógicos (Shifts):** As operações de deslocamento para a direita (`SRL` - *Shift Right Logical*) reposicionam os bits isolados pelas máscaras para as posições menos significativas (alinhamento à direita), convertendo o arranjo de bits original em um valor numérico inteiro diretamente tratável pelo software hospedeiro.


# 4. Metodologia

Esta seção detalha a arquitetura do simulador MIPS construído e as decisões de projeto adotadas para a sua implementação puramente em linguagem de montagem (Assembly MIPS). O núcleo da solução baseia-se na separação estrita entre o estado da máquina hospedeira (o simulador em si) e o estado da máquina alvo (o programa simulado).

## 4.1. Estruturas de Dados e Organização da Memória

Todo o estado do processador simulado foi mapeado estaticamente no segmento `.data` do hospedeiro, garantindo alinhamento em palavra (`.align 2`) para evitar exceções de hardware durante acessos de 32 bits. As estruturas principais incluem:

* **Segmentos de Memória:** Foram alocados três blocos de 4096 bytes (`.space 4096`) denominados `mem_text`, `mem_data` e `mem_stack`. Embora fisicamente adjacentes ou próximos na memória do hospedeiro, logicamente eles representam os endereços base virtuais `0x00400000`, `0x10010000` e o topo da pilha em `0x7FFFEFFC`, respectivamente.
* **Banco de Registradores:** O vetor `reg` foi alocado com 128 bytes (32 palavras de 32 bits).
* **Registradores de Controle:** As variáveis globais `PC` (Program Counter) e `IR` (Instruction Register) mantêm o controle do fluxo. Além disso, os campos individuais das instruções (`inst_opcode`, `inst_rs`, `inst_imm`, etc.) foram declarados como variáveis isoladas para facilitar o acesso durante o estágio de execução.

Para otimizar o desempenho do simulador, os registradores `$s6` e `$s7` do hospedeiro foram dedicados, durante todo o ciclo de vida do programa, para armazenar o endereço base do vetor `reg` e o endereço da variável `PC`, respectivamente.

## 4.2. Encapsulamento do Banco de Registradores

Para garantir a fidelidade arquitetural, o acesso ao vetor `reg` foi estritamente encapsulado por meio de dois procedimentos independentes: `get_reg` e `set_reg`.

Ambos os procedimentos recebem o índice do registrador (0 a 31) como argumento. A regra de ouro do MIPS — a imutabilidade do registrador `$zero` — foi implementada com um desvio condicional simples (`beqz`) no início de ambos os procedimentos. Se o índice solicitado for 0, o procedimento de escrita (`set_reg`) aborta silenciosamente a operação, e o de leitura (`get_reg`) retorna o valor inteiro nulo imediatamente, impedindo a corrupção do estado da máquina.

## 4.3. A Unidade de Gerenciamento de Memória (MMU) Simulada

Um dos maiores desafios técnicos da simulação *host-target* idêntica é o acesso à memória. Se o programa alvo executar um `lw $t0, 0x10010000`, o hospedeiro não pode acessar o endereço físico `0x10010000`, pois isso causaria uma violação de acesso (*segmentation fault*) no sistema operacional subjacente.

Para resolver isso, foi implementado o procedimento `transfere_sim_para_host`. Ele atua como uma MMU básica, realizando a seguinte validação:

1. Recebe o endereço virtual do alvo.
2. Compara o endereço contra os limites (base e teto) dos três domínios virtuais conhecidos (`TEXT_BASE`, `DATA_BASE`, `STACK_TOP`).
3. Ao identificar a qual segmento o endereço pertence, calcula o deslocamento (*offset*) subtraindo o endereço base virtual.
4. Soma este *offset* ao ponteiro real do buffer correspondente no hospedeiro (`mem_text`, `mem_data` ou `mem_stack`), retornando um endereço físico seguro para a operação de leitura ou escrita.

## 4.4. O Ciclo Principal de Execução

O núcleo operacional do simulador reside em um laço infinito denominado `exec_loop`, que orquestra a execução das instruções através de três fases distintas:

### Busca (Fetch)

Nesta fase, o simulador utiliza o valor contido na variável `PC` para calcular o deslocamento dentro do vetor `mem_text`. A palavra de 32 bits correspondente é carregada da memória e armazenada na variável `IR` (Instruction Register).

### Decodificação (Decode)

A primeira ação do estágio de decodificação é incrementar o Program Counter em 4 bytes ($PC = PC + 4$). Isso é crucial para que instruções que dependem do PC relativo (como saltos condicionais e salvamento de endereço de retorno no `$ra`) funcionem corretamente.

Em seguida, o valor de `IR` sofre uma série de operações lógicas para a extração de campos:

* **Deslocamentos (`srl`):** Movem os bits de interesse para a direita.
* **Máscaras (`andi`):** Isolam a quantidade exata de bits (ex: `0x3F` para 6 bits de *opcode*, `0x1F` para 5 bits de registradores).

Um destaque técnico desta fase é a técnica de extensão de sinal para o campo imediato (`inst_imm`) de 16 bits. Em vez de utilizar condicionais para testar o bit mais significativo, o simulador executa um deslocamento lógico à esquerda de 16 bits (`sll`), seguido imediatamente por um deslocamento aritmético à direita de 16 bits (`sra`). Esta abordagem aproveita a arquitetura do hospedeiro para replicar o bit de sinal de forma nativa e altamente eficiente.

### Execução (Execute)

A fase de execução age como um comutador (*switch-case*). O simulador lê o `inst_opcode` isolado na etapa anterior e executa uma cascata de desvios condicionais (`beq`) contra constantes pré-definidas (diretivas `.eqv`).

* **Instruções I e J:** São despachadas diretamente para seus respectivos blocos de execução (ex: `exec_addiu`, `exec_j`, `exec_beq`).
* **Instruções Tipo-R:** Se o *opcode* for `0` (OP_RTYPE), ocorre um sub-roteamento. O simulador lê a variável `inst_funct` e realiza uma segunda camada de desvios para identificar operações específicas como `addu`, `subu`, `jr` ou `syscall`.

## 4.5. Tratamento de Syscalls e Carregamento Incial

Antes de entrar no ciclo principal, o simulador utiliza *syscalls* reais do hospedeiro (13 para `open`, 14 para `read`, e 16 para `close`) para carregar o conteúdo binário bruto dos arquivos `.bin` e `.dat` diretamente para os buffers de memória `mem_text` e `mem_data`.

Durante a execução do programa alvo, quando um `syscall` simulado é encontrado (Tipo-R, funct 12), o sistema intercepta a chamada. Ele utiliza `get_reg` para verificar o serviço solicitado no registrador `$v0` alvo (`reg[2]`). Dependendo do código contido, o simulador repassa a chamada de impressão de inteiros, strings ou solicita o encerramento seguro da simulação, fechando o ciclo de isolamento da máquina virtual.
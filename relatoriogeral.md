
# Simulador Educacional MIPS32 *Host-Target* em Linguagem Assembly

**Disciplina:** ELC1011 - Organização de Computadores

**Desenvolvedores:** Gabriel Souza Baggio e Gabriel Stiegemeier


---

## 1. Introdução

O estudo da Organização e Arquitetura de Computadores exige a compreensão aprofundada de como as camadas de hardware interpretam e executam as instruções codificadas em software. Nesse cenário, os simuladores de Conjunto de Instruções (ISA — *Instruction Set Architecture*) e as Máquinas Virtuais atuam como ferramentas fundamentais. Eles fornecem um ambiente isolado e controlado que permite a observação detalhada do fluxo de dados, da manipulação de registradores e do gerenciamento de memória para fins educacionais e de validação de algoritmos.

Este documento detalha o projeto e a implementação de um simulador educacional da arquitetura MIPS32 desenvolvido integralmente na própria linguagem de montagem Assembly MIPS. Essa metodologia de emulação, na qual o sistema hospedeiro (*host*) e o programa alvo (*target*) compartilham a mesma ISA, impõe desafios de engenharia complexos. O simulador deve manter controle rigoroso sobre o estado da máquina, preservando o seu próprio contexto de execução, incluindo sub-rotinas, ponteiros de pilha e registradores de retorno, enquanto manipula e isola simultaneamente as estruturas de dados do programa emulado, prevenindo sobreposições na memória ou falhas de segmentação (*segmentation faults*).

Para solucionar essa problemática, foi desenvolvida uma arquitetura modular que carrega arquivos binários brutos (`.bin` para instruções e `.dat` para dados), interpretando-os sob a premissa de ordenação de bytes *little-endian* conforme os requisitos de projeto. O software emula o caminho de dados (*datapath*) de um processador monociclo clássico por meio do ciclo síncrono de Busca, Decodificação e Execução (*Fetch-Decode-Execute*). A solução final expande o escopo originalmente proposto ao suportar de forma robusta um subconjunto de 15 instruções dos formatos R, I e J, além de fornecer um subsistema estendido para tratamento de chamadas de sistema (*syscalls*), estabelecendo uma infraestrutura completa e isolada de processamento diretamente no console do hospedeiro.

---



## 2. Objetivos

### 2.1. Objetivo Geral

O objetivo central deste trabalho consiste em projetar, desenvolver e homologar um simulador funcional de um subconjunto da arquitetura de conjunto de instruções (ISA) MIPS32, utilizando a própria linguagem de montagem MIPS como ambiente hospedeiro (*host*). O sistema deve ser capaz de inicializar o seu próprio ambiente de execução de forma independente, carregar programas alvo pré-compilados em formato binário bruto e reproduzir com exatidão o comportamento do caminho de dados e da memória virtual do processador emulado, atuando como uma máquina virtual básica e estritamente isolada.

### 2.2. Objetivos Específicos

Para a consecução do objetivo principal e salvaguarda da estabilidade operacional da máquina virtual, foram estabelecidas as seguintes metas específicas:

* **Mapeamento e Isolamento de Memória:** Estruturar regiões de armazenamento estático no segmento de dados do hospedeiro para emular a segmentação de memória da arquitetura MIPS, isolando e gerenciando os domínios virtuais de Texto, Dados e Pilha, aplicando uma restrição de tamanho fixo de 4096 bytes para cada partição.
* **Controle de Ciclo de Instrução:** Desenvolver o laço principal de controle síncrono encarregado de orquestrar as etapas clássicas de Busca, Decodificação e Execução (*Fetch-Decode-Execute*), operando manipulações de álgebra booleana (máscaras de bits e deslocamentos lógicos) para a extração analítica dos campos contidos no Registrador de Instrução (IR).
* **Encapsulamento Crítico de Registradores:** Construir uma abstração lógica para o banco de 32 registradores de propósito geral de 32 bits, garantindo por software a conformidade com as restrições nativas de hardware, tais como a imutabilidade absoluta do registrador `$zero` e a coerência de inicialização do ponteiro de pilha (`$sp`).
* **Tradução Dinâmica de Endereços (MMU):** Projetar uma unidade de gerenciamento de memória em software capaz de interceptar requisições de leitura e escrita do programa emulado, traduzindo os endereços virtuais do alvo (*target*) em posições físicas seguras no arranjo do hospedeiro (*host*) para evitar violações de acesso.
* **Abstração de Subsistema de Entrada/Saída:** Desenvolver rotinas robustas de manipulação de arquivos com base em chamadas de sistema do hospedeiro, viabilizando a abertura, leitura e transferência sequencial dos fluxos de dados dos arquivos de entrada (`.bin` e `.dat`) para os buffers de memória simulados.
* **Roteamento de Fluxo e Suporte de Instruções:** Implementar uma estrutura de despacho (*dispatcher*) eficiente para suportar o mapeamento e a execução correta do conjunto expandido de 15 instruções (abrangendo os formatos R, I e J), além de prover suporte estendido para o tratamento de *syscalls* simuladas destinadas à exibição de dados e terminação de rotinas.

---

## 3. Fundamentação Teórica

### 3.1. A Arquitetura MIPS e a Filosofia RISC

A arquitetura MIPS (*Microprocessor without Interlocked Pipelined Stages*) representa um modelo consolidado de computadores com conjunto reduzido de instruções (RISC — *Reduced Instruction Set Computer*). Diferenciando-se das arquiteturas CISC (*Complex Instruction Set Computer*), que incorporam instruções complexas de tamanho variável e múltiplos modos de endereçamento, a filosofia RISC fundamenta-se nos princípios de simplicidade, regularidade e simetria para otimizar o desempenho do hardware por meio de estruturas simplificadas:

* **Instruções de Tamanho Fixo:** Todas as instruções MIPS possuem extensão rígida de exatamente 32 bits (4 bytes). Essa padronização simplifica significativamente o estágio de busca (*fetch*), o alinhamento de palavras na memória e a decodificação dos campos por hardware.
* **Arquitetura *Load/Store*:** As operações aritméticas, lógicas e de deslocamento ocorrem exclusivamente entre os registradores internos do processador. O acesso à memória de dados é restrito a um conjunto restrito de instruções dedicadas de carregamento (`lw`, `lbu`) e armazenamento (`sw`, `sb`).
* **Ortogonalidade do Banco de Registradores:** O MIPS32 dispõe de um banco contendo 32 registradores de propósito geral, cada um com 32 bits de largura (denotados de `$0` a `$31`). Por especificação de hardware, o registrador `$0` (`$zero`) é permanentemente aterrado ao valor nulo (0), descartando qualquer tentativa de modificação em seu estado.

### 3.2. Formatos de Instrução MIPS

Para assegurar a regularidade do decodificador, o MIPS unifica o seu mapeamento lógico em apenas três formatos estruturais básicos, variando a interpretação de seus blocos de bits conforme a natureza da operação:

#### Formato Tipo-R (Registrador)

Empregado em instruções aritméticas, lógicas e de desvio indireto por registrador (como `addu`, `subu` e `jr`). Seus 32 bits são subdivididos em seis campos específicos:

* **Opcode (6 bits):** Código de operação principal, fixado em zero (`000000`) para todas as variações do Tipo-R.
* **rs (5 bits):** Identificador do primeiro registrador fonte.
* **rt (5 bits):** Identificador do segundo registrador fonte.
* **rd (5 bits):** Identificador do registrador de destino, onde o resultado da operação será consolidado.
* **shamt (5 bits):** Quantidade de deslocamento (*shift amount*), utilizada em operações de manipulação de bits.
* **funct (6 bits):** Campo de função que mapeia univocamente a operação exata a ser executada pela ULA (ex: código `33` para `addu`), uma vez que o *opcode* permanece zerado.

#### Formato Tipo-I (Imediato)

Utilizado para instruções que demandam constantes numéricas embutidas no próprio código, acessos à memória ou desvios condicionais relativos (como `addiu`, `ori`, `lui`, `lw`, `sw`, `beq` e `bne`). Seus campos compreendem:

* **Opcode (6 bits):** Identifica a instrução de forma unívoca (ex: `9` para `addiu`).
* **rs (5 bits):** Registrador fonte ou ponteiro base para o cálculo de endereçamento.
* **rt (5 bits):** Registrador destino em operações de carregamento e aritmética imediata, ou registrador fonte adicional em rotinas de armazenamento e ramificação.
* **Immediate (16 bits):** Campo para constantes ou *offsets* de memória. Conforme a instrução, este campo é submetido à extensão de sinal (preservando o bit de sinal para operações aritméticas) ou extensão de zeros (para operações lógicas).

#### Formato Tipo-J (Salto)

Aplicado em instruções de desvio incondicional direto (como `j` e `jal`). Possui estrutura simplificada para maximizar o alcance do operando de destino:

* **Opcode (6 bits):** Identificador da instrução de salto absoluto (ex: `2` para `j`).
* **Address (26 bits):** Endereço bruto do alvo do desvio. Como as instruções MIPS estão obrigatoriamente alinhadas em limites de palavras (múltiplos de 4 bytes), os dois bits menos significativos do endereço real são implicitamente nulos. Em tempo de execução, este campo sofre um deslocamento lógico de dois bits para a esquerda (multiplicação por 4) e seus 28 bits resultantes são concatenados com os quatro bits mais significativos do *Program Counter* (PC) corrente para compor o endereço alvo final de 32 bits.

### 3.3. Organização da Memória Virtual no MIPS

O espaço de endereçamento linear do MIPS32 projeta um limite teórico de até $2^{32}$ bytes (4 GB). Para estruturar a execução segura de rotinas e isolar os contextos de software, essa memória virtual é dividida em regiões lógicas distintas:

1. **Segmento de Texto (*Text Segment*):** Região reservada para o armazenamento do código de máquina (instruções binárias). Inicia-se convencionalmente no endereço base `0x00400000`. Trata-se de uma zona protegida contra escrita em tempo de execução para salvaguardar a integridade do programa.
2. **Segmento de Dados (*Data Segment*):** Região destinada ao armazenamento de variáveis globais, dados estáticos alocados em tempo de compilação e estruturas dinâmicas (*heap*). Tem seu início mapeado no endereço base `0x10010000`.
3. **Segmento de Pilha (*Stack Segment*):** Estrutura alocada para gerenciar os registros de ativação de funções, variáveis locais e salvamento de contextos e endereços de retorno (`$ra`). A pilha é inicializada no topo da memória do usuário, no endereço limite `0x7FFFEFFC`, e cresce dinamicamente em direção a endereços decrescentes à medida que novos dados são empilhados.

### 3.4. O Ciclo Clássico de Instrução

O processamento sequencial de um programa baseia-se na repetição contínua de um laço de controle síncrono, estruturado em três etapas macro:

* **Busca (*Fetch*):** A unidade de controle utiliza o endereço armazenado no registrador *Program Counter* (PC) para realizar a leitura da palavra de 32 bits correspondente dentro da memória de texto. Essa palavra é transferida para o *Instruction Register* (IR), que reterá a instrução estaticamente durante o ciclo corrente.
* **Decodificação (*Decode*):** O decodificador analisa os bits contidos no IR, isolando os campos estruturais (opcodes, operandos, imediatos). Simultaneamente, o PC é atualizado para apontar para o próximo endereço sequencial ($PC = PC + 4$) e os registradores fontes mapeados por `rs` e `rt` têm seus valores extraídos do banco de registradores.
* **Execução (*Execute*):** A Unidade Lógica e Aritmética (ULA) processa a operação designada pela unidade de controle, efetua cálculos de ponteiros de memória ou realiza as comparações de desvio. O resultado obtido é gravado no registrador de destino adequado (`rd` ou `rt`) ou utilizado para atualizar o PC em caso de saltos ou ramificações (`j`, `jal`, `jr`, `beq`, `bne`).

### 3.5. Operações Bit a Bit na Emulação de Software

Em um ambiente onde o simulador é construído puramente em software, os circuitos combinatórios do decodificador físico são substituídos por expressões lógicas programadas. Para isolar os bits específicos de cada campo contido no IR, utilizam-se duas operações primitivas da álgebra booleana:

* **Máscaras de Bits (Operação AND):** A operação lógica `AND` com uma constante estruturada (máscara) é empregada para zerar todos os bits irrelevantes da instrução, preservando intactos apenas os bits da janela de interesse. Para campos de 5 bits (como os identificadores de registradores), utiliza-se a máscara hexadecimal `0x1F` (binário `11111`).
* **Deslocamentos Lógicos (*Shifts*):** As operações de deslocamento para a direita (`SRL` — *Shift Right Logical*) reposicionam os bits remanescentes das máscaras em direção às posições menos significativas (alinhamento à direita). Esse processo converte o arranjo binário original em um valor numérico inteiro diretamente tratável pelo fluxo operacional do software hospedeiro.

---

## 4. Metodologia e Arquitetura do Simulador

O núcleo do simulador baseia-se na separação estrita entre o estado da máquina hospedeira (o emulador propriamente dito) e o estado da máquina alvo (o programa MIPS emulado). Todo o estado do processador virtual foi mapeado estaticamente no segmento `.data` do hospedeiro.

### 4.1. Estruturas de Dados e Organização da Memória

Para mitigar o risco de exceções de hardware por acessos desalinhados de 32 bits, todas as estruturas globais receberam a diretiva de alinhamento em palavra (`.align 2`) antes de suas respectivas alocações. A memória virtual mapeada compreende três blocos independentes de 4096 bytes (4 KB), alocados via diretiva `.space 4096`, que representam os seguintes segmentos lógicos:

* **Segmento de Texto (`mem_text`):** Mapeado para o endereço base simulado `0x00400000`, destinado a armazenar as instruções binárias obtidas do arquivo `.bin`.
* **Segmento de Dados (`mem_data`):** Mapeado para o endereço base simulado `0x10010000`, reservado para a inicialização e manipulação de variáveis estáticas extraídas do arquivo `.dat`.
* **Segmento de Pilha (`mem_stack`):** Mapeado para o endereço base superior `0x7FFFEFFC`, operando com crescimento reverso em direção a endereços menores (intervalo limite de `0x7FFFEFFC` até `0x7FFFE000`).

### 4.2. Encapsulamento e Otimização do Banco de Registradores

O banco de registradores da máquina alvo foi construído como um vetor linear denominado `reg`, totalizando 128 bytes (32 elementos de 4 bytes). Para assegurar a integridade das restrições arquiteturais da ISA MIPS, o acesso a essa estrutura foi estritamente encapsulado por meio de dois procedimentos de controle:

* **`get_reg` (Leitura):** Recebe o índice do registrador em `$a0` e retorna o valor correspondente; inclui um desvio condicional (`beqz`) que intercepta o índice `0` e força o retorno imediato do valor nulo.
* **`set_reg` (Escrita):** Recebe o índice em `$a0` e o dado em `$a1`; caso o índice seja `0`, o procedimento aborta a operação silenciosamente, garantindo a imutabilidade do registrador `$zero`.

Como fator de otimização de desempenho e redução de *overhead* de acesso à memória RAM no laço principal, os registradores `$s6` e `$s7` do hospedeiro foram permanentemente dedicados para reter, respectivamente, o endereço base do array `reg` e o ponteiro da variável `PC` ao longo de todo o ciclo de vida da simulação.

### 4.3. A Unidade de Gerenciamento de Memória Virtual (MMU)

O acesso direto aos endereços virtuais do alvo (como `0x10010000`) provocaria falhas de segmentação catastróficas no sistema operacional do hospedeiro. Para solucionar essa barreira, implementou-se o procedimento `transfere_sim_para_host`, que atua como uma Unidade de Gerenciamento de Memória (MMU) em nível de software. O fluxo lógico do tradutor executa os seguintes passos:

1. Recebe o endereço virtual solicitado pelo programa alvo.
2. Compara o valor contra os limites superiores e inferiores dos três domínios virtuais mapeados (`TEXT_BASE`, `DATA_BASE` e `STACK_TOP`).
3. Identificado o segmento legítimo, calcula o deslocamento relativo (*offset*) subtraindo o endereço virtual pelo seu respectivo endereço base estrutural.
4. Soma o *offset* calculado ao endereço de memória real do buffer alocado no *host* (`mem_text`, `mem_data` ou `mem_stack`), disponibilizando um ponteiro físico seguro para a operação de leitura ou escrita.
5. Caso o endereço virtual não pertença a nenhum dos intervalos válidos, o simulador interrompe a execução e emite a mensagem de erro de sistema: `"Endereço fora dos segmentos simulados"`.

---

## 5. Motor de Execução e Conjunto de Instruções

O núcleo operacional do simulador reside em um laço infinito denominado `exec_loop`, responsável por orquestrar a interpretação de cada instrução por meio da emulação estrita de um caminho de dados monociclo.

### 5.1. O Ciclo Lógico de Processamento (*Fetch-Decode-Execute*)

O processamento de cada palavra binária é segmentado em três rotinas independentes:

* **Busca (`exec_fetch`):** A rotina extrai o valor atual da variável `PC` e calcula o limite de deslocamento em memória por meio da equação $Offset = PC - \text{TEXT\_BASE}$. O deslocamento é somado ao endereço nativo do vetor `mem_text`, permitindo a leitura exata de 4 bytes na memória do hospedeiro, cujo valor é transferido para o Registrador de Instrução (`IR`).
* **Decodificação (`exec_decode`):** A primeira operação deste estágio é o incremento obrigatório do Contador de Programa ($PC = PC + 4$), garantindo a corretude dos desvios relativos. Em seguida, a instrução de 32 bits presente no `IR` é dissecada através de máscaras lógicas (`andi`) e deslocamentos lógicos (`sll`, `srl`). Uma otimização arquitetural implementada nesta fase é a técnica de extensão de sinal para o campo imediato (`imm`) de 16 bits: o simulador realiza um deslocamento lógico à esquerda de 16 bits (`sll`), seguido imediatamente por um deslocamento aritmético à direita (`sra`), replicando nativamente o bit mais significativo (MSB) para as posições superiores sem a necessidade de desvios condicionais.
* **Execução (`exec_execute`):** A unidade de despacho age como um comutador de fluxo (*switch-case*) baseado em comparações diretas (`beq`) contra os *opcodes* mapeados em diretivas estáticas do sistema.

### 5.2. Conjunto Expandido de 15 Instruções

O simulador superou as especificações iniciais ao implementar um subconjunto robusto de 15 instruções, gerenciando as complexidades estruturais de cada tipo de formato:

* **Tipo-J (Saltos Absolutos):** Foram implementadas as instruções `j` e `jal`. Ambas extraem o campo de endereço de 26 bits, aplicam um deslocamento à esquerda de 2 posições (transformando-o em 28 bits) e aplicam a porta lógica `OR` com os 4 bits mais significativos do `PC` atualizado. Na instrução `jal`, o simulador invoca preliminarmente a rotina `set_reg(31)` para salvar o endereço de retorno no registrador `$ra` virtual.
* **Tipo-R (Operações Lógico-Aritméticas e Desvios Indiretos):** As instruções de *opcode* zero (`addu`, `subu`, `jr` e `syscall`) são roteadas para sub-ramificações por meio da avaliação de seus campos `funct`. As operações aritméticas utilizam o procedimento `get_reg` para resgatar os operandos, executam o cálculo nativamente no hospedeiro e invocam `set_reg` para consolidação do resultado. O desvio `jr` atualiza diretamente o `PC` com o conteúdo apontado pelo registrador fonte.
* **Tipo-I (Operações Imediatas e Ramificações):** Engloba instruções aritméticas (`addiu`), lógicas (`ori`, `lui`), de acesso à memória (`lw`, `sw`, `lbu`, `sb`) e de desvio condicional (`beq`, `bne`). Nas instruções lógicas puras como `ori`, a extensão de sinal não é aplicada, optando-se por uma limpeza de contexto superior via máscara `0xFFFF`. Nas instruções de ramificação, em caso de equivalência, o campo imediato sofre deslocamento posicional de 2 bits à esquerda e é integrado ao `PC` de forma relativa.

### 5.3. Integração de I/O e Syscalls Avançados

O fluxo de dados da máquina emulada depende substancialmente do gerenciamento de chamadas de sistema. Inicialmente, em sua fase de *boot*, o simulador consome diretamente os *syscalls* reais do sistema operacional hospedeiro (13 para `open`, 14 para `read` e 16 para `close`) para carregar o conteúdo bruto dos binários.

Durante a execução da rotina emulada, a interceptação da instrução `syscall` instrui a leitura imediata do registrador virtual `$v0` (`reg[2]`) para despachar o serviço correspondente. Além das opções de saída padrão (código 1) e terminação (código 10), o simulador foi expandido para suportar um *pipeline* avançado (códigos 4, 5, 8, 11 e 17).

Um desafio crítico superado nesta fase foi o tratamento das rotinas de impressão e leitura de cadeias de caracteres (*syscalls* 4 e 8). Como os endereços textuais fornecidos pelo programa alvo pertencem ao domínio virtual (ex: `0x10010000`), injetá-los diretamente no hospedeiro acarretaria falhas de segmentação fatais. Nesses casos, o simulador utiliza a MMU implementada (`transfere_sim_para_host`) para remapear dinamicamente o ponteiro da *string* para a contraparte real do vetor `mem_data`, garantindo que os fluxos de E/S operem com segurança em espaço físico de memória controlado.

---

## 6. Experimento e Validação

Para validar a corretude, a precisão arquitetural e a robustez do emulador implementado, conduziu-se um experimento de execução baseando-se no modelo *Host-Target*. O programa alvo selecionado como *benchmark* foi o `ex-000-073.asm`, um algoritmo de extração (tokenização) de palavras em uma *string*, cujo comportamento operacional assemelha-se à função `strtok` da biblioteca padrão da linguagem C.

### 6.1. O Programa Alvo (*Benchmark*) e o Teste de Estresse

O *benchmark* foi projetado para varrer uma cadeia de caracteres alocada no segmento de dados virtual, identificar palavras separadas por delimitadores predefinidos (espaço livre, tabulação `\t`, nova linha `\n` e vírgula `,`) e imprimi-las formatadas individualmente na saída padrão.

A escolha deste código de alta densidade como validador atua como um teste de estresse abrangente para a máquina virtual, pois submete múltiplos subsistemas a cenários críticos de operação:

* **Aninhamento de Funções e Fluxo de Controle:** O *benchmark* faz uso intensivo de chamadas de sub-rotinas (como os procedimentos lógicos `leia_palavra` e `caractere_eh_delimitador`), utilizando exaustivamente as instruções `jal` e `jr`. O sucesso desta operação valida a capacidade do simulador de empilhar múltiplos endereços de retorno no registrador virtual `$ra` (`reg[31]`) sem corromper o fluxo do hospedeiro.
* **Gerenciamento de Pilha e Contexto:** Para preservar registradores salvos (`$s0` a `$s2`) entre as chamadas aninhadas, o programa alvo manipula ativamente o `$sp`. Isso afere o crescimento reverso correto do *buffer* `mem_stack` e a capacidade das rotinas `lw` e `sw` de tratar deslocamentos (*offsets*) negativos na memória.
* **Acesso Granular através da MMU:** Tratando-se de processamento textual, o algoritmo acessa caracteres ASCII utilizando instruções de manipulação de *bytes* (`lbu` e `sb`). Este cenário valida se a rotina `transfere_sim_para_host` consegue manipular deslocamentos não alinhados dentro do vetor `mem_data` sem causar corrupção de memória ou exceções de desalinhamento no *host*.
* **Laços e Saltos Relativos:** A lógica intrínseca do laço *while* valida a extração do campo imediato por meio da extensão de sinal estendida na fase de decodificação e o cálculo de saltos relativos ao PC nas instruções de desvio condicional (`beq` e `bne`).

### 6.2. Metodologia de Inicialização (*Boot*)

Para a realização da simulação, o código-fonte do programa alvo foi previamente montado gerando os artefatos binários isolados: `trabalho_01-2026_1.bin` (segmento `.text`) e `trabalho_01-2026_1.dat` (segmento `.data`).

A fase de *boot* do simulador ocorreu de forma autônoma. O emulador consumiu as *syscalls* reais do sistema operacional hospedeiro (`13` para *open* e `14` para *read*) para transferir o conteúdo em arranjo *little-endian* diretamente para as estruturas `mem_text` e `mem_data`. Concluído o carregamento, os registradores de controle foram inicializados ($PC = \text{0x00400000}$ e $SP = \text{0x7FFFEFFC}$) e o controle foi repassado integralmente ao laço síncrono da máquina virtual.

---

## 7. Resultados e Discussão

### 7.1. Resultados Empíricos do *Benchmark*

A avaliação prática do simulador ocorreu por meio do carregamento e processamento integral dos arquivos binários correspondentes ao algoritmo tokenizador (`ex-000-073.asm`). O sistema operou de forma estável, executando o laço de interpretação sequencial sem apresentar travamentos, laços infinitos ou falhas de segmentação no ambiente hospedeiro.

A *string* de teste originalmente armazenada no segmento de dados virtual continha uma sequência complexa de caracteres alfanuméricos intercalados por múltiplos delimitadores contíguos (espaços em branco, tabulações `\t` e quebras de linha `\n`):
`"   \tteste1\tteste2 123.233\t\t\ta  122  r1\n01  fim x,y, z, \t w "`

Ao interceptar as instruções de chamada de sistema simuladas (*Syscalls* 4 e 11) e redirecioná-las de forma segura para os transdutores nativos do console do hospedeiro, o simulador gerou a seguinte saída exata:

```text
String: [   	teste1	teste2 123.233			a  122  r1
01  fim x,y, z, 	 w ]
Lendo as palavras da string
[teste1][teste2][123.233][a][122][r1][01][fim][x][y][z][w]

```

A formatação bem-sucedida das palavras isoladas entre colchetes atesta diretamente a precisão funcional de múltiplos subsistemas da máquina virtual:

1. As instruções de desvio condicional (`beq` e `bne`) computaram perfeitamente os desvios relativos ao PC, controlando a iteração dos ponteiros sobre os caracteres da *string*.
2. O isolamento do contexto de ativação da pilha permitiu que funções aninhadas operassem em harmonia, com a rotina principal (`main`) invocando o procedimento `leia_palavra`, que por sua vez acionava o validador `caractere_eh_delimitador`.
3. A manipulação granular de memória por meio de instruções de leitura e escrita de *bytes* (`lbu` e `sb`) processou os caracteres ASCII de maneira correta, inserindo o terminador nulo (`\0`) nas posições exatas do buffer sem afetar os dados adjacentes.

### 7.2. Discussão Técnica e Desafios de Coexistência

O desenvolvimento de um simulador cujo ambiente hospedeiro e alvo compartilham o mesmo conjunto de instruções impôs restrições severas à gerência de controle. O desafio técnico mais expressivo concentrou-se na preservação do registrador de endereço de retorno (`$ra`).

Quando o código alvo executa a instrução `jal`, o simulador precisa registrar o endereço virtual de retorno na posição `reg[31]` da máquina emulada. Todavia, o próprio simulador consome o registrador `$ra` físico nativo para gerenciar suas sub-rotinas internas, como os métodos `get_reg`, `set_reg` e `transfere_sim_para_host`. Para mitigar o risco de corrupção de fluxo, implementou-se um protocolo rígido de salvamento de contexto na pilha real do hospedeiro antes do despacho de qualquer instrução de desvio, garantindo o completo isolamento de escopo entre as duas instâncias.

Outro aspecto crítico validado pelo experimento foi a cronologia da atualização do *Program Counter*. Conforme preconizado pela arquitetura MIPS monociclo, o incremento $PC = PC + 4$ deve ocorrer obrigatoriamente de forma imediata na fase de decodificação. A precisão do algoritmo de tokenização demonstrou que essa ordem cronológica garantiu que os cálculos de saltos relativos baseados no PC adiantado e os salvamentos de link operassem em estrita conformidade com as especificações de hardware do MIPS32.

### 7.3. Otimizações de Desempenho e Robustez de Memória

Do ponto de vista da eficiência de software, a alocação permanente dos registradores físicos do hospedeiro `$s6` (para reter o endereço base do vetor `reg`) e `$s7` (para apontar para a variável `PC`) eliminou um gargalo crítico de processamento. Caso esses endereços fossem consultados diretamente na memória RAM a cada instrução interpretada, seriam necessárias sucessivas operações de carregamento (`la` e `lw`). Mantê-los constantemente em cache na CPU do *host* reduziu de forma drástica o *overhead* do laço de execução principal (`exec_loop`).

Por fim, o mecanismo de gerenciamento de memória virtual por software provou ser um elemento de salvaguarda essencial para a robustez do sistema. O tradutor de endereços barrou qualquer possibilidade de ponteiros corrompidos ou falhas de limite (*memory-bounds*) originadas pelo código alvo afetarem o espaço físico de memória do simulador, abortando a simulação de forma controlada caso houvesse violação dos limites de 4096 bytes estabelecidos por segmento.

---

## 8. Conclusão

O presente trabalho atingiu com êxito o objetivo de projetar, implementar e validar um simulador educacional da arquitetura MIPS32, desenvolvido integralmente sobre a própria linguagem Assembly MIPS. A adoção da metodologia de simulação *Host-Target* sob a mesma ISA impôs desafios rigorosos de engenharia de software, exigindo controle minucioso de contexto e memória para culminar em uma máquina virtual estável e isolada.

A implementação técnica transcendeu os requisitos funcionais mínimos estipulados pelas diretrizes do projeto. O motor de execução expandiu o subconjunto operacional para 15 instruções, incorporando saltos absolutos aninhados (`j`, `jal`) e consolidando um *pipeline* avançado de chamadas de sistema (*syscalls*) para fluxos de entrada e saída de dados. O desenvolvimento estratégico de uma Unidade de Gerenciamento de Memória (MMU) simulada garantiu a tradução transparente e segura dos endereços virtuais, protegendo o sistema hospedeiro de forma intransigente contra falhas de limites estruturais ou violações de acesso (*segmentation faults*).

Ademais, as decisões arquiteturais relacionadas ao encapsulamento do banco de registradores — destacando-se a salvaguarda inflexível do registrador `$zero` e o uso nativo de registradores fixos do hospedeiro (`$s6` e `$s7`) para o cacheamento de ponteiros base — revelaram-se vitais para a otimização de desempenho e segurança do laço principal. A execução bem-sucedida do *benchmark* de tokenização atestou empiricamente a exatidão cronológica do ciclo *Fetch-Decode-Execute* (especialmente no que tange ao adiantamento lógico do PC na decodificação) e a blindagem efetiva do registrador de retorno virtual (`$ra`).

Conclui-se, portanto, que a arquitetura desenvolvida transcende o propósito meramente ilustrativo de um processador monociclo didático. O sistema entrega uma infraestrutura de emulação robusta, rastreável e confiável, perfeitamente apta para a interpretação e depuração de algoritmos MIPS complexos de forma nativa e independente.

**Missão do Agente:** Você é um desenvolvedor especialista em Arquitetura de Computadores e Assembly MIPS. Seu objetivo é me auxiliar na implementação de um simulador educacional MIPS escrito inteiramente em linguagem Assembly MIPS. O código deve ser limpo, bem documentado e modularizado.

#### 1. Visão Geral da Arquitetura do Simulador

O simulador deverá carregar arquivos binários (`.bin` e `.dat`), alocá-los em estruturas de memória simuladas e reproduzir o ciclo de busca, decodificação e execução de um subconjunto de instruções MIPS. A arquitetura a ser assumida para a leitura dos dados é *little-endian*.

#### 2. Estruturas de Dados Obrigatórias

Você deve definir as seguintes estruturas globais/variáveis no segmento `.data` do nosso simulador:

**Memória (3 Segmentos):** Cada segmento deve possuir tamanho inicial de 4096 bytes e ser tratado como um vetor de inteiros de 32 bits.

`mem_text`: Endereço base em `0x00400000`.

`mem_data`: Endereço base em `0x10010000`.
 
`mem_stack`: Endereço base em `0x7FFFEFFC`, com crescimento para endereços menores.

**Registradores Gerais (`reg`):** Vetor de 32 elementos (inteiros de 32 bits). O índice 0 (`$0`) deve sempre retornar `0`. O registrador `$sp` (`reg[29]`) deve ser inicializado com `0x7FFFEFFC`. Os demais começam zerados.


* **Registradores de Controle:** 
`PC`: Inteiro de 32 bits, inicializado com `0x00400000`.
`IR`: Inteiro de 32 bits para armazenar a instrução atual.
 
**Campos de Instrução:** Variáveis individuais de 32 bits para os campos isolados: `opcode`, `rs`, `rt`, `rd`, `shamt`, `funct`, `immediate` e `address`.



#### 3. Procedimentos Base (Módulos de Sistema)

Antes de implementar o ciclo de execução, os seguintes procedimentos (funções) devem ser criados:

1. **Validação de Endereço:** Verificar se um dado endereço pertence a um dos três segmentos de memória mapeados.


2. **Escrita e Leitura em Memória:** Procedimentos seguros para ler/escrever nos vetores de memória simulada.


3. **Leitura de Arquivos (I/O):**
* Procedimento para abrir e ler os bytes de `trabalho_01-2026_1.bin` sequencialmente para a `mem_text`.


* Procedimento para abrir e ler os bytes de `trabalho_01-2026_1.dat` sequencialmente para a `mem_data`.


#### 4. O Ciclo de Execução (Main Loop)

O laço principal deve repetir os passos abaixo até encontrar um `syscall` de encerramento:

* **Busca (Fetch):** Acessar `mem_text` usando o endereço em `PC`, extrair a palavra de 32 bits e salvar em `IR`.

* **Decodificação:** Isolar os campos da instrução contida no `IR` através de máscaras de bits e shifts, salvar nas variáveis de campos, e obrigatoriamente incrementar o `PC` em 4 (`PC = PC + 4`).

* **Execução:** Utilizar o `opcode` (e `funct` para tipo R) para rotear o fluxo (branch/jump) para o procedimento que simula a instrução específica.

#### 5. Conjunto de Instruções Suportado

A lógica de execução deve implementar o seguinte *Instruction Set*:

* **Aritméticas:** `add`, `sub`, `addi`.


* **Lógicas:** `and`, `or`, `andi`, `ori`.


* **Acesso à Memória:** `lw`, `sw`.


* **Desvios e Saltos:** `beq`, `bne`, `j`.


* **Shifts e Sistema:** `sll`, `srl`, `syscall`.


* **Comportamento do Syscall:** O simulador deve ler o valor do próprio registrador `$v0` (no caso, `reg[2]`) e executar serviços de saída: código `1` (exit padrão) e código `10` (exit 2).

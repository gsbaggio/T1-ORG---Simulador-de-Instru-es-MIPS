
### 1. Estruturas de Dados e Variáveis (Segmento `.data`)

* [ ] **Segmento de Texto (`mem_text`):** Vetor de inteiros de 32 bits , com tamanho inicial de 4096 bytes e endereço base em `0x00400000`.


* [ ] **Segmento de Dados (`mem_data`):** Vetor de inteiros de 32 bits , com tamanho inicial de 4096 bytes e endereço base em `0x10010000`  (com carga de arquivo mapeada a partir de `0x10000000`) .


* [ ] **Segmento de Pilha (`mem_stack`):** Vetor de inteiros de 32 bits , com tamanho inicial de 4096 bytes e endereço base em `0x7FFFEFFC` (crescendo para endereços menores).


* [ ] **Banco de Registradores (`reg`):** Vetor de 32 elementos do tipo inteiro de 32 bits para simular os registradores de propósito geral.


* [ ] **Registradores Internos:** Variáveis inteiras de 32 bits para o Contador de Programa (`PC`) e Registrador de Instrução (`IR`).


* [ ] **Campos de Instrução:** Variáveis inteiras de 32 bits para armazenar isoladamente os campos `opcode`, `rs`, `rt`, `rd`, `shamt`, `funct`, `immediate` e `address`.



### 2. Procedimentos de Memória e Arquivos (I/O)

* [ ] **Procedimento de Validação:** Função para verificar se um determinado endereço de memória pertence a um dos três segmentos simulados.


* [ ] **Procedimento de Escrita:** Função para escrever um dado de forma segura em um dos segmentos de memória simulados.


* [ ] **Procedimento de Leitura:** Função para ler um dado de um dos segmentos de memória simulados.


* [ ] **Procedimento de Leitura de Arquivo Geral:** Função genérica para ler bytes de um arquivo externo e armazená-los na memória simulada.


* [ ] **Carga do Código (`.bin`):** Utilizar o procedimento de leitura para abrir o arquivo `trabalho_01-2026_1.bin` e armazenar os bytes sequencialmente em `mem_text` a partir de `0x00400000`, adotando o padrão *little-endian*.


* [ ] **Carga de Dados (`.dat`):** Utilizar o procedimento de leitura para abrir o arquivo `trabalho_01-2026_1.dat` e armazenar os bytes sequencialmente em `mem_data` a partir de `0x10000000`, adotando o padrão *little-endian*.



### 3. Rotina de Inicialização e Laço Principal (Main Loop)

* [ ] **Inicialização de Registradores:** Garantir que o registrador `$0` (índice 0) sempre retorne zero e inicializar o ponteiro de pilha `$sp` (`reg[29]`) com o valor `0x7FFFEFFC`.


* [ ] **Inicialização do PC:** Configurar o valor inicial de `PC` para `0x00400000`.


* [ ] **Etapa de Busca (Fetch):** Ler a palavra de 32 bits da `mem_text` no endereço apontado por `PC` e transferi-la para o `IR`.


* [ ] **Etapa de Decodificação (Decode):** Extrair e isolar os campos da instrução contida em `IR` , atualizar o `PC` incrementando-o em 4 (`PC = PC + 4`) , e identificar o tipo da instrução (R, I ou J).


* [ ] **Etapa de Execução (Execute):** Desviar o fluxo do programa para o procedimento específico da instrução baseado nos campos `opcode` e `funct`.



### 4. Conjunto de Instruções a Simular

* [ ] **Instruções Aritméticas:** Implementar o comportamento de `add`, `sub` e `addi`.


* [ ] **Instruções Lógicas:** Implementar o comportamento de `and`, `or`, `andi` e `ori`.


* [ ] **Transferência de Dados:** Implementar o comportamento de `lw` e `sw`.


* [ ] **Instruções de Desvio/Salto:** Implementar o comportamento de `beq`, `bne` e `j`.


* [ ] **Instruções de Deslocamento:** Implementar o comportamento de `sll` e `srl`.


* [ ] **Chamadas de Sistema (`syscall`):** Verificar o código de serviço contido em `$v0` (`reg[2]`)  e implementar obrigatoriamente:


* [ ] Serviço `exit` (código de encerramento 1).


* [ ] Serviço `exit 2` (código de encerramento 10).





### 5. Documentação e Entrega Final

* [ ] **Testes e Validação:** Verificar o funcionamento e documentar individualmente cada procedimento logo após sua escrita.


* [ ] **Código-Fonte:** Garantir que todos os arquivos-fonte em assembly MIPS estejam completos, funcionais e com organização clara.


* [ ] **Relatório Técnico (PDF):** Redigir o documento em paralelo com o desenvolvimento das tarefas, estruturado com os seguintes capítulos obrigatórios:


* [ ] Introdução 


* [ ] Objetivos (Geral e Específicos) 


* [ ] Revisão Bibliográfica 


* [ ] Metodologia (detalhes da implementação) 


* [ ] Experimento (testes realizados) 


* [ ] Resultados (saídas geradas pelo simulador) 


* [ ] Discussão (análise de resultados e desafios) 


* [ ] Conclusões e Perspectivas 




* [ ] **Empacotamento:** Compactar o relatório em PDF e os arquivos de código-fonte em um arquivo único no formato `.zip`.


* [ ] **Envio:** Submeter o arquivo `.zip` através do Moodle dentro do prazo estipulado.
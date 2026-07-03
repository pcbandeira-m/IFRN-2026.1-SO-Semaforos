# O Problema dos Leitores / Escritores em Elixir

Este repositório apresenta uma solução para o clássico problema de concorrência dos **Leitores/Escritores**, implementada em Elixir utilizando o modelo de atores através do comportamento `GenServer`.

---

## O Problema

O desafio consiste em gerenciar o acesso a uma base de dados ou recurso compartilhado que é acessado por dois tipos de processos:
* **Leitores:** Apenas consultam a informação (não alteram os dados).
* **Escritores:** Modificam a informação.

### Principais regras:
* **Múltiplos leitores** podem ler simultaneamente (pois a leitura simultânea não destrói o dado).
* **Apenas um escritor** pode modificar o dado por vez.
* **Nenhum leitor** pode ler enquanto um escritor estiver modificando o dado (evitando leituras de dados incompletos ou corrompidos).

---

## Semáforos Utilizados

Na computação tradicional (C, Java), utilizam-se semáforos numéricos e travas (*mutexes*) para controlar o acesso. No entanto, por estarmos utilizando **Elixir (e a Erlang VM)**, o controle é feito de forma diferente:

* **O próprio GenServer funciona como o Semáforo/Gerenciador Central:** Como a Erlang VM garante que um processo processa apenas uma mensagem por vez em sua fila (fila FIFO), não precisamos de travas físicas de memória.
* **Contador de Leitores (`leitores_ativos`):** O estado do servidor mantém um contador interno (`0`, `1`, `2`, etc.) que simula o comportamento de um semáforo contador, controlando quantas threads de leitura estão ativas no momento.

---

## Fluxo do Leitor e do Escritor

### Fluxo do Leitor:
1. O leitor envia uma mensagem síncrona pedindo para ler (`GenServer.call`).
2. O Gerenciador incrementa o número de `leitores_ativos` em 1.
3. O Gerenciador libera o dado imediatamente para o leitor.
4. Ao terminar, o leitor envia uma mensagem assíncrona avisando que saiu (`GenServer.cast`).
5. O Gerenciador decrementa o número de `leitores_ativos`.

### Fluxo do Escritor:
1. O escritor envia uma mensagem síncrona pedindo para escrever o novo dado (`GenServer.call`).
2. O Gerenciador verifica se `leitores_ativos == 0`.
3. **Se sim:** Atualiza o dado e responde com sucesso.
4. **Se não:** Recusa a escrita (ou bloqueia o escritor) até que a mesa esteja vazia.

---

## Soluções Utilizadas

* **Exclusão Mútua (Mutual Exclusion):** Garantida pelo IF que valida se `leitores_ativos == 0` antes de permitir qualquer escrita. Isso garante que leitores e escritores nunca fiquem na região crítica ao mesmo tempo.
* **Modelo de Atores (Isolamento de Estado):** Em Elixir, os dados não são compartilhados na memória de forma desprotegida. Toda modificação passa obrigatoriamente pela caixa de mensagens do processo central `GerenciadorDados`.

---

## Problemas que essas Soluções Evitam

* **Condição de Corrida (Race Condition):** Evita que dois escritores tentem atualizar o mesmo registro ao mesmo tempo, gerando dados inconsistentes.
* **Leitura Suja (Dirty Read):** Evita que um leitor pegue uma informação pela metade enquanto um escritor ainda está salvando as alterações.
* **Corrupção de Memória:** Como os processos do Elixir são
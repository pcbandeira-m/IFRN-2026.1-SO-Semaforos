# Produtor / Consumidor

## O problema

O problema do Produtor e Consumidor (ou *Buffer Limitado*) é um desafio clássico de concorrência. Ele ocorre quando dois tipos de atores precisam compartilhar uma mesma fila de dados (o *buffer*) de tamanho fixo:

* Os **Produtores** inserem dados no *buffer*.
* Os **Consumidores** retiram dados do *buffer*.

O grande desafio é garantir que o sistema não corrompa os dados caso ambos tentem acessar a fila no mesmo milissegundo, impedir que o produtor insira dados se o *buffer* estiver cheio, e impedir que o consumidor tente retirar dados se o *buffer* estiver vazio.

## Semáforos utilizados

**Nenhum semáforo ou Mutex tradicional é utilizado neste código.** Como o Elixir utiliza o **Modelo de Atores**, não existe memória compartilhada entre *threads*. A sincronização que normalmente seria feita por primitivas do sistema operacional (como `wait` e `signal`) é substituída pelos seguintes mecanismos da linguagem:

* **Caixa de Correio (Mailbox):** Garante o processamento de uma mensagem por vez, eliminando a necessidade de um Mutex (trava de exclusão mútua).
* **Troca de Mensagens (Message Passing):** Atores se comunicam via funções `send` e `receive`, o que gerencia as pausas e esperas sem o uso de Semáforos Contadores ou Binários.
* **Pattern Matching e Guards:** O estado do sistema é verificado instantaneamente no recebimento da mensagem (ex: `when fila != []`), substituindo a contagem de vagas típica dos semáforos.

## Fluxo do produtor, consumidor e buffer

### 1. O Ator Buffer (Gerenciador de Estado)

* Inicia com uma lista vazia.
* Fica bloqueado em um laço infinito aguardando mensagens.
* Se recebe um pedido de produção e tem espaço, adiciona o item, envia `:ok` ao remetente e atualiza seu estado.
* Se recebe um pedido de consumo e tem itens, remove o primeiro item, envia `{:ok, item}` ao remetente e atualiza seu estado.

### 2. O Ator Produtor

* Gera um novo item.
* Envia a mensagem `{:produzir, item, self()}` para o Buffer.
* Aguarda a resposta:
* Se receber `:ok`, aguarda um tempo simulado e tenta produzir o próximo.
* Se receber `:cheio`, aguarda um tempo tático e tenta reenviar o mesmo item.



### 3. O Ator Consumidor

* Envia a mensagem `{:consumir, self()}` para o Buffer.
* Aguarda a resposta:
* Se receber `{:ok, item}`, processa o item (tempo simulado) e pede o próximo.
* Se receber `:vazio`, aguarda um tempo tático e tenta pedir novamente.



## O que este modelo evita?

* **Condições de Corrida (Race Conditions):** Evitadas nativamente pela Máquina Virtual do Erlang (BEAM). Como o Ator do Buffer lê estritamente uma mensagem de sua caixa de correio por vez, é impossível que Produtor e Consumidor modifiquem a fila no mesmo instante.
* **Transbordamento (Buffer Overflow):** Evitado pelo gatilho `when length(fila) < max_tamanho`. O Buffer recusa ativamente novos itens antes que o limite seja ultrapassado.
* **Leitura no Vazio (Starvation / Underflow):** Evitado pelo gatilho `when fila != []`. O Buffer recusa a entrega de itens inexistentes, forçando o consumidor a esperar.
* **Deadlocks Fatais:** Como não há travas retidas (nenhum processo é "dono" de um Mutex), um processo que falhe não congela o sistema inteiro segurando um recurso bloqueado.

## Comportamento esperado (Ciclos possíveis)

Ao executar o sistema, você observará três cenários intercalados no terminal de forma autônoma:

1. **Fluxo Estável:** O Produtor e o Consumidor trabalham em ritmos parecidos. O tamanho do *buffer* oscila levemente (ex: entre 1 e 3 itens), com entradas e saídas alternadas com a tag `[Buffer]`.
2. **Ciclo de Sobrecarga (Buffer Cheio):** Se o Produtor for mais rápido, a fila atingirá o tamanho máximo (5). Você verá mensagens frequentes de `[Produtor] Bancada cheia. Esperando...`. O Produtor só conseguirá inserir um novo item logo após a próxima mensagem de sucesso do Consumidor.
3. **Ciclo de Escassez (Buffer Vazio):** Se o Consumidor for mais rápido, a fila chegará a 0. Você verá mensagens frequentes de `[Consumidor] Bancada vazia. Esperando...`. O Consumidor só conseguirá retirar um item logo após a próxima mensagem de sucesso do Produtor.
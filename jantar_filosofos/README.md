# Jantar dos Filósofos

## O Problema

Cinco filósofos sentam em volta de uma mesa circular. Entre cada par há um garfo — cinco garfos no total. Para comer, um filósofo precisa dos **dois garfos adjacentes** (esquerdo e direito). Quando não está comendo, está pensando.

O risco central é o **deadlock**: se todos os filósofos pegarem o garfo da esquerda ao mesmo tempo, ninguém consegue o da direita — todos ficam esperando eternamente.

## Semáforos utilizados

| Semáforo | Valor inicial | Papel |
|---|---|---|
| `garfo[0..4]` | `1` (binário) | Representa cada garfo físico. `wait` = pegar, `signal` = devolver |
| `garcom` | `N - 1 = 4` | Limita a quantos filósofos podem tentar pegar garfos ao mesmo tempo |

## Solução: Semáforo Garçom

Antes de tentar qualquer garfo, cada filósofo pede licença ao garçom (`wait(garcom)`). O garçom só permite que **no máximo N-1 filósofos** tentem simultaneamente. Com isso, a espera circular que causaria deadlock é impossível: sempre haverá pelo menos um par de garfos adjacentes livre para alguém completar a refeição.

## Fluxo de cada filósofo

```mermaid
flowchart TD
    A([início]) --> B[pensar\nProcess.sleep aleatório]
    B --> C[pedir licença ao garçom\nwait garcom]
    C --> D{garcom > 0?}
    D -- não --> D2[bloqueia\naté um filósofo terminar]
    D2 --> D
    D -- sim\ngarcom-- --> E[wait garfo_esquerdo]
    E --> F{garfo esq\ndisponível?}
    F -- não --> F2[bloqueia\naté garfo ser devolvido]
    F2 --> F
    F -- sim --> G[wait garfo_direito]
    G --> H{garfo dir\ndisponível?}
    H -- não --> H2[bloqueia\naté garfo ser devolvido]
    H2 --> H
    H -- sim --> I[*** COMER ***\nProcess.sleep aleatório]
    I --> J[signal garfo_esquerdo\nsignal garfo_direito]
    J --> K[signal garcom\nlibera vaga]
    K --> B
```

## Por que N-1 evita deadlock?

Com N filósofos e N garfos, o deadlock clássico ocorre assim:

```
Sem garçom (garcom = N):         Com garçom (garcom = N-1):

[0] pega garfo 0, espera 1       [0] pega garfo 0, espera 1
[1] pega garfo 1, espera 2       [1] pega garfo 1, espera 2
[2] pega garfo 2, espera 3  →    [2] pega garfo 2, espera 3
[3] pega garfo 3, espera 4       [3] pega garfo 3, espera 4
[4] pega garfo 4, espera 0       [4] BLOQUEADO pelo garçom ← garfo 4 fica livre!
        ↓                                     ↓
    DEADLOCK                      [3] pega garfo 4 → come → devolve tudo
```

O filósofo 4 ser barrado pelo garçom garante que o garfo 4 nunca é ocupado quando o filósofo 3 precisa dele — a cadeia circular é quebrada.

## Comportamento esperado na saída

Rodando com 5 filósofos, a saída deve exibir os seguintes padrões:

**1. Ciclo normal — filósofo obtém os dois garfos sem espera:**
```
[2] Sócrates está com fome, pedindo licença ao garçom...
[2] Sócrates tentando pegar garfo 2 (esq)...
[2] Sócrates pegou garfo 2 (esq), tentando garfo 3 (dir)...
[2] Sócrates pegou garfo 3 (dir)!
[2] *** Sócrates está COMENDO (garfos 2 e 3) ***
[2] Sócrates devolveu os garfos 2 e 3
```

**2. Bloqueio no garfo — filósofo aguarda um garfo que outro está usando:**
```
[3] Descartes tentando pegar garfo 3 (esq)...
[3] Descartes pegou garfo 3 (esq), tentando garfo 4 (dir)...
  ← Descartes fica bloqueado aqui enquanto Nietzsche [4] usa o garfo 4
[4] Nietzsche devolveu os garfos 4 e 0     ← Nietzsche libera
[3] Descartes pegou garfo 4 (dir)!         ← Descartes desbloqueia
```

**3. Dois filósofos não-adjacentes comem ao mesmo tempo (correto):**
```
[4] *** Nietzsche está COMENDO (garfos 4 e 0) ***
[1] *** Platão está COMENDO (garfos 1 e 2) ***
```
Garfos 4,0 e 1,2 são independentes — podem ser usados simultaneamente.

**O que nunca deve aparecer:**
- Dois filósofos usando o mesmo garfo ao mesmo tempo
- Todos os 5 filósofos "tentando pegar garfo" sem nenhum "COMENDO" entre eles (isso seria o deadlock)
- O programa travar indefinidamente

## Como executar

```bash
docker compose build jantar_filosofos
docker compose run --rm jantar_filosofos
```

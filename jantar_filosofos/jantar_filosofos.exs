# Jantar dos Filósofos com Semáforos
#
# Cenário:
#   N filósofos sentados em volta de uma mesa circular.
#   Entre cada par de filósofos há um garfo (N garfos no total).
#   Para comer, um filósofo precisa dos DOIS garfos adjacentes (esq. e dir.).
#   Filósofos alternam entre: pensar → pegar garfos → comer → devolver garfos.
#
# O problema:
#   Se TODOS pegarem o garfo da esquerda ao mesmo tempo, ninguém consegue
#   o da direita → espera circular → DEADLOCK.
#
# Solução usada — Semáforo Garçom (arbitrador):
#   Um semáforo `garcom` começa em N-1.
#   Cada filósofo faz wait(garcom) antes de tentar pegar qualquer garfo.
#   Com no máximo N-1 filósofos tentando simultaneamente, a espera circular
#   é matematicamente impossível: sempre existirá pelo menos um par de garfos
#   adjacentes livres para alguém completar a refeição.
#
# Semáforos:
#   garfo[i] — binário (0 ou 1): garfo entre filósofo i e filósofo (i+1)%N
#   garcom   — contador iniciado em N-1: limita tentativas simultâneas
# =============================================================================

defmodule Semaphore do
  use GenServer

  def start_link(initial_count) do
    GenServer.start_link(__MODULE__, initial_count)
  end

  def wait(sem),   do: GenServer.call(sem, :wait, :infinity)
  def signal(sem), do: GenServer.cast(sem, :signal)

  @impl true
  def init(count), do: {:ok, {count, :queue.new()}}

  @impl true
  def handle_call(:wait, _from, {count, queue}) when count > 0 do
    {:reply, :ok, {count - 1, queue}}
  end

  @impl true
  def handle_call(:wait, from, {0, queue}) do
    {:noreply, {0, :queue.in(from, queue)}}
  end

  @impl true
  def handle_cast(:signal, {count, queue}) do
    case :queue.out(queue) do
      {{:value, waiter}, rest} ->
        GenServer.reply(waiter, :ok)
        {:noreply, {count, rest}}
      {:empty, _} ->
        {:noreply, {count + 1, queue}}
    end
  end
end

# -----------------------------------------------------------------------------

defmodule Filosofo do
  @nomes ~w[Aristóteles Platão Sócrates Descartes Nietzsche]

  def iniciar(id, garfos, garcom, n) do
    nome = Enum.at(@nomes, id)
    spawn(fn -> loop(id, nome, garfos, garcom, n) end)
  end

  defp loop(id, nome, garfos, garcom, n) do
    pensar(id, nome)
    pegar_garfos(id, nome, garfos, garcom, n)
    comer(id, nome, garfos, garcom, n)
    loop(id, nome, garfos, garcom, n)
  end

  defp pensar(id, nome) do
    IO.puts("  [#{id}] #{nome} está pensando...")
    Process.sleep(:rand.uniform(1500) + 500)
  end

  defp pegar_garfos(id, nome, garfos, garcom, n) do
    garfo_esq = id
    garfo_dir = rem(id + 1, n)

    IO.puts("  [#{id}] #{nome} está com fome, pedindo licença ao garçom...")

    # Pede licença ao garçom — bloqueia se já houver N-1 filósofos tentando
    Semaphore.wait(garcom)

    IO.puts("  [#{id}] #{nome} tentando pegar garfo #{garfo_esq} (esq)...")
    Semaphore.wait(Enum.at(garfos, garfo_esq))
    IO.puts("  [#{id}] #{nome} pegou garfo #{garfo_esq} (esq), tentando garfo #{garfo_dir} (dir)...")
    Semaphore.wait(Enum.at(garfos, garfo_dir))
    IO.puts("  [#{id}] #{nome} pegou garfo #{garfo_dir} (dir)!")
  end

  defp comer(id, nome, garfos, garcom, n) do
    garfo_esq = id
    garfo_dir = rem(id + 1, n)

    IO.puts("  [#{id}] *** #{nome} está COMENDO (garfos #{garfo_esq} e #{garfo_dir}) ***")
    Process.sleep(:rand.uniform(1000) + 300)

    # Devolve os garfos e libera vaga no garçom
    Semaphore.signal(Enum.at(garfos, garfo_esq))
    Semaphore.signal(Enum.at(garfos, garfo_dir))
    IO.puts("  [#{id}] #{nome} devolveu os garfos #{garfo_esq} e #{garfo_dir}")

    Semaphore.signal(garcom)
  end
end

# =============================================================================
# Ponto de entrada
# =============================================================================

n = 5  # número de filósofos (e de garfos)

# Um semáforo binário por garfo (todos começam disponíveis)
garfos = for _ <- 0..(n - 1), do: elem(Semaphore.start_link(1), 1)

# Garçom: permite no máximo N-1 filósofos tentando ao mesmo tempo
{:ok, garcom} = Semaphore.start_link(n - 1)

IO.puts("""
=== Jantar dos Filósofos com Semáforos ===
#{n} filósofos  |  #{n} garfos
Solução: semáforo garçom (max #{n - 1} tentando ao mesmo tempo)
Semáforos: garfo[0..#{n-1}]=1, garcom=#{n - 1}
------------------------------------------
""")

for id <- 0..(n - 1), do: Filosofo.iniciar(id, garfos, garcom, n)

Process.sleep(:infinity)

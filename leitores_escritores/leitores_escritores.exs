# Definição do módulo que irá encapsular toda a lógica da concorrência
defmodule GerenciadorDados do
  use GenServer # servidor genérico do Elixir

  # --- Interface Cliente (API Pública) ---

  def start_link(dado_inicial) do
    # Inicia o processo do GenServer com o estado inicial
    GenServer.start_link(__MODULE__, %{dado: dado_inicial, leitores_ativos: 0}, name: __MODULE__)
  end

  def ler() do
    # CALL é síncrono: o leitor envia a mensagem e fica esperando a resposta
    GenServer.call(__MODULE__, :solicitar_leitura)
  end

  def terminar_leitura() do
    # CAST é assíncrono: o leitor avisa que saiu e não precisa esperar resposta
    GenServer.cast(__MODULE__, :terminar_leitura)
  end

  def escrever(novo_dado) do
    # CALL é síncrono: o escritor pede para escrever e espera o OK do servidor
    GenServer.call(__MODULE__, {:escrever, novo_dado}) 
  end

  # --- Callbacks do Servidor (Onde a mágica acontece) ---

  @impl true
  def init(estado_inicial) do
    {:ok, estado_inicial}
  end

  @impl true
  def handle_call(:solicitar_leitura, _from, estado) do
    # Múltiplos leitores podem ler ao mesmo tempo.
    # Incrementamos o contador de leitores ativos e retornamos o dado imediatamente.
    novo_estado = %{estado | leitores_ativos: estado.leitores_ativos + 1}
    {:reply, {:ok, estado.dado}, novo_estado}
  end

  @impl true
  def handle_call({:escrever, novo_dado}, _from, estado) do
    # REGRA: Só pode escrever se NÃO houver leitores ativos (leitores_ativos == 0)
    if estado.leitores_ativos == 0 do
      novo_estado = %{estado | dado: novo_dado}
      {:reply, :escrita_sucesso, novo_estado}
    else
      # Se houver leitores, rejeita a escrita para proteger a consistência
      {:reply, {:erro, :recurso_ocupado_lendo}, estado}
    end
  end

  @impl true
  def handle_cast(:terminar_leitura, estado) do
    # Quando um leitor avisa que terminou, decrementamos o contador
    novo_estado = %{estado | leitores_ativos: max(0, estado.leitores_ativos - 1)}
    {:noreply, novo_estado}
  end
end


# --- Script de Teste / Demonstração ---

# 1. Inicializa o nosso gerenciador com o texto "Primeiro texto, bem legal"
{:ok, _pid} = GerenciadorDados.start_link("Primeiro texto, bem legal")

IO.puts "--- Cenário 1: Múltiplos Leitores ---"
{:ok, dado1} = GerenciadorDados.ler()
{:ok, dado2} = GerenciadorDados.ler()
IO.puts "Leitor 1 leu: #{dado1}"
IO.puts "Leitor 2 leu: #{dado2}"

IO.puts "\n--- Cenário 2: Escritor tenta entrar enquanto leitores leem ---"
case GerenciadorDados.escrever("Segunto texto, UAU") do
  {:erro, motivo} -> IO.puts "Escritor bloqueado! Motivo: #{motivo}"
  :escrita_sucesso -> IO.puts "Escritor conseguiu escrever!"
end

IO.puts "\n--- Cenário 3: Leitores terminam e Escritor tenta novamente ---"
GerenciadorDados.terminar_leitura() # Leitor 1 sai
GerenciadorDados.terminar_leitura() # Leitor 2 sai

case GerenciadorDados.escrever("Segunto texto, UAU") do
  {:erro, motivo} -> IO.puts "Escritor bloqueado! Motivo: #{motivo}"
  :escrita_sucesso -> IO.puts "Escritor atualizou os dados com sucesso para 'Segunto texto, UAU'!"
end

IO.puts "\n--- Cenário 4: Nova leitura após a escrita ---"
{:ok, dado3} = GerenciadorDados.ler()
IO.puts "Novo leitor leu: #{dado3}"

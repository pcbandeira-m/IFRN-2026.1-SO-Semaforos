defmodule ProdutorConsumidor do
  @max_tamanho 5

  # 1. O ATOR DO BUFFER (Gerente da Bancada)
  def buffer(fila \\ []) do
    receive do
      # Se recebe pedido de produção e a fila não está cheia:
      {:produzir, item, remetente} when length(fila) < @max_tamanho ->
        IO.puts("[Buffer] Recebeu #{item}. Tamanho: #{length(fila) + 1}")
        send(remetente, :ok)
        buffer(fila ++ [item])

      # Se recebe pedido de produção, mas está cheia:
      {:produzir, _item, remetente} ->
        send(remetente, :cheio)
        buffer(fila)

      # REFATORAÇÃO APLICADA AQUI:
      # Pattern matching para verificar se a fila NÃO está vazia.
      # A sintaxe [item | resto] só dá 'match' se a lista tiver pelo menos 1 elemento.
      # Isso substitui a verificação ineficiente 'when length(fila) > 0'
      # Se recebe pedido de consumo e a fila não está vazia:
      {:consumir, remetente} when fila != [] ->
        # Como garantimos que a fila não é vazia, podemos extrair a cabeça e a cauda
        [item | resto] = fila
        IO.puts("[Buffer] Entregou #{item}. Tamanho: #{length(resto)}")
        send(remetente, {:ok, item})
        buffer(resto)

      # Se recebe pedido de consumo, mas está vazia:
      {:consumir, remetente} ->
        send(remetente, :vazio)
        buffer(fila)
    end
  end

  # 2. O ATOR DO PRODUTOR (Cozinheiro)
  def produtor(pid_buffer, id_item \\ 0) do
    item = "Prato #{id_item}"

    send(pid_buffer, {:produzir, item, self()})

    receive do
      :ok ->
        Process.sleep(:rand.uniform(1000) + 500)
        produtor(pid_buffer, id_item + 1)

      :cheio ->
        IO.puts("[Produtor] Bancada cheia. Esperando...")
        Process.sleep(500)
        produtor(pid_buffer, id_item)
    end
  end

  # 3. O ATOR DO CONSUMIDOR (Garçom)
  def consumidor(pid_buffer) do
    send(pid_buffer, {:consumir, self()})

    receive do
      {:ok, _item} ->
        Process.sleep(:rand.uniform(1000) + 1000)
        consumidor(pid_buffer)

      :vazio ->
        IO.puts("[Consumidor] Bancada vazia. Esperando...")
        Process.sleep(500)
        consumidor(pid_buffer)
    end
  end

  # 4. FUNÇÃO PARA DAR O PLAY
  def iniciar do
    pid_buffer = spawn(fn -> buffer() end)

    spawn(fn -> produtor(pid_buffer) end)
    spawn(fn -> consumidor(pid_buffer) end)

    Process.sleep(:infinity)
  end
end

# Para rodar automaticamente quando executar o arquivo:
ProdutorConsumidor.iniciar()

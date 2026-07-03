FROM elixir:1.18-alpine

WORKDIR /app

# Copiar o arquivo Elixir
COPY impl/ProdutorConsumidor.exs .

# Executar o script Elixir
CMD ["elixir", "ProdutorConsumidor.exs"]
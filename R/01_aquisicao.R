# Camada de aquisição de dados do TSE.
#
# Prioriza sempre o arquivo já presente em data-raw/downloads/{ano}/, porque
# durante o defeso eleitoral o TSE pode bloquear download automatizado (ver
# CLAUDE.md). O layout observado em 2022 é um único ZIP nacional contendo um
# CSV por UF (votacao_candidato_munzona_{ano}_{UF}.csv), um consolidado
# _BRASIL.csv (redundante e pesado demais para ler de uma vez) e um _BR.csv
# (voto no exterior, só para presidente). A camada de leitura sempre lê
# direto do UF pedido, sem extrair o ZIP inteiro.

nome_zip_dataset <- function(ano) {
  sprintf("votacao_candidato_munzona_%d.zip", ano)
}

nome_membro_uf <- function(ano, uf) {
  sprintf("votacao_candidato_munzona_%d_%s.csv", ano, toupper(uf))
}

diretorio_dataset <- function(ano, base_dir = "data-raw/downloads") {
  file.path(base_dir, ano, "votacao_candidato_munzona")
}

#' Garante que o ZIP de votação por candidato/município/zona está disponível
#' localmente, e retorna o caminho para ele.
#'
#' Não tenta download automático ainda (ponto de atenção: TSE bloqueando
#' downloads automatizados durante o defeso eleitoral em 2026). Se o arquivo
#' não existir, aborta com instruções claras e grava um README com o passo a
#' passo manual.
obter_zip_tse <- function(ano, base_dir = "data-raw/downloads") {
  dir_dataset <- diretorio_dataset(ano, base_dir)
  zip_path <- file.path(dir_dataset, nome_zip_dataset(ano))

  if (file.exists(zip_path)) {
    return(zip_path)
  }

  dir.create(dir_dataset, recursive = TRUE, showWarnings = FALSE)
  instrucoes <- paste(
    sprintf("Arquivo não encontrado: %s", zip_path),
    "",
    "O TSE pode bloquear download automatizado durante o defeso eleitoral.",
    "Baixe manualmente:",
    "",
    "1. Acesse https://dadosabertos.tse.jus.br",
    sprintf("2. Procure 'Resultados - votação por candidato, município e zona' para o ano %d", ano),
    "3. Baixe o ZIP nacional (contém todas as UFs)",
    sprintf("4. Salve o arquivo como '%s' em '%s'", nome_zip_dataset(ano), dir_dataset),
    sep = "\n"
  )
  writeLines(instrucoes, file.path(dir_dataset, "README_DOWNLOAD_MANUAL.md"))
  cli::cli_abort(instrucoes)
}

#' Confere que o CSV de uma UF existe dentro do ZIP e devolve o nome do
#' membro (para leitura via unz(), sem extrair o ZIP inteiro).
obter_membro_uf <- function(zip_path, ano, uf) {
  membro <- nome_membro_uf(ano, uf)
  entradas <- utils::unzip(zip_path, list = TRUE)$Name
  if (!membro %in% entradas) {
    cli::cli_abort(c(
      "UF {.val {uf}} não encontrada em {.file {zip_path}}.",
      "i" = "UFs disponíveis: {.val {sort(entradas)}}"
    ))
  }
  membro
}

#' Ponto de entrada da camada de aquisição: garante o ZIP local e devolve o
#' caminho do ZIP + nome do membro CSV da UF pedida, prontos para
#' `ler_votacao_munzona()`.
obter_dados_tse <- function(ano, uf, base_dir = "data-raw/downloads") {
  zip_path <- obter_zip_tse(ano, base_dir)
  membro <- obter_membro_uf(zip_path, ano, uf)
  list(zip = zip_path, membro = membro)
}

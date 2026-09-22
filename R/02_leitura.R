# Leitura do CSV de votação por candidato/município/zona, direto de dentro
# do ZIP (via unz()), sem extrair o arquivo inteiro para disco.

VALORES_AUSENTES_TSE <- c("#NULO", "#NE", "-1", "-3")

#' Lê o CSV de uma UF de dentro do ZIP do TSE.
#'
#' `fileEncoding` não é aplicado de forma confiável por `read.csv2()` sobre
#' uma conexão `unz()` (erro "string multibyte inválida" com acentos/º em
#' latin1). Em vez de ler via stream, extrai só o membro pedido para
#' `data/interim/` (cache; não extrai o ZIP inteiro) e lê do disco, onde
#' `fileEncoding` funciona normalmente.
#'
#' @param zip Caminho do ZIP (de `obter_dados_tse()$zip`).
#' @param membro Nome do CSV dentro do ZIP (de `obter_dados_tse()$membro`).
#' @param dir_cache Onde deixar o CSV extraído (reaproveitado se já existir).
ler_votacao_munzona <- function(zip, membro, dir_cache = "data/interim") {
  dir.create(dir_cache, recursive = TRUE, showWarnings = FALSE)
  caminho_csv <- file.path(dir_cache, membro)

  if (!file.exists(caminho_csv)) {
    utils::unzip(zip, files = membro, exdir = dir_cache)
  }

  df <- utils::read.csv2(
    caminho_csv,
    fileEncoding = "latin1",
    na.strings = VALORES_AUSENTES_TSE,
    stringsAsFactors = FALSE
  )

  tibble::as_tibble(df)
}

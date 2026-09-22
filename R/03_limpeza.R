# Limpeza/agregação do CSV de votação por candidato/município/zona.
#
# Este dataset já vem por candidato (não por seção), e só lista candidatos
# reais — não existem linhas "VOTO NULO"/"VOTO BRANCO" como no dataset por
# seção usado no protótipo antigo. Isso significa que "votos válidos" de um
# cargo/município é simplesmente a soma dos votos de todos os candidatos
# daquele cargo/município (branco/nulo nunca aparecem como candidato).

CARGOS_RELEVANTES <- c("Presidente", "Governador", "Senador")

# Conectivos que ficam minúsculos ao normalizar nome de candidato (exceto
# quando é a primeira palavra), igual a convenção usual de nome próprio em
# português.
CONECTIVOS_NOME_MINUSCULOS <- c("de", "da", "do", "das", "dos", "e")

#' Normaliza um nome vindo em CAIXA ALTA do TSE para só a 1ª letra de cada
#' palavra maiúscula (ex.: "RAQUEL LYRA" -> "Raquel Lyra"), mantendo
#' conectivos como "de"/"da"/"dos" em minúsculo.
#'
#' @param nome Vetor de caracteres.
normalizar_nome_candidato <- function(nome) {
  vapply(nome, function(n) {
    if (is.na(n)) return(NA_character_)
    palavras <- strsplit(tolower(n), " ", fixed = TRUE)[[1]]
    palavras <- vapply(seq_along(palavras), function(i) {
      p <- palavras[i]
      if (i > 1 && p %in% CONECTIVOS_NOME_MINUSCULOS) return(p)
      paste0(toupper(substr(p, 1, 1)), substr(p, 2, nchar(p)))
    }, character(1))
    paste(palavras, collapse = " ")
  }, character(1), USE.NAMES = FALSE)
}

#' Agrega o CSV de uma UF (ou "BR", para presidente) por município,
#' somando zonas, e calcula o % de votos válidos de cada candidato dentro
#' do seu cargo/turno/município.
#'
#' @param dados Tibble de `ler_votacao_munzona()`.
limpar_votacao <- function(dados) {
  relevantes <- dados[dados$DS_CARGO %in% CARGOS_RELEVANTES, ]
  relevantes$NM_URNA_CANDIDATO <- normalizar_nome_candidato(relevantes$NM_URNA_CANDIDATO)

  por_candidato <- dplyr::summarise(
    dplyr::group_by(
      relevantes,
      .data$ANO_ELEICAO, .data$NR_TURNO, .data$SG_UF,
      .data$CD_MUNICIPIO, .data$NM_MUNICIPIO, .data$DS_CARGO,
      .data$SQ_CANDIDATO, .data$NR_CANDIDATO, .data$NM_CANDIDATO,
      .data$NM_URNA_CANDIDATO, .data$SG_PARTIDO, .data$NR_PARTIDO
    ),
    votos = sum(.data$QT_VOTOS_NOMINAIS_VALIDOS, na.rm = TRUE),
    .groups = "drop"
  )

  por_municipio <- dplyr::mutate(
    dplyr::group_by(
      por_candidato,
      .data$ANO_ELEICAO, .data$NR_TURNO, .data$SG_UF,
      .data$CD_MUNICIPIO, .data$DS_CARGO
    ),
    votos_validos_municipio = sum(.data$votos),
    pct_validos = 100 * .data$votos / .data$votos_validos_municipio
  )

  dplyr::ungroup(por_municipio)
}

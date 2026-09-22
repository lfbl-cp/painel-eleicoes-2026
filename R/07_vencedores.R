# Agregação de votos e cálculo do vencedor, parametrizado pela unidade de
# análise (município, microrregião, mesorregião ou UF). A mesma lógica de
# soma de votos serve pras 4 unidades — só a coluna de agrupamento muda.

UNIDADES_COLUNA <- c(
  municipio = "code_muni",
  microrregiao = "code_micro",
  mesorregiao = "code_meso",
  uf = "SG_UF"
)

#' Agrega votos (já por município, de `juntar_ibge()`) na unidade de
#' análise pedida, recalculando `votos_validos_unidade`/`pct_validos` em
#' relação ao total da unidade (não do município).
#'
#' @param dados_municipio Tibble de `juntar_ibge()` (uma linha por
#'   município/candidato/turno/cargo).
#' @param crosswalk_meso_micro Tibble de `derivar_crosswalk_meso_micro()`
#'   (ignorado quando `unidade` é "municipio" ou "uf").
#' @param unidade Um de "municipio", "microrregiao", "mesorregiao", "uf".
agregar_por_unidade <- function(dados_municipio, crosswalk_meso_micro, unidade) {
  unidade <- match.arg(unidade, names(UNIDADES_COLUNA))
  coluna_unidade <- UNIDADES_COLUNA[[unidade]]

  base <- if (unidade %in% c("microrregiao", "mesorregiao")) {
    dplyr::left_join(dados_municipio, crosswalk_meso_micro, by = "code_muni")
  } else {
    dados_municipio
  }

  por_candidato <- dplyr::summarise(
    dplyr::group_by(
      base,
      .data$ANO_ELEICAO, .data$NR_TURNO, .data$DS_CARGO,
      unidade_id = .data[[coluna_unidade]],
      .data$SQ_CANDIDATO, .data$NM_URNA_CANDIDATO, .data$NM_CANDIDATO, .data$SG_PARTIDO
    ),
    votos = sum(.data$votos, na.rm = TRUE),
    .groups = "drop"
  )

  com_pct <- dplyr::mutate(
    dplyr::group_by(por_candidato, .data$ANO_ELEICAO, .data$NR_TURNO, .data$DS_CARGO, .data$unidade_id),
    votos_validos_unidade = sum(.data$votos),
    pct_validos = 100 * .data$votos / .data$votos_validos_unidade
  )

  dplyr::ungroup(com_pct)
}

#' Vencedor (maior número de votos) por unidade/cargo/turno, a partir do
#' resultado de `agregar_por_unidade()`, com margem de vitória e uma
#' classificação de intensidade ("alta"/"baixa") em duas tonalidades, como
#' no protótipo antigo (`gov pe 2.R`/`senado pe 2.R`).
#'
#' A margem é sempre `% do 1º colocado - % do 2º colocado` na unidade (100
#' quando o candidato é o único concorrente). A intensidade é um corte pela
#' mediana das margens *dentro das unidades que aquele candidato venceu*
#' (mesmo critério do protótipo antigo) — "alta" acima da mediana, "baixa"
#' caso contrário. Quanto menos unidades um candidato vence, menos sentido
#' estatístico esse corte tem: funciona bem em município (muitas
#' unidades), fica grosseiro em mesorregião, e é degenerado quando um
#' candidato só vence 1 unidade (sempre cai em "baixa", não tem o que
#' comparar).
calcular_vencedor <- function(dados_agregados) {
  ordenado <- dplyr::arrange(
    dados_agregados,
    .data$ANO_ELEICAO, .data$NR_TURNO, .data$DS_CARGO, .data$unidade_id,
    dplyr::desc(.data$votos)
  )

  com_margem <- dplyr::mutate(
    dplyr::group_by(ordenado, .data$ANO_ELEICAO, .data$NR_TURNO, .data$DS_CARGO, .data$unidade_id),
    margem = .data$pct_validos[1] - dplyr::coalesce(dplyr::nth(.data$pct_validos, 2), 0)
  )
  com_margem <- dplyr::ungroup(com_margem)

  vencedores <- dplyr::slice_max(
    dplyr::group_by(com_margem, .data$ANO_ELEICAO, .data$NR_TURNO, .data$DS_CARGO, .data$unidade_id),
    order_by = .data$votos, n = 1, with_ties = FALSE
  )
  vencedores <- dplyr::ungroup(vencedores)

  com_intensidade <- dplyr::mutate(
    dplyr::group_by(vencedores, .data$ANO_ELEICAO, .data$NR_TURNO, .data$DS_CARGO, .data$SQ_CANDIDATO),
    intensidade = dplyr::if_else(.data$margem > stats::median(.data$margem), "alta", "baixa")
  )

  dplyr::ungroup(com_intensidade)
}

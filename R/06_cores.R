# Cor por partido: tabela pequena de referência (data-raw/ref/partidos_cores.csv)
# para os partidos mais conhecidos, com fallback determinístico por hash da
# sigla para qualquer partido não catalogado — sem o case_when manual por
# eleição do protótipo antigo.

carregar_cores_partidos <- function(caminho = "data-raw/ref/partidos_cores.csv") {
  if (!file.exists(caminho)) {
    return(tibble::tibble(sigla_partido = character(), cor_hex = character()))
  }
  utils::read.csv(caminho, stringsAsFactors = FALSE, encoding = "UTF-8") |>
    tibble::as_tibble()
}

#' HSL -> hex. Saturação/luminosidade fixas (0.65/0.45) para manter as cores
#' geradas sempre vivas e legíveis, variando só o matiz (hue).
hsl_para_hex <- function(h, s = 0.65, l = 0.45) {
  h <- (h %% 360) / 360
  c_ <- (1 - abs(2 * l - 1)) * s
  x <- c_ * (1 - abs((h * 6) %% 2 - 1))
  m <- l - c_ / 2

  rgb1 <- if (h < 1 / 6) c(c_, x, 0)
  else if (h < 2 / 6) c(x, c_, 0)
  else if (h < 3 / 6) c(0, c_, x)
  else if (h < 4 / 6) c(0, x, c_)
  else if (h < 5 / 6) c(x, 0, c_)
  else c(c_, 0, x)

  rgb <- round((rgb1 + m) * 255)
  grDevices::rgb(rgb[1], rgb[2], rgb[3], maxColorValue = 255)
}

#' Cor determinística a partir da sigla do partido, para qualquer sigla que
#' não esteja na tabela de referência. Puramente determinística (mesma
#' sigla sempre gera a mesma cor), então não precisa ser persistida para
#' se manter consistente entre execuções.
gerar_cor_automatica <- function(sigla) {
  codigos <- utf8ToInt(toupper(sigla))
  semente <- sum(codigos * seq_along(codigos))
  hsl_para_hex(semente %% 360)
}

#' Cor de um partido: da tabela de referência se catalogado, senão gerada
#' por hash da sigla. Vetorizado.
cor_partido <- function(sigla_partido, tabela = carregar_cores_partidos()) {
  idx <- match(sigla_partido, tabela$sigla_partido)
  vapply(
    seq_along(sigla_partido),
    function(i) {
      if (!is.na(idx[i])) tabela$cor_hex[idx[i]] else gerar_cor_automatica(sigla_partido[i])
    },
    character(1)
  )
}

#' Cor de um candidato: usa a cor do partido, exceto se houver override
#' explícito em `overrides` (sq_candidato -> cor_hex). `overrides` é
#' opcional e vazio por padrão.
cor_candidato <- function(sq_candidato, sigla_partido, tabela_partidos = carregar_cores_partidos(),
                           overrides = NULL) {
  cor_base <- cor_partido(sigla_partido, tabela_partidos)

  if (is.null(overrides) || nrow(overrides) == 0) {
    return(cor_base)
  }

  idx <- match(sq_candidato, overrides$sq_candidato)
  ifelse(!is.na(idx), overrides$cor_hex[idx], cor_base)
}

# Swing presidencial entre duas eleições (1º turno): variação, em pontos
# percentuais de votos válidos, de cada candidato entre o ano base e o ano
# atual, por unidade (município/microrregião/mesorregião/UF).
#
# Lê os JSON de resultado já exportados (`montar_resultado_unidade()`) dos
# dois anos, em vez de reprocessar os CSVs do TSE: o ano base (2022) não
# precisa mais estar em data-raw/downloads/, e o código de cada unidade é o
# mesmo nos dois anos (mesma geometria do geobr). Custo: o swing herda o
# arredondamento de 2 casas do `%` exportado (erro máximo de ±0,01 p.p.).

#' Pares candidato atual <-> candidato base para o swing. Flávio Bolsonaro
#' (2026) é comparado com Jair Bolsonaro (2022) — o candidato do mesmo campo
#' político na eleição anterior, não ele mesmo (que não concorreu em 2022).
#' `atual`/`base` casam com `nome` (NM_URNA_CANDIDATO normalizado) do JSON
#' de resultado, ignorando acento e caixa.
PARES_SWING_PADRAO <- list(
  list(chave = "lula", rotulo = "Lula", atual = "Lula", base = "Lula"),
  list(chave = "flavio", rotulo = "Flávio Bolsonaro", atual = "Flavio Bolsonaro", base = "Jair Bolsonaro")
)

normalizar_para_comparacao <- function(nome) {
  tolower(stringi::stri_trans_general(nome, "Latin-ASCII"))
}

#' Candidato de um resultado exportado pelo nome de urna (sem acento/caixa).
#' Devolve o candidato com o `sq` (chave no JSON) junto.
#' Aborta se não achar exatamente um — swing com o candidato errado seria
#' pior que não ter swing nenhum.
encontrar_candidato <- function(resultado, nome) {
  alvo <- normalizar_para_comparacao(nome)
  achados <- Filter(function(c) normalizar_para_comparacao(c$nome) == alvo, resultado$candidatos)
  if (length(achados) != 1) {
    cli::cli_abort(c(
      "{length(achados)} candidato(s) com nome {.val {nome}} no resultado (esperado 1).",
      "i" = "Nomes disponíveis: {.val {vapply(resultado$candidatos, function(c) c$nome, character(1))}}"
    ))
  }
  c(achados[[1]], list(sq = names(achados)[[1]]))
}

#' Monta o swing de uma unidade de análise a partir dos resultados (já
#' lidos com `jsonlite::fromJSON(simplifyVector = FALSE)`) do ano atual e
#' do ano base.
#'
#' Só entram unidades presentes nos dois anos. `escala_max` é o limite
#' simétrico sugerido pra escala de cor do front-end (p95 do |swing| de
#' todos os pares, arredondado pra cima em múltiplos de 5 p.p.) — o mesmo
#' pros dois candidatos, pra que os mapas sejam comparáveis entre si.
#'
#' @param resultado_atual,resultado_base Saídas de
#'   `montar_resultado_unidade()` para a mesma unidade/cargo/turno.
#' @param ano,ano_base Anos das duas eleições (só rotulam a saída).
#' @param pares Lista no formato de `PARES_SWING_PADRAO`.
montar_swing_unidade <- function(resultado_atual, resultado_base, ano, ano_base,
                                  pares = PARES_SWING_PADRAO) {
  candidatos <- lapply(pares, function(par) {
    atual <- encontrar_candidato(resultado_atual, par$atual)
    base <- encontrar_candidato(resultado_base, par$base)

    ids <- intersect(names(atual$valores), names(base$valores))
    valores <- lapply(ids, function(id) {
      pct_atual <- atual$valores[[id]]
      pct_base <- base$valores[[id]]
      list(base = pct_base, atual = pct_atual, swing = round(pct_atual - pct_base, 2))
    })
    names(valores) <- ids

    list(
      rotulo = par$rotulo,
      sq = atual$sq,
      sq_base = base$sq,
      nome = atual$nome,
      partido = atual$partido,
      cor = atual$cor,
      nome_base = base$nome,
      partido_base = base$partido,
      pct_geral = atual$pct_geral,
      pct_geral_base = base$pct_geral,
      swing_geral = round(atual$pct_geral - base$pct_geral, 2),
      valores = valores
    )
  })
  names(candidatos) <- vapply(pares, function(p) p$chave, character(1))

  swings_absolutos <- abs(unlist(lapply(candidatos, function(c) vapply(c$valores, function(v) v$swing, numeric(1)))))
  escala_max <- max(5, ceiling(stats::quantile(swings_absolutos, 0.95, names = FALSE) / 5) * 5)

  list(
    ano = ano,
    ano_base = ano_base,
    cargo = resultado_atual$cargo,
    turno = resultado_atual$turno,
    unidade = resultado_atual$unidade,
    escala_max = escala_max,
    candidatos = candidatos
  )
}

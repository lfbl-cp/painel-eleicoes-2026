# Exportação: geometria simplificada em TopoJSON + atributos em JSON,
# prontos para o front-end estático ler e filtrar no navegador (sem
# servidor, sem recalcular nada por interação do usuário).

#' Simplifica a geometria (preservando topologia entre vizinhos) e escreve
#' como TopoJSON.
#'
#' @param sf_objeto sf a exportar.
#' @param caminho Arquivo de destino (a pasta é criada se não existir).
#' @param keep Fração de vértices a manter (`rmapshaper::ms_simplify`).
exportar_topojson <- function(sf_objeto, caminho, keep = 0.15) {
  dir.create(dirname(caminho), recursive = TRUE, showWarnings = FALSE)
  simplificado <- rmapshaper::ms_simplify(sf_objeto, keep = keep, keep_shapes = TRUE)
  geojsonio::topojson_write(simplificado, file = caminho, object_name = "geometrias")
  invisible(caminho)
}

#' Monta a estrutura de resultado (vencedores + candidatos, com valores por
#' unidade) para uma combinação unidade/cargo/turno, pronta para exportar
#' como JSON.
#'
#' @param dados_agregados Saída de `agregar_por_unidade()`, já com uma
#'   coluna `cor` (ver `R/06_cores.R`).
#' @param vencedores Saída de `calcular_vencedor()` sobre `dados_agregados`.
#' @param unidade Nome da unidade de análise ("municipio", "microrregiao",
#'   "mesorregiao" ou "uf") — só rotula a saída, não filtra nada.
#' @param tabela_cores Tabela de `carregar_cores_partidos()`. A cor é
#'   calculada aqui (não antes da agregação) porque `cor_partido()` é
#'   determinística por sigla — carregar a cor cedo e tentar arrastá-la
#'   pelo `group_by`/`summarise` de `agregar_por_unidade()` é frágil (fica
#'   fácil esquecer de incluir a coluna e ela some silenciosamente).
#' @param lisa_por_candidato Lista nomeada por `SQ_CANDIDATO` (como
#'   caractere), cada elemento uma lista nomeada por `unidade_id` com o
#'   cluster LISA. Só faz sentido quando a unidade é município — `NULL`
#'   nas demais.
montar_resultado_unidade <- function(dados_agregados, vencedores, unidade,
                                      tabela_cores = carregar_cores_partidos(),
                                      lisa_por_candidato = NULL) {
  candidatos_ids <- unique(dados_agregados$SQ_CANDIDATO)
  votos_totais_escopo <- sum(dados_agregados$votos)

  candidatos <- lapply(candidatos_ids, function(sq) {
    linhas <- dados_agregados[dados_agregados$SQ_CANDIDATO == sq, ]

    item <- list(
      nome = linhas$NM_URNA_CANDIDATO[[1]],
      partido = linhas$SG_PARTIDO[[1]],
      cor = cor_partido(linhas$SG_PARTIDO[[1]], tabela_cores),
      # % do candidato sobre o total de votos de todo o escopo (todas as
      # unidades somadas) — não confundir com `valores`, que é o % por
      # unidade. Usado pelo front-end só pra ordenar o seletor de
      # candidato do mais votado pro menos votado (não é exibido como
      # resultado eleitoral em si).
      pct_geral = round(100 * sum(linhas$votos) / votos_totais_escopo, 2),
      valores = stats::setNames(
        as.list(round(linhas$pct_validos, 2)),
        as.character(linhas$unidade_id)
      )
    )

    chave_lisa <- as.character(sq)
    if (!is.null(lisa_por_candidato) && chave_lisa %in% names(lisa_por_candidato)) {
      item$lisa <- lisa_por_candidato[[chave_lisa]]
    }

    item
  })
  names(candidatos) <- as.character(candidatos_ids)

  vencedores_lista <- lapply(seq_len(nrow(vencedores)), function(i) {
    list(
      sq_candidato = vencedores$SQ_CANDIDATO[[i]],
      nome = vencedores$NM_URNA_CANDIDATO[[i]],
      partido = vencedores$SG_PARTIDO[[i]],
      cor = cor_partido(vencedores$SG_PARTIDO[[i]], tabela_cores),
      pct = round(vencedores$pct_validos[[i]], 2),
      margem = round(vencedores$margem[[i]], 2),
      intensidade = vencedores$intensidade[[i]]
    )
  })
  names(vencedores_lista) <- as.character(vencedores$unidade_id)

  list(
    unidade = unidade,
    cargo = dados_agregados$DS_CARGO[[1]],
    turno = dados_agregados$NR_TURNO[[1]],
    vencedores = vencedores_lista,
    candidatos = candidatos
  )
}

#' Escreve o resultado montado por `montar_resultado_unidade()` como JSON.
exportar_resultado_json <- function(resultado, caminho) {
  dir.create(dirname(caminho), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(resultado, caminho, auto_unbox = TRUE, digits = 4, null = "null", na = "null")
  invisible(caminho)
}

#' Monta o índice de metadados (candidatos/cores/caminhos disponíveis por
#' UF/cargo/turno/unidade) que o front-end usa para popular os seletores
#' sem hardcode.
montar_index <- function(entradas) {
  list(gerado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"), entradas = entradas)
}

exportar_index_json <- function(index, caminho = "output/index.json") {
  dir.create(dirname(caminho), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(index, caminho, auto_unbox = TRUE, digits = 4, null = "null", na = "null")
  invisible(caminho)
}

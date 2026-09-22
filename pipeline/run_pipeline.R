# Orquestração do pipeline: dados brutos do TSE -> output/ (topojson +
# json) pronto pro front-end. Uso:
#   Rscript pipeline/run_pipeline.R --ano=2022 --uf=PE

raiz <- normalizePath(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(trailingOnly = FALSE), value = TRUE))), ".."))
if (length(raiz) == 0 || !dir.exists(file.path(raiz, "R"))) raiz <- getwd()

for (arquivo in c(
  "01_aquisicao.R", "02_leitura.R", "03_limpeza.R", "04_crosswalk.R",
  "05_geo_join.R", "06_cores.R", "07_vencedores.R", "08_lisa.R", "09_exportar.R"
)) {
  source(file.path(raiz, "R", arquivo))
}

UNIDADES_SEM_LISA <- c("microrregiao", "mesorregiao", "uf")

#' Roda o pipeline completo (Governador + Senador) para uma UF, exportando
#' topojson + json de resultado nas 4 unidades de análise.
#'
#' @param ano Ano da eleição.
#' @param uf UF de duas letras (ex. "PE").
#' @param diretorio_saida Raiz de `output/` (pasta é criada se preciso).
processar_uf <- function(ano, uf, diretorio_saida = "output") {
  cli::cli_inform("Processando {uf}/{ano}...")

  info <- obter_dados_tse(ano, uf)
  dados <- ler_votacao_munzona(info$zip, info$membro)
  limpo <- limpar_votacao(dados)

  cw_ibge <- carregar_crosswalk_tse_ibge()
  juntado <- juntar_ibge(limpo, cw_ibge)
  juntado <- juntado[!is.na(juntado$code_muni), ]

  cores_partidos <- carregar_cores_partidos()

  municipios_sf <- obter_municipios_sf(uf)
  meso_sf <- obter_meso_sf(uf)
  micro_sf <- obter_micro_sf(uf)
  cw_meso_micro <- derivar_crosswalk_meso_micro(municipios_sf, meso_sf, micro_sf)

  exportar_topojson(municipios_sf, file.path(diretorio_saida, "geo", sprintf("municipios_%s.topojson", uf)))
  exportar_topojson(meso_sf, file.path(diretorio_saida, "geo", sprintf("mesorregioes_%s.topojson", uf)))
  exportar_topojson(micro_sf, file.path(diretorio_saida, "geo", sprintf("microrregioes_%s.topojson", uf)))

  listw_municipio <- construir_vizinhanca(municipios_sf)

  cargos <- intersect(unique(juntado$DS_CARGO), c("Governador", "Senador"))
  entradas_index <- list()

  for (cargo in cargos) {
    turnos <- sort(unique(juntado$NR_TURNO[juntado$DS_CARGO == cargo]))

    for (turno in turnos) {
      fatia <- juntado[juntado$DS_CARGO == cargo & juntado$NR_TURNO == turno, ]

      for (unidade in names(UNIDADES_COLUNA)) {
        agregado <- agregar_por_unidade(fatia, cw_meso_micro, unidade)
        vencedores <- calcular_vencedor(agregado)

        lisa_por_candidato <- NULL
        if (unidade == "municipio") {
          lisa_por_candidato <- lapply(split(agregado, agregado$SQ_CANDIDATO), function(linhas) {
            ordem <- match(municipios_sf$code_muni, linhas$unidade_id)
            pct <- linhas$pct_validos[ordem]
            pct[is.na(pct)] <- 0
            cluster <- calcular_lisa(pct, listw_municipio, nsim = 199)$cluster
            stats::setNames(as.list(cluster), as.character(municipios_sf$code_muni))
          })
        }

        resultado <- montar_resultado_unidade(agregado, vencedores, unidade, cores_partidos, lisa_por_candidato)
        caminho <- file.path(
          diretorio_saida, "results", ano,
          sprintf("%s_%s_%s_t%d.json", uf, unidade, tolower(cargo), turno)
        )
        exportar_resultado_json(resultado, caminho)

        entradas_index[[length(entradas_index) + 1]] <- list(
          uf = uf, cargo = cargo, turno = turno, unidade = unidade,
          lisa_disponivel = unidade == "municipio",
          arquivo_resultado = caminho,
          arquivo_geo = file.path(diretorio_saida, "geo", switch(unidade,
            municipio = sprintf("municipios_%s.topojson", uf),
            microrregiao = sprintf("microrregioes_%s.topojson", uf),
            mesorregiao = sprintf("mesorregioes_%s.topojson", uf),
            uf = NA_character_
          ))
        )
      }
    }
  }

  entradas_index
}

if (identical(environmentName(globalenv()), "R_GlobalEnv") && sys.nframe() == 0 && !interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  ano <- as.integer(sub("--ano=", "", grep("--ano=", args, value = TRUE)))
  uf <- sub("--uf=", "", grep("--uf=", args, value = TRUE))

  entradas <- processar_uf(ano, uf)
  exportar_index_json(montar_index(entradas))
  cli::cli_inform("Pronto: {length(entradas)} combinações exportadas para output/.")
}

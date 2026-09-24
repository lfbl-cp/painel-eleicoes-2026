# Orquestração do pipeline: dados brutos do TSE -> output/ (topojson +
# json) pronto pro front-end. Uso:
#   Rscript pipeline/run_pipeline.R --ano=2022 --uf=PE
#   Rscript pipeline/run_pipeline.R --ano=2022 --uf=all

raiz <- normalizePath(file.path(dirname(sub("--file=", "", grep("--file=", commandArgs(trailingOnly = FALSE), value = TRUE))), ".."))
if (length(raiz) == 0 || !dir.exists(file.path(raiz, "R"))) raiz <- getwd()

for (arquivo in c(
  "01_aquisicao.R", "02_leitura.R", "03_limpeza.R", "04_crosswalk.R",
  "05_geo_join.R", "06_cores.R", "07_vencedores.R", "08_lisa.R", "09_exportar.R"
)) {
  source(file.path(raiz, "R", arquivo))
}

UNIDADES_SEM_LISA <- c("microrregiao", "mesorregiao", "uf")

# As 26 UFs + DF. Presidente é abrangência federal ("BR" — ver
# R/01_aquisicao.R/CLAUDE.md), processado como mais um valor de `uf` nesta
# lista via a mesma `processar_uf()`: `juntar_ibge()` já só traz cargos
# presentes no arquivo lido, então "BR" naturalmente só produz Presidente
# (a única corrida de abrangência nacional) e as demais UFs só produzem
# Governador/Senador — não precisa de um caminho de código separado.
UFS_BRASIL <- c(
  "AC", "AL", "AM", "AP", "BA", "CE", "DF", "ES", "GO", "MA", "MG", "MS",
  "MT", "PA", "PB", "PE", "PI", "PR", "RJ", "RN", "RO", "RR", "RS", "SC",
  "SE", "SP", "TO"
)

#' geobr não reconhece o pseudo-UF "BR" do TSE (só UFs reais, código de
#' município, ou "all") — mapeia para "all" (todos os municípios do
#' Brasil), que é o que a abrangência federal do Presidente precisa.
uf_para_geobr <- function(uf) if (identical(uf, "BR")) "all" else uf

#' Roda o pipeline completo (Presidente/Governador/Senador, conforme o que
#' existir para a UF pedida) para uma UF, exportando topojson + json de
#' resultado nas 4 unidades de análise.
#'
#' @param ano Ano da eleição.
#' @param uf UF de duas letras (ex. "PE"), ou "BR" para Presidente
#'   (abrangência nacional).
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

  uf_geobr <- uf_para_geobr(uf)
  municipios_sf <- obter_municipios_sf(uf_geobr)
  meso_sf <- obter_meso_sf(uf_geobr)
  micro_sf <- obter_micro_sf(uf_geobr)
  uf_sf <- obter_uf_sf(uf_geobr)
  cw_meso_micro <- derivar_crosswalk_meso_micro(municipios_sf, meso_sf, micro_sf)

  # Município em abrangência nacional ("BR"/Presidente, 5.570 polígonos)
  # pesa demais pro `keep` padrão (0.15 dá ~18MB) — mais agressivo só
  # nesse caso. Por UF já foi validado com o padrão no piloto de PE.
  keep_municipio <- if (identical(uf, "BR")) 0.05 else 0.15
  exportar_topojson(municipios_sf, file.path(diretorio_saida, "geo", sprintf("municipios_%s.topojson", uf)), keep = keep_municipio)
  exportar_topojson(meso_sf, file.path(diretorio_saida, "geo", sprintf("mesorregioes_%s.topojson", uf)))
  exportar_topojson(micro_sf, file.path(diretorio_saida, "geo", sprintf("microrregioes_%s.topojson", uf)))
  exportar_topojson(uf_sf, file.path(diretorio_saida, "geo", sprintf("ufs_%s.topojson", uf)))

  # DF é o único caso nacional com um único município (Brasília — o DF não
  # se subdivide em municípios como os outros estados). `spdep::poly2nb()`
  # quebra com 1 polígono só (não há par de vizinhos possível), e LISA
  # também não faz sentido estatístico nesse caso — sem vizinhos, sem
  # autocorrelação espacial a medir. `lisa_por_candidato` fica `NULL`,
  # igual já acontece pras unidades micro/meso/uf.
  listw_municipio <- if (nrow(municipios_sf) > 1) construir_vizinhanca(municipios_sf) else NULL

  cargos <- intersect(unique(juntado$DS_CARGO), c("Presidente", "Governador", "Senador"))
  entradas_index <- list()

  for (cargo in cargos) {
    turnos <- sort(unique(juntado$NR_TURNO[juntado$DS_CARGO == cargo]))

    for (turno in turnos) {
      fatia <- juntado[juntado$DS_CARGO == cargo & juntado$NR_TURNO == turno, ]

      for (unidade in names(UNIDADES_COLUNA)) {
        agregado <- agregar_por_unidade(fatia, cw_meso_micro, unidade)
        vencedores <- calcular_vencedor(agregado)

        lisa_por_candidato <- NULL
        if (unidade == "municipio" && !is.null(listw_municipio)) {
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
            uf = sprintf("ufs_%s.topojson", uf)
          ))
        )
      }
    }
  }

  entradas_index
}

#' Gera entradas de índice pra "Presidente por UF": reaproveita o
#' resultado já exportado em nível nacional ("BR") pareado com a
#' geometria própria de cada UF, sem recomputar nada — o resultado
#' nacional por município/micro/meso/UF já cobre o Brasil inteiro, e a
#' chave de cada unidade (code_muni etc.) de uma UF é sempre um
#' subconjunto direto da chave nacional, então a mesma geometria "fatiada"
#' (topojson só daquela UF) já filtra pra unidades da UF automaticamente.
#' LISA fica sempre indisponível aqui: foi calculado relativo à
#' vizinhança nacional inteira, mostrar como se fosse local à UF seria
#' enganoso.
gerar_entradas_presidente_por_uf <- function(ano, entradas, ufs, diretorio_saida = "output") {
  turnos_presidente <- sort(unique(vapply(
    Filter(function(e) identical(e$uf, "BR") && identical(e$cargo, "Presidente"), entradas),
    function(e) e$turno, integer(1)
  )))

  extras <- list()
  for (uf in ufs) {
    for (turno in turnos_presidente) {
      for (unidade in names(UNIDADES_COLUNA)) {
        extras[[length(extras) + 1]] <- list(
          uf = uf, cargo = "Presidente", turno = turno, unidade = unidade,
          lisa_disponivel = FALSE,
          arquivo_resultado = file.path(
            diretorio_saida, "results", ano,
            sprintf("BR_%s_presidente_t%d.json", unidade, turno)
          ),
          arquivo_geo = file.path(diretorio_saida, "geo", switch(unidade,
            municipio = sprintf("municipios_%s.topojson", uf),
            microrregiao = sprintf("microrregioes_%s.topojson", uf),
            mesorregiao = sprintf("mesorregioes_%s.topojson", uf),
            uf = sprintf("ufs_%s.topojson", uf)
          ))
        )
      }
    }
  }
  extras
}

#' Monta um resultado "mosaico" nacional pra Governador/Senador na UF
#' "Brasil": cada UF tem sua própria eleição (candidatos diferentes) —
#' "nacional" aqui não é uma agregação estatística, é a união lado a lado
#' dos resultados já exportados de cada UF sobre a geometria nacional.
#' Chaves de unidade (code_muni/code_micro/code_meso/SG_UF) e de
#' candidato (SQ_CANDIDATO) nunca colidem entre UFs (checado
#' manualmente contra o output de 2022: 0 colisões em 426 candidatos
#' distintos), então a união por `c()` é direta, sem risco de uma UF
#' sobrescrever silenciosamente outra. LISA nunca entra aqui: misturar a
#' vizinhança de 27 eleições diferentes não tem sentido estatístico.
montar_mosaico_nacional <- function(ano, cargo, ufs, diretorio_saida = "output") {
  extras <- list()

  for (unidade in names(UNIDADES_COLUNA)) {
    por_turno <- list()

    for (uf in ufs) {
      for (turno in 1:2) {
        caminho <- file.path(
          diretorio_saida, "results", ano,
          sprintf("%s_%s_%s_t%d.json", uf, unidade, tolower(cargo), turno)
        )
        if (!file.exists(caminho)) next
        chave <- as.character(turno)
        por_turno[[chave]] <- c(por_turno[[chave]], list(jsonlite::fromJSON(caminho, simplifyVector = FALSE)))
      }
    }

    for (chave in names(por_turno)) {
      partes <- por_turno[[chave]]
      resultado <- list(
        unidade = unidade,
        cargo = cargo,
        turno = as.integer(chave),
        vencedores = do.call(c, lapply(partes, function(p) p$vencedores)),
        candidatos = do.call(c, lapply(partes, function(p) p$candidatos))
      )

      caminho_saida <- file.path(
        diretorio_saida, "results", ano,
        sprintf("BR_%s_%s_t%s.json", unidade, tolower(cargo), chave)
      )
      exportar_resultado_json(resultado, caminho_saida)

      extras[[length(extras) + 1]] <- list(
        uf = "BR", cargo = cargo, turno = as.integer(chave), unidade = unidade,
        lisa_disponivel = FALSE,
        arquivo_resultado = caminho_saida,
        arquivo_geo = file.path(diretorio_saida, "geo", switch(unidade,
          municipio = "municipios_BR.topojson",
          microrregiao = "microrregioes_BR.topojson",
          mesorregiao = "mesorregioes_BR.topojson",
          uf = "ufs_BR.topojson"
        ))
      )
    }
  }

  extras
}

if (identical(environmentName(globalenv()), "R_GlobalEnv") && sys.nframe() == 0 && !interactive()) {
  args <- commandArgs(trailingOnly = TRUE)
  ano <- as.integer(sub("--ano=", "", grep("--ano=", args, value = TRUE)))
  uf_arg <- sub("--uf=", "", grep("--uf=", args, value = TRUE))

  # "all" = as 27 UFs (Governador/Senador) + "BR" (Presidente, abrangência
  # nacional) — cada uma processada por processar_uf(), que já filtra os
  # cargos existentes no arquivo lido de cada uma.
  ufs <- if (identical(uf_arg, "all")) c(UFS_BRASIL, "BR") else uf_arg

  entradas <- list()
  for (uf in ufs) {
    entradas <- c(entradas, processar_uf(ano, uf))
  }

  # Só faz sentido gerar as combinações extras (Presidente por UF,
  # mosaico nacional de Governador/Senador) numa rodada nacional — pedem
  # o resultado "BR" já exportado acima, que só existe com --uf=all.
  if (identical(uf_arg, "all")) {
    cli::cli_inform("Gerando combinações extras (Presidente por UF, mosaico nacional)...")
    entradas <- c(entradas, gerar_entradas_presidente_por_uf(ano, entradas, UFS_BRASIL))
    entradas <- c(entradas, montar_mosaico_nacional(ano, "Governador", UFS_BRASIL))
    entradas <- c(entradas, montar_mosaico_nacional(ano, "Senador", UFS_BRASIL))
  }

  exportar_index_json(montar_index(entradas))
  cli::cli_inform("Pronto: {length(entradas)} combinações exportadas para output/.")
}

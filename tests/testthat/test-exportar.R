source(testthat::test_path("..", "..", "R", "06_cores.R"))
source(testthat::test_path("..", "..", "R", "09_exportar.R"))

testthat::test_that("montar_resultado_unidade monta vencedores/candidatos com cor calculada na hora", {
  tabela_cores <- tibble::tibble(sigla_partido = c("PT", "PL"), cor_hex = c("#C0272D", "#003882"))

  dados_agregados <- tibble::tibble(
    ANO_ELEICAO = 2022, NR_TURNO = 2, DS_CARGO = "Governador",
    unidade_id = c("A", "B", "A", "B"),
    SQ_CANDIDATO = c(1, 1, 2, 2),
    NM_URNA_CANDIDATO = c("FULANO", "FULANO", "SICRANO", "SICRANO"),
    NM_CANDIDATO = c("FULANO", "FULANO", "SICRANO", "SICRANO"),
    SG_PARTIDO = c("PT", "PT", "PL", "PL"),
    votos = c(60, 40, 40, 60),
    votos_validos_unidade = c(100, 100, 100, 100),
    pct_validos = c(60, 40, 40, 60)
  )
  vencedores <- tibble::tibble(
    unidade_id = c("A", "B"),
    SQ_CANDIDATO = c(1, 2),
    NM_URNA_CANDIDATO = c("FULANO", "SICRANO"),
    SG_PARTIDO = c("PT", "PL"),
    pct_validos = c(60, 60),
    margem = c(20, 20),
    intensidade = c("alta", "baixa")
  )

  resultado <- montar_resultado_unidade(dados_agregados, vencedores, "municipio", tabela_cores)

  testthat::expect_equal(resultado$vencedores$A$nome, "FULANO")
  testthat::expect_equal(resultado$vencedores$A$cor, "#C0272D")
  testthat::expect_equal(resultado$vencedores$A$intensidade, "alta")
  testthat::expect_equal(resultado$vencedores$B$cor, "#003882")
  testthat::expect_equal(resultado$candidatos[["1"]]$cor, "#C0272D")
  testthat::expect_equal(resultado$candidatos[["1"]]$valores$A, 60)
  testthat::expect_equal(resultado$candidatos[["1"]]$pct_geral, 50)
  testthat::expect_null(resultado$candidatos[["1"]]$lisa)
})

testthat::test_that("exportar_resultado_json e exportar_topojson escrevem arquivos válidos", {
  resultado <- list(unidade = "municipio", cargo = "Governador", turno = 2, vencedores = list(), candidatos = list())
  destino_json <- file.path(tempdir(), "teste_resultado.json")
  exportar_resultado_json(resultado, destino_json)

  testthat::expect_true(file.exists(destino_json))
  relido <- jsonlite::fromJSON(destino_json)
  testthat::expect_equal(relido$cargo, "Governador")

  quadrado <- sf::st_sf(id = 1, geometry = sf::st_sfc(sf::st_polygon(list(rbind(
    c(0, 0), c(0, 1), c(1, 1), c(1, 0), c(0, 0)
  )))), crs = 4326)
  destino_topo <- file.path(tempdir(), "teste_geo.topojson")
  exportar_topojson(quadrado, destino_topo, keep = 1)

  testthat::expect_true(file.exists(destino_topo))
  topo <- jsonlite::fromJSON(destino_topo)
  testthat::expect_equal(topo$type, "Topology")
})

testthat::test_that("saída gerada pelo pipeline (PE) tem cor preenchida em todo candidato/vencedor", {
  caminho <- testthat::test_path("..", "..", "output", "results", "2022", "PE_uf_governador_t2.json")
  testthat::skip_if_not(file.exists(caminho), "Saída do pipeline para PE não encontrada — rode pipeline/run_pipeline.R primeiro")

  resultado <- jsonlite::fromJSON(caminho, simplifyVector = FALSE)

  cores_vencedores <- vapply(resultado$vencedores, function(v) is.character(v$cor) && nzchar(v$cor), logical(1))
  cores_candidatos <- vapply(resultado$candidatos, function(c) is.character(c$cor) && nzchar(c$cor), logical(1))

  testthat::expect_true(all(cores_vencedores))
  testthat::expect_true(all(cores_candidatos))
})

source(testthat::test_path("..", "..", "R", "06_cores.R"))

testthat::test_that("gerar_cor_automatica é determinístico e produz hex válido", {
  c1 <- gerar_cor_automatica("PARTIDO_INVENTADO_XYZ")
  c2 <- gerar_cor_automatica("PARTIDO_INVENTADO_XYZ")

  testthat::expect_equal(c1, c2)
  testthat::expect_match(c1, "^#[0-9A-Fa-f]{6}$")
})

testthat::test_that("cor_partido usa a tabela para siglas conhecidas e hash para as demais", {
  tabela <- tibble::tibble(sigla_partido = c("PT", "PL"), cor_hex = c("#C0272D", "#003882"))

  cores <- cor_partido(c("PT", "PL", "PARTIDO_DESCONHECIDO"), tabela)

  testthat::expect_equal(cores[1], "#C0272D")
  testthat::expect_equal(cores[2], "#003882")
  testthat::expect_equal(cores[3], gerar_cor_automatica("PARTIDO_DESCONHECIDO"))
})

testthat::test_that("cor_candidato aplica override quando presente", {
  tabela <- tibble::tibble(sigla_partido = "PT", cor_hex = "#C0272D")
  overrides <- tibble::tibble(sq_candidato = 123, cor_hex = "#000000")

  sem_override <- cor_candidato(456, "PT", tabela, overrides)
  com_override <- cor_candidato(123, "PT", tabela, overrides)

  testthat::expect_equal(sem_override, "#C0272D")
  testthat::expect_equal(com_override, "#000000")
})

testthat::test_that("carregar_cores_partidos lê a tabela de referência versionada", {
  caminho <- testthat::test_path("..", "..", "data-raw", "ref", "partidos_cores.csv")
  testthat::skip_if_not(file.exists(caminho), "partidos_cores.csv não encontrado")

  tabela <- carregar_cores_partidos(caminho)

  testthat::expect_true(nrow(tabela) > 0)
  testthat::expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", tabela$cor_hex)))
  testthat::expect_equal(length(unique(tabela$sigla_partido)), nrow(tabela))
})

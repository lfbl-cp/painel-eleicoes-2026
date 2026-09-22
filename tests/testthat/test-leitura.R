source(testthat::test_path("..", "..", "R", "01_aquisicao.R"))
source(testthat::test_path("..", "..", "R", "02_leitura.R"))

dir_downloads <- testthat::test_path("..", "..", "data-raw", "downloads")
dir_interim <- testthat::test_path("..", "..", "data", "interim")
zip_2022 <- file.path(dir_downloads, "2022", "votacao_candidato_munzona", "votacao_candidato_munzona_2022.zip")

testthat::test_that("governador PE 2022 2o turno bate com resultado oficial", {
  testthat::skip_if_not(file.exists(zip_2022), "ZIP de 2022 não encontrado (ver README_DOWNLOAD_MANUAL.md)")

  info <- obter_dados_tse(2022, "PE", base_dir = dir_downloads)
  dados <- ler_votacao_munzona(info$zip, info$membro, dir_cache = dir_interim)

  gov2 <- dados[dados$DS_CARGO == "Governador" & dados$NR_TURNO == 2, ]
  totais <- sort(tapply(gov2$QT_VOTOS_NOMINAIS_VALIDOS, gov2$NM_URNA_CANDIDATO, sum, na.rm = TRUE), decreasing = TRUE)
  pct_vencedora <- 100 * totais[[1]] / sum(totais)

  testthat::expect_equal(names(totais)[1], "RAQUEL LYRA")
  testthat::expect_equal(pct_vencedora, 58.70, tolerance = 0.05)
  testthat::expect_equal(length(unique(gov2$CD_MUNICIPIO)), 185)
})

testthat::test_that("presidente 2022 2o turno nacional bate com resultado oficial", {
  testthat::skip_if_not(file.exists(zip_2022), "ZIP de 2022 não encontrado (ver README_DOWNLOAD_MANUAL.md)")

  info <- obter_dados_tse(2022, "BR", base_dir = dir_downloads)
  dados <- ler_votacao_munzona(info$zip, info$membro, dir_cache = dir_interim)

  pres2 <- dados[dados$DS_CARGO == "Presidente" & dados$NR_TURNO == 2, ]
  totais <- sort(tapply(pres2$QT_VOTOS_NOMINAIS_VALIDOS, pres2$NM_URNA_CANDIDATO, sum, na.rm = TRUE), decreasing = TRUE)
  pct_vencedor <- 100 * totais[[1]] / sum(totais)

  testthat::expect_equal(names(totais)[1], "LULA")
  testthat::expect_equal(pct_vencedor, 50.90, tolerance = 0.05)
})

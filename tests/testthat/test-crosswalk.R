source(testthat::test_path("..", "..", "R", "01_aquisicao.R"))
source(testthat::test_path("..", "..", "R", "02_leitura.R"))
source(testthat::test_path("..", "..", "R", "03_limpeza.R"))
source(testthat::test_path("..", "..", "R", "04_crosswalk.R"))

dir_downloads <- testthat::test_path("..", "..", "data-raw", "downloads")
dir_interim <- testthat::test_path("..", "..", "data", "interim")
zip_2022 <- file.path(dir_downloads, "2022", "votacao_candidato_munzona", "votacao_candidato_munzona_2022.zip")
linkador <- testthat::test_path("..", "..", "data-raw", "ref", "linkador_bases.xlsx")

testthat::test_that("carregar_crosswalk_tse_ibge lê as 5570 linhas do linkador", {
  testthat::skip_if_not(file.exists(linkador), "linkador_bases.xlsx não encontrado")

  cw <- carregar_crosswalk_tse_ibge(linkador)

  testthat::expect_equal(nrow(cw), 5570)
  testthat::expect_true(all(c("CD_MUNICIPIO", "SG_UF", "code_muni", "name_muni") %in% names(cw)))
  testthat::expect_false(anyNA(cw$code_muni))
})

testthat::test_that("juntar_ibge casa 100% dos municípios de PE", {
  testthat::skip_if_not(file.exists(zip_2022), "ZIP de 2022 não encontrado (ver README_DOWNLOAD_MANUAL.md)")
  testthat::skip_if_not(file.exists(linkador), "linkador_bases.xlsx não encontrado")

  info <- obter_dados_tse(2022, "PE", base_dir = dir_downloads)
  dados <- ler_votacao_munzona(info$zip, info$membro, dir_cache = dir_interim)
  limpo <- limpar_votacao(dados)
  cw <- carregar_crosswalk_tse_ibge(linkador)

  juntado <- juntar_ibge(limpo, cw)

  testthat::expect_equal(length(unique(juntado$CD_MUNICIPIO)), 185)
  testthat::expect_equal(sum(is.na(juntado$code_muni)), 0)
})

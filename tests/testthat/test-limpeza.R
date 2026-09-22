source(testthat::test_path("..", "..", "R", "01_aquisicao.R"))
source(testthat::test_path("..", "..", "R", "02_leitura.R"))
source(testthat::test_path("..", "..", "R", "03_limpeza.R"))

dir_downloads <- testthat::test_path("..", "..", "data-raw", "downloads")
dir_interim <- testthat::test_path("..", "..", "data", "interim")
zip_2022 <- file.path(dir_downloads, "2022", "votacao_candidato_munzona", "votacao_candidato_munzona_2022.zip")

testthat::test_that("limpar_votacao agrega por município e turno com pct somando 100", {
  testthat::skip_if_not(file.exists(zip_2022), "ZIP de 2022 não encontrado (ver README_DOWNLOAD_MANUAL.md)")

  info <- obter_dados_tse(2022, "PE", base_dir = dir_downloads)
  dados <- ler_votacao_munzona(info$zip, info$membro, dir_cache = dir_interim)
  limpo <- limpar_votacao(dados)

  gov2 <- limpo[limpo$DS_CARGO == "Governador" & limpo$NR_TURNO == 2, ]
  soma_pct <- tapply(gov2$pct_validos, gov2$CD_MUNICIPIO, sum)

  testthat::expect_equal(length(unique(gov2$CD_MUNICIPIO)), 185)
  testthat::expect_true(all(abs(soma_pct - 100) < 1e-6))
  testthat::expect_false(any(c("VOTO NULO", "VOTO BRANCO") %in% gov2$NM_URNA_CANDIDATO))
})

testthat::test_that("limpar_votacao mantém só os cargos relevantes", {
  testthat::skip_if_not(file.exists(zip_2022), "ZIP de 2022 não encontrado (ver README_DOWNLOAD_MANUAL.md)")

  info <- obter_dados_tse(2022, "PE", base_dir = dir_downloads)
  dados <- ler_votacao_munzona(info$zip, info$membro, dir_cache = dir_interim)
  limpo <- limpar_votacao(dados)

  testthat::expect_true(all(limpo$DS_CARGO %in% c("Presidente", "Governador", "Senador")))
  testthat::expect_false("Deputado Federal" %in% limpo$DS_CARGO)
})

testthat::test_that("normalizar_nome_candidato deixa só a 1ª letra de cada palavra maiúscula", {
  testthat::expect_equal(normalizar_nome_candidato("RAQUEL LYRA"), "Raquel Lyra")
  testthat::expect_equal(normalizar_nome_candidato("MARILIA ARRAES"), "Marilia Arraes")
  testthat::expect_equal(normalizar_nome_candidato("ANTONIO DE PADUA DOS SANTOS"), "Antonio de Padua dos Santos")
  testthat::expect_equal(normalizar_nome_candidato(NA_character_), NA_character_)
})

testthat::test_that("limpar_votacao normaliza NM_URNA_CANDIDATO", {
  testthat::skip_if_not(file.exists(zip_2022), "ZIP de 2022 não encontrado (ver README_DOWNLOAD_MANUAL.md)")

  info <- obter_dados_tse(2022, "PE", base_dir = dir_downloads)
  dados <- ler_votacao_munzona(info$zip, info$membro, dir_cache = dir_interim)
  limpo <- limpar_votacao(dados)

  testthat::expect_false(any(grepl("^[A-ZÀ-Ú]{2,}", limpo$NM_URNA_CANDIDATO)))
})
